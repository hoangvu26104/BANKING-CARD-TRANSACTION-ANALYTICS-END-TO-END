# Hướng dẫn điền Kimball Workbook → sinh DDL cho DW (ĐỦ 21 cột A→U)

Điền vào **bản sao** sheet `Blank Dimension` / `Blank Fact` rồi chạy macro **Generate SQL Script**.
Mọi bảng dưới đây hiển thị **đầy đủ 21 cột Excel A→U** (ô trống = để trống trong Excel).

Thứ tự cột: `A Column Name · B Display Name · C Description · D Unknown Member · E Example Values · F SCD Type · G Display Folder · H ETL Rules · I Comments · J Datatype · K Size · L Precision · M Key? · N FK To · O NULL? · P Default Value · Q Source System · R Source Schema · S Source Table · T Source Field Name · U Source Datatype`

**Token:** F (SCD): `key`/`1`/`2`/`n/a` · M (Key?): `PK ID`/`FK`/trống · O (NULL?): N/Y.
`decimal(p,s)` → K Size=`p`, L Precision=`s`. Nếu macro không nhận `bit`/`date`/`tinyint` → đổi `bit`→`tinyint`, `date`→`datetime`.

## Thiết lập chung
1. **Home**: `Database` = `BankingDW` · `Gen FKs?` = `Y`.
2. Mỗi sheet: `Database Schema` = `dw` · `Generate Script?` = `Y`.
3. Copy `Blank Dimension` cho 6 dim, `Blank Fact` cho fact. Sheet `Audit` (DimAudit) giữ nguyên, set `Generate Script?=Y`.

## ★ Khối Housekeeping (6 dòng có sẵn trong Blank Dimension — GIỮ NGUYÊN). Áp dụng mọi dim TRỪ DimDate.

| A Column Name | B Display Name | C Description | D Unknown Member | E Example Values | F SCD Type | G Display Folder | H ETL Rules | I Comments | J Datatype | K Size | L Precision | M Key? | N FK To | O NULL? | P Default Value | Q Source System | R Source Schema | S Source Table | T Source Field Name | U Source Datatype |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| RowIsCurrent | Row Is Current | Bản ghi hiện hành? | Y | Y, N | n/a | Exclude from cube | Standard SCD-2 | | nchar | 1 | | | | N | | Derived | | | | |
| RowStartDate | Row Start Date | Hiệu lực từ | 1900-01-01 | 2022-01-01 | n/a | Exclude from cube | Standard SCD-2 | | datetime | | | | | N | | Derived | | | | |
| RowEndDate | Row End Date | Hiệu lực đến | 9999-12-31 | 9999-12-31 | n/a | Exclude from cube | Standard SCD-2 | | datetime | | | | | N | 9999-12-31 | Derived | | | | |
| RowChangeReason | Row Change Reason | Lý do đổi | N/A | New | n/a | Exclude from cube | Standard SCD-2 | | nvarchar | 200 | | | | N | | Derived | | | | |
| InsertAuditKey | Insert Audit Key | Process nạp dòng | -1 | 1,2,3 | n/a | Exclude from cube | Standard Audit dim | | int | | | FK | DimAudit.AuditKey | N | | Derived | | | | |
| UpdateAuditKey | Update Audit Key | Process cập nhật | -1 | 1,2,3 | n/a | Exclude from cube | Standard Audit dim | | int | | | FK | DimAudit.AuditKey | N | | Derived | | | | |

---

## 1) DimDate — Type=`Dimension`, Display=`Date` (SCD-0; **XÓA khối Housekeeping**)

