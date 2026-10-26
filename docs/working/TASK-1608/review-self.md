# TASK-1608 C-1 セルフレビュー

> 対象: plan.md / todo.md / test-cases.md（初版、2026-10-24）。実施者は plan 作成者本人（独立レビューではない）。

## 簡易 C-1 再判定（2026-10-26、plan 改訂 3 = 検証モデルの変更 / D-016 / R-001〜R-012 反映後）: WARN

FAIL 項目なし。下記 2 点を Human の C-3 で確認してほしいため WARN。

- C1-PLAN-01 / C1-TEST-13: R-001（D-1d）→ TC-NEST-C4〜C7・N4〜N6、R-002 / R-005〜R-010 / R-012 → TC-DIFF-01〜09、R-003 → TC-CORPUS-01〜03。L1 指摘 8 件すべてに R-NNN と反映先がある → PASS
- C1-PLAN-02 Unknowns: HD-1 / HD-2 は D-016 で決定済み。参照パーサーの準拠 spec 版は exec で実測（plan に明記）→ PASS
- C1-PLAN-03 スコープ: 変更ファイルが増える（差分ハーネス・requirements・fixture）。R-011 の採否と理由を plan に記載。HO（`test.yml`）は patch と適用スクリプトのみで AI は適用しない → PASS
- C1-PLAN-04 テスト戦略: FALSE_REJECT を不合格にし、REJECT 率・件数・版・ハッシュを assert。陽性対照を CI で検査 → **WARN**: REJECT 率上限 50% / `out_of_scope=False` 下限 50% は AI が置いた閾値で、実測の根拠はまだ無い（exec の T-25 で生成器の分布を測り、閾値を変える場合は status に逸脱として記録する）
- C1-PLAN-08/09: 停止条件を E-1〜E-5 の測定可能な条件に再定義。HO 未適用の間は E-1 未達扱い → PASS
- C1-TODO: H-5 → T-23〜T-27 → H-6（Human の HO 適用）→ T-28 → T-29 → T-12、rollback 記載 → **WARN**: T-28 以降は Human の HO 適用（H-6）に依存し、適用まで PR を ready にできない
- C1-SEC-01: 参照パーサーはテスト側のみ・`--require-hashes --no-deps`・venv。impl の import は不変（AC-9 / TC-STRUCT-02）→ PASS
- 注記: 既存の `approvals/c3.json`（plan_hash 24a35af0…）は本改訂と一致しない（編集・削除していない）。HO patch の dry-run は `apply-test-yml.sh --dry-run` で forward 適用可能（rc=0、2026-10-26）

## 簡易 C-1 再判定（2026-10-25、Human 裁定「入れ子をすべて拒否」による plan 改訂 2 後）: PASS

- C1-PLAN-01 / C1-TEST-13: D-1c を AC-10（守備範囲外は fail-closed）/ AC-11（誤拒否なし）の範囲で扱い、TC-NEST-A / B（R6 再現 A・B）/ 03〜07（拒否）/ N1〜N3（同じ深さの blockquote 継続・トップレベルの複数項目・リスト内 fence の受理）に対応づけた → PASS
- C1-PLAN-02 Unknowns: 入れ子の解釈は行わない（D-014）。単一の container 値で正しい根拠（深さ ≤1 ⇒ 最上段の種別でスタックと同値、上書きの行は更新前に拒否）を plan に記載 → PASS
- C1-PLAN-03 スコープ: 変更は同じ 2 ファイル。HO パスなし。pbi-input は変更不要（入れ子は AC-10 の「守備範囲外の構造は fail-closed」に含まれる）→ PASS
- C1-PLAN-04 テスト戦略: 現行データの入れ子 0 行・オフセット ≠2 のリスト 0 行を、陽性対照つきで事前実測して記載 → PASS
- C1-PLAN-08/09: 改訂 2 後は R7 から下限 2、コンテナ軸の新クラス 2 連続で再停止 → PASS
- C1-TODO: H-4 → T-17（RED）→ T-18 → T-19（R6 m-1）→ T-20（R6 m-2 件数是正）→ T-21 → T-22、rollback 記載 → PASS
- 注記: 既存の `approvals/c3.json`（plan_hash 439f1620…）は本改訂と一致しない（編集・削除していない）

## 簡易 C-1 再判定（2026-10-24、Human 裁定 (c) による plan 改訂後）: PASS

