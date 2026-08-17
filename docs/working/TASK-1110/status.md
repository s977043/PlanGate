# 作業ステータス — TASK-1110 (#1110)

## 全体構成

| PR | ブランチ | 状態 |
|----|---------|------|
| （未作成） | `fix/1110-eh13-redirect-correlation`（base = `origin/main` = `7d91f7b`） | push 済 / C-4 待ち |

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|------|---------|------|
| 2026-08-18 | A: PBI INPUT | `pbi-input.md` 作成（オーガナイザー実測の 5 ケースを取り込み） |
| 2026-08-18 | B: Plan/ToDo/TestCases | `plan.md` / `todo.md` / `test-cases.md` 生成 |
| 2026-08-18 | C-1: セルフレビュー | 17 項目 + 追加 4 観点 → **PASS**（WARN 3） |
| 2026-08-18 | C-2: 外部AIレビュー | 未実施（本 run はワーカー委託範囲外） |
| 2026-08-18 | C-3: 人間レビュー | **未実施（Human 待ち）**。`c3.json` は発行していない |
| 2026-08-18 | D: exec（TDD） | RED（3 FAIL）→ 実装 → GREEN（0 failed）→ 変異 2 種 kill |

## モード判定結果

`high-risk`（`lite_eligible=false`）。根拠は `plan.md` の Mode判定節。
`scripts/check-approval-token-write.sh` は Hardening Override 9 カテゴリの
**文言上は非該当**（HO は `scripts/hooks/*.sh`）だが、承認境界そのものを強制する
hook 実体であり、mode-classification の「自動推定の安全側」に従って引き上げた。

## 変更ファイル一覧

| ファイル | 内容 |
|----------|------|
| `scripts/check-approval-token-write.sh` | `_redirect_writes_token()` 新設 / redirect レーンの相関判定化 / BLOCK メッセージに `redirect_target=` |
| `tests/extras/ta-25-approval-token-guard.sh` | `T1110-TC-01〜05` + fixtures 追加、変異 `T1110-TC-06/07` 追加、既存 2 TC の期待値反転 |
| `docs/working/TASK-1110/**` | Plan Package + evidence |

## 計画からの変更点

- **既存 TC の期待値反転が 1 件 → 2 件になった**。plan 時点では `T1045-TC-19` のみを
  想定していたが、実装後に `T1023-TC-09`（`cat TOKEN && echo hi > /tmp/other.txt`）も
  FAIL した。これは「相関解析しない仕様」を明示的に固定していた TC であり、
  #1110 の是正対象クラスそのものだったため、理由をコメントに残して反転した。
  TC の ID ラベルは `T1045-TC-16` のラベル存在チェックのため維持している。
- 語の終端文字集合に `#` を追加した（`echo x >   # <TOKEN>` のように先が
  コメントで欠落するケースを「空 = 判定不能 = block」に倒すため）。

## V 系ステップ進捗

| ステップ | 状態 |
|---------|------|
| L-0 リンター | `sh -n` 通過。markdownlint は未実行（CI に委譲） |
| V-1 受け入れ検査 | test-cases 全件を TA-25 で自動突合 → 0 failed |
| V-2 コード最適化 | 未実施（high-risk では本来必要。オーガナイザー判断待ち） |
| V-3 外部レビュー | 未実施（オーガナイザー / C-4 レビューで実施予定） |
| V-4 リリース前 | 対象外（critical ではない） |

## 残タスク

- [ ] **H-01** C-3 人間レビュー（`c3.json` は AI が発行しない）
- [ ] PR 作成（オーガナイザー判断）
- [ ] **H-02** C-4 レビュー / merge（Human-owned）
- [ ] BLOCKED: フルスイート `tests/run-tests.sh` の実行
  - `blocker`: ta-61 が入れ子で full-suite を再実行する構造のため、並走ワーカーが
    互いに完走できない（実害 2 回）
  - `owner`: オーガナイザー
  - `unblock_condition`: 全ワーカー完了後に 1 本だけ実行する

## 検証コマンド

```sh
sh -n scripts/check-approval-token-write.sh
sh tests/extras/ta-25-approval-token-guard.sh    # exit 0 / 77 passed, 0 failed
```

## 参照ファイル

- `docs/working/TASK-1110/{pbi-input,plan,todo,test-cases,review-self}.md`
- `docs/working/TASK-1110/evidence/README.md`（A〜E の修正前後対比・変異 kill 実証）
