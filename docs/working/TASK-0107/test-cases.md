# TASK-0107 TEST CASES

> Source: `pbi-input.md` r1 AC-1〜AC-13 / Mode: **high-risk**
> Generated: 2026-05-22
> Total: 22 test-cases / Codex 助言 + Gemini Mock 3 系統に基づく

---

## 受入基準 → テストケースマッピング

| AC | TC 件数 | 主要 TC ID |
|----|---:|-----------|
| AC-1 起動 | 1 | TC-01 |
| AC-2 doctor --json 抽出 | 2 | TC-02, TC-03 |
| AC-3 Human-owned 提示のみ | 2 | TC-04, TC-05 |
| AC-4 再検証ループ | 2 | TC-06, TC-07 |
| AC-5 完了サマリ | 1 | TC-08 |
| AC-6 Skill 5 要素対応 | 1 | TC-09 |
| AC-7 Rule 1-5 準拠 | 5 | TC-10〜TC-14 |
| AC-8 handoff.md 6 要素 | 1 | TC-15 |
| AC-9 frontmatter 一致 | 1 | TC-16 |
| AC-10 settings.json diff = 0 | 1 | TC-17 |
| AC-11 永続記録 | 2 | TC-18, TC-19 |
| AC-12 doctor --check-settings ゲート | 1 | TC-20 |
| AC-13 解消不能 FAIL 脱出 | 2 | TC-21, TC-22 |

**合計: 22 件**

---

## Mock 系統定義（共通）

- **Mock A: `passed=true`** — 全項目 PASS の `doctor --json` 出力
- **Mock B: `passed=false, checks[]に ok=false`** — 不足項目あり（例: settings wiring 未適用）
- **Mock C: 解消不能 FAIL** — 環境制約等で永続的に FAIL する想定（例: `--check-settings` が wiring 適用後も FAIL）

---

## テストケース詳細

### TC-01 [AC-1] /plangate-setup で Agent が起動する
- **種別**: integration（grep + invocation） + **manual**（実起動確認）
- **前提条件**: `.claude/commands/plangate-setup.md` が存在
- **入力**: `/plangate-setup` 実行（または fixture でのトリガー）
- **期待出力**: setup-coordinator Agent が呼び出される（command 本文に Agent invocation 文字列が存在）
- **検証**: `grep -E 'setup-coordinator|Agent' .claude/commands/plangate-setup.md`

### TC-02 [AC-2] doctor --json 不足項目を抽出してリスト化
- **種別**: unit mock
- **前提条件**: Mock B（不足項目あり）の JSON fixture
- **入力**: Mock B fixture → Agent
- **期待出力**: Agent の出力に不足項目（`checks[].name` で `ok=false`）がリスト化されている
- **検証**: fixture から想定リスト項目を抽出し出力に含まれることを確認

### TC-03 [AC-2] doctor --json passed=true で抽出スキップ
- **種別**: unit mock
- **前提条件**: Mock A（passed=true）
- **期待出力**: 不足項目リストは空、完了サマリへ進む
- **検証**: 出力に「不足なし」または完了サマリパスへの遷移

### TC-04 [AC-3] Agent が apply-claude-settings.sh を呼ばない（grep negative）
- **種別**: static / grep negative
- **入力**: `.claude/agents/setup-coordinator.md`
- **期待出力**: `apply-claude-settings.sh` を Bash で実行するパスが存在しない
- **検証**: `! grep -E "(Bash|run).*apply-claude-settings\.sh" .claude/agents/setup-coordinator.md`

### TC-05 [AC-3] Agent definition に「実行禁止・提示のみ」明文化
- **種別**: static / grep positive
- **入力**: `.claude/agents/setup-coordinator.md`
- **期待出力**: 「実行しない」「提示のみ」「Human-owned」等のキーワードが存在
- **検証**: `grep -E "(実行しない|提示のみ|Human-owned)" .claude/agents/setup-coordinator.md`

### TC-06 [AC-4] FAIL 状態で次 Step に進まない（再検証ループ）
- **種別**: unit mock + **manual**（Agent 対話シミュレーションが必要）
- **前提条件**: Mock B → ユーザー「完了」報告 → doctor 再実行も Mock B
- **期待出力**: Agent は完了扱いせず再提示
- **検証**: 出力に「PASS まで完了しません」相当のループパス記述

