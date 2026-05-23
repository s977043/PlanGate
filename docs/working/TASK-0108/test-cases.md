# TASK-0108 テストケース定義

> Source: pbi-input.md (AC) / plan.md / Generated: 2026-05-22

## 受入基準 → テストケース マッピング

| AC | TC IDs |
|----|--------|
| AC-1: 公開トップ + README + staged-adoption-guide で 30 分初回体験エントリポイントが 1 本に統一・矛盾なし | TC-01, TC-02 |
| AC-2: README install 直後に doctor --fix 必須度の警告ブロック有・見落とせない強調 | TC-03 |
| AC-3: docs/when-not-to-use.md 存在、Trade-offs / 適用しないべきケース 5 件以上 | TC-04 |
| AC-4: 用語略号 (EH/WF/V/C/L) Glossary を 1 箇所に集約、主要 doc 冒頭からリンク | TC-05, TC-06 |
| AC-5: 呼称統合 — ABCD ↔ WF-XX 対応表 + 表記方針が文書化 | TC-07 |
| AC-6: Codex / Gemini 再委任で「新規ユーザー Yes」評価 (CONDITIONAL → Yes) | TC-08 |
| AC-7: 既存テスト regression なし + markdownlint pass | TC-09, TC-10 |

## テストケース一覧

### Lint / 基本検証

| ID | 前提 | 入力 | 期待出力 | 種別 |
|----|------|------|---------|------|
| TC-09 | 反映後の docs/ 全体 | `markdownlint-cli2 docs/**/*.md README*.md` | exit 0 (全 pass) | lint |
| TC-10 | 反映後 | `sh tests/run-tests.sh` + `sh tests/hooks/run-tests.sh` | 101/0 + 79/0 PASS 維持 | regression |

### 内容検証 (grep)

| ID | 検証内容 | コマンド/方法 | 期待 |
|----|---------|--------------|------|
| TC-01 | README に staged-adoption-guide.md への 「first run の正本リンク」が冒頭で明示 | `grep -n 'staged-adoption-guide\\|first run\\|正本' README.md` | 該当行 1 件以上、冒頭 (L100 以内) |
| TC-02 | staged-adoption-guide.md に「30 分初回体験の正本」明記 + README への参照 | `grep -n '正本\\|README.md.*Quickstart' docs/staged-adoption-guide.md` | 該当 1 件以上 |
| TC-03 | README install 節直後 (L100-L130) に doctor --fix 必須警告 (⚠️ / 注意 / 必須) | `grep -nE 'doctor --fix.*必須\\|⚠️.*doctor' README.md` | 該当 1 件以上、L100-L130 範囲 |
| TC-04 | docs/when-not-to-use.md 実在、トレードオフ 5 件以上記載 | `ls docs/when-not-to-use.md && grep -cE '^- \\|^\\d+\\.' docs/when-not-to-use.md` | 5 行以上の bullet/numbered |
| TC-05 | docs/glossary.md 実在、EH-1〜EH-9 / EHS-1〜3 / WF-01〜05 / V-1〜4 / C-1〜4 / L-0 略号網羅 | `grep -cE '^- \\*\\*EH-[0-9]+\\*\\*\\|^- \\*\\*WF-' docs/glossary.md` | 各カテゴリで該当行あり、計 25 行以上 |
| TC-06 | docs/index.md + plangate.md + philosophy.md 冒頭から glossary.md へのリンク | `grep -n 'glossary.md' docs/index.md docs/plangate.md docs/philosophy.md` | 各ファイル 1 件以上 |
| TC-07 | docs/glossary.md 末尾に ABCD ↔ WF-XX 対応表、docs/ai/project-rules.md に呼称方針 | `grep -nE 'A \\|.*WF-0[1-5]\\|呼称.*WF-XX' docs/glossary.md docs/ai/project-rules.md` | 両方該当 |

### 外部レビュー

| ID | 内容 | 種別 |
|----|------|------|
| TC-08 | Codex + Gemini に再委任、両者から「新規 OSS 利用者が初期導入を Yes と判定可能」評価。前回 CONDITIONAL Yes と比較して major 改善ポイント 0 件 (= 既に修正反映済) | manual (review-external.md に追記) |

### Edge cases

- TC-11: docs/glossary.md の各略号参照 URL が実ファイル/section 到達 (`grep -oE '\\[.*\\]\\(.*md.*\\)' docs/glossary.md` で抽出して `test -f` 検証)
- TC-12: README の "first run" リンクが docs/staged-adoption-guide.md の Phase 0 section に anchor で到達 (Markdown anchor 規約に準拠)
- TC-13: docs/when-not-to-use.md が docs/index.md と docs/philosophy.md の両方からリンクされている (双方向リンクが必須条件として AC ではないが UX 強化)

## 自動化可否

- TC-09/TC-10/TC-01/TC-02/TC-03/TC-04/TC-05/TC-06/TC-07/TC-11/TC-12/TC-13: 全自動化可（grep/find/test -f/markdownlint）
- TC-08: 手動 (外部レビュー、本セッション内で実施)
