# Approval Token Guard — 運用ガイド（TASK-0123）

承認トークン系ファイルへの AI 直接書き込みを防ぐ二重ガード機構の運用手順。

## 概要

TASK-0123 で導入された2つの防御層:

1. **EH-13 token-guard** (`scripts/check-approval-token-write.sh`): AI が承認ファイルに直接 Write/Edit/Bash するのを block するプリフックス（採番は TASK-1023 G-6 裁定で **EH-13**。stderr プレフィックスは `[EH-13 token-guard] BLOCK:`）
2. **HMAC 署名検証** (EH-3 拡張): `maintenance.json` が人間によって正規に発行されたことを HMAC-SHA256 署名で検証

## PLANGATE_MAINTENANCE_KEY の設定

### ローカル環境

```sh
# 新規鍵を生成
export PLANGATE_MAINTENANCE_KEY=$(openssl rand -hex 32)

# シェルプロファイルに永続化（例: ~/.zshrc）
echo 'export PLANGATE_MAINTENANCE_KEY="<your-key>"' >> ~/.zshrc
```

### CI 環境（GitHub Actions）

GitHub リポジトリの Settings > Secrets and variables > Actions に `PLANGATE_MAINTENANCE_KEY_CI` を登録する。

## 正規 maintenance start の使い方

### 手順

1. ターミナル（インタラクティブ TTY）で実行する（AI セッションからは不可）

```sh
bin/plangate maintenance start --reason "hook 整備" [--paths "scripts/hooks/foo.sh"] [--minutes 30]
```

2. 4層防御を通過後、`docs/working/_maintenance/maintenance.json` が生成される
3. `PLANGATE_MAINTENANCE_KEY` が設定されている場合、自動的に HMAC 署名が付与される

### 生成される maintenance.json の例

```json
{
  "scope": "in-session edit",
  "until": 1748000000,
  "granted_at": 1747998200,
  "reason": "hook 整備",
  "approved_by": "your-username",
  "one_shot": true,
  "hmac_signature": "abc123def..."
}
```

## 署名の仕組み

- **署名対象**: `hmac_signature` フィールドを除いた JSON を `sort_keys=True` でシリアライズした正規形式文字列
- **アルゴリズム**: HMAC-SHA256
- **鍵**: `PLANGATE_MAINTENANCE_KEY` 環境変数
- **fail-closed 原則**: 鍵が設定されており署名が存在するが不一致の場合 → block。鍵が設定されており署名がない場合 → 通過（後方互換）。

## hook wiring（Human 操作必須）

