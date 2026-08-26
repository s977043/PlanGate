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

### CLI 必須 / 不要 の分離（#1144）

**plugin 配布物には CLI（`bin/plangate`）も enforcement 層（`scripts/hooks/`）も
含まれない**（読み物層のみ配布）。本コマンドの手順は削除しないが、導入先での可否は
下表のとおり分かれる。

| 手順 | 種別 | 導入先での扱い |
|------|------|--------------|
| 2. `doctor --json` による不足項目の検知 | **CLI 必須** | 実行不可。下記規則に従い停止 |
| 4. `doctor --json` 再実行による実体検証 | **CLI 必須** | 実行不可。「doctor で検証済み」と記録しない |
| settings タスクロック（`doctor --check-settings`） | **CLI 必須** | 実行不可。PASS 扱いにしない |
| 1. TASK ID 動的解決 | CLI 不要 | cwd / `ls` 判定のみで完結 |
| 3. Human-owned 操作の提示 | CLI 不要 | 提示のみ（元々 AI は実行しない） |
| 5. `status.md` 末尾への完了サマリ追記 | CLI 不要 | ファイル追記のみ |
| 上記「呼び出し表記」「doctor の検査対象」の説明 | CLI 不要 | 前提の説明であって手順ではない |

**CLI 必須の手順に到達したときの規則**: 導入先に CLI は配布されないため、**上流
リポジトリの clone（および PATH 追加）が必要である旨をユーザーに告げて停止する**。
黙ってスキップしない。clone しない選択をした場合は degrade（未検証）として
`status.md` に記録し、Gate は未 PASS のまま保持する。

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
