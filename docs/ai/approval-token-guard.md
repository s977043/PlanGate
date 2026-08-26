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
            "command": "sh scripts/check-approval-token-write.sh"
          }
        ]
      }
    ]
  }
}
```

## ガード本体の配置（単一ソース）

EH-13 guard の**正本は `scripts/check-approval-token-write.sh` の 1 本のみ**。
`scripts/hooks/` 配下にコピーを置かない。settings は上記のとおり `scripts/` 直下を
直接参照する。

理由:

- `scripts/hooks/` は tracked のため、そこへコピーすると**同一内容の tracked ファイルが
  2 つ並び、両者の drift を検出する CI も存在しない**（#956 の commit 済み drift と同一構造）。
- 上流の修正（例: [#1045](https://github.com/s977043/plangate/issues/1045) / PR #1069 の
  読み取り誤 block 解消）が、コピー側には伝播しない。
- 同方式の先例: [`scripts/apply-eh-git-destructive-guard.sh`](../../scripts/apply-eh-git-destructive-guard.sh)
  （EH-12 の hook 本体をコピーせず `scripts/` ルートを settings から直接参照する）。

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

```sh
grep -rn "hooks/check-approval-token-write" .claude/settings.json .claude/settings.local.json \
  .claude/settings.example.json .codex/hooks.json .cursor/hooks.json 2>/dev/null
```

**出力が空であること**が削除の前提。1 件でも出た場合は、まずその参照を
`scripts/check-approval-token-write.sh`（`scripts/` 直下）へ張り替える。
`.claude/settings*.json` は Hardening Override 対象のため、**張り替えは Human が実施する**
（AI は patch 提示まで）。

#### 3. 複製を削除する

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

## トラブルシューティング

### `[EH-13 token-guard] BLOCK: 承認トークン系ファイルへの AI 直接書き込みは禁止されています。`

AI が承認ファイルを直接書き込もうとしています。人間が `bin/plangate maintenance start` を実行してください。

### `[EH-3] maintenance.json: PLANGATE_MAINTENANCE_KEY 未設定。署名検証不可 → fail-closed`

`maintenance.json` に `hmac_signature` フィールドがありますが、`PLANGATE_MAINTENANCE_KEY` が環境に設定されていません。鍵を設定して再発行してください。

### `[EH-3] maintenance.json: HMAC署名不一致（AI自作または改ざんの可能性）`

`maintenance.json` の署名が現在の `PLANGATE_MAINTENANCE_KEY` と一致しません。`maintenance.json` を削除して `bin/plangate maintenance start` で再発行してください。