`.claude/settings.json` に以下を追加（AI は settings.json を自己改変できないため Human が手動適用）:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/check-approval-token-write.sh"
          }
        ]
      }
    ]
  }
}
```

> **パスは `${CLAUDE_PROJECT_DIR}` 付きで書くこと**（相対パスにしない）。hook は
> harness の cwd で起動されるため、`sh scripts/...` と書くと cwd 次第で
> **ロードされず無言で無効化される**。実際に効いている配線の正本は
> [`.claude/settings.example.json`](../../.claude/settings.example.json)（EH-13 の 2 エントリ）。

## ガード本体の配置（単一ソース）

EH-13 guard の**正本は `scripts/check-approval-token-write.sh` の 1 本のみ**。
`scripts/hooks/` 配下にコピーを置かない。settings は上記のとおり
`${CLAUDE_PROJECT_DIR}/scripts/` 直下を直接参照する。

理由:

- `scripts/hooks/` は tracked のため、そこへコピーすると**同一内容の tracked ファイルが
  2 つ並び、両者の drift を検出する CI も存在しない**（#956 の commit 済み drift と同一構造）。
- 上流の修正（例: [#1045](https://github.com/s977043/plangate/issues/1045) / PR #1069 の
  読み取り誤 block 解消）が、コピー側には伝播しない。
- 同方式の先例: [`scripts/apply-eh-git-destructive-guard.sh`](../../scripts/apply-eh-git-destructive-guard.sh)
  （EH-12 の hook 本体をコピーせず `scripts/` ルートを settings から直接参照する）。

### この方針の代償: Codex / Cursor ブリッジからは到達できない

Codex / Cursor のブリッジは **`scripts/hooks/` 配下しか起動できない**:

- [`.codex/hooks/eh-bridge.sh`](../../.codex/hooks/eh-bridge.sh): `HOOK_SCRIPT="$REPO_ROOT/scripts/hooks/$HOOK_NAME"`
- [`scripts/hooks/cursor-adapter.sh`](../../scripts/hooks/cursor-adapter.sh): 同上

したがって「`scripts/hooks/` 配下にコピーを置かない」という本方針は、
**EH-13 を Codex / Cursor パリティから恒久的に締め出す**ことを意味する。

現時点で実害はない（`.codex/hooks.json` が wire するのは 5 本で EH-13 を含まず、
`cursor-adapter.sh` は hook 不在時に `deny` で fail-closed する）。

**Codex / Cursor で EH-13 を配線したくなった場合は、`scripts/hooks/` へ複製を置くのではなく、
ブリッジ側にルート直下（`scripts/`）のパスを許可する変更を行う**こと。複製で解決すると
本節冒頭の drift 問題がそのまま戻る。本 doc は方針の明記までで、ブリッジの実装変更は
別途 issue を立てて扱う（本 PBI の範囲外）。

### 適用済み環境向け移行手順（#1071）

[`scripts/apply-task-0123-patches.sh`](../../scripts/apply-task-0123-patches.sh) は
以前、EH-13 guard を `scripts/hooks/check-approval-token-write.sh` へ `cp` し、
**既存時はスキップして更新しなかった**。#1071 でこの `cp` は廃止したが、
**過去にこのスクリプトを適用した環境には複製が残っている**。

#### 1. 複製の有無を確認する（何も変更しない読み取り操作）

```sh
ls -l scripts/hooks/check-approval-token-write.sh 2>/dev/null \
  && echo "DUPLICATE PRESENT" || echo "no duplicate (nothing to do)"
```

`no duplicate` なら以降の手順は不要。

#### 2. 複製がどこからも参照されていないことを確認する

確認対象は **repo ローカルの settings だけではない**。Claude Code / Codex / Cursor が
実際に読み込む配線先を全部見る:

```sh
grep -rn "hooks/check-approval-token-write" \
  .claude/settings.json .claude/settings.local.json .claude/settings.example.json \
  .codex/hooks.json .cursor/hooks.json \
  plugin/plangate/hooks/hooks.json \
  "$HOME/.claude/settings.json" 2>/dev/null
