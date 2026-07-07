/* =====================================================================
   StagingDB — 02_stage.sql
   Tạo database StagingDB riêng và bảng staging mirror cấu trúc nguồn BankingDB.
   Stage giữ nguyên kiểu dữ liệu source, không chứa business logic.
   Thêm 2 cột metadata: StgLoadDate, StgAuditKey.
   ===================================================================== */

-- Create staging database
IF DB_ID('StagingDB') IS NULL
BEGIN
    CREATE DATABASE StagingDB;
END
GO

USE StagingDB;
GO

/* ---------------------------------------------------------------------
   Drop existing staging tables (nếu chạy lại)
   --------------------------------------------------------------------- */
IF OBJECT_ID('dbo.transactions','U') IS NOT NULL DROP TABLE dbo.transactions;
IF OBJECT_ID('dbo.cards','U')        IS NOT NULL DROP TABLE dbo.cards;
IF OBJECT_ID('dbo.users','U')        IS NOT NULL DROP TABLE dbo.users;
IF OBJECT_ID('dbo.mcc_codes','U')    IS NOT NULL DROP TABLE dbo.mcc_codes;
GO

/* ---------------------------------------------------------------------
   dbo.users  —  mirror BankingDB.dbo.users  (2,000 rows)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.users (
    id                  int           NOT NULL
,   current_age         int           NULL
,   retirement_age      int           NULL
,   birth_year          int           NULL
,   birth_month         int           NULL
,   gender              nvarchar(20)  NULL
,   address             nvarchar(255) NULL
,   latitude            nvarchar(20)  NULL
,   longitude           nvarchar(20)  NULL
,   per_capita_income   decimal(12,2) NULL
,   yearly_income       decimal(12,2) NULL
,   total_debt          decimal(12,2) NULL
,   credit_score        int           NULL
,   num_credit_cards    int           NULL
,   StgLoadDate         datetime      NOT NULL DEFAULT GETDATE()
,   StgAuditKey         int           NOT NULL DEFAULT -1
, CONSTRAINT PK_stg_users PRIMARY KEY CLUSTERED (id)
);
GO

/* ---------------------------------------------------------------------
   dbo.cards  —  mirror BankingDB.dbo.cards  (6,146 rows)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.cards (
    id                    int           NOT NULL
,   client_id             int           NOT NULL
,   card_brand            nvarchar(50)  NULL
,   card_type             nvarchar(50)  NULL
,   card_number           nvarchar(20)  NULL
,   expires               date          NULL
,   cvv                   nvarchar(10)  NULL
,   has_chip              nvarchar(10)  NULL
,   num_cards_issued      int           NULL
,   credit_limit          decimal(12,2) NULL
,   acct_open_date        date          NULL
,   year_pin_last_changed int           NULL
,   StgLoadDate           datetime      NOT NULL DEFAULT GETDATE()
,   StgAuditKey           int           NOT NULL DEFAULT -1
, CONSTRAINT PK_stg_cards PRIMARY KEY CLUSTERED (id)
);
GO

/* ---------------------------------------------------------------------
   dbo.transactions  —  mirror BankingDB.dbo.transactions  (157,224 rows)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.transactions (
    id              int            NOT NULL
,   [date]          datetime       NULL
,   client_id       int            NULL
,   card_id         int            NOT NULL
,   amount          decimal(10,2)  NULL
,   use_chip        nvarchar(50)   NULL
,   merchant_id     int            NULL
,   merchant_city   nvarchar(100)  NULL
,   merchant_state  nvarchar(50)   NULL
,   zip             nvarchar(10)   NULL
,   mcc             int            NOT NULL
,   errors          nvarchar(100)  NULL
,   StgLoadDate     datetime       NOT NULL DEFAULT GETDATE()
,   StgAuditKey     int            NOT NULL DEFAULT -1
, CONSTRAINT PK_stg_transactions PRIMARY KEY CLUSTERED (id)
);
GO

/* ---------------------------------------------------------------------
   dbo.mcc_codes  —  mirror BankingDB.dbo.mcc_codes  (109 rows)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.mcc_codes (
    mcc_id       int            NOT NULL
,   description  nvarchar(255)  NULL
,   StgLoadDate  datetime       NOT NULL DEFAULT GETDATE()
,   StgAuditKey  int            NOT NULL DEFAULT -1
, CONSTRAINT PK_stg_mcc_codes PRIMARY KEY CLUSTERED (mcc_id)
);
GO

PRINT '02_stage.sql complete — StagingDB and 4 staging tables created.';
GO
