"""
db.py — Kết nối và đọc dữ liệu từ BankingDW (Data Warehouse).

Đọc qua star schema (Fact join 6 Dim) trả về một DataFrame phẳng để ML.
Tái sử dụng cho cả 3 bài toán (A: fraud, B: credit risk, C: segmentation).

Kết nối: localhost / BankingDW / Windows Authentication / ODBC Driver 17.
"""
from __future__ import annotations

import sys

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

# Windows console mặc định cp1252 — ép UTF-8 để in được tiếng Việt.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

SERVER = "localhost"
DATABASE = "BankingDW"
DRIVER = "ODBC Driver 17 for SQL Server"
OLTP_DATABASE = "BankingDB"  # nguồn OLTP giữ timestamp đầy đủ


def get_engine() -> Engine:
    """Tạo SQLAlchemy engine tới BankingDW (Trusted Connection)."""
    conn_str = (
        f"mssql+pyodbc://@{SERVER}/{DATABASE}"
        f"?driver={DRIVER.replace(' ', '+')}"
        "&trusted_connection=yes"
    )
    return create_engine(conn_str)


def get_oltp_engine() -> Engine:
    """Engine tới BankingDB (OLTP) — nguồn duy nhất còn giữ timestamp giao dịch."""
    conn_str = (
        f"mssql+pyodbc://@{SERVER}/{OLTP_DATABASE}"
        f"?driver={DRIVER.replace(' ', '+')}"
        "&trusted_connection=yes"
    )
    return create_engine(conn_str)


# Đọc timestamp từ OLTP. DW chỉ lưu tới ngày (DateKey YYYYMMDD) nên mất giờ —
# giờ giao dịch và velocity là tín hiệu mạnh cho fraud, phải lấy từ nguồn gốc.
# CHỐNG LEAKAGE: chỉ lấy timestamp (biết ngay khi giao dịch xảy ra), KHÔNG lấy
# errors từ đây — target vẫn tính từ DW.
_OLTP_TIME_SQL = """
SELECT
    id                          AS transaction_id,
    DATEPART(HOUR,   [date])    AS txn_hour,
    DATEPART(WEEKDAY,[date])    AS txn_weekday,
    card_id                     AS card_id,
    CAST([date] AS DATE)        AS txn_date
FROM dbo.transactions
"""


# SQL join Fact + 6 Dim. Chỉ lấy cột phục vụ ML.
# LƯU Ý CHỐNG LEAKAGE: KHÔNG select ErrorType / IsSuccess làm feature.
#   IsSuccess chỉ dùng để tạo target is_error (1 = lỗi).
#   EntryMode / IsOnlineEntry là feature hợp lệ (biết trước khi giao dịch).
_FACT_SQL = """
SELECT
    f.BKTransactionID              AS transaction_id,
    f.DateKey                      AS date_key,
    f.Amount                       AS amount,
    f.BKMerchantID                 AS merchant_id,

    -- Target: 1 = giao dịch lỗi, 0 = thành công
    CASE WHEN tt.IsSuccess = 1 THEN 0 ELSE 1 END AS is_error,

    -- DimDate
    d.[Year]                       AS year,
    d.MonthNumber                  AS month_number,
    d.[Quarter]                    AS quarter,
    d.DayName                      AS day_name,
    d.IsWeekend                    AS is_weekend,

    -- DimCard
    cd.CardBrand                   AS card_brand,
    cd.CardType                    AS card_type,
    cd.CreditLimit                 AS credit_limit,
    cd.CreditLimitBand             AS credit_limit_band,
    cd.HasChip                     AS has_chip,

    -- DimCustomer
    cu.CurrentAge                  AS current_age,
    cu.AgeGroup                    AS age_group,
    cu.Gender                      AS gender,
    cu.YearlyIncome                AS yearly_income,
    cu.IncomeBand                  AS income_band,
    cu.CreditScore                 AS credit_score,
    cu.CreditBand                  AS credit_band,
    cu.DebtToIncome                AS debt_to_income,
    cu.NumCreditCards              AS num_credit_cards,

    -- DimGeography
    g.[State]                      AS state,
    g.IsOnline                     AS is_online,

    -- DimMcc
    m.MccDescription               AS mcc_description,

    -- DimTransactionType (CHỈ entry mode — KHÔNG lấy ErrorType/IsSuccess làm feature)
    tt.EntryMode                   AS entry_mode,
    tt.IsOnlineEntry               AS is_online_entry
FROM dbo.FactTransaction f
JOIN dbo.DimDate            d  ON d.DateKey            = f.DateKey
JOIN dbo.DimCard           cd ON cd.CardKey           = f.CardKey
JOIN dbo.DimCustomer       cu ON cu.CustomerKey       = f.CustomerKey
JOIN dbo.DimGeography      g  ON g.GeographyKey       = f.GeographyKey
JOIN dbo.DimMcc            m  ON m.MccKey             = f.MccKey
JOIN dbo.DimTransactionType tt ON tt.TransactionTypeKey = f.TransactionTypeKey
"""


