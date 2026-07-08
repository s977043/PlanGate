# ai-loop-workflow ドキュメントの入口

> Run-001 の HUMAN_ESCALATED に対する人間判断 (a) を受けて新設。
> 本ファイルは薄い入口であり、資産の再列挙・taxonomy 表の複製は行わない。

## living な文書地図はどこにあるか

各ドキュメントの役割・語彙・第一原理の正本は
[`design-philosophy.md`](./design-philosophy.md) である。特に **§7 文書地図**が
「誰が何に答えるか」の一意なタクソノミであり、新規資産の追加・改廃は同節を
更新することで反映する。個別の機構・手順を探す場合は、まず同節から辿ること。

## 時点固定のスナップショットについて（改変しない）

[`asset-inventory.md`](./asset-inventory.md) / [`related-specs.md`](./related-specs.md) /
[`ho-paths.md`](./ho-paths.md) の Phase 0 記述、および
[`phase3-impact-report.md`](./phase3-impact-report.md) は**時点固定の監査証跡**であり、
最新化のために書き換えない。最新の役割定義は常に `design-philosophy.md` §7 を参照する。

## 実行系正本

ワークフロー手順（flow-detect / decision-table / execution-runbook 等）の正本は
[`docs/workflows/ai-loop/`](../../workflows/ai-loop/) 配下（`00_concept.md` ほか）に
ある。詳細は `design-philosophy.md` §7 を参照。
