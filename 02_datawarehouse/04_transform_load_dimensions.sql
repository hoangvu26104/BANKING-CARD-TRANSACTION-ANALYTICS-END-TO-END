/* =====================================================================
   BankingDW — 04_transform_load_dimensions.sql
   Transform dữ liệu từ StagingDB → load vào 7 dimension tables BankingDW.
   Thứ tự: DimAudit → DimDate → DimMcc → DimGeography →
           DimTransactionType → DimCustomer → DimCard
   Source: StagingDB.dbo.*   |   Target: BankingDW.dbo.*
   ===================================================================== */

USE BankingDW;

/* --------------------------------------------------------------------- */
/*  Audit registration                                                    */
/* --------------------------------------------------------------------- */
SET IDENTITY_INSERT dbo.DimAudit ON;
DECLARE @AuditKey INT;

INSERT INTO dbo.DimAudit (AuditKey, ParentAuditKey, PackageName, PackageVersion,
    ExecutionStartTime, ExecutionEndTime, ExecutionStatus,
    RowsInserted, RowsUpdated, RowsDeleted)
SELECT ISNULL(MAX(AuditKey), 0) + 1, -1, '04_transform_load_dimensions.sql', '1.0',
    GETDATE(), NULL, 'Running', 0, 0, 0
FROM dbo.DimAudit WHERE AuditKey > 0;

SET @AuditKey = SCOPE_IDENTITY();
IF @AuditKey IS NULL
    SET @AuditKey = (SELECT MAX(AuditKey) FROM dbo.DimAudit WHERE AuditKey > 0);

SET IDENTITY_INSERT dbo.DimAudit OFF;

DECLARE @TotalInserted INT = 0;
DECLARE @Rows INT;

/* =====================================================================
   1. DimDate — SCD-0, calendar generation 2022-01-01 → 2024-12-31
   Ghi thêm đến hết 2024 để có buffer cho reporting.
   ===================================================================== */
PRINT '>> Loading DimDate ...';

DELETE FROM dbo.DimDate WHERE DateKey > 0;

;WITH DateSeries AS (
    SELECT CAST('2022-01-01' AS DATE) AS d
    UNION ALL
    SELECT DATEADD(DAY, 1, d) FROM DateSeries WHERE d < '2024-12-31'
)
INSERT INTO dbo.DimDate (DateKey, FullDate, [Year], [Quarter], QuarterName,
    MonthNumber, MonthName, MonthYear, DayOfMonth, DayName, IsWeekend)
SELECT
    CAST(FORMAT(d, 'yyyyMMdd') AS INT)       AS DateKey,
    d                                         AS FullDate,
    YEAR(d)                                   AS [Year],
    DATEPART(QUARTER, d)                      AS [Quarter],
    'Q' + CAST(DATEPART(QUARTER, d) AS CHAR(1)) AS QuarterName,
    MONTH(d)                                  AS MonthNumber,
    DATENAME(MONTH, d)                        AS MonthName,
    FORMAT(d, 'yyyy-MM')                      AS MonthYear,
    DAY(d)                                    AS DayOfMonth,
    DATENAME(WEEKDAY, d)                      AS DayName,
    CASE WHEN DATEPART(WEEKDAY, d) IN (1, 7) THEN 1 ELSE 0 END AS IsWeekend
FROM DateSeries
OPTION (MAXRECURSION 1200);

SET @Rows = @@ROWCOUNT;
SET @TotalInserted += @Rows;
PRINT '   DimDate: ' + CAST(@Rows AS VARCHAR(10)) + ' rows';


/* =====================================================================
   2. DimMcc — SCD-1, full reload from StagingDB.dbo.mcc_codes
   ===================================================================== */
PRINT '>> Loading DimMcc ...';

DELETE FROM dbo.DimMcc WHERE MccKey > 0;

INSERT INTO dbo.DimMcc (BKMccID, MccDescription,
    RowIsCurrent, RowStartDate, RowEndDate, RowChangeReason,
    InsertAuditKey, UpdateAuditKey)
SELECT
    mc.mcc_id,
    mc.[description],
    'Y', GETDATE(), '9999-12-31', 'New',
    @AuditKey, @AuditKey
FROM StagingDB.dbo.mcc_codes mc;

