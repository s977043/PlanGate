# STATUS — TASK-1115 (#1115)

## 全体構成

| PR / ブランチ | 状態 |
|---------------|------|
| `fix/1115-eh13-glob-bypass`（base: `origin/main` = `17cd044`） | push 済 / PR 未作成（C-3 前） |

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|------|---------|------|
| 2026-08-18 12:10 | A/B | `pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md` 生成 |
| 2026-08-18 12:25 | C-1 | `review-self.md` = **PASS**（FAIL 0 / WARN 0、minor 2 件） |
| 2026-08-18 12:30 | D (exec) | `_may_expand_to_token_path` / `_cmd_may_target_token` 実装、`ta-25` に T1115-TC-01〜07 + 変異 M-7〜M-11 |
| 2026-08-18 12:45 | V-1 | `ta-25` 単体実行 rc=0、before/after 実測表・全レーン走査を evidence へ |

## モード判定結果

`high-risk`（承認境界のガード本体 / block を広げる変更）。
`lite_eligible=false`・**C-3 は人間必須**（autonomous APPROVE 不可）。

## C-3 Gate

**未実施**。本ワーカーは `approvals/c3.json` を**発行しない**（Human-owned）。

## 変更ファイル

| ファイル | 変更 |
|----------|------|
| `scripts/check-approval-token-write.sh` | 関数 2 個追加（`_may_expand_to_token_path` / `_cmd_may_target_token`）+ 外側ゲート call site 差し替え + block 詳細に `glob_candidate=` |
| `tests/extras/ta-25-approval-token-guard.sh` | fixture 21 件 + T1115-TC-01〜07 + 変異 M-7〜M-11 |
| `docs/working/TASK-1115/**` | Plan Package + evidence |

## 計画からの変更点

なし（plan の判定設計どおり）。既存 TC の期待値反転は **0 件**（plan の想定どおり）。

## 残タスク

- [ ] **H-01 C-3 ゲート**（Human-owned / `high-risk`）
- [ ] PR 作成 → **H-02 C-4 / merge**（Human-owned）
- [ ] （follow-up 候補）`rm` を `_has_write_intent` に含めるか — 本 PBI の既存ギャップ
- [ ] （follow-up 候補）#1101 の HO 側正規化（同クラス・別実装）

## evidence

| ファイル | 内容 |
|----------|------|
| `evidence/before.txt` | 是正前 rc 実測（`origin/main` の guard を直接起動） |
| `evidence/after.txt` | 是正後 rc 実測 |
| `evidence/lane-scan.txt` | `_has_write_intent` 全ルール（21 コマンド）の before/after |
| `evidence/shell-expansion.txt` | bash / zsh / sh / dash での実展開（中立名 `tok/x9.json`） |
| `evidence/ta-25.log` | `ta-25` 単体実行ログ |

## 参照

- issue #1115 / 同クラス: #1101 / 前段: #1110（誤検出解消）・#1045・#1023
- `scripts/check-approval-token-write.sh`（EH-13 / **HO 外**）
