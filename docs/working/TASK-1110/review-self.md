# C-1 セルフレビュー — TASK-1110 (#1110)

Mode = `high-risk` のため **17 項目フル**で実施。

## Plan チェック（7 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準の網羅性 | **PASS** | AC-1〜6 が plan の S-1〜S-6 と test-cases の T1110-TC-01〜07 に 1 対 1 で写像。AC→TC マッピング表を test-cases に明記 |
| C1-PLAN-02 | Unknowns の処理 | **PASS** | Q1（`&>` / `>&` の相関化）→ Out of scope（TASK-1045 U-2 維持）、Q2（擬似デバイス）→ fail-closed 維持、と plan で決着済み。未決の Unknown を残していない |
| C1-PLAN-03 | スコープ制御 | **PASS** | In/Out scope を pbi-input に明記。触るのは guard 本体 + TA-25 + Plan Package の 3 系統のみ。HO 対象（`scripts/hooks/*.sh` 等）と settings は非対象と明示 |
| C1-PLAN-04 | テスト戦略 | **PASS** | Unit/Integration = TA-25 個別実行、Verification Automation = 18 ケース probe、Mutation = call site 変異 2 種。フルスイート非実行の理由（ta-61 入れ子・並走妨害）も記載 |
| C1-PLAN-05 | Work Breakdown の Output | **PASS** | S-1〜S-6 すべてに Output / Owner / Risk / 🚩 を記載 |
| C1-PLAN-06 | 依存関係 | **PASS** | todo に depends_on を記載。RED（T-03）→ GREEN（T-04）の順序、変異は GREEN 後という前後関係を明示 |
| C1-PLAN-07 | 動作検証の自動化 | **PASS** | probe.sh + gen_cases.py を evidence に同梱し再実行可能。TA-25 へ TC・変異とも常設化したので次回以降 CI/手動どちらでも回る |

## ToDo チェック（5 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-TODO-01 | タスク粒度 | **PASS** | T-01〜T-10。1 タスク = 1 成果物で、いずれも単独で検証可能 |
| C1-TODO-02 | depends_on 設定 | **PASS** | 全タスクに記載。H-01（人間 C-3）との依存も明示 |
| C1-TODO-03 | チェックポイント | **PASS** | RED の確認 / `sh -n` / 既存 TC 期待値不変 / 空振り時の正直な記録、を 🚩 に明記 |
| C1-TODO-04 | Iron Law 遵守 | **PASS** | `c3.json` を発行しない。merge しない。HO 対象ファイル・settings を触らない。main へ直接 commit しない（`fix/1110-...` ブランチを `origin/main` = `7d91f7b` から作成） |
| C1-TODO-05 | 完了条件 | **PASS** | 「TA-25 個別実行 rc=0」「A〜E 実測」「変異 kill 実証」「push」を完了条件として列挙 |

## TestCases チェック（3 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-TC-01 | 受入基準との紐付き | **PASS** | AC→TC マッピング表あり。AC-5（既存 TA-25 の PASS）は期待値を変更する既存 TC を列挙して逃げ道を塞いでいる |
| C1-TC-02 | Edge case 網羅 | **PASS** | 引用 / `./` / `..` / 多重空白 / 複文 / heredoc（複数行）/ 変数・コマンド置換 / glob / 空の先 / 擬似デバイス / `&>` / `>&` / sed 失敗 を網羅。#1101 で問題になったパス正規化と同型の穴（`./` `..`）を明示的に TC 化 |
| C1-TC-03 | 自動化可否 | **PASS** | 全 TC が TA-25 内で自動実行。人手確認に依存する TC はない |

## 追加観点（承認境界の変更であるため）

| 観点 | 判定 | 根拠 |
|------|------|------|
| fail-closed の維持 | **PASS** | 判定不能（抽出失敗 / 展開 / glob / 空 / 擬似デバイス / `&>`）はすべて block 側。T1110-TC-04 が機械担保。M-2 変異で「緩めたら既存 TC が落ちる」ことを実証 |
| 真の陽性の非後退 | **PASS** | 18 ケース実測で rc が変わったのは誤検出 2 件のみ。トークンパス宛の書き込みは 1 件も通っていない |
| 既存検出力の非後退 | **PASS** | 既存変異（T1023 7 種 / T1045 2 種）がすべて killed のまま。相関判定を正規化**後**の文字列に適用することで `_strip_nonwrite_redirects` を load-bearing に保った |
| 移植性 | **PASS** | POSIX BRE のみ・sed RHS の `\n` 不使用（分割は `tr`）・`LC_ALL=C` 固定。BSD sed / GNU sed 両方で TA-25 = 0 failed を実測 |

## 指摘事項 / 残リスク（WARN）

- **W-1（minor）**: 引用で囲まれ**かつ空白を含む**リダイレクト先（`> 'a b.json'`）は
  語抽出が空白で切れるため先頭断片で判定する。現行の `_is_token_path` パターンに
  該当する実トークンパスは空白を含まないため実害はないが、将来パターンを
  拡張する場合は要再検討（handoff の V2 候補）。
- **W-2（minor）**: `&>` / `&>>` / `>& <file>` は TASK-1045 U-2 の決定を尊重して
  block 維持（相関化しない）。よって `cmd &> /tmp/log.txt` にトークン名が同居すると
  依然として誤 block される。#1110 の主症状（`>`）は解消済み。既知の残存として記録。
- **W-3（info）**: 既存 TC の期待値を 2 件反転した（T1023-TC-09 / T1045-TC-19）。
  いずれも「相関解析しない」という**修正対象の仕様そのもの**を固定していた
  TC であり、反転理由をテスト本文のコメントに残した。C-3 での確認事項。

## 判定

**PASS**（WARN 3 件。いずれも block を緩める方向の穴ではない）

C-3 は **人間必須**（mode=high-risk / セキュリティ・承認境界関連）。
本 run では `approvals/` 配下のトークンを**発行していない**。
