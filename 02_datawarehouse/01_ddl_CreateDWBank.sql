/* =====================================================================
   BankingDW — DDL Script (Kimball Star Schema)
   Generated from Kimball Workbook, corrected and aligned to dw_design.md

   Target: BankingDW database, schema [dw]
   Tables: DimDate, DimCustomer, DimCard, DimGeography, DimMcc,
           DimTransactionType, DimAudit, FactTransaction
   ===================================================================== */

-- Create database if not exists
IF DB_ID('BankingDW') IS NULL
BEGIN
    CREATE DATABASE BankingDW;
END
GO

USE BankingDW;
GO

-- Create schema
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dw')
    EXEC('CREATE SCHEMA dw');
GO

/* =====================================================================
   0. Clean up existing objects (FK constraints, views, tables, extended properties)
   ===================================================================== */

-- Drop all FK constraints that reference OR belong to DW tables (allows clean drops)
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += N'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id))
    + '.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id))
    + ' DROP CONSTRAINT ' + QUOTENAME(fk.name) + ';' + CHAR(13)
FROM sys.foreign_keys fk
WHERE OBJECT_NAME(fk.parent_object_id) IN (
    'FactTransaction','FactLoan','DimDate','DimCustomer','DimCard',
    'DimGeography','DimMcc','DimTransactionType','DimAudit',
    'DimAccount','DimDistrict','DimLoanStatus','DimPartnerBank',
    'BlankDimension'
)
   OR OBJECT_NAME(fk.referenced_object_id) IN (
    'FactTransaction','DimDate','DimCustomer','DimCard',
    'DimGeography','DimMcc','DimTransactionType','DimAudit',
    'BlankDimension'
);
EXEC sp_executesql @sql;
GO

-- Drop existing views
IF OBJECT_ID('[dw].[FactTransaction]','V') IS NOT NULL DROP VIEW [dw].[FactTransaction];
IF OBJECT_ID('[dw].[DimDate]','V')         IS NOT NULL DROP VIEW [dw].[DimDate];
IF OBJECT_ID('[dw].[DimCustomer]','V')     IS NOT NULL DROP VIEW [dw].[DimCustomer];
IF OBJECT_ID('[dw].[DimCard]','V')         IS NOT NULL DROP VIEW [dw].[DimCard];
IF OBJECT_ID('[dw].[DimGeography]','V')    IS NOT NULL DROP VIEW [dw].[DimGeography];
IF OBJECT_ID('[dw].[DimMcc]','V')          IS NOT NULL DROP VIEW [dw].[DimMcc];
IF OBJECT_ID('[dw].[DimTransactionType]','V') IS NOT NULL DROP VIEW [dw].[DimTransactionType];
IF OBJECT_ID('[dw].[DimAudit]','V')        IS NOT NULL DROP VIEW [dw].[DimAudit];
GO

-- Drop existing tables (fact first, then dims, then legacy objects)
IF OBJECT_ID('dbo.FactTransaction','U')    IS NOT NULL DROP TABLE dbo.FactTransaction;
IF OBJECT_ID('dbo.FactLoan','U')           IS NOT NULL DROP TABLE dbo.FactLoan;
IF OBJECT_ID('dbo.DimDate','U')            IS NOT NULL DROP TABLE dbo.DimDate;
IF OBJECT_ID('dbo.DimCustomer','U')        IS NOT NULL DROP TABLE dbo.DimCustomer;
IF OBJECT_ID('dbo.DimCard','U')            IS NOT NULL DROP TABLE dbo.DimCard;
IF OBJECT_ID('dbo.DimGeography','U')       IS NOT NULL DROP TABLE dbo.DimGeography;
IF OBJECT_ID('dbo.DimMcc','U')             IS NOT NULL DROP TABLE dbo.DimMcc;
IF OBJECT_ID('dbo.DimTransactionType','U') IS NOT NULL DROP TABLE dbo.DimTransactionType;
IF OBJECT_ID('dbo.DimAccount','U')         IS NOT NULL DROP TABLE dbo.DimAccount;
IF OBJECT_ID('dbo.DimDistrict','U')        IS NOT NULL DROP TABLE dbo.DimDistrict;
IF OBJECT_ID('dbo.DimLoanStatus','U')      IS NOT NULL DROP TABLE dbo.DimLoanStatus;
IF OBJECT_ID('dbo.DimPartnerBank','U')     IS NOT NULL DROP TABLE dbo.DimPartnerBank;
IF OBJECT_ID('dbo.DimAudit','U')           IS NOT NULL DROP TABLE dbo.DimAudit;
IF OBJECT_ID('dbo.BlankDimension','U')     IS NOT NULL DROP TABLE dbo.BlankDimension;
GO


/* =====================================================================
   1. DimDate — SCD-0, NO housekeeping (date dimension, script-generated)
   ===================================================================== */

