/* =====================================================================
   BankingDW — 07_indexes.sql
   Tạo indexes tối ưu performance cho Data Warehouse.
   Strategy:
     - Clustered Columnstore trên FactTransaction (analytics workload)
     - Non-clustered B-tree trên FK columns của fact (for lookups)
     - Non-clustered trên dimension business keys (for ETL lookups)
     - Non-clustered trên dimension filterx/group-by columns (for Power BI)
   ===================================================================== */

USE BankingDW;

PRINT '================================================================';
PRINT '  BankingDW — INDEX CREATION';
PRINT '================================================================';
PRINT '';


/* =====================================================================
   1. FactTransaction — Columnstore + B-tree indexes
   ===================================================================== */
PRINT '>> FactTransaction indexes ...';

-- Clustered Columnstore Index cho analytic queries (scan-heavy, aggregation)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.FactTransaction')
    AND type_desc = 'CLUSTERED COLUMNSTORE')
BEGIN
    CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactTransaction
        ON dbo.FactTransaction;
    PRINT '   CCI_FactTransaction (Clustered Columnstore) created.';
END
ELSE PRINT '   CCI_FactTransaction already exists.';

-- Non-clustered B-tree on DateKey (date-range filtering)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.FactTransaction')
    AND name = 'IX_Fact_DateKey')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Fact_DateKey
        ON dbo.FactTransaction (DateKey);
    PRINT '   IX_Fact_DateKey created.';
END
ELSE PRINT '   IX_Fact_DateKey already exists.';

-- Non-clustered on CustomerKey (customer drill-down)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.FactTransaction')
    AND name = 'IX_Fact_CustomerKey')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Fact_CustomerKey
        ON dbo.FactTransaction (CustomerKey);
    PRINT '   IX_Fact_CustomerKey created.';
END
ELSE PRINT '   IX_Fact_CustomerKey already exists.';

-- Non-clustered on CardKey
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.FactTransaction')
    AND name = 'IX_Fact_CardKey')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Fact_CardKey
        ON dbo.FactTransaction (CardKey);
    PRINT '   IX_Fact_CardKey created.';
END
ELSE PRINT '   IX_Fact_CardKey already exists.';

-- Non-clustered on GeographyKey
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.FactTransaction')
    AND name = 'IX_Fact_GeographyKey')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Fact_GeographyKey
        ON dbo.FactTransaction (GeographyKey);
    PRINT '   IX_Fact_GeographyKey created.';
END
ELSE PRINT '   IX_Fact_GeographyKey already exists.';

-- Non-clustered on MccKey
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.FactTransaction')
    AND name = 'IX_Fact_MccKey')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Fact_MccKey
        ON dbo.FactTransaction (MccKey);
    PRINT '   IX_Fact_MccKey created.';
END
ELSE PRINT '   IX_Fact_MccKey already exists.';

-- Non-clustered on TransactionTypeKey
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.FactTransaction')
    AND name = 'IX_Fact_TransactionTypeKey')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Fact_TransactionTypeKey
        ON dbo.FactTransaction (TransactionTypeKey);
    PRINT '   IX_Fact_TransactionTypeKey created.';
END
ELSE PRINT '   IX_Fact_TransactionTypeKey already exists.';

-- Degenerate dimension: BKTransactionID (transaction lookup)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.FactTransaction')
    AND name = 'IX_Fact_BKTransactionID')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Fact_BKTransactionID
        ON dbo.FactTransaction (BKTransactionID);
    PRINT '   IX_Fact_BKTransactionID created.';
END
ELSE PRINT '   IX_Fact_BKTransactionID already exists.';

PRINT '';


/* =====================================================================
   2. DimDate — already has clustered PK on DateKey
   ===================================================================== */
PRINT '>> DimDate indexes ...';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.DimDate')
    AND name = 'IX_DimDate_FullDate')
BEGIN
    CREATE NONCLUSTERED INDEX IX_DimDate_FullDate
        ON dbo.DimDate (FullDate);
    PRINT '   IX_DimDate_FullDate created.';
END
ELSE PRINT '   IX_DimDate_FullDate already exists.';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.DimDate')
    AND name = 'IX_DimDate_YearMonth')
BEGIN
    CREATE NONCLUSTERED INDEX IX_DimDate_YearMonth
        ON dbo.DimDate ([Year], MonthNumber);
    PRINT '   IX_DimDate_YearMonth created.';
END
ELSE PRINT '   IX_DimDate_YearMonth already exists.';

PRINT '';


/* =====================================================================
   3. DimCustomer — business key + filter columns
   ===================================================================== */
PRINT '>> DimCustomer indexes ...';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.DimCustomer')
    AND name = 'IX_DimCustomer_BK')
BEGIN
    CREATE NONCLUSTERED INDEX IX_DimCustomer_BK
        ON dbo.DimCustomer (BKCustomerID, RowIsCurrent);
    PRINT '   IX_DimCustomer_BK created.';