- C1-PLAN-01 / C1-TEST-13: AC-11 を追加し、TC-CB-01〜07（拒否側。TC-CB-01 は R4 の再現）/ TC-CB-N1〜N3（正常系）/ TC-INT-03 に対応づけた → PASS
- C1-PLAN-02 Unknowns: 「コンテナ境界をどう解釈するか」は解釈しない（拒否）と決定済み（D-011）→ PASS
- C1-PLAN-03 スコープ: 変更は同じ 2 ファイル。HO パスなし。規則の適用範囲は「空行なしのコンテナ切り替え」に一般化して定義し、例は種別として列挙 → PASS
- C1-PLAN-04 テスト戦略: 現行データでの誤拒否ゼロを受入条件にし、事前実測（境界は blockquote 継続のみ）を記載 → PASS
- C1-PLAN-08/09 Stop / Replan: 改訂後の敵対レビューは R5 から下限 2、コンテナ軸で新クラスが 2 連続なら再停止 → PASS
- C1-TODO: H-3（再承認）→ T-13（RED 記録）→ T-14 → T-15 → T-16 の順、rollback 記載 → PASS
- 注記: 既存の `approvals/c3.json` は初版の plan_hash であり本改訂とは一致しない（編集・削除していない）。exec 再開には Human の再承認が要る

## 簡易 C-1 再判定（2026-10-24、Q-1〜Q-4 確定反映後）: PASS

- C1-PLAN-02 Unknowns 処理: WARN → **PASS**（Q-1〜Q-4 を Human 回答で決定済み。decision-log D-004〜D-007）
- C1-PLAN-01 / C1-TEST-13: AC-10（Q-3 の読み替え）を追加し、test-cases の TC-BLK-01〜05 / TC-HTML-01〜04 に対応づけた → PASS
- C1-PLAN-03 スコープ: 依存追加をしないことが確定し、変更範囲は 2 ファイルのまま → PASS
- 他項目は plan の内容に変更がないため初回判定のまま

## 初回判定（2026-10-24）: WARN

FAIL 項目なし。Human 判断が必要な Unknowns（Q-1〜Q-4）が残るため WARN。

| ID | 観点 | 判定 | 所見 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | PASS | AC-1〜9 すべてに test-cases の対応あり |
| C1-PLAN-02 | Unknowns 処理 | WARN | Q-1〜Q-4 を推奨案つきで Human へ。Q-1 で代替案が選ばれたら plan 再生成 |
| C1-PLAN-03 | スコープ制御 | PASS | 変更は 2 ファイル。HO パス・出力スキーマ・依存追加は Out of scope と明記 |
| C1-PLAN-04 | テスト戦略 | PASS | unit / ta-116 / ta-70 / 現行データ / 変異注入 |
| C1-PLAN-05 | Work Breakdown Output | PASS | S1〜S6 に Output と 🚩 |
| C1-PLAN-06 | 依存関係 | PASS | todo の depends_on で直列化 |
| C1-PLAN-07 | 動作検証自動化 | PASS | 3 コマンドのログを evidence に保存 |
| C1-PLAN-08-AEE | Stop Condition | PASS | 3 条件を明記 |
| C1-PLAN-09-AEE | Replan Triggers | PASS | 現行データ 7 / 5 の変化、同層新クラス 2 連続 |
| C1-SUP-PLAN-01 | No Placeholders | PASS | |
| C1-SUP-PLAN-02 | Task Sizing | PASS | 12 タスク |
| C1-TODO-08〜12 | 粒度・depends_on・🚩・Iron Law・完了条件 | PASS | テスト先行（T-2）を実装より前に置く |
| C1-TODO-RB | rollback | PASS | 実装タスク全件に記載 |
| C1-TEST-13 | AC→TC 網羅 | PASS | |
| C1-TEST-14 | 具体性 | PASS | 最小再現の入力を記載 |
| C1-TEST-15 | エッジケース | PASS | 入れ子・CRLF・4 空白 fence |
| C1-SEC-01 | セキュリティ | PASS | 確認マーカー受理判定は安全側（誤拒否を許容し誤受理を避ける）。`authority` 不変 |
| C1-SCOPE-DISC-01 | スコープ規律 | PASS | |

## 自己指摘（反映済み）

- 初稿の D-3 は「先頭トークン判定をやめ値全体で判定」としていたが、`no, later` が受理される fail-open を生むため、
  現行の先頭トークン判定を維持する案へ改め、AC-6 と Q-4 を追加した