| A Column Name | B Display Name | C Description | D Unknown Member | E Example Values | F SCD Type | G Display Folder | H ETL Rules | I Comments | J Datatype | K Size | L Precision | M Key? | N FK To | O NULL? | P Default Value | Q Source System | R Source Schema | S Source Table | T Source Field Name | U Source Datatype |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| DateKey | Date Key | Surrogate date YYYYMMDD | -1 | 20220101 | key | | Sinh bằng script lịch | | int | | | PK ID | | N | | Derived | | | | |
| FullDate | Full Date | Ngày dương lịch | 1900-01-01 | 2022-01-01 | 1 | | Sinh dải ngày 2022–2024 | | date | | | | | N | | Derived | | | | |
| Year | Year | Năm | -1 | 2022 | 1 | | YEAR(FullDate) | | int | | | | | N | | Derived | | | | |
| Quarter | Quarter | Quý 1-4 | -1 | 1 | 1 | | DATEPART(q,FullDate) | | tinyint | | | | | N | | Derived | | | | |
| QuarterName | Quarter Name | Nhãn quý | Unknown | Q1 | 1 | | 'Q'+CAST(quarter) | | nvarchar | 2 | | | | N | | Derived | | | | |
| MonthNumber | Month Number | Tháng 1-12 | -1 | 1 | 1 | | MONTH(FullDate) | | tinyint | | | | | N | | Derived | | | | |
| MonthName | Month Name | Tên tháng | Unknown | January | 1 | | DATENAME(month,FullDate) | | nvarchar | 12 | | | | N | | Derived | | | | |
| MonthYear | Month Year | YYYY-MM sắp xếp | Unknown | 2022-01 | 1 | | FORMAT(FullDate,'yyyy-MM') | | char | 7 | | | | N | | Derived | | | | |
| DayOfMonth | Day Of Month | Ngày 1-31 | -1 | 1 | 1 | | DAY(FullDate) | | tinyint | | | | | N | | Derived | | | | |
| DayName | Day Name | Thứ trong tuần | Unknown | Monday | 1 | | DATENAME(weekday,FullDate) | | nvarchar | 10 | | | | N | | Derived | | | | |
| IsWeekend | Is Weekend | Cờ T7/CN | 0 | 0 | 1 | | CASE weekday IN (1,7) | | bit | | | | | N | | Derived | | | | |

## 2) DimCustomer — Type=`Dimension`, Display=`Customer` (SCD-2 mixed; **giữ Housekeeping ★**) — Source `dbo.users`

| A Column Name | B Display Name | C Description | D Unknown Member | E Example Values | F SCD Type | G Display Folder | H ETL Rules | I Comments | J Datatype | K Size | L Precision | M Key? | N FK To | O NULL? | P Default Value | Q Source System | R Source Schema | S Source Table | T Source Field Name | U Source Datatype |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| CustomerKey | Customer Key | Surrogate key | -1 | 1,2,3 | key | | IDENTITY(1,1) | | int | | | PK ID | | N | | Derived | | | | |
| BKCustomerID | Customer ID | Natural key | -1 | 0,1,2 | key | | Direct | | int | | | | | N | | BankingDB | dbo | users | id | int |
| Gender | Gender | Giới tính | Unknown | Female | 1 | | Direct | | nvarchar | 10 | | | | N | | BankingDB | dbo | users | gender | nvarchar |
| CurrentAge | Current Age | Tuổi | -1 | 53 | 1 | | Direct | | int | | | | | N | | BankingDB | dbo | users | current_age | int |
| AgeGroup | Age Group | Nhóm tuổi | Unknown | 45-54 | 1 | | Bucket(current_age) <25/25-34/35-44/45-54/55-64/65+ | | nvarchar | 20 | | | | N | | Derived | dbo | users | current_age | int |
| BirthYear | Birth Year | Năm sinh | -1 | 1971 | 1 | | Direct | | int | | | | | N | | BankingDB | dbo | users | birth_year | int |
| PerCapitaIncome | Per Capita Income | Thu nhập bình quân vùng | 0 | 22500 | 2 | | Direct | | decimal | 12 | 2 | | | Y | | BankingDB | dbo | users | per_capita_income | decimal |
| YearlyIncome | Yearly Income | Thu nhập năm | 0 | 59500 | 2 | | Direct | | decimal | 12 | 2 | | | Y | | BankingDB | dbo | users | yearly_income | decimal |
| IncomeBand | Income Band | Nhóm thu nhập | Unknown | 30-60k | 2 | | Bucket(yearly_income) <30k/30-60k/60-100k/100k+ | | nvarchar | 20 | | | | N | | Derived | dbo | users | yearly_income | decimal |
| TotalDebt | Total Debt | Tổng nợ | 0 | 127613 | 2 | | Direct | | decimal | 12 | 2 | | | Y | | BankingDB | dbo | users | total_debt | decimal |
| DebtToIncome | Debt To Income | Nợ / thu nhập | 0 | 2.14 | 2 | | total_debt/NULLIF(yearly_income,0) | | decimal | 9 | 4 | | | Y | | Derived | dbo | users | total_debt | decimal |
| CreditScore | Credit Score | Điểm tín dụng | -1 | 698 | 2 | | Direct | | int | | | | | N | | BankingDB | dbo | users | credit_score | int |
| CreditBand | Credit Band | Nhóm điểm (bao trùm) | Unknown | Good | 2 | | Poor<580/Fair≤669/Good≤739/VeryGood≤799/Excellent | | nvarchar | 15 | | | | N | | Derived | dbo | users | credit_score | int |
| NumCreditCards | Num Credit Cards | Số thẻ tín dụng | -1 | 5 | 1 | | Direct | | int | | | | | N | | BankingDB | dbo | users | num_credit_cards | int |

