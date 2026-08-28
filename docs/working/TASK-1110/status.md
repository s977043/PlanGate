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
| 2026-08-18 | V-3: 外部レビュー | `review-external.md` 取り込み。**REJECT**（critical 1 / major 2 / minor 3 / info 3） |
| 2026-08-18 | V-3 反映（1 回確定） | R-001 是正（切り詰めクラスを fail-closed へ）+ R-002〜R-005 反映。TC 5 本・変異 4 本を追加 |
| 2026-08-18 | 簡易 C-1 再実行 | `review-self-2.md` → **PASS**（WARN 4。うち 1 件は Human C-3 判断事項） |

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
  → **V-3 R-003 で「plan の宣言範囲外」と指摘され、pbi-input / plan / test-cases へ
  明示宣言を追加し、TASK-1023 AC-04 の上書き可否を Human C-3 の判断事項として起票した。**
- 語の終端文字集合について、当初は `#` を**含めていた**（先がコメントで欠落する
  ケースを block へ倒すため）。しかし V-3 R-001 の是正過程で、**`#` は語頭のみ
  コメント開始で語中は通常文字**であり、含めると `dir#1/<TOKEN>` のように
  退避不要で書ける先を取りこぼすと判明したため **終端集合から除外**した。
  「先がコメントで欠落する」ケースは `^#` を空へ落とす規則で引き続き block 側。
- **V-3 R-001 是正**: リダイレクト先の「静的に解決できない」判定に
  **切り詰めクラス**（引用符 / バックスラッシュが残る語）を追加。あわせて
  引用符の剥がし処理を廃止（残っていること自体を解決不能の証拠として使う）。
- **V-3 R-002 / R-005 是正**: 変異を「レーン全体を落とす 2 種」から
  **「レーン全体 2 種 + レーン内部の分類を壊す 4 種」**へ拡張。

## V 系ステップ進捗

| ステップ | 状態 |
|---------|------|
| L-0 リンター | `sh -n` 通過。markdownlint は未実行（CI に委譲） |
| V-1 受け入れ検査 | test-cases 全件を TA-25 で自動突合 → 0 failed |
| V-2 コード最適化 | 未実施（high-risk では本来必要。オーガナイザー判断待ち） |
| V-3 外部レビュー | **実施済（REJECT → 1 回確定反映 → 簡易 C-1 PASS）**。`review-external.md` の監査表に R-001〜009 の disposition |
| V-4 リリース前 | 対象外（critical ではない） |

## 残タスク

- [ ] **H-01** C-3 人間レビュー（`c3.json` は AI が発行しない）
  - **判断事項 1**: `T1023-TC-09` の反転 = TASK-1023 AC-04 を **redirect レーンに限り
    上書き**してよいか（`pbi-input.md` §既存 TC の期待値反転）
  - **判断事項 2**: 承認された場合、TASK-1023 側資料（handoff 等）への追補を
    follow-up として実施してよいか
- [ ] **handoff.md 発行**（V-3 R-006）: C-3 承認 → V-1 完了の順で発行する
  （未承認のまま完了資産を出さないため、現時点では未作成）
- [ ] PR 作成（オーガナイザー判断）
- [ ] **H-02** C-4 レビュー / merge（Human-owned）
- [ ] BLOCKED: フルスイート `tests/run-tests.sh` の実行
  - `blocker`: ta-61 が入れ子で full-suite を再実行する構造のため、並走ワーカーが
    互いに完走できない（実害 2 回）
  - `owner`: オーガナイザー
  - `unblock_condition`: 全ワーカー完了後に 1 本だけ実行する

## 検証コマンド

```sh
sh -n scripts/check-approval-token-write.sh                 # exit 0
sh tests/extras/ta-25-approval-token-guard.sh               # exit 0 / 0 failed
python3 docs/working/TASK-1110/evidence/matrix.py           # exit 0 = OLD/NEW/FIXED 不一致 0
python3 docs/working/TASK-1110/evidence/v3-review/cases_v3b.py  # レビューア harness（before.sh/after.sh を用意して実行）
```

## 参照ファイル

- `docs/working/TASK-1110/{pbi-input,plan,todo,test-cases,review-self,review-self-2,review-external}.md`
- `docs/working/TASK-1110/evidence/README.md`（OLD/NEW/FIXED 3 版対比・変異 kill 実証）
