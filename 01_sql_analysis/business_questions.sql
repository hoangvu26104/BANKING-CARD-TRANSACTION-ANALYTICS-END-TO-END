/* =====================================================================
   Xóm Bank — Business Questions (refactored & corrected)
   DB: BankingDB on localhost\SQLEXPRESS  | Data: 2022-01-01 .. 2024-10-31
   QUY TẮC VÀNG: nối transactions với cards qua t.card_id = c.id
                 (KHÔNG nối qua client_id — gây fan-out, thổi tổng tiền 3.77x)
   ===================================================================== */
USE [BankingDB];
GO

/* ---------------------------------------------------------------------
   Q1. Tổng số giao dịch theo năm — cho slide annual review (Risk)
   --------------------------------------------------------------------- */
SELECT YEAR([date]) AS Nam, COUNT(*) AS TongSoGD
FROM transactions
GROUP BY YEAR([date])
ORDER BY Nam;
GO

/* ---------------------------------------------------------------------
   Q2. Top 5 thành phố merchant: số GD + tổng tiền (loại ONLINE)
       — chọn địa điểm campaign (Cards Marketing)
   --------------------------------------------------------------------- */
SELECT TOP (5)
       merchant_city                 AS ThanhPho,
       COUNT(id)                     AS SoGiaoDich,
       SUM(amount)                   AS TongTienGiaoDich
FROM transactions
WHERE merchant_city <> 'ONLINE'
GROUP BY merchant_city
ORDER BY SoGiaoDich DESC;       -- đổi sang SUM(amount) DESC nếu cần theo doanh số
GO

/* ---------------------------------------------------------------------
   Q3. Phân phối khách theo credit score (5 nhóm) + %
       — đánh giá chất lượng portfolio (Chief Risk Officer)
   FIX: ranh giới bao trùm (Fair 580–669, Good 670–739, VeryGood 740–799).
        Bản cũ dùng < 669/739/799 làm rơi sai 669/739/799.
   --------------------------------------------------------------------- */
WITH Banded AS (
    SELECT CASE
             WHEN credit_score < 580 THEN 'Poor'
             WHEN credit_score <= 669 THEN 'Fair'
             WHEN credit_score <= 739 THEN 'Good'
             WHEN credit_score <= 799 THEN 'Very Good'
             ELSE 'Excellent'
           END AS CreditBand,
           CASE
             WHEN credit_score < 580 THEN 1
             WHEN credit_score <= 669 THEN 2
             WHEN credit_score <= 739 THEN 3
             WHEN credit_score <= 799 THEN 4
             ELSE 5
           END AS BandOrder
    FROM users
)
SELECT CreditBand,
       COUNT(*)                                                   AS SoKhach,
       FORMAT(COUNT(*) * 1.0 / SUM(COUNT(*)) OVER(), 'P2')        AS PhanTram
FROM Banded
GROUP BY CreditBand, BandOrder
ORDER BY BandOrder;
GO

/* ---------------------------------------------------------------------
   Q4. Phân bố thẻ theo brand + % — deal với Visa (Cards Product)
   --------------------------------------------------------------------- */
SELECT card_brand,
       COUNT(*)                                              AS TongSo,
       FORMAT(COUNT(*) * 1.0 / SUM(COUNT(*)) OVER(), 'P2')   AS PhanTram
FROM cards
GROUP BY card_brand
ORDER BY TongSo DESC;
GO

/* ---------------------------------------------------------------------
   Q5. Tỷ lệ giao dịch lỗi theo từng loại — báo cáo board (COO)
       errors IS NULL = thành công.
   --------------------------------------------------------------------- */
SELECT ISNULL(errors, N'(Thành công)')                        AS LoaiKetQua,
       COUNT(*)                                                AS TongSo,
       FORMAT(COUNT(*) * 1.0 / SUM(COUNT(*)) OVER(), 'P4')     AS PhanTram
FROM transactions
GROUP BY errors
ORDER BY TongSo DESC;
GO

/* ---------------------------------------------------------------------
   Q6. Top 10 khách chi tiêu nhiều nhất trong 1 tháng (tháng 5)
       — phân khúc kèm gender + yearly_income (Cards Marketing)
   JOIN ĐÚNG: t.card_id = c.id. Loại lỗi & refund (amount > 0).
   --------------------------------------------------------------------- */
SELECT TOP (10)
       u.id                       AS KhachID,
       u.gender                   AS GioiTinh,
       u.yearly_income            AS ThuNhapNam,
       YEAR(t.[date])             AS Nam,
       MONTH(t.[date])            AS Thang,
       SUM(t.amount)              AS TongChiTieu
FROM users u
JOIN cards c        ON c.client_id = u.id
JOIN transactions t ON t.card_id   = c.id          -- KHÓA ĐÚNG
WHERE MONTH(t.[date]) = 5
  AND t.errors IS NULL
  AND t.amount > 0
GROUP BY u.id, u.gender, u.yearly_income, YEAR(t.[date]), MONTH(t.[date])
ORDER BY TongChiTieu DESC;
GO

/* ---------------------------------------------------------------------
   Q7. Top 10 category merchant (MCC) theo chi tiêu hợp lệ
       — hiểu khách tiêu vào đâu (Retail Banking)
   --------------------------------------------------------------------- */
SELECT TOP (10)
       m.[description]            AS CategoryMerchant,
       m.mcc_id                   AS MccCode,
       SUM(t.amount)              AS TongChiTieu,
       COUNT(*)                   AS SoGiaoDich
FROM transactions t
JOIN mcc_codes m ON m.mcc_id = t.mcc
WHERE t.errors IS NULL
  AND t.amount > 0               -- loại refund/hoàn tiền (amount < 0)
GROUP BY m.[description], m.mcc_id
ORDER BY TongChiTieu DESC;
GO

/* ---------------------------------------------------------------------
   Q8. Credit utilization 30 ngày gần nhất — chỉ thẻ Credit
       (tổng chi tiêu / hạn mức). Util cao = rủi ro default cao (CRO).
   --------------------------------------------------------------------- */
WITH MaxDate AS (
    SELECT MAX([date]) AS MaxDate FROM transactions
),
Spend AS (
    SELECT t.client_id, t.card_id, SUM(t.amount) AS TongChiTieu
    FROM transactions t
    JOIN cards c   ON t.card_id = c.id
    CROSS JOIN MaxDate d
    WHERE c.card_type = 'Credit'
      AND t.errors IS NULL
      AND t.amount > 0
      AND t.[date] >= DATEADD(DAY, -30, d.MaxDate)
    GROUP BY t.client_id, t.card_id
)
SELECT s.client_id                                                   AS KhachID,
       s.card_id                                                     AS TheID,
       s.TongChiTieu                                                 AS ChiTieu30Ngay,
       c.credit_limit                                                AS HanMuc,
       ROUND(CAST(s.TongChiTieu AS FLOAT)
             / NULLIF(c.credit_limit, 0) * 100, 2)                   AS CreditUtilizationPct
FROM Spend s
JOIN cards c ON s.card_id = c.id
ORDER BY CreditUtilizationPct DESC;
GO
