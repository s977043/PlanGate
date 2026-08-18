# 簡易 C-1 再セルフレビュー — TASK-1110 (#1110)

> V-3（`review-external.md` / **REJECT**: critical 1 / major 2）の指摘を
> 1 回確定反映した後の簡易 C-1。初版は [`review-self.md`](./review-self.md)。
> 対象は **反映で変わった箇所**に絞る（working-context §C-3 CONDITIONAL の
> 「(3) 簡易 C-1 再実行」に相当）。

## 反映の要約

| R-NNN | severity | 反映 |
|-------|----------|------|
| R-001 | critical | `_redirect_writes_token()` の fail-closed に **切り詰めクラス**を追加（引用・退避が残る先は解決不能扱い）+ 終端文字クラスから `#` を除去 |
| R-002 | major | evidence の全称主張をスコープ付きへ是正 + **レーン内部の分類を壊す変異 4 種**を追加 |
| R-003 | major | 既存 TC 反転 **2 件**を pbi-input / plan / test-cases へ明示宣言し、TASK-1023 AC-04 上書きを **Human C-3 の判断事項**として起票 |
| R-004 | minor | `T1045-TC-19` コメントに TASK-1045 SC-6 との関係を明記 |
| R-005 | minor | `T1110-TC-09` / `T1110-TC-10` を追加し、V-3 で SURVIVED だった変異 2 種を KILLED 化 |
| R-006 | minor | 簡易 C-1（本ファイル）を実施。**C-3 は人間必須のため未取得**、handoff は C-3 後に発行 |
| R-007〜009 | info | ACK（対応方針を `review-external.md` の監査表に記載） |

## Plan チェック（変化した項目のみ / 7 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準の網羅性 | **PASS** | AC-3 に切り詰めクラスを追記、**AC-3b（レーン間一致）を新設**。AC-6 を「レーン内部の分類を壊す変異を含む」へ強化。AC→TC 表を更新 |
| C1-PLAN-02 | Unknowns の処理 | **PASS** | R-001 の代替案 2 を**実測に基づいて棄却**（レコード全体で引用検査すると `T1110-TC-01` 相当が復活する）。棄却理由を `review-external.md` に記載し、回帰ガード TC を常設化 |
| C1-PLAN-03 | スコープ制御 | **PASS** | 触るファイルは初版から不変（guard 本体 / TA-25 / TASK-1110 docs）。**TASK-1023 の資料は書き換えていない**（C-3 後の follow-up として明示） |
| C1-PLAN-04 | テスト戦略 | **PASS** | 3 版比較（OLD/NEW/FIXED）を機械化（`matrix.py` は不一致 0 のときだけ exit 0）+ レビューア harness を再実行 |
| C1-PLAN-05 | Work Breakdown の Output | **PASS** | S-5 に変異 6 種の内訳（レーン全体 2 / レーン内部 4）を記載 |
| C1-PLAN-06 | 依存関係 | **PASS** | 変更なし。C-3（H-01）が実装より後になっている事実は status に明記済 |
| C1-PLAN-07 | 動作検証の自動化 | **PASS** | 新規 TC はすべて TA-25 に常設。evidence の主張は `matrix.py` 再実行で機械検証可能 |

## ToDo / TestCases チェック（変化した項目のみ）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-TODO-04 | Iron Law 遵守 | **PASS** | `c3.json` 未発行 / merge しない / HO 対象・settings 不触 / 他 PBI の AC を単独書換えしない |
| C1-TC-01 | 受入基準との紐付き | **PASS** | AC-3b を新設し `T1110-TC-08` を紐付け。反転 TC 表を 2 件へ是正 |
| C1-TC-02 | Edge case 網羅 | **PASS** | 終端文字 9 種 × 引用 2 種 + バックスラッシュ退避 + 語中 `#` + 空白入り絶対パス + 括弧ディレクトリ + レーン 4 種 + heredoc 本文 + 診断値持ち越し |
| C1-TC-03 | 自動化可否 | **PASS** | 全 TC が TA-25 内で自動実行（`sh tests/extras/ta-25-approval-token-guard.sh` = exit 0） |

## 追加観点（承認境界）

| 観点 | 判定 | 根拠 |
|------|------|------|
| fail-closed の維持 | **PASS** | 「判定不能」の定義に切り詰めクラスを追加。**block を広げる方向の修正**であり、宣言済み 9 項目は OLD/NEW/FIXED 全て rc=2 で不変 |
| 真の陽性の非後退 | **PASS** | 測定範囲で `want=2` かつ `FIXED=0` の行が **0 件**（"TRUE-POSITIVE LOST" 表記が 0）。レーン非対称（`>` だけ通る）も解消 |
| 誤検出を増やしていないか | **PASS** | ケース A〜E と境界 13 は初版から rc 不変。追加の負の対照（引用が先の後ろに来る形 / heredoc 本文）も rc=0 |
| 検出力（変異） | **PASS** | 変異は全て killed（レーン全体 2 + レーン内部 4 + 既存 9）。**空振り 0 件** |

## 残 WARN

- **W-1（major / Human 判断）**: `T1023-TC-09` の反転 = **TASK-1023 AC-04 の
  redirect レーン限定上書き**。技術的妥当性は V-3 も認めているが、**承認済み AC の
  変更可否は人間の決定事項**。C-3 で明示承認が得られない場合は反転を撤回し、
  redirect レーンでも「トークン読取 + 別ファイル書込」を block する分岐を戻す必要がある
  （その場合ケース A 相当の誤検出が一部復活する点を含めて判断が要る）。
- **W-2（minor）**: 引用・退避された先はすべて block になるため、
  `> "/tmp/log file.txt"` のような**トークンでない引用付き先**も、コマンド内に
  トークン名が同居していれば block される（fail-closed 側の誤検出）。
  V-3 も「誤検知は増えるが真の陽性は落とさない側」として推奨した方向。
- **W-3（minor / 本 PBI 対象外）**: 外側ゲート `_is_token_path "$_cmd"` に
  一致しない形（`c3.jso*` / 大文字 / 末尾が `.json` で終わらない引用形）は
  新旧同値で通過（#1115）。
- **W-4（minor）**: `handoff.md` 未発行（R-006）。C-3 承認 → V-1 完了の順で発行する。

## 判定

**PASS**（WARN 4 件。うち W-1 は Human C-3 の判断事項、W-3 は別 issue、
W-2 / W-4 は fail-closed 側 / プロセス順序）。

**C-3 は人間必須**（mode = high-risk / セキュリティ・承認境界）。
本 run でも `approvals/` 配下のトークンは**発行していない**。
