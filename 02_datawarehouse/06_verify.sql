/* =====================================================================
   BankingDW — 06_verify.sql
   Kiểm tra toàn diện Data Warehouse sau khi load xong.
   Checks:
     1. Row counts cho tất cả dimensions và fact
     2. SUM(Amount) = 6,874,483.49
     3. Total Valid Spend = 7,533,887.55 (IsSuccess=1 AND Amount>0)
     4. FK referential integrity (orphan keys trong fact)
     5. Duplicate business keys trong dimensions
     6. Unknown member (-1) tồn tại ở mỗi dimension
     7. SCD housekeeping consistency
     8. DimAudit — tất cả ETL runs completed
   ===================================================================== */

USE BankingDW;

PRINT '================================================================';
PRINT '  BankingDW — COMPREHENSIVE VERIFICATION';
PRINT '================================================================';
PRINT '';

DECLARE @Pass INT = 0, @Fail INT = 0, @Warn INT = 0;
DECLARE @Val INT, @ValDec DECIMAL(15,2), @Msg NVARCHAR(200);

/* =====================================================================
   1. DIMENSION ROW COUNTS (excluding unknown member -1)
   ===================================================================== */
PRINT '-- 1. Dimension Row Counts --';

-- DimDate: expected 1,096 (2022-01-01 → 2024-12-31)
SET @Val = (SELECT COUNT(*) FROM dbo.DimDate WHERE DateKey > 0);
SET @Msg = '   DimDate            : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 1096 THEN '  PASS' ELSE '  FAIL (expected 1096)' END;
PRINT @Msg;
IF @Val = 1096 SET @Pass += 1 ELSE SET @Fail += 1;

-- DimMcc: expected 109
SET @Val = (SELECT COUNT(*) FROM dbo.DimMcc WHERE MccKey > 0);
SET @Msg = '   DimMcc             : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 109 THEN '  PASS' ELSE '  FAIL (expected 109)' END;
PRINT @Msg;
IF @Val = 109 SET @Pass += 1 ELSE SET @Fail += 1;

-- DimGeography: expected 6,715
SET @Val = (SELECT COUNT(*) FROM dbo.DimGeography WHERE GeographyKey > 0);
SET @Msg = '   DimGeography       : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 6715 THEN '  PASS' ELSE '  FAIL (expected 6715)' END;
PRINT @Msg;
IF @Val = 6715 SET @Pass += 1 ELSE SET @Fail += 1;

-- DimTransactionType: expected 27
SET @Val = (SELECT COUNT(*) FROM dbo.DimTransactionType WHERE TransactionTypeKey > 0);
SET @Msg = '   DimTransactionType : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 27 THEN '  PASS' ELSE '  FAIL (expected 27)' END;
PRINT @Msg;
IF @Val = 27 SET @Pass += 1 ELSE SET @Fail += 1;

-- DimCustomer: expected 2,000
SET @Val = (SELECT COUNT(*) FROM dbo.DimCustomer WHERE CustomerKey > 0);
SET @Msg = '   DimCustomer        : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 2000 THEN '  PASS' ELSE '  FAIL (expected 2000)' END;
PRINT @Msg;
IF @Val = 2000 SET @Pass += 1 ELSE SET @Fail += 1;

-- DimCard: expected 6,146
SET @Val = (SELECT COUNT(*) FROM dbo.DimCard WHERE CardKey > 0);
SET @Msg = '   DimCard            : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 6146 THEN '  PASS' ELSE '  FAIL (expected 6146)' END;
PRINT @Msg;
IF @Val = 6146 SET @Pass += 1 ELSE SET @Fail += 1;

PRINT '';


/* =====================================================================
   2. FACT TABLE — ROW COUNT & AMOUNT TOTALS
   ===================================================================== */
PRINT '-- 2. FactTransaction Totals --';

-- COUNT = 157,224
SET @Val = (SELECT COUNT(*) FROM dbo.FactTransaction);
SET @Msg = '   COUNT              : ' + CAST(@Val AS VARCHAR(15))
    + CASE WHEN @Val = 157224 THEN '  PASS' ELSE '  FAIL (expected 157224)' END;
PRINT @Msg;
IF @Val = 157224 SET @Pass += 1 ELSE SET @Fail += 1;

-- SUM(Amount) = 6,874,483.49
SET @ValDec = (SELECT SUM(Amount) FROM dbo.FactTransaction);
SET @Msg = '   SUM(Amount)        : ' + CAST(@ValDec AS VARCHAR(20))
    + CASE WHEN @ValDec = 6874483.49 THEN '  PASS' ELSE '  FAIL (expected 6874483.49)' END;
PRINT @Msg;
IF @ValDec = 6874483.49 SET @Pass += 1 ELSE SET @Fail += 1;

