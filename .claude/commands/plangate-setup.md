# /plangate-setup

PlanGate の初期セットアップを対話的に実行する。

## 前提条件

`plangate` CLI が必要です。**呼び出し表記は実行環境で変わります**: 上流リポジトリ（`s977043/plangate`）を clone した cwd では `bin/plangate`、PATH を通した導入先では `plangate`（`bin/plangate` ではない）。Plugin 単体導入では CLI が同梱されないため、未導入の場合は先に PlanGate リポジトリを clone して PATH に追加してください:

    git clone https://github.com/s977043/plangate.git ~/plangate
    export PATH="$HOME/plangate/bin:$PATH"

### CLI 未導入時の degrade

CLI を導入しない場合、本コマンドの機械検証（`plangate doctor`）は実行できません。その場合は [`plangate-setup`](../skills/plangate-setup/SKILL.md) Skill のチェックリストを手動で突合し、**「doctor で検証済み」とは記録しない**でください。ゲートの厳密な強制（EH-3 / plan_hash / presence gate）には CLI + hooks の導入が必要です。

> **注意: doctor の検査対象は cwd ではなく CLI 本体の位置で決まる。**
> `doctor --json` は `scripts/doctor_check.py` へ委譲され、同スクリプトは
> `_paths.REPO_ROOT`（= `bin/` の親）を検査対象とする。`doctor` に `--dir` 相当の
> オプションは無いため、PATH 上の `plangate` を導入先で実行しても検査されるのは
> **上流 clone 側**であり、導入先リポジトリではない。導入先の設定を確認する場合は
> `.claude/settings.json` を直接読む。

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