SET @Rows = @@ROWCOUNT;
SET @TotalInserted += @Rows;
PRINT '   DimMcc: ' + CAST(@Rows AS VARCHAR(10)) + ' rows';


/* =====================================================================
   3. DimGeography — SCD-1, distinct merchant city/state/zip
   BKGeoCode = city|state|zip (composite business key)
   IsOnline = 1 khi merchant_city = 'ONLINE'
   ===================================================================== */
PRINT '>> Loading DimGeography ...';

DELETE FROM dbo.DimGeography WHERE GeographyKey > 0;

INSERT INTO dbo.DimGeography (BKGeoCode, City, [State], Zip, IsOnline,
    RowIsCurrent, RowStartDate, RowEndDate, RowChangeReason,
    InsertAuditKey, UpdateAuditKey)
SELECT DISTINCT
    CONCAT(t.merchant_city, '|',
           ISNULL(t.merchant_state, ''), '|',
           ISNULL(t.zip, ''))              AS BKGeoCode,
    t.merchant_city                        AS City,
    t.merchant_state                       AS [State],
    t.zip                                  AS Zip,
    CASE WHEN t.merchant_city = 'ONLINE' THEN 1 ELSE 0 END AS IsOnline,
    'Y', GETDATE(), '9999-12-31', 'New',
    @AuditKey, @AuditKey
FROM StagingDB.dbo.transactions t;

SET @Rows = @@ROWCOUNT;
SET @TotalInserted += @Rows;
PRINT '   DimGeography: ' + CAST(@Rows AS VARCHAR(10)) + ' rows';


/* =====================================================================
   4. DimTransactionType — Junk dimension, SCD-1
   BKTransTypeCode = EntryMode|IsSuccess|ErrorType
   EntryMode: lấy phần đầu của use_chip (Chip/Swipe/Online)
   ===================================================================== */
PRINT '>> Loading DimTransactionType ...';

DELETE FROM dbo.DimTransactionType WHERE TransactionTypeKey > 0;

INSERT INTO dbo.DimTransactionType (BKTransTypeCode, EntryMode, IsSuccess,
    ErrorType, IsOnlineEntry,
    RowIsCurrent, RowStartDate, RowEndDate, RowChangeReason,
    InsertAuditKey, UpdateAuditKey)
SELECT DISTINCT
    CONCAT(
        LEFT(t.use_chip, CHARINDEX(' ', t.use_chip) - 1), '|',
        CASE WHEN t.errors IS NULL THEN '1' ELSE '0' END, '|',
        ISNULL(t.errors, 'None')
    )                                                        AS BKTransTypeCode,
    LEFT(t.use_chip, CHARINDEX(' ', t.use_chip) - 1)         AS EntryMode,
    CASE WHEN t.errors IS NULL THEN 1 ELSE 0 END             AS IsSuccess,
    ISNULL(t.errors, 'None')                                  AS ErrorType,
    CASE WHEN t.use_chip = 'Online Transaction' THEN 1 ELSE 0 END AS IsOnlineEntry,
    'Y', GETDATE(), '9999-12-31', 'New',
    @AuditKey, @AuditKey
FROM StagingDB.dbo.transactions t;

SET @Rows = @@ROWCOUNT;
SET @TotalInserted += @Rows;
PRINT '   DimTransactionType: ' + CAST(@Rows AS VARCHAR(10)) + ' rows';


/* =====================================================================
   5. DimCustomer — SCD-2, initial load from StagingDB.dbo.users
   Business derivations:
     AgeGroup:     <25 / 25-34 / 35-44 / 45-54 / 55-64 / 65+
     IncomeBand:   <30k / 30-60k / 60-100k / 100k+
     CreditBand:   Poor <580 / Fair 580-669 / Good 670-739 / VeryGood 740-799 / Excellent 800+
     DebtToIncome: total_debt / NULLIF(yearly_income, 0)
   ===================================================================== */
PRINT '>> Loading DimCustomer ...';

DELETE FROM dbo.DimCustomer WHERE CustomerKey > 0;

