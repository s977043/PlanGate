# TASK-0818 D-3 設計: discovery候補 → 既存Gate接続

> 親: #822（HITL→HOTL EPIC）/ #818。承認済み: D-3まで（Human決定 2026-07-11）。
> 不変条件: discoveryはGateをbypassしない。着手判断は既存arbiter/ai-loop-cycleが行う。merge/HO/重大はHuman。

## Goal

D-2が出したcandidateを「次に何をすべきか」まで具体化する。discovery自身はexecしない・arbiterを呼ばない。
**人間またはorchestratorがcandidateを見て、既存のai-loop-cycle（W check→arbiter→...)を通常どおり起動する導線を明確にする。**

## 設計方針（bypassしない、を機械的に保証する）

D-3は新しい実行経路を作らない。既存の `ai-loop-cycle` skill／`execution-runbook.md` の入口を、
discoveryの出力からそのまま辿れる形にするだけ。

### 変更点（discovery.py への追記のみ・新規ファイルなし）

1. `candidates[].recommended_next` を具体化する:
   - 現状: 固定文字列 `"propose-to-ai-loop-cycle"`
   - 変更後: `{"action": "propose-to-ai-loop-cycle", "entry_point": "docs/workflows/ai-loop/execution-runbook.md", "next_step": "human/orchestratorがissueを読み、通常のai-loop-cycle（W check→arbiter裁定）をこのissueに対して開始する"}`
   - discoveryはexecを一切呼ばない。テキストの道しるべを厚くするだけ

2. `--emit-next-command` オプション（任意・read-only）:
   - candidate一覧に対し、人間がコピペ実行できる**提案コマンド文字列**を出力に含める（例: `# candidate #123: 'ai-loop-cycle' skillを issue #123 に対して開始してください`）
   - discovery自身はこのコマンドを実行しない（文字列生成のみ）

3. サマリに「次にGateを通すのはHuman/orchestratorの判断」である旨を明記（bypass不可の明示）

## Out of scope（本Sliceでやらないこと）

- discovery.pyからarbiter.pyを直接呼び出す自動化（bypassリスクがあるため今回はしない）
- issue自動assign・自動exec起動
- 上記が必要になった場合は別issueでHuman承認を得る

## Testing

- candidatesのrecommended_nextが構造化オブジェクトになっている
- `--emit-next-command` で提案コマンド文字列が出力される
- 既存のread-only不変・no-bypass不変のテストが維持される
- discovery.pyがsubprocess/exec/git操作を一切呼ばないことの回帰テスト維持

## Mode

standard（既存2ファイルの追記のみ）。承認境界非接触。
