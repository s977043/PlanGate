# Handoff — TASK-0099 / /simplify follow-up（#198/#199 局所クリーンアップ）
## 1. 要件適合確認
| AC | 判定 |
|----|------|
| AC1 keep-rate.py 改善 | PASS |
| AC2 context-engine.py 改善 | PASS |
| AC3 出力 main 等価（TASK-0095/0087/0090/0096 in-place）| PASS |
| AC4 MJ-2 回帰 + schema validate | PASS |
behavior-preserving（純リファクタ）。機能・受入・V-3 反映は不変。
## 2. 既知課題
- reuse H-1（plan_hash 抽出が check-plan-hash.sh/metrics_collector/keep-rate/
  context-engine の 4 箇所分散）/ M-2（REPO/WORKING パス 6+ 箇所重複）は
  **横断共有モジュール化＝別 PBI**（本 follow-up スコープ外・note のみ）。
## 3. V2 候補
- 共有 `scripts/plan_hash_util.py`（json ベース extract + current）新設し
  check-plan-hash.sh 意味整合のうえ 3 Python 呼び出し元を差し替え（EH-3 整合テスト付）。
- 共有 paths/_git/task_id バリデータ モジュール（横断 PBI）。
## 4. 妥協点
- 単一ファイル内の behavior-preserving 改善に限定（merged コードの横断改修は
  リスク高く別 PBI 化が妥当との reuse エージェント判断に従う）。
## 5. 引き継ぎ
/simplify 3 並列レビュー（reuse/quality/efficiency）の単一ファイル内・高価値
指摘を反映。keep-rate.py: 一括 git show(N fork→1)/_unknown・_ratio ヘルパ/
UNKNOWN・REFERENCED 定数/c3 json 化/hashlib top。context-engine.py:
_POLICY_ORDER 単一化/c3 json 化/_contract nesting 緩和/コメント trim。
全 TASK で main 版と in-place 出力等価を機械確認。横断共有化は別 PBI。
## 6. テスト結果
T1-T4 + E1 全 PASS（compile / in-place 等価 / MJ-2 回帰 / schema validate）。
