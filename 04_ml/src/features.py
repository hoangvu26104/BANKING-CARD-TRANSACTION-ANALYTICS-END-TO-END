"""
features.py — Feature engineering cho bài A (Fraud/Error detection).

Chuyển DataFrame phẳng từ db.read_fact_dataset() thành ma trận đặc trưng số (X)
và vector target (y). Tái sử dụng cho các bài khác khi cần.

Nguyên tắc chống leakage:
  - KHÔNG dùng error_type / is_success làm feature (đó là target).
  - Encode dùng thống kê chỉ nên fit trên train (frequency encoding ở đây
    được tính trên toàn tập cho đơn giản; với dữ liệu snapshot tĩnh, tần suất
    merchant/mcc ổn định — chấp nhận. Nếu strict, gọi build_features riêng cho
    train rồi map sang test).
"""
from __future__ import annotations

import numpy as np
import pandas as pd

TARGET = "is_error"

# Cột số giữ nguyên
NUMERIC_COLS = [
    "amount",
    "current_age",
    "yearly_income",
    "credit_score",
    "debt_to_income",
    "num_credit_cards",
    "credit_limit",
]

# Feature thời gian từ OLTP (nếu có — DW không lưu giờ). Bổ sung khi with_time=True.
TIME_NUMERIC_COLS = ["txn_hour", "txn_per_card_day"]
TIME_CATEGORICAL_COLS = ["is_night", "txn_weekday"]

# Cột phân loại cardinality thấp → one-hot
CATEGORICAL_COLS = [
    "card_brand",
    "card_type",
    "credit_limit_band",
    "credit_band",
    "income_band",
    "age_group",
    "gender",
    "entry_mode",
    "has_chip",
    "is_online",
    "is_online_entry",
    "is_weekend",
    "quarter",
    "month_number",
    "day_name",
]

# Cột phân loại cardinality cao → frequency encoding
FREQ_ENCODE_COLS = ["mcc_description", "merchant_id"]

# State cardinality trung bình → top-N + Other rồi one-hot
STATE_TOP_N = 15

# Cột KHÔNG bao giờ được là feature (leakage / định danh)
FORBIDDEN = {"is_error", "is_success", "error_type", "transaction_id", "date_key", "year"}


def _freq_encode(s: pd.Series) -> pd.Series:
    """Frequency encoding: mỗi giá trị → tần suất xuất hiện (0..1)."""
    freq = s.value_counts(normalize=True)
    return s.map(freq).astype(float)


def _collapse_state(s: pd.Series, top_n: int = STATE_TOP_N) -> pd.Series:
    """Giữ top-N state phổ biến, còn lại gộp 'Other'."""
    top = s.value_counts().nlargest(top_n).index
    return s.where(s.isin(top), other="Other")


def build_features(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.Series, list[str]]:
    """Trả về (X, y, feature_names).

    X: DataFrame số đã encode. y: Series target is_error.
    """
    data = df.copy()

    # --- target ---
    y = data[TARGET].astype(int)

    # Feature thời gian chỉ dùng khi read_fact_dataset(with_time=True) đã merge.
    has_time = all(c in data.columns for c in TIME_NUMERIC_COLS + TIME_CATEGORICAL_COLS)
    numeric_cols = NUMERIC_COLS + (TIME_NUMERIC_COLS if has_time else [])
    categorical_cols = CATEGORICAL_COLS + (TIME_CATEGORICAL_COLS if has_time else [])

    # --- numeric ---
    X_num = data[numeric_cols].astype(float)
    # Điền khuyết (debt_to_income có thể NaN khi yearly_income = 0)
    X_num = X_num.fillna(X_num.median(numeric_only=True))

    # --- frequency encode (high cardinality) ---
    freq_parts = {}
    for col in FREQ_ENCODE_COLS:
        freq_parts[f"{col}_freq"] = _freq_encode(data[col].astype(str))
    X_freq = pd.DataFrame(freq_parts, index=data.index)

    # --- state: top-N + Other ---
    data["state_grp"] = _collapse_state(data["state"].astype(str))

    # --- categorical one-hot ---
    cat_cols = categorical_cols + ["state_grp"]
    X_cat = pd.get_dummies(
        data[cat_cols].astype(str),
        prefix=cat_cols,
        drop_first=False,
        dtype=float,
    )

    # --- gộp ---
    X = pd.concat([X_num, X_freq, X_cat], axis=1)

    # Làm sạch tên feature: XGBoost/SHAP không nhận '[', ']', '<'.
    X.columns = [
        c.replace("[", "(").replace("]", ")").replace("<", "lt")
        for c in X.columns
    ]

    # --- kiểm tra leakage ---
    leaked = [c for c in X.columns if c in FORBIDDEN]
    if leaked:
        raise ValueError(f"Leakage: feature bị cấm lọt vào X: {leaked}")

    feature_names = list(X.columns)
    return X, y, feature_names


def time_split(df: pd.DataFrame, cutoff: int = 20240101) -> tuple[np.ndarray, np.ndarray]:
    """Split theo thời gian dựa trên date_key (YYYYMMDD dạng int).

    Trả về (train_idx, test_idx) là mảng vị trí (positional index).
    Train: date_key < cutoff (2022-2023). Test: date_key >= cutoff (2024).
    """
    dk = df["date_key"].to_numpy()
    train_mask = dk < cutoff
    test_mask = ~train_mask
    train_idx = np.where(train_mask)[0]
    test_idx = np.where(test_mask)[0]
    return train_idx, test_idx


if __name__ == "__main__":
    import sys
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    from db import read_fact_dataset

    df = read_fact_dataset()
    X, y, names = build_features(df)
    tr, te = time_split(df)

    print(f"X shape        : {X.shape}")
    print(f"y positive rate: {y.mean():.4f}")
    print(f"n features     : {len(names)}")
    print(f"train rows     : {len(tr):,}  (error rate {y.iloc[tr].mean():.4f})")
    print(f"test  rows     : {len(te):,}  (error rate {y.iloc[te].mean():.4f})")
    print("\nLeakage check  :",
          "CLEAN" if not (set(names) & FORBIDDEN) else "LEAK!")
    print("Sample features:", names[:8], "...")