➕ Tiếp theo **giữ nguyên 6 dòng Housekeeping (★)**.

## 3) DimCard — Type=`Dimension`, Display=`Card` (SCD-2 mixed; **giữ Housekeeping ★**) — Source `dbo.cards`

| A Column Name | B Display Name | C Description | D Unknown Member | E Example Values | F SCD Type | G Display Folder | H ETL Rules | I Comments | J Datatype | K Size | L Precision | M Key? | N FK To | O NULL? | P Default Value | Q Source System | R Source Schema | S Source Table | T Source Field Name | U Source Datatype |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| CardKey | Card Key | Surrogate key | -1 | 1,2,3 | key | | IDENTITY(1,1) | | int | | | PK ID | | N | | Derived | | | | |
| BKCardID | Card ID | Natural key | -1 | 2972 | key | | Direct | | int | | | | | N | | BankingDB | dbo | cards | id | int |
| CardBrand | Card Brand | Mạng thẻ | Unknown | Visa | 1 | | Direct | | nvarchar | 20 | | | | N | | BankingDB | dbo | cards | card_brand | nvarchar |
| CardType | Card Type | Loại thẻ | Unknown | Credit | 1 | | Direct | | nvarchar | 20 | | | | N | | BankingDB | dbo | cards | card_type | nvarchar |
| CreditLimit | Credit Limit | Hạn mức | 0 | 14400 | 2 | | Direct | | decimal | 12 | 2 | | | Y | | BankingDB | dbo | cards | credit_limit | decimal |
| CreditLimitBand | Credit Limit Band | Nhóm hạn mức | Unknown | 5-15k | 2 | | Bucket(credit_limit) 0/<5k/5-15k/15-30k/30k+ | | nvarchar | 15 | | | | N | | Derived | dbo | cards | credit_limit | decimal |
| HasChip | Has Chip | Có chip | 0 | 1 | 1 | | CASE has_chip WHEN 'YES' THEN 1 ELSE 0 | | bit | | | | | N | | BankingDB | dbo | cards | has_chip | nvarchar |
| NumCardsIssued | Num Cards Issued | Số thẻ phát hành | -1 | 2 | 1 | | Direct | | int | | | | | N | | BankingDB | dbo | cards | num_cards_issued | int |
| AcctOpenDate | Acct Open Date | Ngày mở | 1900-01-01 | 2013-09-01 | 1 | | Direct | | date | | | | | Y | | BankingDB | dbo | cards | acct_open_date | date |

➕ Tiếp theo **giữ nguyên 6 dòng Housekeeping (★)**.