### TC-07 [AC-4] FAIL → PASS 遷移で次 Step
- **種別**: unit mock + **manual**（Agent 対話シミュレーションが必要）
- **前提条件**: 1 回目 Mock B → 2 回目 Mock A
- **期待出力**: 2 回目で次 Step に進む
- **検証**: 出力の遷移を確認

### TC-08 [AC-5] 完了サマリ出力
- **種別**: unit mock + **manual**（出力フォーマット人間確認）
- **前提条件**: Mock A
- **期待出力**: 完了項目 / 残項目 / 次のアクション候補（PBI 作成 / `/ai-dev-workflow` 等）の 3 セクションが含まれる
- **検証**: 出力のフォーマット検査

### TC-09 [AC-6] Skill に 5 要素対応表が存在
- **種別**: static / grep positive
- **入力**: `.claude/skills/plangate-setup/SKILL.md`
- **期待出力**: Cowork 5 要素（Context files / Global instructions / Folder instructions / Plugins / Connectors）と PlanGate 対応物の表が存在
- **検証**: `grep -cE "(Context files|Global instructions|Folder instructions|Plugins|Connectors)" .claude/skills/plangate-setup/SKILL.md` >= 5

### TC-10 [AC-7] Rule 1: Workflow 順序のみ
- **種別**: static / grep negative
- **入力**: 該当する Workflow ファイルがあればそれ。本 PBI は Workflow 追加なしのため `docs/workflows/0*.md` への変更が無いこと
- **期待出力**: Workflow への新規追加コミットなし
- **検証**: `git diff --name-only main..HEAD | grep -E "docs/workflows/0[0-9]_.*\.md" | wc -l` == 0

### TC-11 [AC-7] Rule 2: Skill 再利用単位（案件固有なし）
- **種別**: static / grep negative
- **入力**: `.claude/skills/plangate-setup/SKILL.md`
- **期待出力**: 「TASK-0107」「このプロジェクト」「PlanGate 固有」等の案件固有表現を含まない
- **検証**: `! grep -E "TASK-0107|このプロジェクト" .claude/skills/plangate-setup/SKILL.md`
- **Note**: Skill は再利用単位のため案件固有名は CLAUDE.md 補足の対象だが Skill 内に直書きしない

### TC-12 [AC-7] Rule 3: Agent 責務のみ
- **種別**: static / grep
- **入力**: `.claude/agents/setup-coordinator.md`
- **期待出力**: 単一責務（Human action の追跡・Gate 保持）の記述あり、他 Agent への過剰委譲なし
- **検証**: frontmatter description + 責務本文の構造確認

### TC-13 [AC-7] Rule 4: 案件固有は CLAUDE.md
- **種別**: static
- **入力**: 三層実装ファイル
- **期待出力**: PlanGate 固有の wiring 詳細は CLAUDE.md / settings-wiring-contract.md への参照に留め、Agent / Skill / Command 本文に直書きしない
- **検証**: 三層実装ファイル内で固有 wiring 詳細記述箇所のレビュー

### TC-14 [AC-7] Rule 5: handoff 集約
- **種別**: integration
- **入力**: `docs/working/TASK-0107/handoff.md`
- **期待出力**: 6 要素網羅
- **検証**: TC-15 と同等。本 TC では handoff の存在のみ確認

### TC-15 [AC-8] handoff.md 6 要素網羅
- **種別**: integration / grep
- **入力**: `docs/working/TASK-0107/handoff.md`
- **期待出力**: 以下 6 セクションが存在
  1. 要件適合確認結果
  2. 既知課題一覧
  3. V2 候補
  4. 妥協点
  5. 引き継ぎ文書
  6. テスト結果サマリ
- **検証**: `grep -cE "(要件適合|既知課題|V2|妥協点|引き継ぎ|テスト結果)" docs/working/TASK-0107/handoff.md` >= 6

### TC-16 [AC-9] Agent frontmatter 既存 Agent と同構造
- **種別**: static / diff
- **入力**: `.claude/agents/setup-coordinator.md` と `.claude/agents/acceptance-tester.md`
- **期待出力**: frontmatter のキー集合（name, description, tools, model 等）が一致
- **検証**: frontmatter を YAML パースしてキー比較

