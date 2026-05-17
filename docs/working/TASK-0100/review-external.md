# V-3 外部レビュー（Codex）— TASK-0100

> 検討経緯: Codex 相談 → 実証検証（shell sed vs python json の異常系挙動を
> /tmp/phtest で機械比較）→ Gemini 検証依頼（両モデル容量上限・確立 precedent
> に従い Codex 主体 + 実証検証で代替）→ 方針確定。

## 結果サマリ
critical: 0 / major: 0 / minor: 3 / info: 7 — **APPROVE**

## 指摘と対応
| ID | severity | 指摘 | 対応 |
|----|----------|------|------|
| mn-1 | minor | recorded_plan_hash が top-level 非 object の valid JSON（[]/"x"/123）で AttributeError。契約 docstring「不正は None」と不整合 | `isinstance(data, dict)` ガード追加→非 object は None（承認記録として信用しない・契約一貫）。[]/"x"/123/{bad すべて None 確認 |
| mn-2 | minor | ta-11 の python -c に $PHC_ROOT/$1 直接埋め込み（パス特殊文字で構文破壊）| `python3 - "$PHC_ROOT/scripts" "$1" <<'PY'` argv 経由 heredoc 化（pass=4 維持）|
| mn-3 | minor | metrics_collector の sha256_hex/hashlib が未使用残置 | 削除（inline hashlib 除去意図と一貫・hashlib残=0）。metrics plan_hash は util 経由で完全等価維持 |
| info×7 | info | strict json=承認境界保護妥当 / ta-11 parity+意図差異固定 / 差し替え behavior-preserving / import 方式整合 / _sys/_P 非衝突 / PHC_ROOT 解決整合 / Non-goal 遵守・68 passed | 対応不要 |

## 判定
APPROVE（critical/major 0）。minor 3 全反映。回帰: 非object/不正JSON→None /
ta-11 pass=4 fail=0 / 全スイート 68 passed 0 failed / metrics plan_hash 等価 /
check-plan-hash.sh 無変更。
