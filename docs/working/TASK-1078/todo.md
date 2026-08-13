# TASK-1078 S-2 EXECUTION TODO

> 正本: [`plan.md`](./plan.md) / 受入基準: [`pbi-input.md`](./pbi-input.md) / 検証: [`test-cases.md`](./test-cases.md)
> mode = `high-risk` のため **各実装タスクに `rollback:` を必須記載**する。
> L-0 / V-1〜V-4 / PR 作成は workflow-conductor が制御するため本 TODO には含めない。

## 依存関係

```text
T-01 ─→ T-02 ─→ T-03 ─→ H-01(👤 Gate) ─→ T-04 ─→ T-06
                          │
                          └─→ T-05（trusted_hash 手順・T-04 の前提）
T-07（doc）は T-02 完了後いつでも可・H-01 に依存しない
H-02(👤 C-4) は全タスク完了後
```

⚠️ **T-04（注記キー除去）は H-01 の承認なしに実行してはならない。** 本 PBI で唯一の不可逆ステップ。

## 🤖 Agent タスク

### 準備フェーズ

- [ ] **T-01**: fixture と baseline テストの導入
  - owner: agent / depends_on: なし / AC: AC-01 の土台
  - 実 payload 形状の fixture 6 件（`apply_patch` × 4 / `Bash` × 2）+ `tests/extras/codex-bridge/run.sh`
  - **env（`PLANGATE_HOOK_TASK` / `PLANGATE_HOOK_STRICT` / `PLANGATE_DELEGATION_NOCOMMIT`）を必ず明示設定**する（セッションからの継承を禁止）
  - 期待値は **現行 bridge の挙動**で記述し、無改造で PASS することを確認する
  - 🚩 チェックポイント: `.codex/` に差分が無いこと
  - `rollback:` `git rm -r tests/extras/codex-bridge` — ランタイム影響なし

### 実装フェーズ

- [ ] **T-02**: bridge の I/O 契約修正（TDD）
  - owner: agent / depends_on: T-01 / AC: AC-01・AC-02・AC-04・AC-05
  - 期待値を修正後契約に更新 → **RED 確認** → 実装 → **GREEN 確認** の順を守る
  - 実装内容: (a) stdin 転送 (b) stdout / stderr の分離捕捉 (c) **stdout のみ**で判定 (d) 未知 rc → deny (e) `scripts/hooks/` → `scripts/` フォールバック (f) deny の reason 常時非空
  - 🚩 チェックポイント: `scripts/**` と `.claude/**` に差分が無いこと（HO 不可侵）
  - `rollback:` `git checkout -- .codex/hooks/eh-bridge.sh` — **この時点では Codex 未登録のため無害**

- [ ] **T-03**: 変異注入によるテスト検出力の実証
  - owner: agent / depends_on: T-02 / AC: AC-03
  - 変異 1: stdin 転送を戻す → **EH-9 ケースが FAIL** すること
  - 変異 2: stdout 判定を戻す → **EH-1 / EH-2 ケースが FAIL** すること
  - 変異は **call site（bridge の該当行）を壊す**。テスト側の期待値を書き換えて FAIL を作らない
  - 🚩 チェックポイント: 2 変異とも FAIL を確認し、**元に戻したうえで GREEN** を再確認する
  - `rollback:` 変異は一時適用のみ。`git checkout -- .codex/hooks/eh-bridge.sh` で復帰

- [ ] **T-04**: matcher の死に文字列除去
  - owner: agent / depends_on: T-03 / AC: AC-06 の前段
  - `apply_patch|Edit|Write` → `apply_patch`。`Bash` group は不変。**注記キーは残す**
  - 🚩 チェックポイント: `hooks/list` が依然 PlanGate hook **0 件** + 同一 warning（＝未有効化のまま）
  - `rollback:` `git checkout -- .codex/hooks.json`

### 検証フェーズ

- [ ] **T-05**: `trusted_hash` 手順の確立（T-06 の前提）
  - owner: agent / depends_on: T-04 / AC: AC-06
  - `hooks.json` 編集後に hash が変わることを踏まえ、「編集 → 再 trust」の手順を文書化する
  - hash は **hook 単位**（同一ファイル内の別 matcher group は個別）である点を明記する
  - `rollback:` 不要（手順記述のみ・`CODEX_HOME` 側の設定変更は Human が実施）

- [ ] **T-06**: 注記キー除去＝**有効化**（唯一の不可逆ステップ）
  - owner: agent / depends_on: **H-01（承認）** / AC: AC-06・AC-07
  - top-level を `description` / `hooks` の 2 キーのみにする
  - `hooks/list` で 登録 5 件・`warnings[]` 空・`enabled` true・`trustStatus=trusted` を確認する
  - H-01 で承認された場合のみ `codex exec` を **1 回**実行し、block 証跡（stderr の `Command blocked by PreToolUse hook:` + 対象ファイル不在）を保存する
  - 🚩 チェックポイント: **登録件数を成果として報告しない**。deny / block の証跡が取れて初めて完了扱い
  - `rollback:`
    1. **即時無効化**: top-level に不正キー 1 行（例 `"$note"`）を戻す → parse 拒否で全件未登録に戻る（双方向再現済み）
    2. `git revert <T-06 commit>`
    3. 緊急時は `PLANGATE_BYPASS_HOOK=1`

- [ ] **T-07**: 責務分界の曖昧さ解消（doc）
  - owner: agent / depends_on: T-02 / AC: AC-09
  - `docs/ai/settings-wiring-contract.md` の責務分界節を**パス単位の表**へ置換し、機械判定（HO 9 カテゴリに `.codex` が無いこと）との一致を明記する
  - `rollback:` `git checkout -- docs/ai/settings-wiring-contract.md`

### 完了フェーズ

- [ ] **T-08**: 非回帰の証明
  - owner: agent / depends_on: T-06 / AC: AC-08
  - `git diff origin/main -- scripts/hooks .claude` が **差分 0** であることを出力ごと保存する
  - `rollback:` 不要（読取のみ）

- [ ] **T-09**: status.md 追記 / handoff.md 発行
  - owner: agent / depends_on: T-08
  - `status.md` は**既存記述を改変せずフェーズ履歴を追記**する（S-1 の記録は別ワーカーの成果）
  - AC-07 が WARN の場合は理由・代替・未充足リスクを handoff に必須記載する
  - `rollback:` 不要（文書のみ）

## 👤 Human タスク

- [ ] **H-01（C-3 相当の追加ゲート / exec 中の有効化判断）**
  - depends_on: T-05
  - 判断事項:
    1. 有効化後の deny 範囲（plan の実測表）を許容するか
    2. **AC-07 の `codex exec` 実走 1 回（課金あり）を許可するか**
    3. `CODEX_HOME` 側 `trusted_hash` 設定の適用（**外部状態の変更＝Human-owned**）
  - ⚠️ この承認が無い限り T-06 に進まない（自己設置 Gate。`/goal` や autonomy 指示では解除されない）

- [ ] **H-02（C-3 ゲート・本 plan の承認）**
  - `high-risk` のため **autonomous APPROVE 不可**。人間の同期 C-3 が必須
  - `approvals/c3.json` の発行は Human（AI は作成しない）

- [ ] **H-03（C-4 ゲート・PR レビュー）**
  - merge は Human-owned 固定

## 完了条件

- AC-01〜AC-06・AC-08・AC-09 が PASS
- AC-07 が PASS、または **WARN（理由・代替・未充足リスクを記録）**
- `scripts/**` / `.claude/**` に差分 0
- `handoff.md` が必須 6 要素を満たして発行済み