-- Total Valid Spend = 7,533,887.55 (IsSuccess=1 AND Amount>0)
SET @ValDec = (
    SELECT SUM(f.Amount)
    FROM dbo.FactTransaction f
    JOIN dbo.DimTransactionType dtt ON dtt.TransactionTypeKey = f.TransactionTypeKey
    WHERE dtt.IsSuccess = 1 AND f.Amount > 0
);
SET @Msg = '   Valid Spend        : ' + CAST(@ValDec AS VARCHAR(20))
    + CASE WHEN @ValDec = 7533887.55 THEN '  PASS' ELSE '  FAIL (expected 7533887.55)' END;
PRINT @Msg;
IF @ValDec = 7533887.55 SET @Pass += 1 ELSE SET @Fail += 1;

PRINT '';


/* =====================================================================
   3. ORPHAN KEY CHECK — fact rows pointing to non-existent dimension keys
   ===================================================================== */
PRINT '-- 3. FK Referential Integrity (orphan keys) --';

SET @Val = (SELECT COUNT(*) FROM dbo.FactTransaction f
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimDate d WHERE d.DateKey = f.DateKey));
SET @Msg = '   DateKey orphans    : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
PRINT @Msg;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.FactTransaction f
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimCustomer d WHERE d.CustomerKey = f.CustomerKey));
SET @Msg = '   CustomerKey orphans: ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
PRINT @Msg;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.FactTransaction f
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimCard d WHERE d.CardKey = f.CardKey));
SET @Msg = '   CardKey orphans    : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
PRINT @Msg;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.FactTransaction f
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimGeography d WHERE d.GeographyKey = f.GeographyKey));
SET @Msg = '   GeographyKey orphans: ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
PRINT @Msg;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.FactTransaction f
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimMcc d WHERE d.MccKey = f.MccKey));
SET @Msg = '   MccKey orphans     : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
PRINT @Msg;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.FactTransaction f
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimTransactionType d WHERE d.TransactionTypeKey = f.TransactionTypeKey));
SET @Msg = '   TransTypeKey orphans: ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
PRINT @Msg;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

PRINT '';


/* =====================================================================
   4. UNKNOWN MEMBER USAGE — rows pointing to -1 (should be 0)
   ===================================================================== */
PRINT '-- 4. Unknown Member (-1) Usage in Fact --';

SET @Val = (SELECT COUNT(*) FROM dbo.FactTransaction WHERE DateKey = -1);
PRINT '   DateKey = -1       : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  WARN' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Warn += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.FactTransaction WHERE CustomerKey = -1);
PRINT '   CustomerKey = -1   : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  WARN' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Warn += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.FactTransaction WHERE CardKey = -1);
PRINT '   CardKey = -1       : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  WARN' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Warn += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.FactTransaction WHERE GeographyKey = -1);
PRINT '   GeographyKey = -1  : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  WARN' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Warn += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.FactTransaction WHERE MccKey = -1);
PRINT '   MccKey = -1        : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  WARN' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Warn += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.FactTransaction WHERE TransactionTypeKey = -1);
PRINT '   TransTypeKey = -1  : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  WARN' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Warn += 1;

PRINT '';


/* =====================================================================
   5. DUPLICATE BUSINESS KEYS — each BK should appear once per current row
   ===================================================================== */
PRINT '-- 5. Duplicate Business Keys (current rows only) --';

SET @Val = (SELECT COUNT(*) FROM (
    SELECT BKCustomerID FROM dbo.DimCustomer WHERE RowIsCurrent = 'Y' AND CustomerKey > 0
    GROUP BY BKCustomerID HAVING COUNT(*) > 1) x);
PRINT '   DimCustomer dupes  : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM (
    SELECT BKCardID FROM dbo.DimCard WHERE RowIsCurrent = 'Y' AND CardKey > 0
    GROUP BY BKCardID HAVING COUNT(*) > 1) x);
PRINT '   DimCard dupes      : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM (
    SELECT BKGeoCode FROM dbo.DimGeography WHERE RowIsCurrent = 'Y' AND GeographyKey > 0
    GROUP BY BKGeoCode HAVING COUNT(*) > 1) x);
PRINT '   DimGeography dupes : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM (
    SELECT BKMccID FROM dbo.DimMcc WHERE RowIsCurrent = 'Y' AND MccKey > 0
    GROUP BY BKMccID HAVING COUNT(*) > 1) x);
PRINT '   DimMcc dupes       : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM (
    SELECT BKTransTypeCode FROM dbo.DimTransactionType WHERE RowIsCurrent = 'Y' AND TransactionTypeKey > 0
    GROUP BY BKTransTypeCode HAVING COUNT(*) > 1) x);
PRINT '   DimTransType dupes : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

PRINT '';


/* =====================================================================
   6. UNKNOWN MEMBER SEEDS — each dimension must have key = -1
   ===================================================================== */
PRINT '-- 6. Unknown Member Seeds Exist --';

