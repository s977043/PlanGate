# Handoff — TASK-0101 / #277 scripts パス定数共有モジュール化（reuse M-2）
## 1. 要件適合確認
| AC | 判定 |
|----|------|
| AC1 _paths.py 固定定数(REPO_ROOT/SCRIPTS_DIR/WORKING_DIR/SCHEMAS_DIR)| PASS |
| AC2 11 script が _paths 参照・ローカル重複除去 | PASS（11/11）|
| AC3 全スイート回帰なし | PASS（68 passed 0 failed）|
| AC4 behavior-preserving（smoke + plan_hash 等価）| PASS |
| AC5 shell/hooks/bin 無変更 | PASS（git diff 空）|
V-1 PASS。V-3 = Codex 無応答のため precedent に従い機械自己 V-3 全観点 PASS。

## 2. 検討経緯（ユーザー指示: Codex相談→決定→実装）
- Codex 相談: EPIC #193 完遂で混入懸念消滅・8(実態11)ファイル focused・
  ユーザー進行希望 → 「今・最小リファクタとして実装」推奨。設計助言
  （固定定数のみ/override・env・package化なし/shell・hooks 不巻込/
  plan_hash_util 無理に依存させない/sys.path.insert 慣習整合）を全採用。
- 実装後 V-3: Codex CLI 10分超無応答 → 確立 precedent（外部不可時は実証
  検証が意見より強い）で機械自己 V-3 に切替・全観点 PASS。

## 3. 既知課題 / V2
- bootstrap 行（sys.path.insert）が各 script に 1 行増。将来 scripts/ を
  正式 package 化する場合は本 bootstrap を __init__ 解決へ移せる（V2・YAGNI）。
- eval-runner/context-engine/keep-rate/metrics_collector は plan_hash_util 用の
  既存 sys.path.insert も持つ（重複だが無害・behavior 不変）。統合は V2 任意。

## 4. 妥協点
- _paths を private 名（直接実行されない共有定数モジュール）に。package 化・
  env override は YAGNI で見送り（Codex 助言・#277 Non-goal 準拠）。
- V-3 外部レビューは Codex 無応答により機械自己検証で代替（precedent）。

## 5. 引き継ぎ
#277（reuse M-2）解消。scripts/_paths.py に REPO/WORKING/SCHEMAS/SCRIPTS を
集約、11 script を alias import で behavior-preserving 置換（下流変数名・値
不変）。shell/hooks/bin/plan_hash_util 不変。全スイート 68/0・CLI smoke 全 OK・
metrics plan_hash 等価。これで reuse follow-up（H-1 #276 / M-2 本 #277）完了。
EPIC #193 配下の reuse 由来技術負債ゼロ。

## 6. テスト結果
V-1 AC1/2/5 + V-3 機械 9 観点 + run-tests 68/0 + 主要 CLI 7 smoke + metrics
plan_hash 等価 + shell 無変更 全 PASS。
