"""
evaluate.py — Đánh giá mô hình phát hiện giao dịch lỗi (Bài A).

Nạp model đã lưu, đánh giá trên tập test 2024 (time-based hold-out):
  - Metric cho imbalanced: PR-AUC, ROC-AUC, Precision/Recall/F1 @ ngưỡng chọn.
  - Recall@k: bắt được bao nhiêu % lỗi khi review top-k% giao dịch rủi ro nhất.
  - Confusion matrix tại ngưỡng tối ưu F1.
  - SHAP summary plot (TreeExplainer trên XGBoost) → lưu ảnh models/.

Chạy: python src/evaluate.py   (cần chạy train_fraud.py trước)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import joblib
import numpy as np
import matplotlib
matplotlib.use("Agg")  # không cần GUI
import matplotlib.pyplot as plt
from sklearn.metrics import (
    average_precision_score,
    confusion_matrix,
    f1_score,
    precision_recall_curve,
    roc_auc_score,
)

sys.path.insert(0, str(Path(__file__).resolve().parent))
from db import read_fact_dataset  # noqa: E402
from features import build_features, time_split  # noqa: E402

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

MODELS_DIR = Path(__file__).resolve().parent.parent / "models"


def recall_at_k(y_true: np.ndarray, scores: np.ndarray, k_frac: float) -> float:
    """Recall khi review top k_frac (vd 0.05 = 5%) giao dịch điểm cao nhất."""
    n = len(scores)
    k = max(int(n * k_frac), 1)
    top_idx = np.argsort(scores)[::-1][:k]
    caught = y_true[top_idx].sum()
    total_pos = y_true.sum()
    return caught / total_pos if total_pos else 0.0


def best_threshold(y_true: np.ndarray, scores: np.ndarray) -> float:
    """Tìm ngưỡng tối đa F1 từ precision-recall curve."""
    prec, rec, thr = precision_recall_curve(y_true, scores)
    # thr có len = len(prec)-1
    f1 = 2 * prec[:-1] * rec[:-1] / (prec[:-1] + rec[:-1] + 1e-12)
    if len(f1) == 0:
        return 0.5
    return float(thr[np.argmax(f1)])


def main() -> None:
    model_path = MODELS_DIR / "fraud_model.pkl"
    if not model_path.exists():
        raise SystemExit("Chưa có model. Chạy: python src/train_fraud.py trước.")

    print(">> Nạp dữ liệu & model ...")
    df = read_fact_dataset()
    X, y, feature_names = build_features(df)
    _, te = time_split(df)
    X_te, y_te = X.iloc[te].to_numpy(), y.iloc[te].to_numpy()

    model = joblib.load(model_path)
    xgb = joblib.load(MODELS_DIR / "fraud_xgb.pkl")
    scores = model.predict_proba(X_te)[:, 1]

    # --- Metric tổng ---
    pr = average_precision_score(y_te, scores)
    roc = roc_auc_score(y_te, scores)
    print(f"\n== Test 2024 ({len(y_te):,} giao dịch, {int(y_te.sum())} lỗi) ==")
    print(f"  PR-AUC   : {pr:.4f}")
    print(f"  ROC-AUC  : {roc:.4f}")

    # --- Recall@k (ứng dụng thực tế: đội review chỉ soi top-k%) ---
    print("\n  Recall@k (bắt lỗi khi review top-k% rủi ro nhất):")
    rak = {}
    for k in (0.01, 0.05, 0.10, 0.20):
        r = recall_at_k(y_te, scores, k)
        rak[f"{int(k*100)}%"] = r
        print(f"    top {int(k*100):2d}%  ->  recall {r:.3f}")

    # --- Ngưỡng tối ưu F1 + confusion matrix ---
    thr = best_threshold(y_te, scores)
    y_pred = (scores >= thr).astype(int)
    f1 = f1_score(y_te, y_pred)
    tn, fp, fn, tp = confusion_matrix(y_te, y_pred).ravel()
    prec = tp / (tp + fp) if (tp + fp) else 0.0
    rec = tp / (tp + fn) if (tp + fn) else 0.0
    print(f"\n  Ngưỡng tối ưu F1 = {thr:.4f}")
    print(f"    Precision={prec:.3f}  Recall={rec:.3f}  F1={f1:.3f}")
    print(f"    Confusion: TN={tn:,} FP={fp:,} FN={fn:,} TP={tp:,}")

    # --- SHAP ---
    print("\n>> SHAP (TreeExplainer trên XGBoost) ...")
    try:
        import shap
        # Lấy mẫu để nhanh (SHAP trên 46k dòng chậm)
        rng = np.random.RandomState(42)
        sample_idx = rng.choice(len(X_te), size=min(3000, len(X_te)), replace=False)
        X_sample = X.iloc[te].iloc[sample_idx]
        explainer = shap.TreeExplainer(xgb)
        shap_values = explainer.shap_values(X_sample)

        plt.figure()
        shap.summary_plot(shap_values, X_sample, feature_names=feature_names,
                          show=False, max_display=15)
        plt.tight_layout()
        shap_path = MODELS_DIR / "shap_summary.png"
        plt.savefig(shap_path, dpi=120, bbox_inches="tight")
        plt.close()

        # Top feature theo |SHAP| trung bình
        mean_abs = np.abs(shap_values).mean(axis=0)
        order = np.argsort(mean_abs)[::-1][:15]
        top_feats = [(feature_names[i], float(mean_abs[i])) for i in order]
        print(f"   Đã lưu {shap_path}")
        print("   Top 10 feature quan trọng:")
        for name, val in top_feats[:10]:
            print(f"     {name:32s}  {val:.4f}")
    except Exception as e:  # noqa: BLE001
        print(f"   SHAP bỏ qua (lỗi: {e})")
        top_feats = []

    # --- Lưu metrics đánh giá ---
    eval_metrics = {
        "test_rows": int(len(y_te)),
        "test_errors": int(y_te.sum()),
        "pr_auc": pr,
        "roc_auc": roc,
        "recall_at_k": rak,
        "threshold_f1": thr,
        "precision": prec,
        "recall": rec,
        "f1": f1,
        "confusion": {"tn": int(tn), "fp": int(fp), "fn": int(fn), "tp": int(tp)},
        "top_features": top_feats,
    }
    (MODELS_DIR / "eval_metrics.json").write_text(
        json.dumps(eval_metrics, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n>> Đã lưu {MODELS_DIR/'eval_metrics.json'}")


if __name__ == "__main__":
    main()
