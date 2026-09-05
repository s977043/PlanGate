# ai-loop-workflow ドキュメントの入口

> **Legacy / Freeze notice (2026-09-05)**: この namespace は既存 ai-loop の PoC / Legacy 正本・監査証跡として保持する。新しい ai-loop V2 の最上位判断基準は [`../ai-loop-v2/north-star.md`](../ai-loop-v2/north-star.md) とし、V2 の新機能・新しい自律モデル・Evolution 機能は原則としてこの Legacy namespace へ追加しない。security fix / critical bug fix / migration support は例外として許可する。詳細は [`../ai-loop-v2/phase0-migration.md`](../ai-loop-v2/phase0-migration.md) を参照する。
>
> Run-001 の HUMAN_ESCALATED に対する人間判断 (a) を受けて新設。
> 本ファイルは薄い入口であり、資産の再列挙・taxonomy 表の複製は行わない。

## living な文書地図はどこにあるか

**Legacy ai-loop 内**の各ドキュメントの役割・語彙・第一原理の正本は
[`design-philosophy.md`](./design-philosophy.md) である。特に **§7 文書地図**が
「誰が何に答えるか」の一意なタクソノミであり、Legacy 資産の個別の機構・手順を探す場合は同節から辿ること。

V2 の Issue / Plan / PR では、この Legacy 正本を暗黙に最上位へ置かず、先に
[`../ai-loop-v2/north-star.md`](../ai-loop-v2/north-star.md) を参照する。

## 時点固定のスナップショットについて（改変しない）

[`asset-inventory.md`](./asset-inventory.md) / [`related-specs.md`](./related-specs.md) /
[`ho-paths.md`](./ho-paths.md) の Phase 0 記述、および
[`phase3-impact-report.md`](./phase3-impact-report.md) は**時点固定の監査証跡**であり、
最新化のために書き換えない。Legacy ai-loop 内の役割定義は `design-philosophy.md` §7 を参照する。

## 実行系正本

Legacy ワークフロー手順（flow-detect / decision-table / execution-runbook 等）の正本は
[`docs/workflows/ai-loop/`](../../workflows/ai-loop/) 配下（`00_concept.md` ほか）に
ある。詳細は `design-philosophy.md` §7 を参照。

これらは V2 の設計入力・fixture・Evidence として再利用できるが、V2 へ自動継承される正本ではない。