SET @Val = (SELECT COUNT(*) FROM dbo.DimDate WHERE DateKey = -1);
PRINT '   DimDate(-1)        : ' + CASE WHEN @Val = 1 THEN 'PASS' ELSE 'FAIL' END;
IF @Val = 1 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.DimCustomer WHERE CustomerKey = -1);
PRINT '   DimCustomer(-1)    : ' + CASE WHEN @Val = 1 THEN 'PASS' ELSE 'FAIL' END;
IF @Val = 1 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.DimCard WHERE CardKey = -1);
PRINT '   DimCard(-1)        : ' + CASE WHEN @Val = 1 THEN 'PASS' ELSE 'FAIL' END;
IF @Val = 1 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.DimGeography WHERE GeographyKey = -1);
PRINT '   DimGeography(-1)   : ' + CASE WHEN @Val = 1 THEN 'PASS' ELSE 'FAIL' END;
IF @Val = 1 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.DimMcc WHERE MccKey = -1);
PRINT '   DimMcc(-1)         : ' + CASE WHEN @Val = 1 THEN 'PASS' ELSE 'FAIL' END;
IF @Val = 1 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.DimTransactionType WHERE TransactionTypeKey = -1);
PRINT '   DimTransType(-1)   : ' + CASE WHEN @Val = 1 THEN 'PASS' ELSE 'FAIL' END;
IF @Val = 1 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.DimAudit WHERE AuditKey = -1);
PRINT '   DimAudit(-1)       : ' + CASE WHEN @Val = 1 THEN 'PASS' ELSE 'FAIL' END;
IF @Val = 1 SET @Pass += 1 ELSE SET @Fail += 1;

PRINT '';


/* =====================================================================
   7. SCD HOUSEKEEPING — RowIsCurrent consistency
   ===================================================================== */
PRINT '-- 7. SCD Housekeeping --';

SET @Val = (SELECT COUNT(*) FROM dbo.DimCustomer
    WHERE CustomerKey > 0 AND RowIsCurrent = 'Y' AND RowEndDate <> '9999-12-31');
PRINT '   DimCustomer: Current with closed EndDate  : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.DimCard
    WHERE CardKey > 0 AND RowIsCurrent = 'Y' AND RowEndDate <> '9999-12-31');
PRINT '   DimCard: Current with closed EndDate      : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.DimGeography
    WHERE GeographyKey > 0 AND RowIsCurrent = 'Y' AND RowEndDate <> '9999-12-31');
PRINT '   DimGeography: Current with closed EndDate : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.DimMcc
    WHERE MccKey > 0 AND RowIsCurrent = 'Y' AND RowEndDate <> '9999-12-31');
PRINT '   DimMcc: Current with closed EndDate       : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

SET @Val = (SELECT COUNT(*) FROM dbo.DimTransactionType
    WHERE TransactionTypeKey > 0 AND RowIsCurrent = 'Y' AND RowEndDate <> '9999-12-31');
PRINT '   DimTransType: Current with closed EndDate : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  FAIL' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Fail += 1;

PRINT '';


/* =====================================================================
   8. AUDIT TRAIL — all ETL runs should be Success
   ===================================================================== */
PRINT '-- 8. DimAudit ETL Runs --';

SET @Val = (SELECT COUNT(*) FROM dbo.DimAudit
    WHERE AuditKey > 0 AND ExecutionStatus NOT IN ('Success'));
PRINT '   Non-Success runs   : ' + CAST(@Val AS VARCHAR(10))
    + CASE WHEN @Val = 0 THEN '  PASS' ELSE '  WARN' END;
IF @Val = 0 SET @Pass += 1 ELSE SET @Warn += 1;

SELECT AuditKey, PackageName, ExecutionStatus,
    RowsInserted, ExecutionStartTime, ExecutionEndTime
FROM dbo.DimAudit
WHERE AuditKey > 0
ORDER BY AuditKey;

PRINT '';


/* =====================================================================
   9. CROSS-CHECK — Source vs DW record count
   ===================================================================== */
PRINT '-- 9. Source vs DW Cross-Check --';

DECLARE @SrcTxn INT = (SELECT COUNT(*) FROM StagingDB.dbo.transactions);
DECLARE @DwTxn INT  = (SELECT COUNT(*) FROM dbo.FactTransaction);
PRINT '   StagingDB.transactions: ' + CAST(@SrcTxn AS VARCHAR(10));
PRINT '   FactTransaction       : ' + CAST(@DwTxn AS VARCHAR(10));
PRINT '   Match                 : ' + CASE WHEN @SrcTxn = @DwTxn THEN 'PASS' ELSE 'FAIL' END;
IF @SrcTxn = @DwTxn SET @Pass += 1 ELSE SET @Fail += 1;

PRINT '';


/* =====================================================================
   SUMMARY
   ===================================================================== */
PRINT '================================================================';
PRINT '  VERIFICATION SUMMARY';
PRINT '  PASS: ' + CAST(@Pass AS VARCHAR(5))
    + '  |  FAIL: ' + CAST(@Fail AS VARCHAR(5))
    + '  |  WARN: ' + CAST(@Warn AS VARCHAR(5));
PRINT '  Result: ' + CASE
    WHEN @Fail = 0 AND @Warn = 0 THEN 'ALL CHECKS PASSED'
    WHEN @Fail = 0 THEN 'PASSED with warnings'
    ELSE 'FAILED — investigate above'
    END;
PRINT '================================================================';

PRINT '';
PRINT '06_verify.sql complete.';
