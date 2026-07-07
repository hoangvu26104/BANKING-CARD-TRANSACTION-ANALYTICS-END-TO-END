/* =====================================================================
   StagingDB — 03_extract.sql
   Full reload từ BankingDB.dbo → StagingDB.dbo.
   Truncate trước, insert toàn bộ. Cập nhật StgLoadDate = GETDATE().
   Audit ghi vào BankingDW.dbo.DimAudit.
   ===================================================================== */

USE BankingDW;

-- Register ETL audit entry
SET IDENTITY_INSERT dbo.DimAudit ON;
DECLARE @AuditKey INT;

INSERT INTO dbo.DimAudit (AuditKey, ParentAuditKey, PackageName, PackageVersion,
    ExecutionStartTime, ExecutionEndTime, ExecutionStatus,
    RowsInserted, RowsUpdated, RowsDeleted)
SELECT ISNULL(MAX(AuditKey), 0) + 1, -1, '03_extract.sql', '1.0',
    GETDATE(), NULL, 'Running', 0, 0, 0
FROM dbo.DimAudit WHERE AuditKey > 0;

SET @AuditKey = SCOPE_IDENTITY();
IF @AuditKey IS NULL
    SET @AuditKey = (SELECT MAX(AuditKey) FROM dbo.DimAudit WHERE AuditKey > 0);

SET IDENTITY_INSERT dbo.DimAudit OFF;

DECLARE @TotalRows INT = 0;
DECLARE @Rows INT;

/* --------------------------------------------------------------------- */
PRINT '>> Extracting StagingDB.dbo.users ...';
TRUNCATE TABLE StagingDB.dbo.users;

INSERT INTO StagingDB.dbo.users (id, current_age, retirement_age, birth_year, birth_month,
    gender, address, latitude, longitude,
    per_capita_income, yearly_income, total_debt,
    credit_score, num_credit_cards, StgLoadDate, StgAuditKey)
SELECT id, current_age, retirement_age, birth_year, birth_month,
    gender, address, latitude, longitude,
    per_capita_income, yearly_income, total_debt,
    credit_score, num_credit_cards, GETDATE(), @AuditKey
FROM BankingDB.dbo.users;

SET @Rows = @@ROWCOUNT;
SET @TotalRows += @Rows;
PRINT '   users: ' + CAST(@Rows AS VARCHAR(10)) + ' rows';

/* --------------------------------------------------------------------- */
PRINT '>> Extracting StagingDB.dbo.cards ...';
TRUNCATE TABLE StagingDB.dbo.cards;

INSERT INTO StagingDB.dbo.cards (id, client_id, card_brand, card_type, card_number,
    expires, cvv, has_chip, num_cards_issued, credit_limit,
    acct_open_date, year_pin_last_changed, StgLoadDate, StgAuditKey)
SELECT id, client_id, card_brand, card_type, card_number,
    expires, cvv, has_chip, num_cards_issued, credit_limit,
    acct_open_date, year_pin_last_changed, GETDATE(), @AuditKey
FROM BankingDB.dbo.cards;

SET @Rows = @@ROWCOUNT;
SET @TotalRows += @Rows;
PRINT '   cards: ' + CAST(@Rows AS VARCHAR(10)) + ' rows';

/* --------------------------------------------------------------------- */
PRINT '>> Extracting StagingDB.dbo.transactions ...';
TRUNCATE TABLE StagingDB.dbo.transactions;

INSERT INTO StagingDB.dbo.transactions (id, [date], client_id, card_id, amount,
    use_chip, merchant_id, merchant_city, merchant_state, zip,
    mcc, errors, StgLoadDate, StgAuditKey)
SELECT id, [date], client_id, card_id, amount,
    use_chip, merchant_id, merchant_city, merchant_state, zip,
    mcc, errors, GETDATE(), @AuditKey
FROM BankingDB.dbo.transactions;

SET @Rows = @@ROWCOUNT;
SET @TotalRows += @Rows;
PRINT '   transactions: ' + CAST(@Rows AS VARCHAR(10)) + ' rows';

/* --------------------------------------------------------------------- */
PRINT '>> Extracting StagingDB.dbo.mcc_codes ...';
TRUNCATE TABLE StagingDB.dbo.mcc_codes;

INSERT INTO StagingDB.dbo.mcc_codes (mcc_id, description, StgLoadDate, StgAuditKey)
SELECT mcc_id, description, GETDATE(), @AuditKey
FROM BankingDB.dbo.mcc_codes;

SET @Rows = @@ROWCOUNT;
SET @TotalRows += @Rows;
PRINT '   mcc_codes: ' + CAST(@Rows AS VARCHAR(10)) + ' rows';

/* --------------------------------------------------------------------- */
-- Update audit record
UPDATE dbo.DimAudit
SET ExecutionEndTime = GETDATE(),
    ExecutionStatus  = 'Success',
    RowsInserted     = @TotalRows
WHERE AuditKey = @AuditKey;

PRINT '';
PRINT '03_extract.sql complete — ' + CAST(@TotalRows AS VARCHAR(10)) + ' total rows extracted to StagingDB.';
