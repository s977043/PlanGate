# 修正前 → 修正後 実測対比 — TASK-1109 (#1109)

base: `7d91f7b`（`origin/main`）/ 実行環境: macOS, python3 あり

## 既定 target（引数なし）

| 項目 | 修正前 | 修正後 |
|------|--------|--------|
| 検査 root | `.codex/skills` のみ | **`.codex/skills` + `plugin/plangate/skills`** |
| 出力 | `Checked 39 skills` | `SKILL.md dirs=39 / openai.yaml dirs=39 / field-checked=39`（root ごと）+ `Checked 78 skills across 2 target(s)` |
| VIOLATIONS | **8** | **0** |
| rc | **1** | **0** |
| `--warn-only` の rc | 0 | 0（不変） |

## `--target plugin/plangate/skills`（配布物）

| 項目 | 修正前 | 修正後 |
|------|--------|--------|
| 出力 | `Checked 35 skills` | `SKILL.md dirs=39 / openai.yaml dirs=39 / field-checked=39 / ignored=1` |
| 未検出だった欠落 | **4 件（silently skip）** | **0**（4 件を補完済。欠落があれば violation として名指しされる） |
| VIOLATIONS | 1（`diff-audit` の 66 文字） | **0** |
| rc | 1 | **0** |

> 修正前の `Checked 35` は「35 件検査して 1 件違反」ではなく
> 「**openai.yaml がある 35 件しか見ていない**」だった（欠落 4 件は出力に一切現れない）。

## `--target .codex/skills`

| 項目 | 修正前 | 修正後 |
|------|--------|--------|
| VIOLATIONS | 8（全て `short_description too long`） | **0** |
| rc | 1 | **0** |

## target 不在時（契約）

| コマンド | 修正前 | 修正後 |
|---------|--------|--------|
| `--warn-only --target /tmp/nonexistent` | `FileNotFoundError` traceback / **rc=1**（契約違反） | 理由付き 1 行 + violation 出力 / **rc=0** |
| `--target /tmp/nonexistent` | 同上（traceback） | `target directory not found` / **rc=1**（traceback なし） |

## 既存 8 violations の内訳と処理

すべて `.codex/skills/*/agents/openai.yaml` の `short_description` 長さ超過。
`install-plangate-skills-to-codex.sh` が 64 文字切り詰めロジックを持つ**前**に生成された
stale 資産であり、同スクリプトの `--force` 再生成で全件解消した。

| # | skill | 長さ | 処理 |
|---|-------|------|------|
| 1 | `context-packager` | 94 | 再生成で解消 |
| 2 | `design-gate` | 100 | 再生成で解消 |
| 3 | `evidence-ledger` | 100 | 再生成で解消 |
| 4 | `intent-classifier` | 100 | 再生成で解消 |
| 5 | `pr-decision` | 100 | 再生成で解消 |
| 6 | `skill-creator` | 100 | 再生成で解消 |
| 7 | `skill-policy-router` | 100 | 再生成で解消 |
| 8 | `subagent-dispatch` | 100 | 再生成で解消 |

配布物側の追加 5 件（本 PBI で新たに検出できるようになったもの）:

| # | skill | 内容 | 処理 |
|---|-------|------|------|
| 9–12 | `ai-loop-cycle` / `breakdown-gate` / `ref-integrity-scan` / `subagent-delegation-brief` | `agents/openai.yaml` 欠落 | 手書き英語 description で新規作成（既存 34 件のスタイル踏襲） |
| 13 | `diff-audit` | `short_description` 66 文字 | 50 文字へ短縮 |

## 巻き込みを避けた差分（スコープ外・報告のみ）

`install-plangate-skills-to-codex.sh --force` は openai.yaml 8 件のほかに
**`.codex/skills` の SKILL.md 4 件**（`ai-dev-exec` / `ai-loop-cycle` /
`local-exec-handoff` / `plan-review-gate`）も更新した。これは `.codex/skills` が
`.agents/skills` に対して stale であることを意味する（#1086 の二重 root 問題の実体）。
**本 PBI では revert し、スコープ外の報告事項として残した。**
