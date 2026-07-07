# DW Dimensional Design — Xóm Bank (Kimball)

Thiết kế theo **Kimball "Microsoft DW Toolkit" Workbook** (file `Detailed-Dimensional-Modeling-Workbook-KimballU.xlsm`).
Áp dụng quy ước của workbook: surrogate key, business key (BK = natural key), SCD Type, **Unknown Member = -1**, audit keys (Insert/UpdateAuditKey), degenerate dimension.
Đây là **khung thiết kế** (xác định dim & fact) — DDL/ETL viết ở bước sau khi duyệt.

Tài liệu này phục vụ trực tiếp [BQ_KPI.md](../BQ_KPI.md). Mọi dim/fact đều truy về ít nhất một BQ/KPI.

---

## 1. Bốn bước Kimball

1. **Business process:** *Card Transaction* (giao dịch quẹt thẻ). Đây là process duy nhất trong phạm vi — toàn bộ 10 BQ + 5 KPI đều xoay quanh nó.
2. **Grain:** **1 dòng = 1 giao dịch** (= 1 dòng bảng `transactions`, khóa tự nhiên `transactions.id`). Grain nguyên tử, mịn nhất → trả lời được mọi mức tổng hợp.
3. **Dimensions:** Date, Customer, Card, Geography, MCC, TransactionType (junk) → "ai/cái gì/ở đâu/khi nào/thế nào".
4. **Facts:** `Amount` (additive). Các đại lượng còn lại là dẫn xuất/phi cộng (utilization, avg ticket, success rate) → tính ở BI/DAX, không lưu.

> Phạm vi: **1 fact transaction-grain**. Các process tương lai (Account Monthly Snapshot, Card Application) ghi nhận nhưng OUT OF SCOPE.

---

## 2. Bus Matrix

| Business Process | DimDate | DimCustomer | DimCard | DimGeography | DimMcc | DimTransactionType |
|------------------|:---:|:---:|:---:|:---:|:---:|:---:|
| **Card Transaction** (FactTransaction) | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| *Account Monthly Snapshot* (future) | ✔ | ✔ | ✔ | | | |

---

## 3. Dimension inventory

| Dimension | Type | Surrogate PK | Business Key (BK) | SCD | #Rows (≈) | Source |
|-----------|------|--------------|-------------------|-----|-----------|--------|
| **DimDate** | Conformed, static | `DateKey` (smart int YYYYMMDD) | full date | **SCD-0** | ~1.030 (2022–2024) | sinh bằng script |
| **DimCustomer** | Dimension | `CustomerKey` IDENTITY | `BKCustomerID` = users.id | **SCD-2-ready** (initial load: 1 current row/BK) | 2.000 | `users` |
| **DimCard** | Dimension | `CardKey` IDENTITY | `BKCardID` = cards.id | **SCD-2-ready** (initial load: 1 current row/BK) | 6.146 | `cards` |
| **DimGeography** | Conformed | `GeographyKey` IDENTITY | `BKGeoCode` = hash(city,state,zip) | **SCD-1** | ~distinct(city,state,zip) | `transactions` (city/state/zip) |
| **DimMcc** | Dimension | `MccKey` IDENTITY | `BKMccID` = mcc_id | **SCD-1** | 109 | `mcc_codes` |
| **DimTransactionType** | **Junk** | `TransactionTypeKey` IDENTITY | n/a | **SCD-1** | ~30 tổ hợp | `transactions` (use_chip, errors) |
| **DimAudit** | Utility | `AuditKey` IDENTITY | n/a | n/a | mỗi lần chạy ETL | ETL metadata |

Mỗi dim có **Unknown Member = -1** để fact luôn join được (không mất dòng khi nguồn thiếu/khuyết).

---

## 4. Chi tiết từng Dimension (cột theo workbook: Column · Datatype · SCD · Source)

