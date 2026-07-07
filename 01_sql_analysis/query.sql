Select * from users
Select * from cards
Select * from transactions
Select * from mcc_codes

--Em cho anh tổng số giao dịch thẻ của Xóm Bank trong năm 2019 — 1 con số. 
--Anh cần cho slide annual review.— Leader team Risk

Select Count(*) as TongSoGD
From transactions t
Where Year(t.[date]) = 2022


Select Min(Year(t.date)) As NamNhoNhat
From transactions t

-- Chị cần top 5 thành phố merchant có nhiều giao dịch nhất + tổng số tiền giao dịch ở đó. 
-- Để team marketing chọn địa điểm chạy campaign thẻ mới.— Head of Cards Marketing

Select Top(5) Count(id) as SoGiaoDich, merchant_city as ThanhPho
From transactions
Where merchant_city not like 'ONLINE'
Group by merchant_city
Order by SoGiaoDich DESC


Select Top(5) Count(id) as SoGiaoDich,
				Sum(amount) as SoTienGiaoDich, 
				merchant_city as ThanhPho
From transactions
Where merchant_city not like 'ONLINE'
Group by merchant_city
Order by SoTienGiaoDich DESC

-- Em cho anh phân phối khách theo credit score chia 5 nhóm: dưới 580 (poor), 580-669 (fair),
-- 670-739 (good), 740-799 (very good), 800+ (excellent).
-- Cần để đánh giá chất lượng portfolio khách.— Chief Risk Officer

Select
	Case
		When u.credit_score < 580 Then 'Poor'
		When 580 <= u.credit_score and u.credit_score < 669 Then 'Fair'
		When 670 <= u.credit_score and u.credit_score < 739 Then 'Good'
		When 740 <= u.credit_score and u.credit_score < 799 Then 'Very Good'
		Else 'Excellent'
	End as [DistributedCus],
	Count (*) as Amount,
	Format (Count(*) * 1.0 / Sum(Count(*)) Over(), 'P2') as [Percentage]

From users u
Group by
	Case
		When u.credit_score < 580 Then 'Poor'
		When 580 <= u.credit_score and u.credit_score < 669 Then 'Fair'
		When 670 <= u.credit_score and u.credit_score < 739 Then 'Good'
		When 740 <= u.credit_score and u.credit_score < 799 Then 'Very Good'
		Else 'Excellent'
	End
Order by Amount




-- Mình đang có bao nhiêu thẻ theo từng brand (Visa, Mastercard, Amex, Discover)? Kèm % trên tổng. 
-- Chị cần để deal với đối tác Visa tuần sau.— Head of Cards Product
Select c.card_brand,
		Count(*) as TongSo,
		Format (Count(*) * 1.0 / Sum(Count(*)) Over(), 'P2' ) as [Percentage]
From cards c
Group by c.card_brand







-- Em cho anh % giao dịch bị lỗi (fail transaction) trên tổng, và chi tiết số lượng theo từng loại lỗi. 
-- Anh cần để báo cáo cho board về chất lượng hệ thống.— Chief Operating Officer

Select t.errors as N'Lỗi Giao Dịch',
				Count(*) as TongSo,
				Format(Count(*) * 1.0 / Sum(Count(*)) Over(), 'P4') as [Percentage]
				
From transactions t
Group by t.errors
Order by TongSo DESC


--Q6: Top 10 khách tiêu nhiều nhất 1 tháng
-- Team marketing cần top 10 khách tiêu nhiều nhất trong 1 tháng bất kỳ 
-- (tính tổng chi tiêu của khách đó trong cùng 1 tháng). 
-- Kèm giới tính + thu nhập năm của khách để phân khúc.— Head of Cards Marketing

--Cách sai
Select Top (10) u.id as ID, 
				gender as Gender, 
				yearly_income [Year Income], 
				Month(date) as Thang,
				Year(date) as Nam,
				Sum(amount) as TongSoTienGD
From users u
Join cards c on c.client_id = u.id
Join transactions t on t.client_id = c.client_id
Where Month(date) = 5 and t.errors is Null and t.amount > 0
Group by u.id, gender, yearly_income, Month(date), Year(date)
Order by TongSoTienGD DESC

--Cách đúng 
Select Top (10) u.id as ID, 
				gender as Gender, 
				yearly_income [Year Income], 
				Month(date) as Thang,
				Year(date) as Nam,
				Sum(amount) as TongSoTienGD
From users u
Join cards c on c.client_id = u.id
Join transactions t on t.card_id = c.id
Where Month(date) = 5 and t.errors is Null and t.amount > 0
Group by u.id, gender, yearly_income, Month(date), Year(date)
Order by TongSoTienGD DESC



Select u.id, c.client_id, c.id, t.card_id, t.client_id
From users u
Join cards c on c.client_id = u.id
Join transactions t on t.client_id = c.client_id


Select *
From users u
Join transactions t on t.client_id = u.id

SELECT 
    t.id AS Transaction_ID,
    t.[date] AS Transaction_Date,
    t.client_id AS Transaction_Client_ID,
    t.card_id AS Transaction_Card_ID,
    t.amount AS Amount
