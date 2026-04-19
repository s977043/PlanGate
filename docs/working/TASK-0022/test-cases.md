# TASK-0022 テストケース定義

> 生成日: 2026-04-20
> PBI: [TASK-0021-A] Workflow 5 phase を定義する（WF-01〜WF-05）

## 受入基準 → テストケース マッピング

| 受入基準 | テストケースID | 種別 |
|---------|--------------|------|
| 5 ファイルが存在する | TC-1 | Unit |
| 各 phase に必須6項目が含まれる | TC-2 | Unit |
| Rule 1 準拠（実装ノウハウなし） | TC-3 | Unit |
| `docs/workflows/README.md` 存在 + 対応表含む | TC-4 | Unit / Integration |
| 実行シーケンスが README に記載 | TC-5 | Unit |
| 既存 PlanGate ドキュメントとの整合 | TC-6 | Integration |
| markdown lint 通過 | TC-7 | CI |

## テストケース一覧

### TC-1: 5 phase ファイルの存在確認

- **前提条件**: `docs/workflows/` ディレクトリが存在
- **入力**:

  ```bash
  ls docs/workflows/01_context_bootstrap.md \
     docs/workflows/02_requirement_expansion.md \
     docs/workflows/03_solution_design.md \
     docs/workflows/04_build_and_refine.md \
     docs/workflows/05_verify_and_handoff.md
  ```

- **期待出力**: 全ファイルが存在（exit code 0）、欠落するとエラー
- **種別**: Unit

### TC-2: 必須6項目の存在確認

- **前提条件**: TC-1 パス
- **入力**: 各 phase ファイルに対して以下の見出しが存在するか検証

  ```bash
  for f in docs/workflows/0*_*.md; do
    for heading in "目的" "入力" "完了条件" "呼び出す Skill" "主担当 Agent" "次 phase への引き継ぎ"; do
      grep -q "## $heading" "$f" || echo "MISSING: $heading in $f"
    done
  done
  ```

- **期待出力**: MISSING の出力なし
- **種別**: Unit

### TC-3: Rule 1 準拠確認（2段階 / EX-02 対応）

- **前提条件**: TC-1 パス
- **Layer 1（機械的 grep）**: 完了条件セクションに「手順」「実施する」「実行する」「How to」「Steps」が含まれないか検証

  ```bash
  for f in docs/workflows/0*_*.md; do
    awk '/^## 完了条件/,/^## [^完]/' "$f" | \
      grep -E "手順|実施する|実行する|How to|Steps" && echo "VIOLATION(L1) in $f"
  done
  ```

- **Layer 2（目視ルーブリック）**: 各完了条件項目を以下のルーブリックで判定:
  - **state（合格）**: 「〜が明文化されている」「〜が決定されている」「〜が一覧化されている」「〜が記録されている」
  - **procedure（不合格）**: 「〜を明文化する」「〜を実施する」「〜を決定する」「〜を洗い出す」「〜する」で終わる命令形
  - **判定記録**: `docs/working/TASK-0022/evidence/rule1-compliance-check.md` に「ファイル / 完了条件項目 / 抽出テキスト / state or procedure」のテーブルで列挙
  - Layer 2 で procedure が 1 件でもあれば VIOLATION
- **期待出力**: Layer 1 / Layer 2 ともに VIOLATION なし、evidence ファイルに全項目のテーブル記録
- **種別**: Unit + Manual Review

### TC-4: README 存在 + 対応表確認

- **前提条件**: `docs/workflows/README.md` が存在
- **入力**: README の内容確認

  ```bash
  test -f docs/workflows/README.md
  grep -q "PlanGate 既存フェーズ" docs/workflows/README.md
  grep -q "WF-01" docs/workflows/README.md && \
  grep -q "WF-02" docs/workflows/README.md && \
  grep -q "WF-03" docs/workflows/README.md && \
  grep -q "WF-04" docs/workflows/README.md && \
  grep -q "WF-05" docs/workflows/README.md
  ```

- **期待出力**: 全ての grep が成功（exit code 0）
- **種別**: Unit / Integration

### TC-5: 実行シーケンスの記載確認

- **前提条件**: TC-4 パス
- **入力**: README に実行シーケンスが含まれるか

  ```bash
  grep -q "orchestrator" docs/workflows/README.md && \
  grep -q "requirements-analyst" docs/workflows/README.md && \
  grep -q "solution-architect" docs/workflows/README.md && \
  grep -q "implementation-agent" docs/workflows/README.md && \
  grep -q "qa-reviewer" docs/workflows/README.md
  ```

- **期待出力**: 全 Agent 名が README に含まれる
- **種別**: Unit

### TC-6: 既存 PlanGate ドキュメントとの整合

- **前提条件**: TC-1〜TC-5 パス
- **入力**: 手動レビュー

  - `docs/plangate.md` のフェーズ定義（A/B/C-1〜D/L-0/V-1〜V-4）が README の対応表と矛盾しないか
  - `docs/plangate-v6-roadmap.md` の記述と矛盾しないか

- **期待出力**: `docs/working/TASK-0022/evidence/consistency-check.md` に「矛盾なし」または矛盾点の記録
- **種別**: Integration（Manual）

### TC-7: markdown lint 通過

- **前提条件**: TC-1 パス
- **入力**: CI と同じ markdown lint 設定で検証

  ```bash
  # .github/workflows/ に定義された markdown lint を再現
  npx markdownlint-cli2 'docs/workflows/**/*.md'
  ```

- **期待出力**: エラーなし（exit code 0）
- **種別**: CI

## エッジケース

### TC-E1: Skill / Agent 名の不一致検出

- **前提条件**: 親 PBI の Skill 10個 / Agent 5体と、本 TASK の phase 定義に書かれた名前の整合
- **入力**: grep で親 PBI と本 TASK の phase 定義を突合
- **期待出力**: 親 PBI に定義されていない Skill / Agent 名は存在しない
- **種別**: Integration

### TC-E2: 完了条件が状態形式か動作形式か（TC-3 Layer 2 に統合済）

TC-3 Layer 2（目視ルーブリック）で判定する。本 E2 は **TC-3 の一部として扱い独立実行しない**（EX-02 対応による統合）。

### TC-E3: PlanGate 既存フェーズ対応表の粒度

- **前提条件**: README の対応表
- **入力**: 対応表に PlanGate のどのフェーズまで含めるか（A/B/C-1/C-2/C-3/D/L-0/V-1/V-2/V-3/V-4 全て? or 主要のみ?）
- **期待出力**: 主要フェーズ（A/B/C-1〜D/L-0/V-1）に絞る or 全フェーズを含める、いずれかの方針が README 冒頭に明記
- **種別**: Manual Review

### TC-E4: 1 phase あたりの行数

- **前提条件**: TC-1 パス
- **入力**: 各 phase ファイルの行数

  ```bash
  wc -l docs/workflows/0*_*.md
  ```

- **期待出力**: 各ファイル 30〜120 行（極端に短い or 長いファイルがないことを確認）
- **種別**: Unit（ガードレール）