### DimDate — SCD-0 (sinh)
| Column | Datatype | Mô tả / nguồn |
|--------|----------|----------------|
| DateKey (PK) | int | YYYYMMDD (smart key), Unknown=-1 |
| FullDate | date | ngày |
| Year, Quarter, MonthNumber, DayOfMonth | int | trích từ ngày |
| QuarterName, MonthName, DayName | nvarchar | 'Q1'…, 'January'…, 'Monday'… |
| MonthYear | nvarchar | '2022-01' (sắp xếp trục thời gian) |
| IsWeekend | bit | T7/CN |

Phục vụ: **BQ1, BQ4, BQ5, BQ8** + mọi KPI theo kỳ.

### DimCustomer — SCD-2-ready
| Column | Datatype | Source / ETL |
|--------|----------|--------------|
| CustomerKey (PK) | int IDENTITY | derived |
| BKCustomerID | int | users.id |
| Gender | nvarchar(10) | users.gender |
| CurrentAge | int | users.current_age |
| **AgeGroup** | nvarchar(20) | derived: <25 / 25-34 / 35-44 / 45-54 / 55-64 / 65+ |
| BirthYear | int | users.birth_year |
| PerCapitaIncome, YearlyIncome, TotalDebt | decimal | users.* |
| **IncomeBand** | nvarchar(20) | derived: <30k / 30-60k / 60-100k / 100k+ |
| CreditScore | int | users.credit_score |
| **CreditBand** | nvarchar(15) | derived: Poor<580 / Fair≤669 / Good≤739 / VeryGood≤799 / Excellent (ranh giới bao trùm — đã fix) |
| **DebtToIncome** | decimal(9,4) | derived: total_debt / NULLIF(yearly_income,0) |
| NumCreditCards | int | users.num_credit_cards |
| + SCD-2 housekeeping/audit | | RowIsCurrent, RowStartDate, RowEndDate, RowChangeReason, InsertAuditKey, UpdateAuditKey |

Phục vụ: **BQ3, BQ8, BQ9, BQ10, K4**.
*Ghi chú SCD:* credit_score / yearly_income / total_debt là thuộc tính cần giữ lịch sử nếu nguồn sau này có thay đổi. Nguồn hiện là snapshot tĩnh không có lịch sử → lần load đầu chỉ sinh 1 dòng current cho mỗi `BKCustomerID`, nhưng schema và ETL phải sẵn sàng SCD-2.

### DimCard — SCD-2-ready
| Column | Datatype | Source / ETL |
|--------|----------|--------------|
| CardKey (PK) | int IDENTITY | derived |
| BKCardID | int | cards.id |
| CardBrand | nvarchar | cards.card_brand (Visa/Mastercard/Amex/Discover) |
| CardType | nvarchar | cards.card_type (Credit/Debit/Debit (Prepaid)) |
| CreditLimit | decimal | cards.credit_limit |
| **CreditLimitBand** | nvarchar | derived: 0 / <5k / 5-15k / 15-30k / 30k+ |
| HasChip | bit | cards.has_chip (YES/NO → 1/0) |
| NumCardsIssued | int | cards.num_cards_issued |
| AcctOpenDate | date | cards.acct_open_date |
| + SCD-2 housekeeping/audit | | RowIsCurrent, RowStartDate, RowEndDate, RowChangeReason, InsertAuditKey, UpdateAuditKey |

Phục vụ: **BQ2, BQ4, BQ10, K3**.
*Ghi chú:* `credit_limit` là thuộc tính cần giữ lịch sử nếu hạn mức thay đổi. Nguồn hiện là snapshot tĩnh → lần load đầu chỉ sinh 1 dòng current cho mỗi `BKCardID`, nhưng schema và ETL phải sẵn sàng SCD-2.

### DimGeography — SCD-1 (thay cho "DimMerchant")
Lý do: `merchant_id` có 729/7562 merchant gắn >1 city → không 1:1 với địa lý, và merchant **không có thuộc tính mô tả nào khác ngoài vị trí**. ⇒ tách vị trí thành dim địa lý, còn `merchant_id` đưa xuống **degenerate dimension** trong fact.
| Column | Datatype | Source / ETL |
|--------|----------|--------------|
| GeographyKey (PK) | int IDENTITY | derived |
| City | nvarchar | transactions.merchant_city |
| State | nvarchar | transactions.merchant_state |
| Zip | nvarchar | transactions.zip |
| **IsOnline** | bit | derived: City = 'ONLINE' |
| Grain | | distinct (City, State, Zip) |

