# #982 patch — `.claude/commands/ai-loop-workflow.md` の入口表記（**Human 適用**）

> 対象: `.claude/commands/ai-loop-workflow.md`（**HO 9 カテゴリ**の `.claude/commands/*.md`）
> 同期先: `plugin/plangate/commands/ai-loop-workflow.md`（`sh scripts/sync-plugin-plangate.sh` が生成）
> 測定基点: `origin/main` = `4a625c1` / 2026-08-19
> 関連 PR: `docs/982-cli-entry-reality`（skills / docs 側 4 箇所を是正済み）

## なぜ AI が到達できないか

`.claude/commands/*.md` は **Hardening Override 9 カテゴリ**
（[`.claude/rules/mode-classification.md`](../../../.claude/rules/mode-classification.md)
「承認境界周辺の変更」節）に含まれ、**AI は c3 + plan_hash 承認があっても編集できない**。
本件は 1 行の表記修正だが、**規模ではなくパスで塞がれている**。

`scripts/apply-*.sh` 形式ではなく **patch 文書**として提示するのは、`.sh` を新規追加しても
`scripts/` 自体が本 PR のスコープ外であり、かつ 1 箇所の文字列置換に実行スクリプトを
起こす必要がないため（既存の `_reports/*-patch.md` と同形式）。

---

## 問題: 表記が CLI 呼び出しに見える

### 実測（両方とも真）

| 主張 | 実測 | 根拠 |
|---|---|---|
| `/ai-loop-workflow run TASK-XXXX` は**実在する** | ✅ **真** | `.claude/commands/ai-loop-workflow.md:19-27`（TASK ID 必須・Plan Package 束縛） |
| `bin/plangate` に `ai-loop` サブコマンドがある | ❌ **偽** | `grep -cE '^\s+ai-loop\)\|"ai-loop"' bin/plangate` → **0** |

```sh
$ grep -cE '^\s+ai-loop\)|"ai-loop"' bin/plangate
0
$ bin/plangate ai-loop --help
（実行失敗）
```

**欠陥は「入口の不在」ではなく「表記の曖昧さ」である。**
`ai-loop run TASK-XXXX` という書き方が `plangate ai-loop run …` という CLI 呼び出しに
読め、実際にそう読んだ結果が issue #982 の起票理由になっている。

> **#982 の issue 本文自身がこの取り違えをしている。**
> 「`bin/plangate` の dispatch に `ai-loop` は存在しない」は**正しい**が、
> そこから「入口が無い」は導けない。#982 の 3 案（A: CLI 追加 / B: docs を実体へ /
> C: wrapper 新設）は**いずれもこの前提の上に立っている**ため、本 patch は
> **どの案も選ばない**。表記の曖昧さだけを解消する。

### 現状の記述

```text
.claude/commands/ai-loop-workflow.md:21

- `run TASK-XXXX` — **Plan-first の正式入口**（TASK ID 必須）。既存の Plan Package
```

`正式入口` であること自体は正しい（TASK-0872 / #872 が実装したのは
**slash command の引数仕様**であり、`bin/plangate` のサブコマンドではない）。
不足しているのは **CLI サブコマンドではない**という但し書きのみ。

---

## 差分（1 箇所・追記のみ）

```diff
 - `run TASK-XXXX` — **Plan-first の正式入口**（TASK ID 必須）。既存の Plan Package
   （pbi-input / plan / todo / test-cases + C-1/C-2 evidence）を起点に production run を
   開始する。LoopSpec は `scripts/ai-loop/plan_package.py` の `derive_loopspec()` で
   Plan Package から決定論派生し、`production: true` + `plan_package` ブロックを
   arbiter へ渡す（契約正本: `docs/workflows/ai-loop/c3-prime-contract.md`）。
   TASK ID を伴わない自由文だけの `run <説明>` は **production run を開始できない**
   （TASK-0872 / #872。Plan Package 束縛の無い run を Wチェックへ進めない）
+  **本コマンドの引数仕様であり `bin/plangate` のサブコマンドではない**
+  （`plangate ai-loop run …` は失敗する。CLI 入口を設けるか否かは #982 で未決）
```

**`正式入口` の語は変更しない。** 変えると skills / docs 側 4 箇所（本 PR で是正済み）
および `docs/workflows/ai-loop/decision-table.md` と再び乖離する。

---

## 適用手順（Human）

```sh
# 1. 上記 diff を .claude/commands/ai-loop-workflow.md:27 の直後に追記
# 2. plugin ミラーへ同期（手編集しない）
sh scripts/sync-plugin-plangate.sh
```

## 検証

```sh
# 1. 両ファイルに但し書きが入ったこと（期待: 2）
grep -lc 'bin/plangate` のサブコマンドではない' \
  .claude/commands/ai-loop-workflow.md \
  plugin/plangate/commands/ai-loop-workflow.md | wc -l

# 2. 同期が冪等であること（期待: exit 0 / no changes）
sh scripts/sync-plugin-plangate.sh --dry-run

# 3. #982 AC-2（6 箇所が同一の入口を指す）の機械照合
git grep -n 'ai-loop run TASK-XXXX\|run TASK-XXXX' -- \
  .agents/skills/ai-loop-cycle .claude/skills/ai-loop-cycle \
  docs/workflows/ai-loop .claude/commands plugin/plangate
#    期待: 全ヒットが「/ai-loop-workflow の引数仕様」かつ
#          「bin/plangate のサブコマンドではない」を伴う
```

---

## 責務

| 操作 | 担当 | 根拠 |
|---|---|---|
| patch の設計・検証手順の提示 | **AI-owned** | 本文書 |
| `.claude/commands/*.md` への適用 | **Human-owned** | HO 9 カテゴリ（`.claude/rules/responsibility-classes.md`） |
| 適用後の `sync-plugin-plangate.sh` 実行 | AI-owned（適用後） | 生成物同期 |

## #982 AC-2 に対する現在地

| 箇所 | 状態 |
|---|---|
| `.agents/skills/ai-loop-cycle/SKILL.md:88` | ✅ 是正済み（本 PR） |
| `.claude/skills/ai-loop-cycle/SKILL.md:70` | ✅ 是正済み（本 PR） |
| `docs/workflows/ai-loop/execution-runbook.md:134` | ✅ 是正済み（本 PR） |
| `docs/workflows/ai-loop/loopspec.md:31` | ✅ 是正済み（本 PR） |
| **`.claude/commands/ai-loop-workflow.md:21`** | ⏳ **本 patch・Human 適用待ち** |
| **`plugin/plangate/commands/ai-loop-workflow.md:21`** | ⏳ **上記適用後に sync で追従** |

**4/6 是正・残 2 は HO のため Human 適用待ち。** 残 2 は `正式入口` の語を保持したまま
但し書きを追記するだけなので、**適用前の現状でも 6 箇所は同一の入口（`/ai-loop-workflow`
の `run TASK-XXXX`）を指しており、指す先の乖離は無い**。不足は CLI 誤読を防ぐ但し書きのみ。
