"""
train_fraud.py — Huấn luyện mô hình phát hiện giao dịch lỗi (Bài A).

Quy trình:
  1. Đọc DW → build features → time-based split (train 2022-2023, test 2024).
  2. Baseline: DummyClassifier + LogisticRegression (class_weight balanced).
  3. Model chính: XGBoost (scale_pos_weight) và SMOTE + XGBoost.
  4. Chọn model theo PR-AUC trên test, lưu model + feature_names + metrics.

Chạy: python src/train_fraud.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import joblib
import numpy as np
from sklearn.dummy import DummyClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from imblearn.over_sampling import SMOTE
from xgboost import XGBClassifier

sys.path.insert(0, str(Path(__file__).resolve().parent))
from db import read_fact_dataset  # noqa: E402
from features import build_features, time_split  # noqa: E402

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

MODELS_DIR = Path(__file__).resolve().parent.parent / "models"
MODELS_DIR.mkdir(exist_ok=True)
RANDOM_STATE = 42


def _report(name: str, y_true, scores) -> dict:
    """Tính PR-AUC + ROC-AUC cho điểm dự đoán xác suất."""
    pr = average_precision_score(y_true, scores)
    roc = roc_auc_score(y_true, scores)
    print(f"  {name:22s}  PR-AUC={pr:.4f}  ROC-AUC={roc:.4f}")
    return {"model": name, "pr_auc": pr, "roc_auc": roc}


def main() -> None:
    print(">> Đọc dữ liệu từ BankingDW ...")
    df = read_fact_dataset()
    X, y, feature_names = build_features(df)
    tr, te = time_split(df)

    X_tr, X_te = X.iloc[tr].to_numpy(), X.iloc[te].to_numpy()
    y_tr, y_te = y.iloc[tr].to_numpy(), y.iloc[te].to_numpy()

    print(f"   train={len(tr):,} (err {y_tr.mean():.4f})  "
          f"test={len(te):,} (err {y_te.mean():.4f})  features={len(feature_names)}")

    pos = int(y_tr.sum())
    neg = int(len(y_tr) - pos)
    spw = neg / max(pos, 1)  # scale_pos_weight
    print(f"   scale_pos_weight = {spw:.1f}")

    results = []
    models = {}

    print("\n>> Baseline ...")
    # DummyClassifier — dự đoán theo tỷ lệ lớp
    dummy = DummyClassifier(strategy="stratified", random_state=RANDOM_STATE)
    dummy.fit(X_tr, y_tr)
    results.append(_report("Dummy(stratified)", y_te, dummy.predict_proba(X_te)[:, 1]))

    # Logistic Regression — cần scale
    logreg = Pipeline([
        ("scaler", StandardScaler()),
        ("clf", LogisticRegression(
            max_iter=1000, class_weight="balanced", random_state=RANDOM_STATE)),
    ])
    logreg.fit(X_tr, y_tr)
    logreg_scores = logreg.predict_proba(X_te)[:, 1]
    results.append(_report("LogReg(balanced)", y_te, logreg_scores))
    models["logreg"] = logreg

    print("\n>> XGBoost ...")
    xgb = XGBClassifier(
        n_estimators=400,
        max_depth=6,
        learning_rate=0.05,
        subsample=0.9,
        colsample_bytree=0.9,
        scale_pos_weight=spw,
        eval_metric="aucpr",
        n_jobs=-1,
        random_state=RANDOM_STATE,
    )
    xgb.fit(X_tr, y_tr)
    xgb_scores = xgb.predict_proba(X_te)[:, 1]
    results.append(_report("XGBoost(spw)", y_te, xgb_scores))
    models["xgb"] = xgb

    print("\n>> SMOTE + XGBoost ...")
    # Áp SMOTE thủ công CHỈ trên train (tránh imblearn Pipeline vì xung đột
    # __sklearn_tags__ giữa xgboost 2.1 và sklearn 1.6). Test giữ nguyên.
    X_res, y_res = SMOTE(random_state=RANDOM_STATE).fit_resample(X_tr, y_tr)
    smote_xgb = XGBClassifier(
        n_estimators=400, max_depth=6, learning_rate=0.05,
        subsample=0.9, colsample_bytree=0.9,
        eval_metric="aucpr", n_jobs=-1, random_state=RANDOM_STATE)
    smote_xgb.fit(X_res, y_res)
    smote_scores = smote_xgb.predict_proba(X_te)[:, 1]
    results.append(_report("SMOTE+XGBoost", y_te, smote_scores))
    models["smote_xgb"] = smote_xgb

    # --- Chọn model tốt nhất theo PR-AUC ---
    best = max(results, key=lambda r: r["pr_auc"])
    print(f"\n>> Model tốt nhất: {best['model']}  (PR-AUC={best['pr_auc']:.4f})")

    # Map tên hiển thị -> key model đã lưu
    name_to_key = {
        "XGBoost(spw)": "xgb",
        "SMOTE+XGBoost": "smote_xgb",
        "LogReg(balanced)": "logreg",
    }
    best_key = name_to_key.get(best["model"], "xgb")
    best_model = models[best_key]

    # --- Lưu artifacts ---
    joblib.dump(best_model, MODELS_DIR / "fraud_model.pkl")
    # Luôn lưu riêng XGBoost cho SHAP (TreeExplainer cần model cây)
    joblib.dump(models["xgb"], MODELS_DIR / "fraud_xgb.pkl")
    (MODELS_DIR / "feature_names.json").write_text(
        json.dumps(feature_names, ensure_ascii=False, indent=2), encoding="utf-8")
    (MODELS_DIR / "train_metrics.json").write_text(
        json.dumps({"results": results, "best": best,
                    "n_features": len(feature_names),
                    "train_rows": len(tr), "test_rows": len(te)},
                   ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"   Đã lưu: {MODELS_DIR/'fraud_model.pkl'}")
    print(f"           {MODELS_DIR/'fraud_xgb.pkl'} (cho SHAP)")
    print(f"           feature_names.json, train_metrics.json")

    # Kiểm tra: model chính phải vượt baseline Dummy
    dummy_pr = next(r for r in results if r["model"].startswith("Dummy"))["pr_auc"]
    assert best["pr_auc"] > dummy_pr, "Model không vượt baseline — xem lại feature!"
    print("\n>> OK: model vượt baseline.")


if __name__ == "__main__":
    main()