FROM dbo.transactions t
LEFT JOIN dbo.cards c ON t.card_id = c.id
WHERE c.id IS NULL; -- Thẻ không tồn tại trong bảng cards nhưng vẫn có giao dịch
GO


USE [BankingDB];
GO

SELECT 
    -- Cách 1: JOIN trực tiếp (Bất chấp thẻ có tồn tại hay không, miễn khớp client_id là cộng tiền)
    (
        SELECT SUM(t.amount) 
        FROM dbo.users u 
        INNER JOIN dbo.transactions t ON u.id = t.client_id
    ) AS Tong_Tien_Join_Truc_Tiep,

    -- Cách 2: JOIN gián tiếp (Mạch đứt ở bảng cards là mất dòng, không được cộng tiền)
    (
        SELECT SUM(t.amount) 
        FROM dbo.users u 
        INNER JOIN dbo.cards c ON u.id = c.client_id
        INNER JOIN dbo.transactions t ON c.id = t.card_id
    ) AS Tong_Tien_Join_Gian_Tiep;
GO

--Q7: Category merchant chi tiêu nhiều nhất
--Chị cần top 10 category merchant có khách chi tiêu nhiều nhất (chỉ tính giao dịch hợp lệ, không tính refund). 
--Để hiểu khách Xóm Bank tiêu tiền vào đâu.— Head of Retail Banking

Select *
From transactions

Select t.merchant_id, merchant_city, merchant_state
From transactions as t
Group by t.merchant_id, merchant_city, merchant_state



Select *
From transactions t
Join mcc_codes m on m.mcc_id = t.mcc

SELECT TOP (10) 
    m.[description] AS [Category Merchant], 
    m.mcc_id AS [MCC Code],
    SUM(t.amount) AS [TongSoTien]
FROM transactions t
JOIN mcc_codes m ON m.mcc_id = t.mcc
WHERE t.errors IS NULL 
  AND t.amount > 0 -- Loại bỏ hoàn toàn các giao dịch refund/hoàn tiền (thường có giá trị âm)
GROUP BY m.[description], m.mcc_id
ORDER BY [TongSoTien] DESC;


--Q8: Credit utilization trong 30 ngày
--Anh cần check tỷ lệ sử dụng hạn mức thẻ tín dụng của từng khách trong 30 ngày gần nhất (tổng chi tiêu / tổng hạn mức). 
--Chỉ xét thẻ credit, không tính debit/prepaid. Khách utilization cao = rủi ro default cao.— Chief Risk Officer

WITH MaxDateCTE AS (
    -- Bước 1: Tìm ngày lớn nhất (ngày đóng dữ liệu) trong hệ thống
    SELECT MAX([date]) AS MaxDate FROM transactions
),
ClientSpending AS (
    -- Bước 2: Gom nhóm và tính tổng chi tiêu trong 30 ngày cuối cùng của dữ liệu
    SELECT 
        t.client_id,
        t.card_id,
        SUM(t.amount) AS TongChiTieu
    FROM transactions t
    JOIN cards c ON t.card_id = c.id
    CROSS JOIN MaxDateCTE m                      -- Đưa ngày max vào để so sánh
    WHERE c.card_type = 'Credit'
      AND t.errors IS NULL
      AND t.amount > 0
      -- Lấy các giao dịch từ (MaxDate - 30 ngày) cho đến MaxDate
      AND t.[date] >= DATEADD(day, -30, m.MaxDate)
    GROUP BY t.client_id, t.card_id
)
-- Bước 3: Tính toán tỷ lệ Credit Utilization và sắp xếp theo rủi ro giảm dần
SELECT 
    s.client_id AS [Mã Khách Hàng],
    s.card_id AS [Mã Thẻ],
    s.TongChiTieu AS [Tổng Chi Tiêu (30 Ngày Cuối)],
    c.credit_limit AS [Hạn Mức Thẻ],
    ROUND(CAST(s.TongChiTieu AS FLOAT) / NULLIF(c.credit_limit, 0) * 100, 2) AS [Credit Utilization (%)]
FROM ClientSpending s
JOIN cards c ON s.card_id = c.id
Where c.client_id = 200
ORDER BY [Credit Utilization (%)] DESC;


SELECT 
    t.client_id AS [Mã Khách Hàng],
    t.card_id AS [Mã Thẻ],
    SUM(t.amount) AS [Tổng Chi Tiêu],
    MAX(c.credit_limit) AS [Hạn Mức Thẻ], -- Dùng MAX để lấy ra giá trị hạn mức duy nhất của thẻ đó
    ROUND(SUM(t.amount) * 100.0 / NULLIF(MAX(c.credit_limit), 0), 2) AS [Credit Utilization (%)]
FROM transactions t
JOIN cards c ON t.card_id = c.id
WHERE c.card_type = 'Credit'
  AND t.errors IS NULL
  AND t.amount > 0
  -- Lọc 30 ngày kể từ ngày lớn nhất trong dữ liệu
  AND t.[date] >= DATEADD(day, -30, (SELECT MAX([date]) FROM transactions))
GROUP BY t.client_id, t.card_id
ORDER BY t.client_id DESC;