```

| 追加した対象 | なぜ必要か |
|------------|-----------|
| **ユーザーレベル `~/.claude/settings.json`** | repo 外だが Claude Code が実際に読む配線先。repo ローカルだけ見て「参照ゼロ」と判定すると、ここに残った参照を見落とす |
| **plugin 配布の `hooks/hooks.json`** | plugin は `hooks/hooks.json` 経由でしか hook を起動できない（[`docs/working/_reports/1144-plugin-packaging-patch.md`](../working/_reports/1144-plugin-packaging-patch.md) §1）。未作成なら空振りする |

**出力が空であること**が削除の前提。**列挙が不完全なら、この前提判定も不完全**である
（上の一覧以外の配線先を持つ環境では、その分も自分で足すこと）。1 件でも出た場合は、
まずその参照を `${CLAUDE_PROJECT_DIR}/scripts/check-approval-token-write.sh`
（`scripts/` 直下）へ張り替える。
`.claude/settings*.json` および `~/.claude/settings.json` は Hardening Override 対象
（および AI の self-mod ガード対象）のため、**張り替えは Human が実施する**
（AI は patch 提示まで）。

#### 3. 複製を削除する（👤 Human が実施）

> **`scripts/hooks/*.sh` は Hardening Override 対象**（正本:
> [`scripts/hooks/check-plan-hash.sh`](../../scripts/hooks/check-plan-hash.sh) の
> `_override=0` 直後の `case` ブロック内 `scripts/hooks/*.sh) _override=1`）。
> **作成・変更だけでなく削除も Human が実施する。AI は本手順の提示までで、
> 自分では実行しない**（step 2 の張り替えと同じ強さの制約）。
>
> 特に EH-3 の PreToolUse は `Edit|Write` にのみ配線されており **Bash 経路は素通りする**
> （#1104）。下の `rm` / `git rm` を AI が Bash で走らせても**物理的には止まらない**ため、
> ここは規範層で担保するしかない。

```sh
rm scripts/hooks/check-approval-token-write.sh
```

複製は tracked ファイルとして commit されている場合があるため、その環境では
`git rm scripts/hooks/check-approval-token-write.sh` を使い、削除を commit に含める。

#### 4. 正本が生きていることを確認する

```sh
ls -l scripts/check-approval-token-write.sh          # 存在すること
sh -n scripts/check-approval-token-write.sh          # syntax OK
sh tests/extras/ta-25-approval-token-guard.sh        # EH-13 の TC が全 PASS
```

### 削除しなかった場合に何が起きるか

複製を残したままにすると、次の状態が続く:

| 事象 | 影響 |
|------|------|
| 複製が settings から**参照されていない**場合 | 実行時の挙動は正本のみで決まるため**機能上の実害はない**。ただし tracked な死んだコピーが残り、次に読んだ人が「どちらが正本か」を誤り、正本でない側を修正する事故（#956 と同型）の温床になる |
| 複製が settings から**参照されている**場合 | **#1045 の読み取り誤 block が解消されない**。`cat` / `grep` などの読み取り専用コマンドが承認トークンパスに触れただけで `exit 2` で block され、以後の上流修正も一切伝播しない |
| どちらの場合も | 複製は本スクリプトの旧 `cp` で作られたスナップショットであり、**以後自動更新されない**。`scripts/` 直下の正本と無言で乖離し続ける |

`bin/plangate doctor` / CI に複製の存在検出は**追加していない**（#1071 で案 (c) は
不採用）。導線（`cp`）を断って**新たな複製が生まれない**ようにしたうえで、既存の複製は
本節の移行手順で 1 度だけ解消する方針を採る。

### 残存脅威モデル（この節が守らないもの）

**残存複製は、本節の手順を実行した環境でのみ解消される（機械保証は無い）。**
導線（`cp`）を断ったことで**新たな複製は生まれない**が、**既に存在する複製の除去は
各環境の運用者の手順実行に依存する**。

#### 誰が被害者になりうるか（実測に基づく母集団）

複製を持ちうるのは「**この repo の checkout で
[`scripts/apply-task-0123-patches.sh`](../../scripts/apply-task-0123-patches.sh) を
自分で走らせた人**」に限られる。根拠（いずれも実測）:

| 実測 | 確認コマンド | 結果 |
|------|------------|------|
| 複製 `scripts/hooks/check-approval-token-write.sh` は**一度も tracked になっていない** | `git log --all -- scripts/hooks/check-approval-token-write.sh` | 出力ゼロ（履歴なし） |
| apply スクリプトも guard 本体も **plugin 配布物に含まれない** | `find plugin -name '*check-approval-token-write*' -o -name 'apply-task-0123*'` | 出力ゼロ |

したがって複製は **clone + 手動 apply の産物**としてのみ生まれる。この母集団は
`tests/` を必ず持つため、**T1071-TC-03（複製不在の固定）は被害者の大半をカバーする**。

**「plugin 導入先環境が被害者」という記述は過大**である（plugin には該当ファイルが
1 つも入らないため、そもそも複製が生まれない）。逆にそう書くと TC-03 のカバレッジを
過小に見せる。

#### それでも守れないもの

- **過去に apply を走らせた checkout のうち、`ta-25` を回さない環境** — 複製の存在は
  誰にも通知されない。
- **回しても本節 #2 / #3 を実施しない環境** — TC-03 が FAIL を出すだけで、削除は
  Human 操作（`scripts/hooks/*.sh` は Hardening Override 対象）に依存する。
- **repo 外の配線先（`~/.claude/settings.json` 等）に残った複製参照** — `ta-25` の
  T1071-TC-04 は**これを FAIL にしない**（repo の CI 判定と環境の運用指摘を混ぜないため）。
  検出したときは **WARN + 該当パス表示**で本節 #2 / #3 へ誘導するのみで、
  実施は運用者に依存する。
- **`scripts/check-settings-wiring.sh` の `checks` に EH-13 は未登録**（実測: EH-1 / EH-2 / EH-3 / EH-3 引数 / EH-6 / EH-9 の 6 件のみ）。契約ドリフト検知は EH-13 をまだ見ていないため、`ta-25` の `T1071-TC-04a` が tracked 配線に対する事実上唯一の機械ゲートである。

#### T1071-TC-04 の検査モデル: tracked / untracked / loaded

`ta-25` の T1071-TC-04 は走査母集団を **ファイルの位置ではなく git の追跡状態**で
切る（#1252 R3）。パスが repo 内にあることと、その配線が repo の資産であることは
別物である。

| 概念 | 定義 | レーン | 根拠 |
|------|------|--------|------|
| **tracked** | `git ls-files --error-unmatch` が通る = CI と他人の checkout に必ず存在する | **FAIL** | repo が壊れているなら repo の責任 |
| **untracked / 環境依存** | `.gitignore` 済み（`.claude/settings.json` / `.claude/settings.local.json`）・repo 外（`~/.claude/settings.json`） | **WARN** | 環境都合の FAIL が repo を名指しすると誤誘導になる。しかも `.claude/settings*.json` は Hardening Override 対象で AI には直せない |
| **loaded** | harness が実際にロード・発火させた配線 | **検証対象外** | 設定ファイルに書いてあることは「効いている」証拠ではない |

この軸に張り替える前は、**tracked 配線（`.claude/settings.example.json` の 2 エントリ）を
全削除しても、手元の untracked な `.claude/settings.json` に同じ参照が 1 件あれば
PASS**していた（実測）。repo の EH-13 配線が丸ごと消えても、どの機械ゲートも赤く
ならない状態だった。逆に環境側にファイルがあるだけで、repo が完全に正しくても
FAIL が repo を名指しした。

検出力は同じテスト内の陽性コントロールで実測している（`T1071-TC-04b` 〜 `04e`）:
tracked 配線の全削除は必ず FAIL、untracked な環境ファイルは tracked の欠落を
**救済しない**、repo が正しければ環境側の複製参照だけでは **FAIL しない**（WARN には
載る）、tracked 側の複製参照は引き続き FAIL。

**`loaded` は本 TC の射程外**。実ロード結果（hook が実際に登録され発火したか）は
設定ファイルの静的検査では分からない。本 TC は多層防御の 1 層でしかなく、
実発火の保証は C-4 Human レビューと実環境での観測に依存する。

## トラブルシューティング

### `[EH-13 token-guard] BLOCK: 承認トークン系ファイルへの AI 直接書き込みは禁止されています。`

AI が承認ファイルを直接書き込もうとしています。人間が `bin/plangate maintenance start` を実行してください。

### `[EH-3] maintenance.json: PLANGATE_MAINTENANCE_KEY 未設定。署名検証不可 → fail-closed`

`maintenance.json` に `hmac_signature` フィールドがありますが、`PLANGATE_MAINTENANCE_KEY` が環境に設定されていません。鍵を設定して再発行してください。

### `[EH-3] maintenance.json: HMAC署名不一致（AI自作または改ざんの可能性）`

`maintenance.json` の署名が現在の `PLANGATE_MAINTENANCE_KEY` と一致しません。`maintenance.json` を削除して `bin/plangate maintenance start` で再発行してください。