CREATE TABLE dbo.DimDate (
   [DateKey]       int           NOT NULL
,  [FullDate]      date          NOT NULL
,  [Year]          int           NOT NULL
,  [Quarter]       smallint      NOT NULL
,  [QuarterName]   nvarchar(10)  NOT NULL
,  [MonthNumber]   smallint      NOT NULL
,  [MonthName]     nvarchar(12)  NOT NULL
,  [MonthYear]     char(7)       NOT NULL
,  [DayOfMonth]    smallint      NOT NULL
,  [DayName]       nvarchar(10)  NOT NULL
,  [IsWeekend]     bit           NOT NULL
, CONSTRAINT [PK_dbo.DimDate] PRIMARY KEY CLUSTERED
( [DateKey] )
) ON [PRIMARY];

-- Table extended properties
exec sys.sp_addextendedproperty @name=N'Table Type', @value=N'Dimension', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimDate;
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Date', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimDate;
exec sys.sp_addextendedproperty @name=N'Table Description', @value=N'Date dimension (SCD-0). Generated via calendar script for 2022-01-01 to 2024-12-31.', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimDate;

-- Unknown member seed
INSERT INTO dbo.DimDate (DateKey, FullDate, Year, Quarter, QuarterName, MonthNumber, MonthName, MonthYear, DayOfMonth, DayName, IsWeekend)
VALUES (-1, '1899-12-31', -1, -1, 'Unknown', -1, 'Unknown', 'Unknown', -1, 'Unknown', 0);

-- User-oriented view
GO
CREATE VIEW [dw].[DimDate] AS
SELECT [DateKey]     AS [Date Key]
,  [FullDate]        AS [Full Date]
,  [Year]            AS [Year]
,  [Quarter]         AS [Quarter]
,  [QuarterName]     AS [Quarter Name]
,  [MonthNumber]     AS [Month Number]
,  [MonthName]       AS [Month Name]
,  [MonthYear]       AS [Month Year]
,  [DayOfMonth]      AS [Day Of Month]
,  [DayName]         AS [Day Name]
,  [IsWeekend]       AS [Is Weekend]
FROM dbo.DimDate
GO

-- Column extended properties
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Date Key', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'DateKey';
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Full Date', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'FullDate';
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Year', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'Year';
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Quarter', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'Quarter';
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Quarter Name', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'QuarterName';
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Month Number', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'MonthNumber';
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Month Name', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'MonthName';
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Month Year', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'MonthYear';
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Day Of Month', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'DayOfMonth';
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Day Name', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'DayName';
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Is Weekend', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'IsWeekend';

exec sys.sp_addextendedproperty @name=N'Description', @value=N'Surrogate date YYYYMMDD', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'DateKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Calendar date', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'FullDate';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Year', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'Year';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Quarter 1-4', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'Quarter';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Quarter label', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'QuarterName';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Month 1-12', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'MonthNumber';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Month name', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'MonthName';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'YYYY-MM sortable', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'MonthYear';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Day 1-31', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'DayOfMonth';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Weekday name', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'DayName';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Sat/Sun flag', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'IsWeekend';

exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'key', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'DateKey';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'FullDate';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'Year';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'Quarter';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'QuarterName';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'MonthNumber';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'MonthName';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'MonthYear';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'DayOfMonth';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'DayName';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'IsWeekend';

exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'Calendar script', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'DateKey';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'Date range 2022-2024', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'FullDate';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'YEAR(FullDate)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'Year';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'DATEPART(q,FullDate)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'Quarter';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'''Q''+CAST(quarter)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'QuarterName';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'MONTH(FullDate)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'MonthNumber';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'DATENAME(month,FullDate)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'MonthName';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'FORMAT(FullDate,''yyyy-MM'')', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'MonthYear';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'DAY(FullDate)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'DayOfMonth';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'DATENAME(weekday,FullDate)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'DayName';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'CASE weekday IN (1,7)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'IsWeekend';

exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'DateKey';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'FullDate';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'Year';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'Quarter';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'QuarterName';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'MonthNumber';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'MonthName';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'MonthYear';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'DayOfMonth';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'DayName';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimDate', @level2type=N'COLUMN', @level2name=N'IsWeekend';


/* =====================================================================
   2. DimCustomer — SCD-2 ready, WITH housekeeping
      Source: BankingDB.dbo.users
   ===================================================================== */

CREATE TABLE dbo.DimCustomer (
   [CustomerKey]     int IDENTITY  NOT NULL
,  [BKCustomerID]    int           NOT NULL
,  [Gender]          nvarchar(10)  NOT NULL
,  [CurrentAge]      int           NOT NULL
,  [AgeGroup]        nvarchar(20)  NOT NULL
,  [BirthYear]       int           NOT NULL
,  [PerCapitaIncome] decimal(12,2) NULL
,  [YearlyIncome]    decimal(12,2) NULL
,  [IncomeBand]      nvarchar(20)  NOT NULL
,  [TotalDebt]       decimal(12,2) NULL
,  [DebtToIncome]    decimal(9,4)  NULL
,  [CreditScore]     int           NOT NULL
,  [CreditBand]      nvarchar(15)  NOT NULL
,  [NumCreditCards]   int           NOT NULL
,  [RowIsCurrent]    nchar(1)      NOT NULL
,  [RowStartDate]    datetime      NOT NULL
,  [RowEndDate]      datetime      DEFAULT '9999-12-31' NOT NULL
,  [RowChangeReason] nvarchar(200) NOT NULL
,  [InsertAuditKey]  int           NOT NULL
,  [UpdateAuditKey]  int           NOT NULL
, CONSTRAINT [PK_dbo.DimCustomer] PRIMARY KEY CLUSTERED
( [CustomerKey] )
) ON [PRIMARY];

exec sys.sp_addextendedproperty @name=N'Table Type', @value=N'Dimension', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimCustomer;
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Customer', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimCustomer;
exec sys.sp_addextendedproperty @name=N'Table Description', @value=N'Customer dimension (SCD-2 ready). Source: BankingDB.dbo.users.', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimCustomer;

SET IDENTITY_INSERT dbo.DimCustomer ON;
INSERT INTO dbo.DimCustomer (CustomerKey, BKCustomerID, Gender, CurrentAge, AgeGroup, BirthYear, PerCapitaIncome, YearlyIncome, IncomeBand, TotalDebt, DebtToIncome, CreditScore, CreditBand, NumCreditCards, RowIsCurrent, RowStartDate, RowEndDate, RowChangeReason, InsertAuditKey, UpdateAuditKey)
VALUES (-1, -1, 'Unknown', -1, 'Unknown', -1, 0, 0, 'Unknown', 0, 0, -1, 'Unknown', -1, 'Y', '1899-12-31', '9999-12-31', 'N/A', -1, -1);
SET IDENTITY_INSERT dbo.DimCustomer OFF;

GO
CREATE VIEW [dw].[DimCustomer] AS
SELECT [CustomerKey]     AS [Customer Key]
,  [BKCustomerID]        AS [Customer ID]
,  [Gender]              AS [Gender]
,  [CurrentAge]          AS [Current Age]
,  [AgeGroup]            AS [Age Group]
,  [BirthYear]           AS [Birth Year]
,  [PerCapitaIncome]     AS [Per Capita Income]
,  [YearlyIncome]        AS [Yearly Income]
,  [IncomeBand]          AS [Income Band]
,  [TotalDebt]           AS [Total Debt]
,  [DebtToIncome]        AS [Debt To Income]
,  [CreditScore]         AS [Credit Score]
,  [CreditBand]          AS [Credit Band]
,  [NumCreditCards]      AS [Num Credit Cards]
,  [RowIsCurrent]        AS [Row Is Current]
,  [RowStartDate]        AS [Row Start Date]
,  [RowEndDate]          AS [Row End Date]
,  [RowChangeReason]     AS [Row Change Reason]
,  [InsertAuditKey]      AS [InsertAuditKey]
,  [UpdateAuditKey]      AS [UpdateAuditKey]
FROM dbo.DimCustomer
GO

exec sys.sp_addextendedproperty @name=N'Description', @value=N'Surrogate key', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'CustomerKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Natural key', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'BKCustomerID';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Gender', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'Gender';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Age', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'CurrentAge';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Age group bucket', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'AgeGroup';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Birth year', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'BirthYear';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Per capita income', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'PerCapitaIncome';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Yearly income', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'YearlyIncome';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Income band bucket', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'IncomeBand';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Total debt', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'TotalDebt';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Debt to income ratio', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'DebtToIncome';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Credit score', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'CreditScore';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Credit score band', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'CreditBand';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Number of credit cards', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'NumCreditCards';

exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'key', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'CustomerKey';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'key', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'BKCustomerID';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'Gender';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'CurrentAge';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'AgeGroup';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'BirthYear';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'2', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'PerCapitaIncome';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'2', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'YearlyIncome';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'2', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'IncomeBand';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'2', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'TotalDebt';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'2', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'DebtToIncome';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'2', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'CreditScore';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'2', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'CreditBand';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'NumCreditCards';

exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'CustomerKey';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'BKCustomerID';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'Gender';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'CurrentAge';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'AgeGroup';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'BirthYear';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'PerCapitaIncome';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'YearlyIncome';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'IncomeBand';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'TotalDebt';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'DebtToIncome';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'CreditScore';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'CreditBand';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCustomer', @level2type=N'COLUMN', @level2name=N'NumCreditCards';


/* =====================================================================
   3. DimCard — SCD-2 ready, WITH housekeeping
      Source: BankingDB.dbo.cards
   ===================================================================== */

CREATE TABLE dbo.DimCard (
   [CardKey]          int IDENTITY  NOT NULL
,  [BKCardID]         int           NOT NULL
,  [CardBrand]        nvarchar(20)  NOT NULL
,  [CardType]         nvarchar(20)  NOT NULL
,  [CreditLimit]      decimal(12,2) NULL
,  [CreditLimitBand]  nvarchar(15)  NOT NULL
,  [HasChip]          bit           NOT NULL
,  [NumCardsIssued]   int           NOT NULL
,  [AcctOpenDate]     date          NULL
,  [RowIsCurrent]     nchar(1)      NOT NULL
,  [RowStartDate]     datetime      NOT NULL
,  [RowEndDate]       datetime      DEFAULT '9999-12-31' NOT NULL
,  [RowChangeReason]  nvarchar(200) NOT NULL
,  [InsertAuditKey]   int           NOT NULL
,  [UpdateAuditKey]   int           NOT NULL
, CONSTRAINT [PK_dbo.DimCard] PRIMARY KEY CLUSTERED
( [CardKey] )
) ON [PRIMARY];

exec sys.sp_addextendedproperty @name=N'Table Type', @value=N'Dimension', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimCard;
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Card', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimCard;
exec sys.sp_addextendedproperty @name=N'Table Description', @value=N'Card dimension (SCD-2 ready). Source: BankingDB.dbo.cards.', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimCard;

SET IDENTITY_INSERT dbo.DimCard ON;
INSERT INTO dbo.DimCard (CardKey, BKCardID, CardBrand, CardType, CreditLimit, CreditLimitBand, HasChip, NumCardsIssued, AcctOpenDate, RowIsCurrent, RowStartDate, RowEndDate, RowChangeReason, InsertAuditKey, UpdateAuditKey)
VALUES (-1, -1, 'Unknown', 'Unknown', 0, 'Unknown', 0, -1, '1900-01-01', 'Y', '1899-12-31', '9999-12-31', 'N/A', -1, -1);
SET IDENTITY_INSERT dbo.DimCard OFF;

GO
CREATE VIEW [dw].[DimCard] AS
SELECT [CardKey]          AS [Card Key]
,  [BKCardID]             AS [Card ID]
,  [CardBrand]            AS [Card Brand]
,  [CardType]             AS [Card Type]
,  [CreditLimit]          AS [Credit Limit]
,  [CreditLimitBand]      AS [Credit Limit Band]
,  [HasChip]              AS [Has Chip]
,  [NumCardsIssued]       AS [Num Cards Issued]
,  [AcctOpenDate]         AS [Acct Open Date]
,  [RowIsCurrent]         AS [Row Is Current]
,  [RowStartDate]         AS [Row Start Date]
,  [RowEndDate]           AS [Row End Date]
,  [RowChangeReason]      AS [Row Change Reason]
,  [InsertAuditKey]       AS [InsertAuditKey]
,  [UpdateAuditKey]       AS [UpdateAuditKey]
FROM dbo.DimCard
GO

exec sys.sp_addextendedproperty @name=N'Description', @value=N'Surrogate key', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'CardKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Natural key (cards.id)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'BKCardID';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Card network', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'CardBrand';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Card type', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'CardType';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Credit limit', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'CreditLimit';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Credit limit band', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'CreditLimitBand';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Has chip', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'HasChip';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Num cards issued', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'NumCardsIssued';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Account open date', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'AcctOpenDate';

exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'key', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'CardKey';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'key', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'BKCardID';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'CardBrand';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'CardType';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'2', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'CreditLimit';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'2', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'CreditLimitBand';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'HasChip';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'NumCardsIssued';
exec sys.sp_addextendedproperty @name=N'SCD  Type', @value=N'1', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'AcctOpenDate';

exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'CardKey';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'BKCardID';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'CardBrand';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'CardType';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'CreditLimit';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'Derived', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'CreditLimitBand';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'HasChip';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'NumCardsIssued';
exec sys.sp_addextendedproperty @name=N'Source System', @value=N'BankingDB', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimCard', @level2type=N'COLUMN', @level2name=N'AcctOpenDate';


/* =====================================================================
   4. DimGeography — SCD-1, WITH housekeeping
      Source: BankingDB.dbo.transactions (distinct city/state/zip)
   ===================================================================== */

CREATE TABLE dbo.DimGeography (
   [GeographyKey]    int IDENTITY  NOT NULL
,  [BKGeoCode]       nvarchar(120) NOT NULL
,  [City]            nvarchar(50)  NOT NULL
,  [State]           nvarchar(50)  NULL
,  [Zip]             nvarchar(10)  NULL
,  [IsOnline]        bit           NOT NULL
,  [RowIsCurrent]    nchar(1)      NOT NULL
,  [RowStartDate]    datetime      NOT NULL
,  [RowEndDate]      datetime      DEFAULT '9999-12-31' NOT NULL
,  [RowChangeReason] nvarchar(200) NOT NULL
,  [InsertAuditKey]  int           NOT NULL
,  [UpdateAuditKey]  int           NOT NULL
, CONSTRAINT [PK_dbo.DimGeography] PRIMARY KEY CLUSTERED
( [GeographyKey] )
) ON [PRIMARY];

exec sys.sp_addextendedproperty @name=N'Table Type', @value=N'Dimension', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimGeography;
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Geography', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimGeography;
exec sys.sp_addextendedproperty @name=N'Table Description', @value=N'Geography dimension (SCD-1). Distinct merchant city/state/zip from transactions.', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimGeography;

SET IDENTITY_INSERT dbo.DimGeography ON;
INSERT INTO dbo.DimGeography (GeographyKey, BKGeoCode, City, State, Zip, IsOnline, RowIsCurrent, RowStartDate, RowEndDate, RowChangeReason, InsertAuditKey, UpdateAuditKey)
VALUES (-1, 'Unknown', 'Unknown', 'Unknown', 'Unknown', 0, 'Y', '1899-12-31', '9999-12-31', 'N/A', -1, -1);
SET IDENTITY_INSERT dbo.DimGeography OFF;

GO
CREATE VIEW [dw].[DimGeography] AS
SELECT [GeographyKey]    AS [Geography Key]
,  [BKGeoCode]           AS [Geo Code]
,  [City]                AS [City]
,  [State]               AS [State]
,  [Zip]                 AS [Zip]
,  [IsOnline]            AS [Is Online]
,  [RowIsCurrent]        AS [Row Is Current]
,  [RowStartDate]        AS [Row Start Date]
,  [RowEndDate]          AS [Row End Date]
,  [RowChangeReason]     AS [Row Change Reason]
,  [InsertAuditKey]      AS [InsertAuditKey]
,  [UpdateAuditKey]      AS [UpdateAuditKey]
FROM dbo.DimGeography
GO

exec sys.sp_addextendedproperty @name=N'Description', @value=N'Surrogate key', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimGeography', @level2type=N'COLUMN', @level2name=N'GeographyKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'city|state|zip', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimGeography', @level2type=N'COLUMN', @level2name=N'BKGeoCode';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Merchant city', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimGeography', @level2type=N'COLUMN', @level2name=N'City';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Merchant state', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimGeography', @level2type=N'COLUMN', @level2name=N'State';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'ZIP code', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimGeography', @level2type=N'COLUMN', @level2name=N'Zip';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Online flag', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimGeography', @level2type=N'COLUMN', @level2name=N'IsOnline';


/* =====================================================================
   5. DimMcc — SCD-1, WITH housekeeping
      Source: BankingDB.dbo.mcc_codes
   ===================================================================== */

CREATE TABLE dbo.DimMcc (
   [MccKey]           int IDENTITY  NOT NULL
,  [BKMccID]          int           NOT NULL
,  [MccDescription]   nvarchar(100) NOT NULL
,  [RowIsCurrent]     nchar(1)      NOT NULL
,  [RowStartDate]     datetime      NOT NULL
,  [RowEndDate]       datetime      DEFAULT '9999-12-31' NOT NULL
,  [RowChangeReason]  nvarchar(200) NOT NULL
,  [InsertAuditKey]   int           NOT NULL
,  [UpdateAuditKey]   int           NOT NULL
, CONSTRAINT [PK_dbo.DimMcc] PRIMARY KEY CLUSTERED
( [MccKey] )
) ON [PRIMARY];

exec sys.sp_addextendedproperty @name=N'Table Type', @value=N'Dimension', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimMcc;
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'MCC', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimMcc;
exec sys.sp_addextendedproperty @name=N'Table Description', @value=N'MCC dimension (SCD-1). Source: BankingDB.dbo.mcc_codes.', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimMcc;

SET IDENTITY_INSERT dbo.DimMcc ON;
INSERT INTO dbo.DimMcc (MccKey, BKMccID, MccDescription, RowIsCurrent, RowStartDate, RowEndDate, RowChangeReason, InsertAuditKey, UpdateAuditKey)
VALUES (-1, -1, 'Unknown', 'Y', '1899-12-31', '9999-12-31', 'N/A', -1, -1);
SET IDENTITY_INSERT dbo.DimMcc OFF;

GO
CREATE VIEW [dw].[DimMcc] AS
SELECT [MccKey]           AS [MCC Key]
,  [BKMccID]              AS [MCC ID]
,  [MccDescription]       AS [MCC Description]
,  [RowIsCurrent]         AS [Row Is Current]
,  [RowStartDate]         AS [Row Start Date]
,  [RowEndDate]           AS [Row End Date]
,  [RowChangeReason]      AS [Row Change Reason]
,  [InsertAuditKey]       AS [InsertAuditKey]
,  [UpdateAuditKey]       AS [UpdateAuditKey]
FROM dbo.DimMcc
GO

exec sys.sp_addextendedproperty @name=N'Description', @value=N'Surrogate key', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimMcc', @level2type=N'COLUMN', @level2name=N'MccKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Natural key (mcc_id)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimMcc', @level2type=N'COLUMN', @level2name=N'BKMccID';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'MCC description', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimMcc', @level2type=N'COLUMN', @level2name=N'MccDescription';


/* =====================================================================
   6. DimTransactionType — Junk dimension, SCD-1, WITH housekeeping
      Source: BankingDB.dbo.transactions (use_chip, errors)
      NOTE: NumCreditCards removed (does not belong in this dimension)
   ===================================================================== */

CREATE TABLE dbo.DimTransactionType (
   [TransactionTypeKey] int IDENTITY  NOT NULL
,  [BKTransTypeCode]    nvarchar(120) NOT NULL
,  [EntryMode]          nvarchar(10)  NOT NULL
,  [IsSuccess]          bit           NOT NULL
,  [ErrorType]          nvarchar(60)  NOT NULL
,  [IsOnlineEntry]      bit           NOT NULL
,  [RowIsCurrent]       nchar(1)      NOT NULL
,  [RowStartDate]       datetime      NOT NULL
,  [RowEndDate]         datetime      DEFAULT '9999-12-31' NOT NULL
,  [RowChangeReason]    nvarchar(200) NOT NULL
,  [InsertAuditKey]     int           NOT NULL
,  [UpdateAuditKey]     int           NOT NULL
, CONSTRAINT [PK_dbo.DimTransactionType] PRIMARY KEY CLUSTERED
( [TransactionTypeKey] )
) ON [PRIMARY];

exec sys.sp_addextendedproperty @name=N'Table Type', @value=N'Dimension', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimTransactionType;
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Transaction Type', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimTransactionType;
exec sys.sp_addextendedproperty @name=N'Table Description', @value=N'Junk dimension (SCD-1). Combines entry mode, success/error flags from transactions.', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimTransactionType;

SET IDENTITY_INSERT dbo.DimTransactionType ON;
INSERT INTO dbo.DimTransactionType (TransactionTypeKey, BKTransTypeCode, EntryMode, IsSuccess, ErrorType, IsOnlineEntry, RowIsCurrent, RowStartDate, RowEndDate, RowChangeReason, InsertAuditKey, UpdateAuditKey)
VALUES (-1, 'Unknown', 'Unknown', 0, 'None', 0, 'Y', '1899-12-31', '9999-12-31', 'N/A', -1, -1);
SET IDENTITY_INSERT dbo.DimTransactionType OFF;

GO
CREATE VIEW [dw].[DimTransactionType] AS
SELECT [TransactionTypeKey] AS [Transaction Type Key]
,  [BKTransTypeCode]        AS [Trans Type Code]
,  [EntryMode]              AS [Entry Mode]
,  [IsSuccess]              AS [Is Success]
,  [ErrorType]              AS [Error Type]
,  [IsOnlineEntry]          AS [Is Online Entry]
,  [RowIsCurrent]           AS [Row Is Current]
,  [RowStartDate]           AS [Row Start Date]
,  [RowEndDate]             AS [Row End Date]
,  [RowChangeReason]        AS [Row Change Reason]
,  [InsertAuditKey]         AS [InsertAuditKey]
,  [UpdateAuditKey]         AS [UpdateAuditKey]
FROM dbo.DimTransactionType
GO

exec sys.sp_addextendedproperty @name=N'Description', @value=N'Surrogate key', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimTransactionType', @level2type=N'COLUMN', @level2name=N'TransactionTypeKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'mode|success|error', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimTransactionType', @level2type=N'COLUMN', @level2name=N'BKTransTypeCode';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Chip/Swipe/Online', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimTransactionType', @level2type=N'COLUMN', @level2name=N'EntryMode';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Transaction success flag', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimTransactionType', @level2type=N'COLUMN', @level2name=N'IsSuccess';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Error reason', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimTransactionType', @level2type=N'COLUMN', @level2name=N'ErrorType';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Online entry flag', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimTransactionType', @level2type=N'COLUMN', @level2name=N'IsOnlineEntry';

exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'IDENTITY(1,1)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimTransactionType', @level2type=N'COLUMN', @level2name=N'TransactionTypeKey';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'CONCAT(EntryMode,''|'',IsSuccess,''|'',ErrorType)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimTransactionType', @level2type=N'COLUMN', @level2name=N'BKTransTypeCode';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'LEFT(use_chip,CHARINDEX('' '',use_chip)-1)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimTransactionType', @level2type=N'COLUMN', @level2name=N'EntryMode';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'CASE WHEN errors IS NULL THEN 1 ELSE 0', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimTransactionType', @level2type=N'COLUMN', @level2name=N'IsSuccess';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'ISNULL(errors,''None'')', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimTransactionType', @level2type=N'COLUMN', @level2name=N'ErrorType';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'CASE WHEN use_chip=''Online Transaction'' THEN 1 ELSE 0', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimTransactionType', @level2type=N'COLUMN', @level2name=N'IsOnlineEntry';


/* =====================================================================
   7. DimAudit — Utility dimension (Kimball workbook standard)
   ===================================================================== */

CREATE TABLE dbo.DimAudit (
   [AuditKey]             int IDENTITY  NOT NULL
,  [ParentAuditKey]       int           NOT NULL
,  [PackageName]          nvarchar(100) NOT NULL
,  [PackageVersion]       nvarchar(20)  NOT NULL
,  [ExecutionStartTime]   datetime      NOT NULL
,  [ExecutionEndTime]     datetime      NULL
,  [ExecutionStatus]      nvarchar(20)  NOT NULL
,  [RowsInserted]         int           NOT NULL
,  [RowsUpdated]          int           NOT NULL
,  [RowsDeleted]          int           NOT NULL
, CONSTRAINT [PK_dbo.DimAudit] PRIMARY KEY CLUSTERED
( [AuditKey] )
) ON [PRIMARY];

exec sys.sp_addextendedproperty @name=N'Table Type', @value=N'Dimension', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimAudit;
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Audit', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimAudit;
exec sys.sp_addextendedproperty @name=N'Table Description', @value=N'Audit dimension for ETL lineage tracking.', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=DimAudit;

SET IDENTITY_INSERT dbo.DimAudit ON;
INSERT INTO dbo.DimAudit (AuditKey, ParentAuditKey, PackageName, PackageVersion, ExecutionStartTime, ExecutionEndTime, ExecutionStatus, RowsInserted, RowsUpdated, RowsDeleted)
VALUES (-1, -1, 'Unknown', 'Unknown', '1899-12-31', '9999-12-31', 'Unknown', 0, 0, 0);
SET IDENTITY_INSERT dbo.DimAudit OFF;

GO
CREATE VIEW [dw].[DimAudit] AS
SELECT [AuditKey]             AS [AuditKey]
,  [ParentAuditKey]           AS [ParentAuditKey]
,  [PackageName]              AS [Package Name]
,  [PackageVersion]           AS [Package Version]
,  [ExecutionStartTime]       AS [Execution Start Time]
,  [ExecutionEndTime]         AS [Execution End Time]
,  [ExecutionStatus]          AS [Execution Status]
,  [RowsInserted]             AS [Rows Inserted]
,  [RowsUpdated]              AS [Rows Updated]
,  [RowsDeleted]              AS [Rows Deleted]
FROM dbo.DimAudit
GO

exec sys.sp_addextendedproperty @name=N'Description', @value=N'Surrogate primary key', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimAudit', @level2type=N'COLUMN', @level2name=N'AuditKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'FK to self for calling package', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimAudit', @level2type=N'COLUMN', @level2name=N'ParentAuditKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'ETL package/script name', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimAudit', @level2type=N'COLUMN', @level2name=N'PackageName';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Package version', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimAudit', @level2type=N'COLUMN', @level2name=N'PackageVersion';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Execution start', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimAudit', @level2type=N'COLUMN', @level2name=N'ExecutionStartTime';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Execution end', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimAudit', @level2type=N'COLUMN', @level2name=N'ExecutionEndTime';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Status (Success/Failed)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimAudit', @level2type=N'COLUMN', @level2name=N'ExecutionStatus';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Rows inserted', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimAudit', @level2type=N'COLUMN', @level2name=N'RowsInserted';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Rows updated', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimAudit', @level2type=N'COLUMN', @level2name=N'RowsUpdated';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Rows deleted', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'DimAudit', @level2type=N'COLUMN', @level2name=N'RowsDeleted';


/* =====================================================================
   8. FactTransaction — Transaction fact (grain = 1 transaction)
   ===================================================================== */

CREATE TABLE dbo.FactTransaction (
   [DateKey]             int           NOT NULL
,  [CustomerKey]         int           NOT NULL
,  [CardKey]             int           NOT NULL
,  [GeographyKey]        int           NOT NULL
,  [MccKey]              int           NOT NULL
,  [TransactionTypeKey]  int           NOT NULL
,  [InsertAuditKey]      int           NOT NULL
,  [UpdateAuditKey]      int           NOT NULL
,  [BKTransactionID]     int           NULL
,  [BKMerchantID]        int           NULL
,  [Amount]              decimal(12,2) NOT NULL
) ON [PRIMARY];

exec sys.sp_addextendedproperty @name=N'Table Type', @value=N'Fact', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=FactTransaction;
exec sys.sp_addextendedproperty @name=N'Display Name', @value=N'Transaction', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=FactTransaction;
exec sys.sp_addextendedproperty @name=N'Table Description', @value=N'Transaction fact table. Grain: 1 row = 1 transaction. CardKey lookup via card_id (NOT client_id).', @level0type=N'SCHEMA', @level0name=dbo, @level1type=N'TABLE', @level1name=FactTransaction;

GO
CREATE VIEW [dw].[FactTransaction] AS
SELECT [DateKey]             AS [Date Key]
,  [CustomerKey]             AS [Customer Key]
,  [CardKey]                 AS [Card Key]
,  [GeographyKey]            AS [Geography Key]
,  [MccKey]                  AS [MCC Key]
,  [TransactionTypeKey]      AS [Transaction Type Key]
,  [InsertAuditKey]          AS [Insert Audit Key]
,  [UpdateAuditKey]          AS [Update Audit Key]
,  [BKTransactionID]         AS [Transaction ID]
,  [BKMerchantID]            AS [Merchant ID]
,  [Amount]                  AS [Amount]
FROM dbo.FactTransaction
GO

exec sys.sp_addextendedproperty @name=N'Description', @value=N'FK DimDate', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'DateKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'FK DimCustomer', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'CustomerKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'FK DimCard', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'CardKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'FK DimGeography', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'GeographyKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'FK DimMcc', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'MccKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'FK DimTransactionType', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'TransactionTypeKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'FK DimAudit (insert)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'InsertAuditKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'FK DimAudit (update)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'UpdateAuditKey';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Degenerate: transaction ID', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'BKTransactionID';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Degenerate: merchant ID', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'BKMerchantID';
exec sys.sp_addextendedproperty @name=N'Description', @value=N'Transaction amount (additive)', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'Amount';

exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'Key lookup from transactions.date', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'DateKey';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'Key lookup from transactions.client_id', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'CustomerKey';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'Key lookup from transactions.card_id', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'CardKey';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'Key lookup from merchant_city/state/zip', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'GeographyKey';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'Key lookup from transactions.mcc', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'MccKey';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'Key lookup from use_chip+errors', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'TransactionTypeKey';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'Standard auditing', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'InsertAuditKey';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'Standard auditing', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'UpdateAuditKey';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'Direct', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'BKTransactionID';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'Direct', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'BKMerchantID';
exec sys.sp_addextendedproperty @name=N'ETL Rules', @value=N'Direct', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'FactTransaction', @level2type=N'COLUMN', @level2name=N'Amount';


/* =====================================================================
   9. Foreign Key Constraints
   ===================================================================== */

-- Dimension audit FKs
ALTER TABLE dbo.DimCustomer ADD CONSTRAINT
   FK_dbo_DimCustomer_InsertAuditKey FOREIGN KEY (InsertAuditKey)
   REFERENCES dbo.DimAudit (AuditKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.DimCustomer ADD CONSTRAINT
   FK_dbo_DimCustomer_UpdateAuditKey FOREIGN KEY (UpdateAuditKey)
   REFERENCES dbo.DimAudit (AuditKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.DimCard ADD CONSTRAINT
   FK_dbo_DimCard_InsertAuditKey FOREIGN KEY (InsertAuditKey)
   REFERENCES dbo.DimAudit (AuditKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.DimCard ADD CONSTRAINT
   FK_dbo_DimCard_UpdateAuditKey FOREIGN KEY (UpdateAuditKey)
   REFERENCES dbo.DimAudit (AuditKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.DimGeography ADD CONSTRAINT
   FK_dbo_DimGeography_InsertAuditKey FOREIGN KEY (InsertAuditKey)
   REFERENCES dbo.DimAudit (AuditKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.DimGeography ADD CONSTRAINT
   FK_dbo_DimGeography_UpdateAuditKey FOREIGN KEY (UpdateAuditKey)
   REFERENCES dbo.DimAudit (AuditKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.DimMcc ADD CONSTRAINT
   FK_dbo_DimMcc_InsertAuditKey FOREIGN KEY (InsertAuditKey)
   REFERENCES dbo.DimAudit (AuditKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.DimMcc ADD CONSTRAINT
   FK_dbo_DimMcc_UpdateAuditKey FOREIGN KEY (UpdateAuditKey)
   REFERENCES dbo.DimAudit (AuditKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.DimTransactionType ADD CONSTRAINT
   FK_dbo_DimTransactionType_InsertAuditKey FOREIGN KEY (InsertAuditKey)
   REFERENCES dbo.DimAudit (AuditKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.DimTransactionType ADD CONSTRAINT
   FK_dbo_DimTransactionType_UpdateAuditKey FOREIGN KEY (UpdateAuditKey)
   REFERENCES dbo.DimAudit (AuditKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.DimAudit ADD CONSTRAINT
   FK_dbo_DimAudit_ParentAuditKey FOREIGN KEY (ParentAuditKey)
   REFERENCES dbo.DimAudit (AuditKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

-- Fact FK constraints
ALTER TABLE dbo.FactTransaction ADD CONSTRAINT
   FK_dbo_FactTransaction_DateKey FOREIGN KEY (DateKey)
   REFERENCES dbo.DimDate (DateKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.FactTransaction ADD CONSTRAINT
   FK_dbo_FactTransaction_CustomerKey FOREIGN KEY (CustomerKey)
   REFERENCES dbo.DimCustomer (CustomerKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.FactTransaction ADD CONSTRAINT
   FK_dbo_FactTransaction_CardKey FOREIGN KEY (CardKey)
   REFERENCES dbo.DimCard (CardKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.FactTransaction ADD CONSTRAINT
   FK_dbo_FactTransaction_GeographyKey FOREIGN KEY (GeographyKey)
   REFERENCES dbo.DimGeography (GeographyKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.FactTransaction ADD CONSTRAINT
   FK_dbo_FactTransaction_MccKey FOREIGN KEY (MccKey)
   REFERENCES dbo.DimMcc (MccKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.FactTransaction ADD CONSTRAINT
   FK_dbo_FactTransaction_TransactionTypeKey FOREIGN KEY (TransactionTypeKey)
   REFERENCES dbo.DimTransactionType (TransactionTypeKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.FactTransaction ADD CONSTRAINT
   FK_dbo_FactTransaction_InsertAuditKey FOREIGN KEY (InsertAuditKey)
   REFERENCES dbo.DimAudit (AuditKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE dbo.FactTransaction ADD CONSTRAINT
   FK_dbo_FactTransaction_UpdateAuditKey FOREIGN KEY (UpdateAuditKey)
   REFERENCES dbo.DimAudit (AuditKey) ON UPDATE NO ACTION ON DELETE NO ACTION;

PRINT 'BankingDW DDL complete — all tables, views, extended properties, and FK constraints created.';
GO