INSERT INTO dbo.DimCustomer (BKCustomerID, Gender, CurrentAge, AgeGroup,
    BirthYear, PerCapitaIncome, YearlyIncome, IncomeBand,
    TotalDebt, DebtToIncome, CreditScore, CreditBand, NumCreditCards,
    RowIsCurrent, RowStartDate, RowEndDate, RowChangeReason,
    InsertAuditKey, UpdateAuditKey)
SELECT
    u.id,
    u.gender,
    u.current_age,
    CASE
        WHEN u.current_age < 25  THEN '<25'
        WHEN u.current_age <= 34 THEN '25-34'
        WHEN u.current_age <= 44 THEN '35-44'
        WHEN u.current_age <= 54 THEN '45-54'
        WHEN u.current_age <= 64 THEN '55-64'
        ELSE '65+'
    END                                                     AS AgeGroup,
    u.birth_year,
    u.per_capita_income,
    u.yearly_income,
    CASE
        WHEN u.yearly_income < 30000   THEN '<30k'
        WHEN u.yearly_income <= 60000  THEN '30-60k'
        WHEN u.yearly_income <= 100000 THEN '60-100k'
        ELSE '100k+'
    END                                                     AS IncomeBand,
    u.total_debt,
    CAST(u.total_debt / NULLIF(u.yearly_income, 0) AS DECIMAL(9,4)) AS DebtToIncome,
    u.credit_score,
    CASE
        WHEN u.credit_score < 580  THEN 'Poor'
        WHEN u.credit_score <= 669 THEN 'Fair'
        WHEN u.credit_score <= 739 THEN 'Good'
        WHEN u.credit_score <= 799 THEN 'Very Good'
        ELSE 'Excellent'
    END                                                     AS CreditBand,
    u.num_credit_cards,
    'Y', GETDATE(), '9999-12-31', 'New',
    @AuditKey, @AuditKey
FROM StagingDB.dbo.users u;

SET @Rows = @@ROWCOUNT;
SET @TotalInserted += @Rows;
PRINT '   DimCustomer: ' + CAST(@Rows AS VARCHAR(10)) + ' rows';


/* =====================================================================
   6. DimCard — SCD-2, initial load from StagingDB.dbo.cards
   Business derivations:
     HasChip:          CASE has_chip WHEN 'YES' THEN 1 ELSE 0
     CreditLimitBand:  0 / <5k / 5-15k / 15-30k / 30k+
   ===================================================================== */
PRINT '>> Loading DimCard ...';

DELETE FROM dbo.DimCard WHERE CardKey > 0;

INSERT INTO dbo.DimCard (BKCardID, CardBrand, CardType,
    CreditLimit, CreditLimitBand, HasChip, NumCardsIssued, AcctOpenDate,
    RowIsCurrent, RowStartDate, RowEndDate, RowChangeReason,
    InsertAuditKey, UpdateAuditKey)
SELECT
    c.id,
    c.card_brand,
    c.card_type,
    c.credit_limit,
    CASE
        WHEN c.credit_limit = 0       THEN '0'
        WHEN c.credit_limit < 5000    THEN '<5k'
        WHEN c.credit_limit <= 15000  THEN '5-15k'
        WHEN c.credit_limit <= 30000  THEN '15-30k'
        ELSE '30k+'
    END                                                     AS CreditLimitBand,
    CASE WHEN c.has_chip = 'YES' THEN 1 ELSE 0 END          AS HasChip,
    c.num_cards_issued,
    c.acct_open_date,
    'Y', GETDATE(), '9999-12-31', 'New',
    @AuditKey, @AuditKey
FROM StagingDB.dbo.cards c;

SET @Rows = @@ROWCOUNT;
SET @TotalInserted += @Rows;
PRINT '   DimCard: ' + CAST(@Rows AS VARCHAR(10)) + ' rows';


/* --------------------------------------------------------------------- */
/*  Finalize audit                                                        */
/* --------------------------------------------------------------------- */
UPDATE dbo.DimAudit
SET ExecutionEndTime = GETDATE(),
    ExecutionStatus  = 'Success',
    RowsInserted     = @TotalInserted
WHERE AuditKey = @AuditKey;

PRINT '';
PRINT '04_transform_load_dimensions.sql complete — '
    + CAST(@TotalInserted AS VARCHAR(10)) + ' total rows loaded into 6 dimensions.';
