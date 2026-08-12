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

## トラブルシューティング

### `[EH-13 token-guard] BLOCK: 承認トークン系ファイルへの AI 直接書き込みは禁止されています。`

AI が承認ファイルを直接書き込もうとしています。人間が `bin/plangate maintenance start` を実行してください。

### `[EH-3] maintenance.json: PLANGATE_MAINTENANCE_KEY 未設定。署名検証不可 → fail-closed`

`maintenance.json` に `hmac_signature` フィールドがありますが、`PLANGATE_MAINTENANCE_KEY` が環境に設定されていません。鍵を設定して再発行してください。

### `[EH-3] maintenance.json: HMAC署名不一致（AI自作または改ざんの可能性）`

`maintenance.json` の署名が現在の `PLANGATE_MAINTENANCE_KEY` と一致しません。`maintenance.json` を削除して `bin/plangate maintenance start` で再発行してください。
