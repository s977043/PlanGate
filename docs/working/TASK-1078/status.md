# TASK-1078 status — Codex CLI parity の実態是正

- issue: [#1078](https://github.com/s977043/plangate/issues/1078)
- ブランチ: `docs/1078-parity-truth-2`（base = `origin/main`）
- 先行 PR: [#1080](https://github.com/s977043/PlanGate/pull/1080)（**MERGED**。1 度目の是正）
- 関連 PR: #1082（spike ブランチの証跡）

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|------|---------|------|
| 2026-08-13 10:00 | 是正 1 | PR #1080: 「達成済」→「部分達成（5 / 11 wiring）・強制力は未検証」 |
| 2026-08-13 14:30 | 是正 2 | `hooks/list` 実測で **登録 0 件**が判明。「強制力 0 / 11」へ再是正 |
| 2026-08-13 16:10 | 差し戻し | PR 前レビューで critical 1 / major 4 / minor 4 / info 2 |
| 2026-08-13 16:40 | 是正 3 | **C-1**: 「除去すると全 deny で使用不能」は**誤り**（実測は 12/12 `allow`）。禁止の結論は維持し理由を差し替え。M-1〜M-4 / m-1〜m-4 / i-1 反映 |

## モード判定

**doc-light 除外 → 通常モード**。`.agents/skills/**` を含み、承認境界（HO）周辺の
記述を扱うため doc-light は適用しない。

## 残タスク

### BLOCKED（Human 適用待ち）

| # | タスク | blocker | owner | unblock_condition |
|---|--------|---------|-------|-------------------|
| B-1 | `CLAUDE.md:34` の「物理発火」記述の是正 | **HO パスのため AI は適用不可** | human | `git apply docs/working/TASK-1078/patches/CLAUDE.md.codex-parity.patch` |
| B-2 | `AGENTS.md:18` / `:48` の「Codex 側でも発火」記述の是正 | **HO パスのため AI は適用不可**。Codex セッションが読む正本のため実害最大 | human | `git apply docs/working/TASK-1078/patches/AGENTS.md.codex-parity.patch` |

> patch は **サンドボックスで実適用テスト済み**（`patch -p1` exit 0・適用後内容を確認）。
> `--check` のみでは済ませていない。

### 未着手（別 PBI / 本 PR スコープ外）

- [ ] **S-2**: `eh-bridge.sh` の I/O 契約修正（**stdin 転送の実装を先行必須**）+ 注記キー除去を**同一 PR**で。**受入基準は「deny が実際に返ること」**（「`hooks/list` に登録された」を受入基準に使わない）
- [ ] **S-3**: `hooks/list` ベースの機械検出を doctor / CI へ追加（登録件数・`warnings[]` 空・`enabled`）
- [ ] **S-4**: `trusted_hash` 運用フロー整備（編集 → 再 trust）
- [ ] **S-5**: U-1 / U-2 の因果確定（モデル API 課金を伴う。**要 Human 判断**）
- [ ] **S-6**: 未是正の「達成済」主張の残存箇所（`README.md:90` / `:450`、`docs/ai-driven-development.md:312`、`.codex/README.md:43`、`.codex/skills/**`、`tests/extras/README.md:14`、`CHANGELOG.md` v8.10.0 節の誤読防止注記）。一覧は `docs/ai/settings-wiring-contract.md` §「達成済」主張の残存箇所 一覧

## 検証結果

| 項目 | 結果 |
|------|------|
| `hooks/list` 独立再現 | PlanGate hook 登録 **0 件** / parse 拒否 warning あり |
| bridge decision 実測 | **12 / 12 が `allow`**（HO パス含む） |
| plugin drift（CI 同等） | `sh scripts/sync-plugin-plangate.sh --dry-run` → **no changes** |
| markdownlint | 本 PR 由来 **0 件**（pre-existing のみ） |

## 参照

- 正本: [`docs/ai/settings-wiring-contract.md`](../../ai/settings-wiring-contract.md) §Codex CLI parity
- 証跡: [`evidence/hooks-list-reverify.md`](./evidence/hooks-list-reverify.md) / [`evidence/hooks-list-raw.json`](./evidence/hooks-list-raw.json)
- patch: [`patches/`](./patches/)