## 4) DimGeography — Type=`Dimension`, Display=`Geography` (SCD-1; **giữ Housekeeping ★**) — Source `dbo.transactions`

| A Column Name | B Display Name | C Description | D Unknown Member | E Example Values | F SCD Type | G Display Folder | H ETL Rules | I Comments | J Datatype | K Size | L Precision | M Key? | N FK To | O NULL? | P Default Value | Q Source System | R Source Schema | S Source Table | T Source Field Name | U Source Datatype |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| GeographyKey | Geography Key | Surrogate key | -1 | 1,2,3 | key | | IDENTITY(1,1) | | int | | | PK ID | | N | | Derived | | | | |
| BKGeoCode | Geo Code | city\|state\|zip | Unknown | Houston\|TX\|77001 | key | | CONCAT(city,'\|',state,'\|',zip) | | nvarchar | 120 | | | | N | | Derived | dbo | transactions | merchant_city | nvarchar |
| City | City | Thành phố merchant | Unknown | Houston | 1 | | Direct | | nvarchar | 50 | | | | N | | BankingDB | dbo | transactions | merchant_city | nvarchar |
| State | State | Bang merchant | Unknown | TX | 1 | | Direct | | nvarchar | 20 | | | | Y | | BankingDB | dbo | transactions | merchant_state | nvarchar |
| Zip | Zip | Mã ZIP | Unknown | 77001 | 1 | | Direct | | nvarchar | 10 | | | | Y | | BankingDB | dbo | transactions | zip | nvarchar |
| IsOnline | Is Online | Cờ online | 0 | 0 | 1 | | CASE WHEN merchant_city='ONLINE' THEN 1 ELSE 0 | | bit | | | | | N | | Derived | dbo | transactions | merchant_city | nvarchar |

➕ Tiếp theo **giữ nguyên 6 dòng Housekeeping (★)**.

## 5) DimMcc — Type=`Dimension`, Display=`MCC` (SCD-1; **giữ Housekeeping ★**) — Source `dbo.mcc_codes`

| A Column Name | B Display Name | C Description | D Unknown Member | E Example Values | F SCD Type | G Display Folder | H ETL Rules | I Comments | J Datatype | K Size | L Precision | M Key? | N FK To | O NULL? | P Default Value | Q Source System | R Source Schema | S Source Table | T Source Field Name | U Source Datatype |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| MccKey | MCC Key | Surrogate key | -1 | 1,2,3 | key | | IDENTITY(1,1) | | int | | | PK ID | | N | | Derived | | | | |
| BKMccID | MCC ID | Natural key | -1 | 5411 | key | | Direct | | int | | | | | N | | BankingDB | dbo | mcc_codes | mcc_id | int |
| MccDescription | MCC Description | Mô tả category | Unknown | Grocery Stores | 1 | | Direct | | nvarchar | 100 | | | | N | | BankingDB | dbo | mcc_codes | description | nvarchar |

➕ Tiếp theo **giữ nguyên 6 dòng Housekeeping (★)**.

## 6) DimTransactionType — Type=`Dimension`, Display=`Transaction Type` (Junk, SCD-1; **giữ Housekeeping ★**) — Source `dbo.transactions`

