# Giai đoạn 4 — ML/DL: Bài A — Fraud / Error Detection

Mô hình phát hiện **giao dịch lỗi** (`errors IS NOT NULL`) trên dữ liệu Xóm Bank — bài toán phân loại nhị phân **mất cân bằng (~1.74%)**, proxy cho anomaly/fraud detection.

## Cấu trúc

```
04_ml/
├── src/
│   ├── db.py             # Kết nối BankingDW, đọc Fact join 6 Dim → DataFrame
│   ├── features.py       # Feature engineering + time-based split (chống leakage)
│   ├── train_fraud.py    # Baseline + XGBoost + SMOTE, lưu model
│   └── evaluate.py       # PR-AUC, Recall@k, confusion matrix, SHAP
├── notebooks/
│   └── 01_eda_fraud.ipynb  # EDA
├── models/               # Artifacts (model .pkl, metrics .json, SHAP .png)
└── README.md
```

## Cách chạy

```bash
cd 04_ml
python src/db.py            # (tùy chọn) verify đọc DW: 157,224 dòng, lỗi 1.74%
python src/features.py      # (tùy chọn) verify features: 88 cột, CLEAN
python src/train_fraud.py   # huấn luyện → lưu models/
python src/evaluate.py      # đánh giá + SHAP → models/
```

Notebook EDA: mở `notebooks/01_eda_fraud.ipynb` (dùng lại `src/db.py`).

## Dữ liệu & Feature

- **Nguồn:** `BankingDW` (star schema), đọc qua `FactTransaction` join 6 dimension. **Bổ sung timestamp từ `BankingDB.transactions`** (OLTP) vì DW chỉ lưu tới ngày.
- **Target:** `is_error` = 1 khi `DimTransactionType.IsSuccess = 0`.
- **99 feature:** số (amount, income, credit_score, debt_to_income, credit_limit...), one-hot (card_brand/type, band, entry_mode, state top-15...), frequency encoding (mcc, merchant_id), **time features từ OLTP** (`txn_hour`, `is_night`, `txn_weekday`, `txn_per_card_day` = velocity).

### Chống data leakage (bắt buộc)
1. **Không dùng** `ErrorType` / `IsSuccess` làm feature — chúng chính là target.
2. **Time-based split:** train 2022–2023 (111k dòng), test 2024 (46k dòng). Không random split.
3. **SMOTE chỉ trên train**, sau khi split.
4. Tự kiểm tra: `feature_names.json` không chứa cột `error`/`success`.

## Kết quả (test 2024, hold-out theo thời gian)

| Model | PR-AUC | ROC-AUC |
|---|---|---|
| Dummy (stratified) | 0.018 | 0.507 |
| LogReg (balanced) | 0.028 | 0.634 |
| **XGBoost (scale_pos_weight)** | **0.056** | **0.683** |
| SMOTE + XGBoost | 0.049 | 0.686 |

**XGBoost thắng**, vượt baseline ~3x (PR-AUC). Với base rate chỉ 1.74%, PR-AUC 0.056 nghĩa là mô hình có tín hiệu thực nhưng bài toán khó (nhãn `errors` phần lớn là lỗi vận hành ngẫu nhiên).

> **Đóng góp của time features (đọc bổ sung từ OLTP):** PR-AUC tăng từ 0.053 (chỉ DW) → **0.056** (+5%). Feature `txn_per_card_day` (velocity) và `txn_hour` lọt vào top-5 quan trọng — xác nhận giờ giao dịch và tần suất là tín hiệu thật cho fraud.

**Recall@k** (ứng dụng thực tế — đội review chỉ soi top-k% rủi ro nhất):

| Review top | Bắt được lỗi |
|---|---|
| 5% | 20.3% |
| 10% | 32.0% |
| 20% | 45.9% |

→ Nếu chỉ review 10% giao dịch điểm cao nhất, bắt được **~1/3** số lỗi thay vì soi toàn bộ.

**Top feature (SHAP):** `amount` (mạnh nhất), `yearly_income`, `merchant_id_freq`, **`txn_per_card_day` (velocity)**, **`txn_hour`**. Khớp trực giác: lỗi Insufficient Balance gắn với số tiền/thu nhập; giao dịch dồn dập trong ngày và khung giờ đêm rủi ro hơn.

## Hạn chế & hướng cải thiện

- **Time features đã bổ sung từ OLTP:** `db.py` đọc timestamp từ `BankingDB.transactions` (DW chỉ lưu tới ngày) để tạo `txn_hour`, `is_night`, `txn_weekday`, `txn_per_card_day` (velocity). Đây là lý do PR-AUC cải thiện +5%.
- **Nhãn `errors` không phải fraud thật:** phần lớn là lỗi vận hành (Insufficient Balance, Bad PIN), nên trần hiệu năng bị giới hạn bởi tính ngẫu nhiên của lỗi khách hàng — đây là lý do chính PR-AUC không thể cao hơn nhiều.
- **Velocity đơn giản:** hiện đếm số GD/thẻ/ngày. Có thể tinh hơn với cửa sổ giờ/phút (velocity thời gian thực) nếu cần.
- **Chưa tune sâu:** giữ grid hyperparameter nhỏ, hợp lý. Có thể thêm Optuna nếu cần.

## Artifacts (`models/`)

| File | Nội dung |
|---|---|
| `fraud_model.pkl` | Model tốt nhất (XGBoost) |
| `fraud_xgb.pkl` | XGBoost riêng cho SHAP |
| `feature_names.json` | 88 tên feature (đã verify không leakage) |
| `train_metrics.json` | PR-AUC/ROC-AUC 4 model |
| `eval_metrics.json` | Recall@k, confusion, top feature |
| `shap_summary.png` | SHAP summary plot |

---

**Trạng thái:** Bài A hoàn thành. Bài B (Credit risk) và C (Segmentation) chờ review trước khi triển khai — sẽ tái sử dụng `db.py` và `features.py`.