Phục vụ: **BQ7**.

### DimMcc — SCD-1
| Column | Datatype | Source |
|--------|----------|--------|
| MccKey (PK) | int IDENTITY | derived |
| BKMccID | int | mcc_codes.mcc_id |
| MccDescription | nvarchar | mcc_codes.description |
| **CategoryGroup** | nvarchar | derived (gộp nhóm thô: Travel/Retail/Food/…)*tùy chọn* |

Phục vụ: **BQ6**.

### DimTransactionType — Junk dimension, SCD-1
Gom các cờ rời rạc, ít cardinality (Kimball: tránh nhồi cờ vào fact). Grain = distinct tổ hợp.
| Column | Datatype | Source / ETL |
|--------|----------|--------------|
| TransactionTypeKey (PK) | int IDENTITY | derived |
| EntryMode | nvarchar | use_chip → 'Chip' / 'Swipe' / 'Online' |
| IsSuccess | bit | derived: errors IS NULL |
| ErrorType | nvarchar | errors (NULL → 'None'); giữ nguyên chuỗi (kể cả tổ hợp 'Bad PIN,Insufficient Balance') |
| IsOnlineEntry | bit | derived: use_chip = 'Online Transaction' |

Phục vụ: **BQ5, K2** (success/error rate, channel mix).

### DimAudit — Utility (chuẩn workbook)
`AuditKey, PackageName, ExecStartTime, RowsInserted, SourceFile, …` — gắn vào InsertAuditKey/UpdateAuditKey để truy vết ETL.

---

## 5. FactTransaction

- **Grain:** 1 giao dịch (`transactions.id`).
- **Table type:** Transaction fact (không phải snapshot).

| Column | Vai trò | Datatype | Ghi chú |
|--------|---------|----------|---------|
| DateKey | FK → DimDate | int | từ transactions.date |
| CustomerKey | FK → DimCustomer | int | lookup theo client_id |
| CardKey | FK → DimCard | int | lookup theo **card_id** (KHÓA ĐÚNG, không dùng client_id) |
| GeographyKey | FK → DimGeography | int | lookup (city,state,zip) |
| MccKey | FK → DimMcc | int | lookup theo mcc |
| TransactionTypeKey | FK → DimTransactionType | int | junk |
| InsertAuditKey | FK → DimAudit | int | lineage |
| **BKTransactionID** | Degenerate dim | int | transactions.id (số giao dịch) |
| **BKMerchantID** | Degenerate dim | int | transactions.merchant_id |
| **Amount** | **Measure** | decimal(12,2) | additive theo MỌI dim |

**Additivity:**
- `Amount` — **fully additive**.
- Đếm giao dịch = `COUNT(*)`; chi tiêu hợp lệ = `SUM(Amount) WHERE IsSuccess=1 AND Amount>0` (lọc qua junk dim) → **K1**.
- Phi cộng (tính ở DAX): **K3** Utilization (ratio), **K5** Avg Ticket (ratio), **K2** Success Rate (ratio), **K4** Active Customers (distinct count).

---

## 6. Quyết định đã chốt (2026-06-06)

1. ✅ **Junk dimension** `DimTransactionType` — gom (EntryMode, IsSuccess, ErrorType, IsOnlineEntry).
2. ✅ **merchant_id = degenerate** trong fact + **DimGeography** cho location (thay DimMerchant).
3. ✅ **SCD-2** cho `DimCustomer` và `DimCard` — thiết kế sẵn cột lịch sử (xem §4 đã cập nhật). DimDate=SCD-0, DimGeography/DimMcc=SCD-1.
4. ✅ **DimAudit đầy đủ** + Insert/UpdateAuditKey trên mọi dim & fact (chuẩn workbook).
5. ⏳ **CategoryGroup** (DimMcc): mặc định **để nguyên description**, chưa gộp nhóm (có thể bổ sung mapping sau khi cần cho BQ6).

