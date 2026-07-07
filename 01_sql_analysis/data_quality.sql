/* =====================================================================
   Xóm Bank — Data Quality & EDA checks
   Chạy: sqlcmd -S 'localhost\SQLEXPRESS' -E -d BankingDB -i data_quality.sql
   Kết quả tham chiếu (chốt 2026-06-06) ghi trong comment mỗi check.
   ===================================================================== */
USE [BankingDB];
GO

-- Volume tổng quan  -> users 2000 | cards 6146 | transactions 157224 | mcc 109
SELECT 'users' tbl, COUNT(*) n FROM users
UNION ALL SELECT 'cards', COUNT(*) FROM cards
UNION ALL SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL SELECT 'mcc_codes', COUNT(*) FROM mcc_codes;
GO

-- Khoảng thời gian  -> 2022-01-01 .. 2024-10-31
SELECT MIN([date]) MinDate, MAX([date]) MaxDate FROM transactions;
GO

-- DQ1. Orphan card_id (txn trỏ tới card không tồn tại)  -> 0
SELECT COUNT(*) AS OrphanCardTxn
FROM transactions t LEFT JOIN cards c ON t.card_id = c.id
WHERE c.id IS NULL;
GO

-- DQ2. Orphan mcc (txn có mcc không có trong mcc_codes)  -> 0
SELECT COUNT(*) AS OrphanMccTxn
FROM transactions t LEFT JOIN mcc_codes m ON t.mcc = m.mcc_id
WHERE m.mcc_id IS NULL;
GO

-- DQ3. NULL ở cột then chốt của users  -> 0 / 0
SELECT SUM(CASE WHEN credit_score  IS NULL THEN 1 ELSE 0 END) AS NullCreditScore,
       SUM(CASE WHEN yearly_income IS NULL THEN 1 ELSE 0 END) AS NullYearlyIncome
FROM users;
GO

-- DQ4. Phân bố dấu của amount  -> Am 8184 | Khong 121 | Duong 148919
--      amount < 0 = refund/hoàn tiền; lọc amount > 0 khi tính chi tiêu thực.
SELECT SUM(CASE WHEN amount < 0 THEN 1 ELSE 0 END) AS Am,
       SUM(CASE WHEN amount = 0 THEN 1 ELSE 0 END) AS Khong,
       SUM(CASE WHEN amount > 0 THEN 1 ELSE 0 END) AS Duong
FROM transactions;
GO

-- DQ5. Tỷ lệ lỗi  -> success 154486 (98.26%), lỗi nhiều nhất: Insufficient Balance 1760
SELECT ISNULL(errors, '(success)') AS result, COUNT(*) n,
       FORMAT(COUNT(*)*1.0/SUM(COUNT(*)) OVER(), 'P2') pct
FROM transactions GROUP BY errors ORDER BY n DESC;
GO

/* ---------------------------------------------------------------------
   BẪY FAN-OUT (minh chứng) — vì sao phải JOIN qua card_id.
   SAI  (ON t.client_id = c.client_id) -> 25,933,164.00  (gấp 3.77x)
   ĐÚNG (ON t.card_id  = c.id)         ->  6,874,483.49
   Một khách có nhiều thẻ => nối qua client_id nhân bản mỗi giao dịch.
   --------------------------------------------------------------------- */
SELECT
  (SELECT SUM(t.amount) FROM cards c JOIN transactions t ON t.client_id = c.client_id) AS SAI_clientid,
  (SELECT SUM(t.amount) FROM cards c JOIN transactions t ON t.card_id   = c.id)        AS DUNG_cardid;
GO