def read_time_features(engine: Engine | None = None) -> pd.DataFrame:
    """Đọc timestamp từ OLTP và tạo feature thời gian + velocity.

    Trả DataFrame theo transaction_id gồm:
      - txn_hour (0-23), txn_weekday (1-7)
      - is_night (1 khi 0<=hour<6 — khung giờ rủi ro cao)
      - txn_per_card_day: số giao dịch cùng thẻ trong ngày (velocity)

    Velocity tính trên toàn lịch sử — an toàn với leakage vì chỉ đếm số GD
    trong cùng NGÀY (thông tin có sẵn tại thời điểm giao dịch, không nhìn tương lai
    xa). Với dữ liệu snapshot tĩnh, đây là xấp xỉ hợp lý.
    """
    if engine is None:
        engine = get_oltp_engine()
    with engine.connect() as conn:
        t = pd.read_sql(text(_OLTP_TIME_SQL), conn)

    t["is_night"] = ((t["txn_hour"] >= 0) & (t["txn_hour"] < 6)).astype(int)
    # Velocity: đếm số giao dịch cùng (card_id, ngày)
    t["txn_per_card_day"] = t.groupby(["card_id", "txn_date"])["transaction_id"].transform("count")

    return t[["transaction_id", "txn_hour", "txn_weekday", "is_night", "txn_per_card_day"]]


def read_fact_dataset(engine: Engine | None = None,
                      with_time: bool = True) -> pd.DataFrame:
    """Đọc toàn bộ FactTransaction join 6 Dim → DataFrame phẳng (~157k dòng).

    Cột target: `is_error` (1 = lỗi, 0 = thành công).
    Cột `date_key` dùng để split theo thời gian.

    with_time=True: merge thêm feature thời gian từ OLTP (txn_hour, is_night,
    velocity) — DW không lưu giờ nên phải lấy bổ sung từ BankingDB.
    """
    if engine is None:
        engine = get_engine()
    with engine.connect() as conn:
        df = pd.read_sql(text(_FACT_SQL), conn)

    if with_time:
        tf = read_time_features()  # dùng OLTP engine riêng
        df = df.merge(tf, on="transaction_id", how="left")
        # Điền khuyết nếu vài GD không match (an toàn)
        df["txn_hour"] = df["txn_hour"].fillna(df["txn_hour"].median())
        df["txn_weekday"] = df["txn_weekday"].fillna(df["txn_weekday"].median())
        df["is_night"] = df["is_night"].fillna(0).astype(int)
        df["txn_per_card_day"] = df["txn_per_card_day"].fillna(1)

    return df


if __name__ == "__main__":
    # Verify nhanh
    df = read_fact_dataset()
    print(f"Rows           : {len(df):,}")
    print(f"Columns        : {df.shape[1]}")
    print(f"is_error mean  : {df['is_error'].mean():.4f}  "
          f"({df['is_error'].sum():,} errors)")
    print(f"date_key range : {df['date_key'].min()} -> {df['date_key'].max()}")
    print("\nLeakage check (phải KHÔNG có error_type / is_success):")
    leak = [c for c in df.columns if c in ("error_type", "is_success")]
    print("  ->", "CLEAN" if not leak else f"LEAK: {leak}")