| A Column Name | B Display Name | C Description | D Unknown Member | E Example Values | F SCD Type | G Display Folder | H ETL Rules | I Comments | J Datatype | K Size | L Precision | M Key? | N FK To | O NULL? | P Default Value | Q Source System | R Source Schema | S Source Table | T Source Field Name | U Source Datatype |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TransactionTypeKey | Transaction Type Key | Surrogate key | -1 | 1,2,3 | key | | IDENTITY(1,1) | | int | | | PK ID | | N | | Derived | | | | |
| BKTransTypeCode | Trans Type Code | mode\|success\|error | Unknown | Chip\|1\|None | key | | CONCAT(EntryMode,'\|',IsSuccess,'\|',ErrorType) | | nvarchar | 120 | | | | N | | Derived | dbo | transactions | use_chip | nvarchar |
| EntryMode | Entry Mode | Chip/Swipe/Online | Unknown | Chip | 1 | | LEFT(use_chip,CHARINDEX(' ',use_chip)-1) | | nvarchar | 10 | | | | N | | Derived | dbo | transactions | use_chip | nvarchar |
| IsSuccess | Is Success | GD thành công | 0 | 1 | 1 | | CASE WHEN errors IS NULL THEN 1 ELSE 0 | | bit | | | | | N | | Derived | dbo | transactions | errors | nvarchar |
| ErrorType | Error Type | Lý do lỗi | None | Insufficient Balance | 1 | | ISNULL(errors,'None') | | nvarchar | 60 | | | | N | | BankingDB | dbo | transactions | errors | nvarchar |
| IsOnlineEntry | Is Online Entry | use_chip='Online' | 0 | 0 | 1 | | CASE WHEN use_chip='Online Transaction' THEN 1 ELSE 0 | | bit | | | | | N | | Derived | dbo | transactions | use_chip | nvarchar |

➕ Tiếp theo **giữ nguyên 6 dòng Housekeeping (★)**.

## 7) DimAudit — sheet `Audit` (có sẵn trong template), Type=`Dimension`, Display=`Audit`, Schema=`dw`, `Generate Script? = Y`

**Giống Fact:** F (SCD Type) **để trống** mọi dòng (audit không track lịch sử). `Q Source System` = `Derived` (ETL sinh). 2 dòng đầu (AuditKey, ParentAuditKey) giữ NGUYÊN như template — phần còn lại là cột lineage ETL sẽ ghi.

| A Column Name | B Display Name | C Description | D Unknown Member | E Example Values | F SCD Type | G Display Folder | H ETL Rules | I Comments | J Datatype | K Size | L Precision | M Key? | N FK To | O NULL? | P Default Value | Q Source System | R Source Schema | S Source Table | T Source Field Name | U Source Datatype |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| AuditKey | AuditKey | Surrogate primary key | -1 | 1, 2, 3… | | | | | int | | | PK ID | | N | | Derived | | | | |
| ParentAuditKey | ParentAuditKey | Foreign key to self, to identify calling package execution | -1 | 1, 2, 3… | | | | | int | | | FK | DimAudit.AuditKey | N | | Derived | | | | |
| PackageName | Package Name | Tên package/script ETL | Unknown | Load_FactTransaction | | | | | nvarchar | 100 | | | | N | | Derived | | | | |
| PackageVersion | Package Version | Phiên bản package | Unknown | 1.0 | | | | | nvarchar | 20 | | | | N | | Derived | | | | |
| ExecutionStartTime | Execution Start Time | Thời điểm bắt đầu chạy | 1900-01-01 | 2026-06-06 09:00 | | | | | datetime | | | | | N | | Derived | | | | |
| ExecutionEndTime | Execution End Time | Thời điểm kết thúc | 9999-12-31 | 2026-06-06 09:05 | | | | | datetime | | | | | Y | | Derived | | | | |
| ExecutionStatus | Execution Status | Trạng thái (Success/Failed) | Unknown | Success | | | | | nvarchar | 20 | | | | N | | Derived | | | | |
| RowsInserted | Rows Inserted | Số dòng insert | 0 | 157224 | | | | | int | | | | | N | | Derived | | | | |
| RowsUpdated | Rows Updated | Số dòng update | 0 | 0 | | | | | int | | | | | N | | Derived | | | | |
| RowsDeleted | Rows Deleted | Số dòng deleted | 0 | 0 | | | | | int | | | | | N | | Derived | | | | |

> 2 dòng đặc biệt cần seed sẵn: `AuditKey=-1` (Unknown/chưa rõ process) và `AuditKey=-2` (dành cho `UpdateAuditKey` của dòng chưa từng update). ETL ghi 1 dòng AuditKey mới mỗi lần chạy.

---