### Cột SCD-2 chuẩn (thêm vào DimCustomer & DimCard)
Theo template workbook:
| Column | Datatype | Default / ý nghĩa |
|--------|----------|-------------------|
| RowIsCurrent | bit | 1 = bản ghi hiện hành |
| RowStartDate | datetime | thời điểm bản ghi có hiệu lực (Unknown: 1900-01-01) |
| RowEndDate | datetime | hết hiệu lực (current: 9999-12-31) |
| RowChangeReason | nvarchar(200) | lý do thay đổi |
| InsertAuditKey / UpdateAuditKey | int FK→DimAudit | lineage |

Khóa tự nhiên (`BKCustomerID`, `BKCardID`) **không còn là unique** ở DimCustomer/DimCard khi SCD-2 (một BK có nhiều phiên bản); unique là (BK + RowIsCurrent=1) cho bản hiện hành. Fact lookup CustomerKey/CardKey theo **BK + ngày giao dịch nằm trong [RowStartDate, RowEndDate]**.

> Lưu ý: nguồn hiện là snapshot tĩnh (1 phiên bản/khách) → lần load đầu mỗi BK chỉ sinh 1 dòng current; cơ chế SCD-2 sẵn sàng cho các lần load sau khi có thay đổi.

---

## 7. Quy trình triển khai tiếp theo

Khung Kimball đã chốt. Phần triển khai DW sẽ tách rõ **Stage → Extract → Transform → Load → Verify** để dễ chạy lại, debug và giải thích trong báo cáo.

```text
02_datawarehouse/
├── 01_ddl.sql
├── 02_stage.sql
├── 03_extract.sql
├── 04_transform_load_dimensions.sql
├── 05_load_fact.sql
├── 06_verify.sql
└── 07_indexes.sql
```

1. **`01_ddl.sql` — DW schema**: tạo `BankingDW.dw`, 7 dim + 1 fact, PK/FK, Unknown Member, audit keys, SCD-2 housekeeping columns cho `DimCustomer`/`DimCard`.
2. **`02_stage.sql` — Stage structure**: tạo `BankingDW.stg` và các bảng stage gần raw source nhất có thể (`users`, `cards`, `transactions`, `mcc_codes`). Stage chỉ copy/chuẩn hóa tối thiểu, không tính KPI.
3. **`03_extract.sql` — Extract to Stage**: full reload từ `BankingDB.dbo` vào `BankingDW.stg` vì dữ liệu hiện nhỏ; có thể thêm batch metadata để audit.
4. **`04_transform_load_dimensions.sql` — Transform + Load dimensions**: load `DimAudit`/Unknown members, `DimDate`, `DimCustomer`, `DimCard`, `DimGeography`, `DimMcc`, `DimTransactionType`; tính derived attributes (`AgeGroup`, `IncomeBand`, `CreditBand`, `DebtToIncome`, `CreditLimitBand`, `IsOnline`, `IsSuccess`, ...).
5. **`05_load_fact.sql` — Load FactTransaction**: load fact sau khi dim đã sẵn surrogate key. Bắt buộc lookup `CardKey` theo **`transactions.card_id = cards.id`**, không dùng `client_id`; lookup `CustomerKey`/`CardKey` SCD-2 theo BK + ngày giao dịch nằm trong `[RowStartDate, RowEndDate]`.
6. **`06_verify.sql` — Reconcile**: đối soát tối thiểu `COUNT(FactTransaction)=157,224`, `SUM(Amount)=6,874,483.49`, Total Valid Spend `=7,533,887.55` với rule `errors IS NULL AND amount > 0`, FK/Unknown counts, và kiểm tra không fan-out.
7. **`07_indexes.sql` — Performance**: tạo index/columnstore sau khi ETL và verify ổn định; Power BI dùng star schema này làm semantic layer.
