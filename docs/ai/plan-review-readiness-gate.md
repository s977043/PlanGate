# Plan Review Readiness Gate

> Issue: [#652](https://github.com/s977043/plangate/issues/652)
> Related upstream: [s977043/river-review#1325](https://github.com/s977043/river-review/issues/1325)

## 1. 目的と位置づけ

Plan Review Readiness Gate は、`plan.md` / `todo.md` / `test-cases.md` が生成された直後、C-1 self-review の前に置く計画実行準備ゲートである。

```text
WF-00 -> WF-01 -> WF-02 -> WF-03 -> B[plan/todo/test-cases]
  -> Plan Review Readiness Gate
  -> C-1 -> C-2 -> C-3 -> D[exec] -> WF-04 -> WF-05
```

PlanGate 統制層フェーズ（A / B / D / L-0）との対応は [`plangate-insertion-map.md`](../workflows/plangate-insertion-map.md) を参照。

このゲートの目的は、AI 実行に渡す前の計画が「レビュー可能」であり、かつ C-1 / C-2 / C-3 が見るべき境界を明示していることを確認することである。実装品質そのものを判定するゲートではなく、レビュー対象 artifact の準備状態を判定する。

> Design decision: 新規 standalone gate として定義する。`docs/ai/plan-quality-checks.md` は advisory な計画品質チェック、`docs/ai/gate-checks.md` は C-3 承認記録の optional 拡張であり、本ゲートのように C-1 前で `pass / needs_revision / blocked` を返す実行前判定とは責務と時点が異なるため、既存文書への混在を避ける。

## 2. 判定値

| Verdict | 意味 | 次アクション |
|---------|------|--------------|
| `pass` | 7 項目がすべて記入され、C-1 で妥当性レビューできる状態 | C-1 self-review へ進む |
| `needs_revision` | 計画の不足はあるが、危険操作や承認境界違反ではない | `plan.md` / `todo.md` / `test-cases.md` を修正して再判定 |
| `blocked` | 矛盾、未承認の危険操作、Human-owned 境界、破壊的操作、依存追加など、AI が自己判断で進めてはいけない要素がある | 人間判断または PBI 再整理まで停止 |

判定不能な場合は安全側に倒し、少なくとも `needs_revision` とする。危険操作・承認境界・破壊的変更に関わる判定不能は `blocked` とする。

## 3. チェック項目

すべての項目は `plan.md` に明示し、必要に応じて `todo.md` / `test-cases.md` と対応させる。

| # | 項目 | `pass` | `needs_revision` | `blocked` |
|---|------|--------|------------------|-----------|
| 1 | Success criteria | AC、完了境界、Done 判定が具体的で、`test-cases.md` と対応している | AC と作業の対応が一部曖昧、検証方法が不足 | 成功条件が矛盾、または完了境界が定義不能 |
| 2 | Review criteria | 設計整合、テスト期待値、セキュリティ、保守性、後方互換、運用リスクの観点が揃っている | 一部観点が N/A 理由なし（N/A の根拠が未記載）または空欄で欠落 | 重要リスクをレビュー対象から外している |
| 3 | Required context | 参照 Issue / ADR / docs / 既存実装 / 関連テスト / 制約が列挙されている | 参照先が不足、または確認済み/未確認の区別が弱い | 必須前提が未確認で、誤実装や破壊的変更につながる |
| 4 | Non-goals and scope boundary | Out of scope、変更禁止領域、禁止依存が明示されている | 禁止領域や依存追加方針が曖昧 | HO パス（`bin/plangate`・`schemas/`・`.claude/`・`CLAUDE.md` 等、[EH-1 正本](./hook-enforcement.md) 参照）や禁止領域を編集対象に含めている |
| 5 | Stop conditions | 競合要件、認証/課金/破壊的操作、新規依存、大規模な想定外変更の停止条件がある | 停止条件が一般論で、実行者が判断しにくい | 停止すべき条件を通常作業として扱っている |
| 6 | Replan Triggers | hidden dependency、public API 変更、test contract mismatch、scope bloat、security impact の再計画トリガーが列挙されている | 再計画トリガーが一部未記入、または閾値が曖昧 | 再計画が必要な変更を exec 中に吸収する計画になっている |
| 7 | Human approval boundary | security、auth、billing、permissions、prod ops、data deletion、migration、irreversible changes、merge（C-4）の人間承認境界が明示されている | 一部境界が N/A 理由なし（N/A の根拠が未記載）または空欄で欠落 | Human-owned 操作を AI 判断で実行する計画になっている |

## 4. Decision table

複数条件が同時に成立した場合は、より厳しい verdict を採用する（`blocked` > `needs_revision` > `pass`）。

| 条件 | Verdict |
|------|---------|
| 7 項目すべてが具体的に記入され、未解決の危険境界がない | `pass` |
| 1 つ以上の項目に記入不足があるが、修正すれば C-1 に進める | `needs_revision` |
| `TBD` / `TODO` / `必要に応じて` / プレースホルダ未置換 / 空欄 が重要項目に残っている | `needs_revision` |
| AC と `test-cases.md` の対応が欠落している | `needs_revision` |
| 禁止ファイル、HO パス（EH-1 正本参照）、Out of scope が変更対象に含まれている | `blocked` |
| 認証、課金、権限、本番運用、データ削除、migration、不可逆変更、merge（C-4）を AI 判断で実行する | `blocked` |
| 承認トークンファイル（`approvals/c3.json`・`maintenance.json` 等）を AI が直接編集する計画がある | `blocked` |
| 新規依存や public API 変更が必要だが、承認境界と再計画条件が未定義 | `blocked` |
| 要件が互いに矛盾し、AI が一意に解釈できない | `blocked` |

## 5. 良い AI 実行計画の例

```markdown
## Plan Review Readiness

### Success Criteria
- AC-1 は `test-cases.md` T1/T2 で確認する。
- Done は docs 更新、リンク整合、`rg` による旧名称なし確認まで。

### Review Criteria
- Design alignment: 既存の `docs/workflows/` 命名と対応表に合わせる。
- Security: executable code と hook は変更しないため N/A。
- Backward compatibility: 既存フェーズ名を削除せず追記のみ。

### Required Context
- Issue: #652
- Existing docs: `docs/ai/gate-checks.md`, `docs/ai/plan-quality-checks.md`
- Constraints: HO paths は編集しない。

### Non-goals and Scope Boundary
- Out of scope: schema 変更、hook 実装、CLI 実装。
- Forbidden zones: `bin/plangate`, `schemas/*.schema.json`, `.github/workflows/*.yml`,
  `.claude/settings*.json`, `.claude/rules/**`, `plugin/plangate/**`,
  `CLAUDE.md`, `AGENTS.md`, `docs/ai/core-contract.md`
  （詳細は EH-1 production code 定義参照）

### Stop Condition
- HO パス編集が必要になったら停止。
- 新規依存や CLI 実装が必要になったら停止。

### Replan Triggers
- C-1 前でなく C-3 側に置くべき既存正本が見つかった場合は再計画。
- public API / schema 変更が必要になった場合は再計画。

### Human Approval Boundary
- schema、hook、CI、権限、本番運用、データ削除、migration、merge（C-4）は人間承認なしに実行しない。
- 承認トークンファイル（`approvals/c3.json` 等）の AI 直接編集は禁止。
```

この例は、レビュー観点と停止境界が具体的で、実行者が「どこまで進めてよいか」を判断できる。

## 6. 悪い AI 実行計画の例

```markdown
## Plan Review Readiness

### Success Criteria
- いい感じに動くこと。

### Review Criteria
- 必要に応じて確認する。

### Required Context
- たぶん既存 docs を見る。

### Non-goals and Scope Boundary
- 特になし。

### Stop Condition
- 問題があれば止める。

### Replan Triggers
- 必要なら再計画する。

### Human Approval Boundary
- AI が判断する。
```

この例は、AC・レビュー観点・停止条件・再計画条件が実行可能な粒度ではないため `needs_revision` の要素を含む。さらに Human Approval Boundary に「AI が判断する」と記入されている箇所は Section 4 の `blocked` 条件に直接該当する。`needs_revision` と `blocked` は独立した判定軸であり、`blocked` 条件が 1 つでも成立すれば最終判定は `blocked`（優先順: `blocked` > `needs_revision` > `pass`）。

## 7. ドキュメント仕様変更時の追加観点

仕様ドキュメント（Markdown）を変更・追加する場合、§3 の 7 項目に加えて以下を確認する。
過去の PR レビュー指摘（#661/662）で繰り返し検出されたパターンを起点としている。

| # | 観点 | チェック内容 | `needs_revision` | `blocked` |
|---|------|-------------|------------------|-----------|
| D-1 | **テーブル・判定表の網羅性** | 判定テーブルの全入力パターンが行として定義されているか（例: W チェック 4 パターン、スキーマのフィールド定義テーブルに全フィールドが揃っているか） | 明確なパターンが 1 件以上欠落 | 欠落により別セクションの定義と矛盾する |
| D-2 | **セクション間整合性** | 同一概念が複数セクションで矛盾なく定義されているか（条件 A ⊃ 条件 B の関係を確認） | 記述が曖昧・冗長で混乱を招く | 2 セクション以上で矛盾（例: §X でブロック定義、§Y で human escalate として重複定義） |
| D-3 | **用語の統一** | 同一概念を指す用語が文書内・文書間で統一されているか（UI ラベルと API 値が混在する場合は対応表を追記） | 同一概念に複数の表記が混在 | — |
| D-4 | **参照の完全性** | 参照先がリポジトリ内に実在し一意に辿れるか（Markdown 相対リンク可。ファイル名のみの曖昧参照・デッドリンクを排除） | 一意に辿れない参照（ファイル名のみ等）がある | 参照先ファイルがリポジトリに存在しない |
| D-5 | **仕様記述の精度** | 安全保証・効果の主張が正確か。エッジケース（リセット条件・スコープ・時間窓の種類）が明記されているか | 曖昧な表現（「防止」と「検知」の混同、リセット条件未記載） | 仕様が実装者に誤解させる記述（「replay 防止」と書いて実際は「検知のみ」等） |
| D-6 | **セクション番号・相互参照の整合** | 見出しの挿入・リネーム時に後続番号と章内相互参照（「詳細は §N」等）が追従しているか。連番の欠番・重複がないか | 参照先の節番号ズレ・欠番がある | 参照ズレにより読者が正本定義に到達できない |

> **D-2 の適用範囲**: セクション間整合は「文書↔文書」に加えて
> 「**文書↔実装コード**」にも適用する（例: 仕様書の刻印条件と実装の出力条件の
> 揺れ。PR #678 で実害）。

### 適用タイミング

`§3 チェック項目 #2 Review criteria` の確認時に上記 D-1〜D-5 をドキュメント変更分に追加適用する。
コード変更を伴わないドキュメント単体の PR でも同様に適用する。

## 8. シェル / Python コード変更時の追加観点

シェルスクリプト（`bin/plangate`、`scripts/hooks/`）または Python スクリプトを変更・追加する PR において、
§3 の 7 項目に加えて以下を確認する。
6月の PR #602/618/625/630/631/632/646 で繰り返し検出されたパターンを起点としている。

| # | 観点 | チェック内容 | `needs_revision` | `blocked` |
|---|------|-------------|------------------|-----------|
| C-1 | **`set -e` × コマンド置換** | `result=$(command)` を `set -e` 環境で使うと非ゼロ終了でスクリプト全体が中断する。非ゼロを許容する場合は `if command; then ...` パターンを使う。`2>&1` リダイレクトで stderr が変数に混入する場合も同様 | 1 箇所以上で `set -e` 下のコマンド置換に非ゼロ終了の可能性がある | フック（hook）スクリプトで静かに失敗し、フックバイパスになる |
| C-2 | **Python `open()` の `encoding` 未指定** | `open(path)` は環境ロケールに依存する。日本語コンテンツで `UnicodeDecodeError` が起きると false-positive ブロックになる | 1 箇所以上で `encoding='utf-8'` が省略されている | hook / provenance スクリプトで読み取り失敗が false-positive ブロックを引き起こす |
| C-3 | **GHA `run:` へのコンテキスト式直接展開** | `${{ github.event.xxx }}` を `run:` ステップに直接書くと、任意コマンド実行の脆弱性（Script Injection）になる。必ず `env:` 変数経由で渡す | — | `${{ github.event.*.tag_name }}` 等をインライン展開している |
| C-4 | **CLI 実装とドキュメントの記法不整合** | `--flag=value` と `--flag value` を混用するとサイレント失敗（引数が別変数に入る）。実装とドキュメントで記法を統一する | ドキュメントが実装と異なる記法を示している | 実装が `=` 区切りのみ対応だがドキュメントはスペース区切りを示し、呼び出し元がスペース区切りで呼ぶ |
| C-5 | **診断系ツールでの `2>/dev/null` 抑制** | `doctor` や debug モードでも `2>/dev/null` で警告を捨てると、トラブルシューティングが不可能になる。ログレベルや `--quiet` フラグで制御する | 診断コマンドで原因調査に必要な警告が抑制されている | — |
| C-6 | **実装定数↔ドキュメントスキーマ例の一致** | 実装の定数・フィールド名・列挙値が仕様書のスキーマ例と一致しているか（例: `issued_by` の値。不一致は provenance 追跡・バージョン判定を混乱させる） | 表記ゆれ（大文字小文字・suffix 差）がある | 値そのものが不一致 |

### 適用タイミング

`§3 チェック項目 #2 Review criteria` の確認時に、シェルスクリプト / Python ファイルの差分がある場合に上記 C-1〜C-5 を追加適用する。

> **検証スクリプトの git diff**: 差分検証に `git diff --name-only` を使う場合は
> `<base>...HEAD` の範囲指定を必須とする（引数なしは未ステージ変更のみが対象と
> なり、コミット済み変更で空を返す。PR #680 で実害）。

## 9. 関連

- [`plan-quality-checks.md`](./plan-quality-checks.md) — advisory な計画品質チェック
- [`gate-checks.md`](./gate-checks.md) — C-3 承認時の optional 記録拡張
- [`review-gate-decision-mapping.md`](./review-gate-decision-mapping.md) — C-2 / C-3 判定接続
- [`../workflows/03_solution_design.md`](../workflows/03_solution_design.md) — WF-03 の完了条件
- [`../working/templates/plan.md`](../working/templates/plan.md) — 本ゲートが確認する plan fields
