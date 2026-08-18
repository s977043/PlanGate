# PBI INPUT PACKAGE — TASK-1109 (#1109)

## Context / Why

`scripts/check-codex-skill-spec.sh` は「skill の `agents/openai.yaml` が仕様を満たすか」を
検査する検出器だが、**openai.yaml が存在しない skill を violation にせず silently skip**
していた。したがって出力の `Checked N skills` は「N 件検査して問題なし」ではなく
「**openai.yaml がある N 件しか見ていない**」を意味する。

さらに CI (`.github/workflows/sync-plugin-plangate.yml`) は `--warn-only` 付きで呼ぶため、
**既存 violation があっても job は常に緑**だった。

実測（修正前 / head `7d91f7b`）:

| コマンド | 出力 | rc |
|---|---|---|
| `sh scripts/check-codex-skill-spec.sh` | Checked 39 / VIOLATIONS (8) | 1 |
| `sh scripts/check-codex-skill-spec.sh --warn-only` | 同上 | 0 |
| `sh scripts/check-codex-skill-spec.sh --target plugin/plangate/skills` | Checked 35 / VIOLATIONS (1) | 1 |
| `sh scripts/check-codex-skill-spec.sh --warn-only --target /tmp/nonexistent` | `FileNotFoundError` traceback | 1 |

3 行目の `Checked 35` は配布物 `plugin/plangate/skills` に **`agents/openai.yaml` が 4 件
欠落**（`ai-loop-cycle` / `breakdown-gate` / `ref-integrity-scan` /
`subagent-delegation-brief`）していることを検出できていない。
4 行目は冒頭コメントの「`--warn-only` 時は常に 0」という宣言に反する（契約違反）。

## What（Scope）

### In scope

- 欠落 `agents/openai.yaml` を **violation として数える**（silent skip をやめる。
  検査対象外にするものは**件数と理由を必ず出力**する）
- 配布物 `plugin/plangate/skills` を**検査対象に含める**
- `--warn-only` が **target 不在でも rc=0** を返す（契約どおりに直す）
- 検査対象集合を **`SKILL.md` を持つディレクトリとの同値照合**で担保する
  （**絶対件数を契約値にしない**。skill は運用で増える）
- 既存 violation の内訳を洗い出し、解消できるものは解消する
- `--warn-only` を workflow から外す **patch の提示**（適用は Human）

### Out of scope

- `.codex/skills` を untrack するか（**#1086**）
- `commands/*.md` が Skill 登録される問題（**#1081**）
- `--warn-only` を workflow から外す **実適用**（HO / Human-owned）
- `plugin/plangate/skills/*/agents/openai.yaml` の**生成を sync 経路に組み込む**こと
  （構造的な再発防止。本 PBI は「検出」までで、生成は follow-up）

## 受入基準

| AC | 内容 |
|----|------|
| **AC-1** | `SKILL.md` があり `agents/openai.yaml` が無い skill が violation として報告される |
| **AC-2** | `agents/openai.yaml` があり `SKILL.md` が無いディレクトリも violation になる（逆方向の穴） |
| **AC-3** | 既定 target に配布物 `plugin/plangate/skills` を含む |
| **AC-4** | 検査対象から外したエントリは件数と理由が出力される（silent skip ゼロ） |
| **AC-5** | `--warn-only` は violation・target 不在のいずれでも rc=0（traceback を出さない） |
| **AC-6** | `--warn-only` なしの target 不在は rc=1（fail-closed。緑にしない） |
| **AC-7** | 既定 2 root の実リポジトリ実行が rc=0（= `--warn-only` を外せる状態） |
| **AC-8** | 既存呼び出し元（`tests/extras/ta-30-install-skills.sh`）が壊れない |

## Notes from Refinement

- `plugin/plangate/scripts/install-plangate-skills.sh` は `agents` を bundled resource の
  同期対象**外**とし、**target 側で `openai.yaml` を SKILL.md frontmatter から再生成**する。
  よって欠落 4 件は install 経路には影響しない（実測で確認 / plan.md §調査結果 F-3）。
- `sync-plugin-plangate.sh` は `plugin/plangate/skills/*/agents/openai.yaml` を**同期対象に
  していない**。配布物の openai.yaml は現状**手書き資産**であり、drift は構造的に起きる。

## Estimation Evidence

- **Risks**: 検査を強化すると CI が赤で固定される（既存 violation を先に解消しないと
  `--warn-only` を外せない = 適用順序の制約）
- **Unknowns**: `.codex/skills` の去就（#1086）。既定 target から消えても壊れない設計が要る
- **Assumptions**: `.codex/skills` の 8 violations は `install-plangate-skills-to-codex.sh`
  の再生成で解消できる（実測で確認済み）