### TC-17 [AC-10] settings.json hooks セクション diff = 0
- **種別**: static / git diff
- **入力**: `.claude/settings.json`
- **期待出力**: 当 PBI の変更で hooks セクションが変更されていない
- **検証**: `git diff main..HEAD -- .claude/settings.json | wc -l` == 0、または変更があっても hooks 配下のキーは不変

### TC-18 [AC-11] status.md に完了マーカー
- **種別**: integration
- **前提条件**: T-01〜T-06 を踏んだ後
- **期待出力**: `docs/working/TASK-0107/status.md` に各 Step の完了マーカー（例: `## Step N: ... ✅`）が記録
- **検証**: status.md を読み完了マーカー数が Step 数以上

### TC-19 [AC-11] decision-log.jsonl に append-only エントリ
- **種別**: integration
- **前提条件**: T-01〜T-06 後
- **期待出力**: `docs/working/TASK-0107/decision-log.jsonl` に各 manual action の `pending` → `resolved` エントリが append（タイムスタンプ昇順）
- **検証**: jsonl を 1 行ずつ JSON パース、タイムスタンプ昇順、status 遷移が pending → resolved の順

### TC-20 [AC-12] doctor --check-settings FAIL で V-1/handoff ブロック
- **種別**: gate negative test
- **前提条件**: settings wiring 未適用状態
- **入力**: `bin/plangate doctor --check-settings` 実行 → FAIL
- **期待出力**: V-1 / handoff 完了処理が走らない（Agent が「未完了」と判定）
- **検証**: Agent の対話パスに `--check-settings PASS` を待つ分岐が存在 + 実行で FAIL 時のブロックを確認

### TC-21 [AC-13] 解消不能 FAIL でフォローアップ PBI 起票誘導
- **種別**: unit mock + **manual**（Agent 対話パス人間確認）
- **前提条件**: Mock C（解消不能 FAIL）
- **期待出力**: Agent が「フォローアップ PBI 起票」を提示する対話パス
- **検証**: 出力に「フォローアップ」「PBI 起票」「issue 作成」等のキーワード

### TC-22 [AC-13] 承知スキップで status.md に明示記録
- **種別**: unit mock + **manual**（Agent 対話シミュレーション）
- **前提条件**: Mock C → ユーザー「承知スキップ」選択
- **期待出力**: `status.md` に「skip (acknowledged): {理由}」が記録
- **検証**: status.md に skip マーカー + 理由が存在

---

## エッジケース

### EC-01 TASK ID 不明時の起動
- **シナリオ**: `/plangate-setup` を `docs/working/TASK-XXXX/` の外（ルート等）から起動
- **期待**: Agent が「TASK ID を指定するか、新規 Task を作成してください」と促す（U7 guard）
- **検証**: 起動コンテキスト fixture で TASK ID 不明状態を作り、Agent の応答を確認

### EC-02 doctor --json 出力スキーマ変更
- **シナリオ**: 将来 `doctor --json` のキー追加 / 削除
- **期待**: Agent が `level` / `ok` / `passed` の必須キーに依存し、未知キーには無関心
- **検証**: 拡張 fixture（追加キーあり）でも Agent が正常動作

### EC-03 同時起動（同一 TASK で複数セッション）— **v1 unsupported**
- **シナリオ**: 同じ TASK-XXXX で `/plangate-setup` を二重起動
- **期待**: Agent は**「同時起動は v1 では未サポート」を検出し中断・注意喚起**（同時 append の原子性 / ロック方式は v1 では定義しない）
- **検証**: 二重起動シナリオで Agent が中断 or 警告メッセージを出すことを確認
- **v2 候補**: 完全な同時書き込み耐性（flock 等）は v2 範囲に分離。本 PBI Out of scope（R-013 反映）

### EC-04 doctor 自体が起動しない
- **シナリオ**: `bin/plangate doctor` 実行が失敗（permission 等）
- **期待**: Agent が「doctor 自体が起動できません」エラーを表示し再起動を促す
- **検証**: doctor 起動失敗 fixture で Agent の応答を確認

---

## 既知の自動化制約

- TC-01 / TC-06 / TC-07 / TC-08 / TC-21 / TC-22 は Agent の対話シミュレーションを要するため、現状の test infra で部分的に手動検証となる可能性。manual marker を付与し V-1 で人間確認を併用。
- 完全自動化は v2 範囲（Out of scope）。