## 8) FactTransaction — `Blank Fact`, Type=`Fact`, Display=`Transaction`, Schema=`dw` (grain = 1 giao dịch)

**Khác Dimension:** F (SCD Type) **để trống** mọi dòng. FK → G=`key`, H=`Key lookup...`; degenerate → G=`Exclude from cube`; measure → G=`Amounts`. `UpdateAuditKey` D=`-2`.

| A Column Name | B Display Name | C Description | D Unknown Member | E Example Values | F SCD Type | G Display Folder | H ETL Rules | I Comments | J Datatype | K Size | L Precision | M Key? | N FK To | O NULL? | P Default Value | Q Source System | R Source Schema | S Source Table | T Source Field Name | U Source Datatype |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| DateKey | Date Key | FK DimDate | | 1,2,3 | | key | Key lookup from transactions.date | | int | | | FK | DimDate.DateKey | N | ETL Process | Derived | dbo | transactions | date | datetime |
| CustomerKey | Customer Key | FK DimCustomer | | 1,2,3 | | key | Key lookup from transactions.client_id | | int | | | FK | DimCustomer.CustomerKey | N | ETL Process | Derived | dbo | transactions | client_id | int |
| CardKey | Card Key | FK DimCard | | 1,2,3 | | key | Key lookup from transactions.card_id | | int | | | FK | DimCard.CardKey | N | ETL Process | Derived | dbo | transactions | card_id | int |
| GeographyKey | Geography Key | FK DimGeography | | 1,2,3 | | key | Key lookup from merchant_city/state/zip | | int | | | FK | DimGeography.GeographyKey | N | ETL Process | Derived | dbo | transactions | merchant_city | nvarchar |
| MccKey | MCC Key | FK DimMcc | | 1,2,3 | | key | Key lookup from transactions.mcc | | int | | | FK | DimMcc.MccKey | N | ETL Process | Derived | dbo | transactions | mcc | int |
| TransactionTypeKey | Transaction Type Key | FK DimTransactionType | | 1,2,3 | | key | Key lookup from use_chip+errors | | int | | | FK | DimTransactionType.TransactionTypeKey | N | ETL Process | Derived | dbo | transactions | use_chip | nvarchar |
| InsertAuditKey | Insert Audit Key | FK DimAudit (insert) | | 1,2,3 | | key | Standard auditing | | int | | | FK | DimAudit.AuditKey | N | ETL Process | Derived | | | | |
| UpdateAuditKey | Update Audit Key | FK DimAudit (update) | -2 | 1,2,3 | | key | Standard auditing | | int | | | FK | DimAudit.AuditKey | N | ETL Process | Derived | | | | |
| BKTransactionID | Transaction ID | Degenerate: số GD | | 100 | | Exclude from cube | Direct | | int | | | | | Y | | BankingDB | dbo | transactions | id | int |
| BKMerchantID | Merchant ID | Degenerate: số merchant | | 5000 | | Exclude from cube | Direct | | int | | | | | Y | | BankingDB | dbo | transactions | merchant_id | int |
| Amount | Amount | Số tiền (additive) | | 45.20 | | Amounts | Direct | | decimal | 12 | 2 | | | N | | BankingDB | dbo | transactions | amount | decimal |

> ETL: `CardKey` lookup theo **card_id** (KHÔNG client_id) tránh fan-out. Verify cuối: `COUNT(FactTransaction)=157,224`, `SUM(Amount)=6,874,483.49`, Total Valid Spend `=7,533,887.55` với rule `errors IS NULL AND amount > 0`.

---

## Chạy macro
1. Điền 7 dim + 1 fact → **Create/Update Diagram(s)** kiểm tra star schema.
2. **Generate SQL Script** → dùng làm đầu vào để hoàn thiện script chính `02_datawarehouse/01_ddl.sql`.
3. Bước sau triển khai theo chuỗi: `02_stage.sql` → `03_extract.sql` → `04_transform_load_dimensions.sql` → `05_load_fact.sql` → `06_verify.sql` → `07_indexes.sql`.
