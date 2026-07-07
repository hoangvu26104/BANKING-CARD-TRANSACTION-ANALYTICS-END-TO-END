/* =====================================================================
   BankingDW — 05_load_fact.sql
   Load FactTransaction từ StagingDB.dbo.transactions.
   Surrogate key lookup qua 6 dimensions. Unknown member (-1) khi không match.
   JOIN cards qua card_id (KHÔNG client_id) để lấy CustomerKey qua cards.client_id.
   Verify: COUNT=157,224  SUM(Amount)=6,874,483.49
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
SELECT ISNULL(MAX(AuditKey), 0) + 1, -1, '05_load_fact.sql', '1.0',
    GETDATE(), NULL, 'Running', 0, 0, 0
FROM dbo.DimAudit WHERE AuditKey > 0;

SET @AuditKey = SCOPE_IDENTITY();
IF @AuditKey IS NULL
    SET @AuditKey = (SELECT MAX(AuditKey) FROM dbo.DimAudit WHERE AuditKey > 0);

SET IDENTITY_INSERT dbo.DimAudit OFF;

/* --------------------------------------------------------------------- */
/*  Truncate fact before full reload                                      */
/* --------------------------------------------------------------------- */
TRUNCATE TABLE dbo.FactTransaction;

PRINT '>> Loading FactTransaction ...';

INSERT INTO dbo.FactTransaction (
    DateKey, CustomerKey, CardKey, GeographyKey, MccKey, TransactionTypeKey,
    InsertAuditKey, UpdateAuditKey, BKTransactionID, BKMerchantID, Amount)
SELECT
    /* DateKey: YYYYMMDD từ transaction date */
    ISNULL(dd.DateKey, -1),

    /* CustomerKey: lookup qua cards.client_id (JOIN card_id → cards → DimCustomer) */
    ISNULL(dc.CustomerKey, -1),

    /* CardKey: lookup qua card_id */
    ISNULL(dcard.CardKey, -1),

    /* GeographyKey: lookup qua BKGeoCode = city|state|zip */
    ISNULL(dg.GeographyKey, -1),

    /* MccKey: lookup qua mcc */
    ISNULL(dm.MccKey, -1),

    /* TransactionTypeKey: lookup qua BKTransTypeCode */
    ISNULL(dtt.TransactionTypeKey, -1),

    @AuditKey,
    @AuditKey,
    t.id,
    t.merchant_id,
    t.amount

FROM StagingDB.dbo.transactions t

/* DateKey lookup */
LEFT JOIN dbo.DimDate dd
    ON dd.DateKey = CAST(FORMAT(CAST(t.[date] AS DATE), 'yyyyMMdd') AS INT)

/* CardKey lookup — dùng card_id, KHÔNG client_id */
LEFT JOIN dbo.DimCard dcard
    ON dcard.BKCardID = t.card_id
    AND dcard.RowIsCurrent = 'Y'

/* CustomerKey lookup — qua staging cards để lấy client_id rồi match DimCustomer */
LEFT JOIN StagingDB.dbo.cards sc
    ON sc.id = t.card_id
LEFT JOIN dbo.DimCustomer dc
    ON dc.BKCustomerID = sc.client_id
    AND dc.RowIsCurrent = 'Y'

/* GeographyKey lookup — composite key city|state|zip */
LEFT JOIN dbo.DimGeography dg
    ON dg.BKGeoCode = CONCAT(t.merchant_city, '|',
                              ISNULL(t.merchant_state, ''), '|',
                              ISNULL(t.zip, ''))
    AND dg.RowIsCurrent = 'Y'

/* MccKey lookup */
LEFT JOIN dbo.DimMcc dm
    ON dm.BKMccID = t.mcc
    AND dm.RowIsCurrent = 'Y'

/* TransactionTypeKey lookup — composite key mode|success|error */
LEFT JOIN dbo.DimTransactionType dtt
    ON dtt.BKTransTypeCode = CONCAT(
        LEFT(t.use_chip, CHARINDEX(' ', t.use_chip) - 1), '|',
        CASE WHEN t.errors IS NULL THEN '1' ELSE '0' END, '|',
        ISNULL(t.errors, 'None'))
    AND dtt.RowIsCurrent = 'Y';

DECLARE @FactRows INT = @@ROWCOUNT;
PRINT '   FactTransaction: ' + CAST(@FactRows AS VARCHAR(10)) + ' rows';

/* --------------------------------------------------------------------- */
/*  Quick verification                                                    */
/* --------------------------------------------------------------------- */
DECLARE @SumAmt DECIMAL(15,2) = (SELECT SUM(Amount) FROM dbo.FactTransaction);

PRINT '';
PRINT '-- Verification --';
PRINT '   COUNT  : ' + CAST(@FactRows AS VARCHAR(15))
    + CASE WHEN @FactRows = 157224 THEN '  OK' ELSE '  MISMATCH (expected 157224)' END;
PRINT '   SUM    : ' + CAST(@SumAmt AS VARCHAR(20))
    + CASE WHEN @SumAmt = 6874483.49 THEN '  OK' ELSE '  MISMATCH (expected 6874483.49)' END;

DECLARE @UnkDate INT = (SELECT COUNT(*) FROM dbo.FactTransaction WHERE DateKey = -1);
DECLARE @UnkCust INT = (SELECT COUNT(*) FROM dbo.FactTransaction WHERE CustomerKey = -1);
DECLARE @UnkCard INT = (SELECT COUNT(*) FROM dbo.FactTransaction WHERE CardKey = -1);
DECLARE @UnkGeo  INT = (SELECT COUNT(*) FROM dbo.FactTransaction WHERE GeographyKey = -1);
DECLARE @UnkMcc  INT = (SELECT COUNT(*) FROM dbo.FactTransaction WHERE MccKey = -1);
DECLARE @UnkTT   INT = (SELECT COUNT(*) FROM dbo.FactTransaction WHERE TransactionTypeKey = -1);

PRINT '   Unknown DateKey            : ' + CAST(@UnkDate AS VARCHAR(10));
PRINT '   Unknown CustomerKey        : ' + CAST(@UnkCust AS VARCHAR(10));
PRINT '   Unknown CardKey            : ' + CAST(@UnkCard AS VARCHAR(10));
PRINT '   Unknown GeographyKey       : ' + CAST(@UnkGeo  AS VARCHAR(10));
PRINT '   Unknown MccKey             : ' + CAST(@UnkMcc  AS VARCHAR(10));
PRINT '   Unknown TransactionTypeKey : ' + CAST(@UnkTT   AS VARCHAR(10));

/* --------------------------------------------------------------------- */
/*  Finalize audit                                                        */
/* --------------------------------------------------------------------- */
UPDATE dbo.DimAudit
SET ExecutionEndTime = GETDATE(),
    ExecutionStatus  = CASE WHEN @FactRows = 157224 THEN 'Success' ELSE 'Warning' END,
    RowsInserted     = @FactRows
WHERE AuditKey = @AuditKey;

PRINT '';
PRINT '05_load_fact.sql complete.';