END
ELSE PRINT '   IX_DimCustomer_BK already exists.';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.DimCustomer')
    AND name = 'IX_DimCustomer_CreditBand')
BEGIN
    CREATE NONCLUSTERED INDEX IX_DimCustomer_CreditBand
        ON dbo.DimCustomer (CreditBand) INCLUDE (CustomerKey, Gender, AgeGroup, IncomeBand);
    PRINT '   IX_DimCustomer_CreditBand created.';
END
ELSE PRINT '   IX_DimCustomer_CreditBand already exists.';

PRINT '';


/* =====================================================================
   4. DimCard — business key + filter columns
   ===================================================================== */
PRINT '>> DimCard indexes ...';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.DimCard')
    AND name = 'IX_DimCard_BK')
BEGIN
    CREATE NONCLUSTERED INDEX IX_DimCard_BK
        ON dbo.DimCard (BKCardID, RowIsCurrent);
    PRINT '   IX_DimCard_BK created.';
END
ELSE PRINT '   IX_DimCard_BK already exists.';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.DimCard')
    AND name = 'IX_DimCard_CardBrandType')
BEGIN
    CREATE NONCLUSTERED INDEX IX_DimCard_CardBrandType
        ON dbo.DimCard (CardBrand, CardType) INCLUDE (CardKey, CreditLimitBand);
    PRINT '   IX_DimCard_CardBrandType created.';
END
ELSE PRINT '   IX_DimCard_CardBrandType already exists.';

PRINT '';


/* =====================================================================
   5. DimGeography — business key + filter columns
   ===================================================================== */
PRINT '>> DimGeography indexes ...';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.DimGeography')
    AND name = 'IX_DimGeography_BK')
BEGIN
    CREATE NONCLUSTERED INDEX IX_DimGeography_BK
        ON dbo.DimGeography (BKGeoCode, RowIsCurrent);
    PRINT '   IX_DimGeography_BK created.';
END
ELSE PRINT '   IX_DimGeography_BK already exists.';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.DimGeography')
    AND name = 'IX_DimGeography_State')
BEGIN
    CREATE NONCLUSTERED INDEX IX_DimGeography_State
        ON dbo.DimGeography ([State]) INCLUDE (GeographyKey, City, IsOnline);
    PRINT '   IX_DimGeography_State created.';
END
ELSE PRINT '   IX_DimGeography_State already exists.';

PRINT '';


/* =====================================================================
   6. DimMcc — business key
   ===================================================================== */
PRINT '>> DimMcc indexes ...';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.DimMcc')
    AND name = 'IX_DimMcc_BK')
BEGIN
    CREATE NONCLUSTERED INDEX IX_DimMcc_BK
        ON dbo.DimMcc (BKMccID, RowIsCurrent);
    PRINT '   IX_DimMcc_BK created.';
END
ELSE PRINT '   IX_DimMcc_BK already exists.';

PRINT '';


/* =====================================================================
   7. DimTransactionType — business key + filter columns
   ===================================================================== */
PRINT '>> DimTransactionType indexes ...';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.DimTransactionType')
    AND name = 'IX_DimTransType_BK')
BEGIN
    CREATE NONCLUSTERED INDEX IX_DimTransType_BK
        ON dbo.DimTransactionType (BKTransTypeCode, RowIsCurrent);
    PRINT '   IX_DimTransType_BK created.';
END
ELSE PRINT '   IX_DimTransType_BK already exists.';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.DimTransactionType')
    AND name = 'IX_DimTransType_IsSuccess')
BEGIN
    CREATE NONCLUSTERED INDEX IX_DimTransType_IsSuccess
        ON dbo.DimTransactionType (IsSuccess) INCLUDE (TransactionTypeKey, EntryMode, ErrorType);
    PRINT '   IX_DimTransType_IsSuccess created.';
END
ELSE PRINT '   IX_DimTransType_IsSuccess already exists.';

PRINT '';


/* =====================================================================
   SUMMARY
   ===================================================================== */
PRINT '================================================================';
PRINT '  INDEX SUMMARY';
PRINT '================================================================';

SELECT
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    STUFF((
        SELECT ', ' + c.name
        FROM sys.index_columns ic
        JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
        ORDER BY ic.key_ordinal
        FOR XML PATH('')
    ), 1, 2, '') AS KeyColumns
FROM sys.indexes i
WHERE i.object_id IN (
    OBJECT_ID('dbo.FactTransaction'), OBJECT_ID('dbo.DimDate'),
    OBJECT_ID('dbo.DimCustomer'), OBJECT_ID('dbo.DimCard'),
    OBJECT_ID('dbo.DimGeography'), OBJECT_ID('dbo.DimMcc'),
    OBJECT_ID('dbo.DimTransactionType'))
    AND i.name IS NOT NULL
ORDER BY OBJECT_NAME(i.object_id), i.name;

PRINT '';
PRINT '07_indexes.sql complete.';
