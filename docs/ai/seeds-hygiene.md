# improvement-seeds hygiene（統合フェーズ）正本仕様（#754）

> 本書は `docs/working/improvement-seeds.md`（[`retro-phase.md`](./retro-phase.md) §2
> 正本スキーマ）に対する **統合フェーズ（hygiene）** の正本仕様である。
> 起源: issue #754（Anthropic Managed Agents（Memory Store / Dreams / Outcomes）
> とのギャップ分析、2026-07-07 セッション）。seeds 本体・retro-phase.md の
> 既存仕様は変更しない（追加専用の正本）。

## 背景（issue #754 記載のギャップ分析より）

issue #754 記載のギャップ分析（2026-07-07）より: Anthropic Managed Agents の
7 論点中 5 つ（Outcome/rubric・却下理由ログ・Memory Candidate・memory write
保護・subagent 文脈分離）は既存正本でカバー済みと判定されたが、1 点だけ
構造的ギャップが残る。`improvement-seeds.md` は append-only で溜まる一方で、
Dreams 相当の **統合フェーズ（重複排除・矛盾解消・陳腐化更新）** と、統合
結果を **次回 plan 生成の入力に還流する経路** が未定義だった。本書はこの
ギャップを埋める仕様正本である。

参考（issue #754 記載のギャップ分析より）: Anthropic Dreams は「過去セッ
ション + 既存 Memory Store → 整理済み新 Memory Store を生成し、元は不変・
出力を人間がレビューして採否」という非破壊 + 人間承認の構造を取る。これは
PlanGate の append-only + `confirmed_by` 原則とそのまま整合する。

## 入力

- `docs/working/improvement-seeds.md`（[`retro-phase.md`](./retro-phase.md) §2
  スキーマに従う全エントリ。1 run 1 エントリの append-only 蓄積）
- 必要に応じ各 `docs/working/TASK-XXXX/decision-log.jsonl`（seeds の記述だけ
  では判断根拠が薄い場合の補助入力。必須ではない）

## 処理

統合フェーズは以下 3 種の処理を行う。いずれも **元ファイルへの書き込みを
一切伴わない**（読み取り専用処理。出力は別ファイルへのみ行う）。

1. **重複統合**: 複数エントリに同一の摩擦点・判断が繰り返し出現する場合
   （例: 同じツール制約への対処が 2 回以上記録されている）、1 項目に統合し
   「恒常運用へ昇格すべき候補」として明示する。判定基準: 同一の技術的原因
   （同じスクリプト・同じ hook・同じ制約）に言及する記述が 2 エントリ以上
   に存在すること。
2. **矛盾検出**: 異なるエントリが同じ論点に対して相反する「次回再利用すべ
   き判断」を記録している場合、両方を残したまま矛盾として明記し、どちらか
   一方の自動採用は行わない（判断は人間レビューに委ねる）。
3. **陳腐化判定**: エントリが記録した摩擦点が、その後の PR・仕様変更・
   hook 配線で解消済みと確認できる場合、「解消済み（resolved）」とマークす
   る。判定基準: (a) 摩擦点の原因となった仕組み（スクリプト・hook・設定）
   が現在のリポジトリに実在し、(b) その変更が摩擦点発生日以降のコミット /
   仕様（settings.json・スクリプトの実在確認等）で裏付けられること。両方を
   満たさない場合は resolved と判定せず「現役（未解消）」のまま残す。

## 出力

- **元ファイルは不変**（append-only 不変条件を維持する）。統合フェーズは
  `docs/working/improvement-seeds.md` に対して **一切の書き込みを行わない**。
- 統合結果は別ファイル `docs/working/improvement-digest.md` として **新規
  生成**する（既存 digest がある場合は新しい版で上書き生成してよいが、
  seeds 本体側は常に不変）。
- 生成された digest は **人間レビュー → PR マージで採用**する。digest の
  生成自体は自動化してよいが、内容の正式採用（後続フェーズの参照対象と
  すること）は PR の C-4 レビュー通過をもって確定する。
- **不変の検証手順**（AC-2v2 準拠）: 統合フェーズの実行前後で以下のコマン
  ドが exit 0 を返すことを必須検証とする。

  ```sh
  git diff --quiet <base> -- docs/working/improvement-seeds.md
  ```

  exit 0 = seeds 本体に差分なし（append-only 不変条件を満たす）。exit 1 が
  返る場合は統合フェーズの実装が不変条件に違反しているため、そのまま
  マージしてはならない。

## 還流

生成・採用された `docs/working/improvement-digest.md` は、以下の参照入力
として位置づける:

- **WF-01 context bootstrap**: セッション開始時の Progressive Disclosure
  （[`working-context.md`](../../.claude/rules/working-context.md)）で、
  過去の教訓を圧縮した形で参照できるようにする。
- **plan 生成時**（フェーズ B）: 「次回再利用すべき判断」の集約版として
  Work Breakdown / Risks & Mitigations の参考情報に用いる。

digest はあくまで**参照入力**であり、plan 生成や C-3 承認の自動判断材料と
して機械的に使ってはならない（人間・AI いずれも、digest の記述を根拠に
承認境界を緩和しない）。

## 責務分類

[`responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
の 4 分類に準拠し、本フェーズの責務を以下のように分界する:

| 作業                                                                 | 分類            | 備考                                                                    |
| -------------------------------------------------------------------- | --------------- | ----------------------------------------------------------------------- |
| digest の生成（重複統合・矛盾検出・陳腐化判定の実行）                | **AI-owned**    | seeds を読み digest を書く処理そのもの                                  |
| 検証（AC-2v2 コマンド等の実行・PASS/FAIL 判定）                      | **AI-owned**    | 元ファイル不変の機械検証                                                |
| digest の採用（後続フェーズの参照対象として確定させる、= PR マージ） | **Human-owned** | 対外公開アーティファクト publish 責務分界と同様、不可逆・確定操作は人間 |

digest 採用フローは Human-owned（PR レビュー経由）とする。統合結果に対する
最終判断（重複統合の妥当性・矛盾の解消方針・resolved 判定の正しさ）は、
PR の C-4 レビューが兼ねる。AI は digest の生成・検証までを担い、採否を
決定しない。

## 実行トリガー（v1）

- **v1 = 手動起動のみ**。skill もしくは `bin/plangate` サブコマンド経由で
  人間が明示的に起動する。
- **scheduled 実行は宣言のみ**（設計メモ）。LoopSpec の `trigger.type:
scheduled` 互換のトリガー形式を将来的に採用できるよう、起動条件を
  `{type: manual}` として明示しておく。scheduled 実装（cron 等での自動起動）
  は本書のスコープ外であり、v2 候補として扱う。

## Non-goals（#754 Out of Scope の転記）

- `improvement-seeds.md` 本体の編集・削除（append-only 不変条件は変更しな
  い）
- `~/.claude` agent memory の整理（`growth-core:memory-dream` の責務、本書
  では統合しない）
- rubric スコアリング・優劣判定（#231 dogfooding eval / #228 Run Outcome
  Review の責務）
- scheduled 自動実行の実装（v2 候補。v1 は手動起動のみ）
- memory への自動書き込み（人間承認なしの digest 採用は行わない）

## 関連

- [`retro-phase.md`](./retro-phase.md) §2（improvement-seeds スキーマ正本）
- [`working-context.md`](../../.claude/rules/working-context.md)
  improvement-seeds.md 節
- [`responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
  （4 分類正本）
- issue #754（本書の起源。関連 #235 / #228 / #231 / #200）
