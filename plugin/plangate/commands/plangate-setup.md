# /plangate-setup

PlanGate の初期セットアップを対話的に実行する。

## 前提条件

`plangate` CLI が必要。Plugin単体にはCLIが含まれないため、未導入なら PlanGate clone を用意し PATH に追加する。

    git clone https://github.com/s977043/plangate.git ~/plangate
    export PATH="$HOME/plangate/bin:$PATH"

### CLI 未導入時の degrade

CLI が無ければ doctor による機械検証は行わず、plangate-setup Skill の手動チェックへ degrade する。
**未検証を doctor PASS と記録しない**。

> **対象 project root（#962）**: #1497 以降、read-only doctor は
> `--project-root` → `PLANGATE_PROJECT_ROOT` → cwd git root → CLI root fallback の順で対象を決める。
> PATH上の `plangate` を導入先repoの cwd から実行すれば、その導入先を検査する。
> 別repoは `plangate --project-root <dir> doctor ...` で明示する。
> downstream `doctor --fix` は #1144 解決まで **rc=2 / no-write**。

### CLI 必須 / 不要 の分離（#1144）

| 手順 | CLI が利用可能 | CLI が無い |
|------|---------------|-----------|
| 2 / 4. `doctor --json` | selected project root を検査 | 手動突合 |
| settings タスクロック | `doctor --check-settings` で read-only 検査 | PASS 扱いにしない |
| TASK ID 解決 / Human操作提示 / status追記 | CLI 不要 | 同左 |

CLI が利用できても hooks 自体は導入先へ配布されないため、doctor の wiring 検査と enforcement の
実在・発火を混同しない。

## 引数

なし（カレントディレクトリから TASK ID を動的解決する）。

## 起動

[`setup-coordinator`](../agents/setup-coordinator.md) Agent に委譲する。

Agent が以下を順に実行する:

1. TASK ID 動的解決
2. `plangate doctor --json` で不足項目を検知（上流リポジトリの cwd では `bin/plangate doctor --json`）
3. Human-owned 操作の提示（実行はしない）
4. ユーザー報告 → `plangate doctor --json` 再実行で実体検証
5. `status.md` 末尾に完了サマリを追記

詳細仕様: [`docs/working/TASK-0107/contract-notes.md`](../../docs/working/TASK-0107/contract-notes.md)
