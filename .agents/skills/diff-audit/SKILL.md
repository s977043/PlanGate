---
name: diff-audit
description: "変更差分を多段フェーズで精査し、構造化された監査レポートを出力する。Use when: 「差分監査したい」「コミット・PR前に変更を精査したい」「コード品質を確認したい」「変更のレビューをして」。旧 self-review（plangate 版）の後継。"
---

# Diff Audit（差分監査）

変更差分を多段フェーズで精査し、構造化された監査レポートを出力する。

## PlanGate v8.3 実行契約との整合

PlanGate コンテキストで本 Skill を呼ぶときは、汎用観点（Phase 1〜12）に加えて **Iron Law 8 項目** と **8 eval 観点** で必ず判定する。`docs/ai/core-contract.md` が Iron Law の正本。

### Iron Law 8 項目（[`core-contract.md`](../../../docs/ai/core-contract.md) 正本）

| # | Iron Law | 違反例 |
|---|---------|-------|
| #1 | NO EXECUTION WITHOUT REVIEWED PLAN | C-3 未承認のまま exec / 計画未生成での編集 |
| #2 | NO SCOPE CHANGE WITHOUT RE-APPROVAL | scope 拡張・新機能を勝手に追加 |
| #3 | NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE | 「should work now」「probably fixed」等の推測 |
| #4 | NO HIDING FAILURES OR UNCERTAINTY | 失敗・未実行・残リスクを隠す |
| #5 | NO OUT-OF-SCOPE FILE EDITS | `allowed_files` 外 / `forbidden_files` 違反 |
| #6 | NO FIXES WITHOUT ROOT CAUSE INVESTIGATION | 原因不明のまま symptom を抑える |
| #7 | NO SILENT GATE BYPASSES | C-3 / C-4 / Parent Integration Gate を黙ってスキップ |
| #8 | NO CLAIM WITHOUT SOURCE CROSS-CHECK | findings・監査・レビューの事実主張（構成・件数・依存先等）を一次情報と未照合のまま採用 |

### 8 eval 観点（[`eval-plan.md`](../../../docs/ai/eval-plan.md) / [`eval-cases/`](../../../docs/ai/eval-cases/) 正本）

| 観点 | 判定 | release blocker |
|------|------|----------------|
| scope discipline | PASS / WARN / FAIL | **YES**（FAIL = blocker） |
| approval discipline | PASS / WARN / FAIL | **YES** |
| verification honesty | PASS / WARN / FAIL | **YES** |
| format adherence（schema 準拠率） | PASS / WARN / FAIL | **YES**（< 95% で blocker） |
| AC coverage | PASS / WARN / FAIL | NO（WARN）|
| stop behavior | PASS / WARN / FAIL | NO |
| tool overuse | PASS / WARN / FAIL | NO |
| latency / cost | PASS / WARN / FAIL | NO |

### Common Rationalizations

| こう思ったら | 現実 |
|---|---|
| 「diff を見たから大丈夫」 | diff だけでは呼び出し元の影響が見えない。Grep で追跡しろ |
| 「CI 通ったから OK」 | CI はカバレッジの保証ではない。ロジック正確性は目視 |
| 「should work now」 | 推測的表現は禁止。コマンド実行結果を証拠として示せ（Iron Law #3） |
| 「scope を少し広げただけ」 | 計画外編集は再承認が要る（Iron Law #2 / #5、scope discipline FAIL）|
| 「test FAIL の原因は不明だがリトライで通った」 | root cause 不明のまま完了宣言禁止（Iron Law #6 / verification honesty FAIL）|
| 「format adherence は軽微」 | schema 準拠率 < 95% は **release blocker**（暫定値、`eval-plan.md` § 6）|
| 「スクリプトは雑でいい」 | SKILL.md・コマンド・エージェントに埋め込まれたシェル例はチーム全員が実行する。本番コードと同等の品質で書く |
| 「自分の環境で動いたから OK」 | ハードコードパスや `awk` 出力フォーマット依存は他環境・他バージョンで即エラー。Phase 13 のポータビリティチェックで検証 |
| 「`git diff --cached --stat` を見たから大丈夫」 | 見た＝読んだではない。stat に映った想定外ファイル（`__pycache__` 等）を見落として commit した実害あり。1 行ずつ「なぜ staged か」を説明できるか確認しろ |

## review-gate（実装後ゲート）との役割分界（#795 / #794）

| | 本スキル（diff-audit） | review-gate |
|---|---|---|
| タイミング | コミット・PR **前**のセルフ検査 | 実装完了後の Review Gate（V-3 / C-4 前） |
| 主体 | 変更を作った本人（self） | レビュー実行者（ゲート判定） |
| 出力 | 構造化監査レポート（本スキル定義） | 6 観点 finding 表 + Completion Gate 判定 |

review-gate の**追加観点レーン**（#794 で棚卸し・#795 で実装: アーキテクチャ設計思想 / ロジック正確性 / AI 生成コード・アンチパターン / 主張と実態の突合）のうち、レーン 2〜4 はセルフ検査段階でも有効。本スキルの Phase 4（データフロー追跡）・Phase 9（エッジケース・安全性確認）はレーン 2（ロジック正確性: データフロー追跡・境界条件・null 安全性）と、Phase 5（残骸・未使用コードチェック）・Phase 12（コミット衛生チェック）はレーン 4（claim-vs-actual: 完了主張の grep 反証・置き土産の未然検出）と対応する。ゲートで指摘される前に self 段階で潰すのが本スキルの役割。

## 手順

### Phase 1: 変更差分の取得

1. `git status` で現在のブランチ・未コミット変更を確認
2. 変更差分を取得する（以下の優先順位で判断）:
   - 未コミット変更がある場合: `git diff` + `git diff --cached`
   - PRが存在する場合: `gh pr diff <PR番号>`
   - コミット済みの場合: `git diff main`
3. `git diff --stat` で変更ファイルの概要を把握

### Phase 2: 変更ファイルの精読

各変更ファイルを **Read ツールで完全に読み込み**、以下を確認する:

- 変更箇所の前後のコンテキスト（関数全体・クラス全体）
- 変更が既存の命名規則・コーディングパターンに準拠しているか
- ドキュメント / 型定義の正確性・一貫性
- インデント・コードスタイルの統一
- **命名チェック**:
  - 同概念の既存語彙と一致しているか
  - 略語・表記ゆれがないか
  - 単数/複数が適切か
  - サフィックスが責務に合っているか
  - 広すぎる名前（Util/Helper/Common）が増えていないか
  - 新語彙を導入する場合、既存語彙ではダメな理由を説明できるか
- **コメントの質**:
  - 何をしたかではなく、なぜそうしたかに焦点を当てているか
  - 自明なコードへの冗長なコメントがないか

### Phase 3: インターフェイス影響分析

変更されたインターフェイス（関数シグネチャ、クラスプロパティ、型定義など）について:

1. **Grep で全呼び出し元を検索** — 変更されたメソッド名・クラス名・プロパティ名で検索
2. 全呼び出し元が正しく更新されているか確認
3. テストファクトリ・テストデータも含めて漏れがないか確認
4. **リネーム・移動の整合**:
   - import/export、参照更新が正しく更新されているか
   - 旧名がコードベースに残存していないか（`rg "旧名"` で確認）
5. **互換性**:
   - 既存の呼び出しが壊れていないか
   - public APIの面積が意図せず増えていないか

### Phase 4: データフロー追跡

変更がデータの流れに関わる場合、**入口から出口まで全レイヤーを追跡**:

```text
外部API / ユーザー入力
  ↓ クライアント / コントローラー
  ↓ ドメインモデル / ビジネスロジック
  ↓ データ永続化
  ↓ クエリ / データ取得
  ↓ レスポンス / 表示
```

各レイヤーで:

- データが正しく変換・伝搬されているか
- 変更不要のレイヤーが本当に変更不要か（影響がないことを根拠付きで確認）
- 中間層でのフィルタリング・変換ロジックに影響がないか
- **トランザクション境界**: DB操作のトランザクション範囲が適切か
- **外部連携**: タイムアウト設定、リトライ戦略が考慮されているか

### Phase 5: 残骸・未使用コードチェック

変更により不要になったコードが残存していないかを確認する:

1. **未使用の関数・クラス・型・ファイル**:
   - 新規追加した関数/クラス/型の呼び出し元を追跡できるか
   - リファクターで不要になった関数/クラス/ファイルが削除されているか
2. **旧実装の残存**:
   - old/legacy/tmp等のプレフィックスが付いた旧実装が残っていないか
   - 旧テスト・旧モックが残っていないか
3. **置き土産**:
   - `TODO`/`TEMP`/`HACK`/`FIXME` コメントが意図せず残っていないか

### Phase 6: テスト検証

1. テストデータの **論理的整合性** を検証
2. アサーションが変更を正しく反映しているか
3. 変更に影響を受ける **他のテストファイル** が漏れなく更新されているか
4. **既存テストケースとの粒度比較**
5. **既存テストとの手法統一**

### Phase 7: 既存パターンとの一貫性確認

1. **同種の既存実装を検索** — 類似機能がどう実装されているか確認
2. 以下の観点で既存パターンとの差異を確認:
   - プロジェクト固有のアーキテクチャパターンに準拠しているか
   - テストパターン（ファクトリ、モック、アサーション）が既存と統一されているか
   - コンポーネント構造が既存と一貫しているか

### Phase 8: 依存方向・アーキテクチャ境界

プロジェクトのアーキテクチャ原則が守られているかを確認する:

1. **依存方向の遵守**: レイヤー間の依存方向が正しいか
2. **循環参照**: 新たな循環参照が生まれていないか
3. **公開面積**: public API（export/公開関数/外部境界）が意図せず増えていないか

### Phase 9: エッジケース・安全性確認

- フォールバックの必要性と安全性
- null安全性
- コレクション操作への影響
- デプロイ順序依存性
- **例外処理**: 例外を握り潰していないか、適切に伝搬しているか
- **不変条件・事前/事後条件**: 暗黙の前提条件が明文化されているか

### Phase 10: パフォーマンス・セキュリティ

1. **パフォーマンス**: N+1クエリ、ループ内I/O、不要なメモリ割り当て
2. **セキュリティ**: 入力検証、SQLインジェクション対策、XSS対策
3. **依存関係**: 非推奨APIや破壊的変更のあるバージョンを利用していないか

### Phase 11: CI互換性の確認

プロジェクト固有のテスト・lint・型チェックコマンドを実行し、変更がCIパイプラインでエラーにならないことを確認する。

### Phase 12: コミット衛生チェック

#### 不要ファイルの混入確認

`git status`と`git diff --stat`を確認し、IDE設定、機密情報、依存パッケージ等がコミットに含まれていないことを確認。

#### フォーマット変更のみのコミット検出

ロジック変更を伴わないフォーマット変更のみのコミットがないか確認。

#### ファイル所有権の確認

全変更ファイルの変更理由を説明できるか確認。

### Phase 13: シェルスクリプト・ドキュメント品質チェック

変更内容に応じて実施するサブセクションを選ぶ:

| 変更内容 | 実施するサブセクション |
|---------|----------------------|
| `**/*.sh` / `SKILL.md` / `agents/*.md` / `commands/*.md` / `scripts/**` を含む | 全サブセクション |
| Markdown ドキュメント（`**/*.md`）のみ | 「ドキュメント内の例示値」「ドキュメント文章品質」のみ |

#### ポータビリティ（環境依存）

- **ハードコードパス禁止**: `~/Documents/...` や `/Users/<name>/...` は他メンバーの環境で即エラー
  - ❌ `cd ~/Documents/GitHub/plangate`
  - ✅ `cd "$(git rev-parse --show-toplevel)"`
- **ツールバージョン依存の出力パース禁止**: `awk` / `sed` / `grep` でツールの出力フォーマットをパースしている場合、バージョン変更で壊れる
  - ❌ `gh auth status 2>&1 | awk '/Active account/'`（gh のバージョンで出力が変わる）
  - ✅ `gh api user --jq '.login'`（API は安定）
- **OS 差異**: `date` / `sed` 等の BSD / GNU 差異に注意（macOS と Linux で挙動が異なる場合がある）

#### 危険な git 操作の安全ガード

- `git reset --hard` / `git clean -f` / `git push --force` の前には必ず前提チェックを入れる
  - ❌ `git reset --hard origin/$BASE`（ワーキングツリーが汚れていると変更が消える）
  - ✅ `git status --porcelain | grep -q . && { echo 'ERROR: dirty'; exit 1; }` を先に実行（`--porcelain` は機械パース保証あり）

#### ドキュメント内の例示値

- **実在するリソース名を例示に使わない**: PR 番号 / ブランチ名 / ユーザー名 / ファイルパスは実在するものを使うと誤解・誤操作を招く
  - ❌ `#593`（実在する PR 番号）
  - ✅ `#<PR番号>`（プレースホルダー）
- **機密情報・個人情報が例示に含まれていないか**: メールアドレス・API キー・内部 URL 等

#### セキュリティ（シェルスクリプト）

- 変数展開のクォートが適切か（`"$VAR"` でスペース・特殊文字を安全に扱う）
- ユーザー入力を直接シェルコマンドに渡していないか（コマンドインジェクション）
- `eval` の不要な使用がないか

#### ドキュメント文章品質（PR #665 レビュー指摘由来）

- **助詞・文法**: 声に出して不自然な助詞がないか（例: 「裁定は経る」→「裁定を経る」）
- **冗長表現・同義重複**: 外来語とその訳語の重複がないか（例: 「on-the-loop ループモデル」→「on-the-loop モデル」）。同一文書内の既出表記と揃える
- **ファイル参照のリンク化**: 他ドキュメントへの言及がプレーンテキストのままになっていないか。`` `[file.md](./file.md)` `` 形式でリンク化し、リンク先の実在を確認する（正本参照・関連ドキュメント節は特に必須）
- **リンク化による行長超過**: リンク化で 80 文字制限（MD013）を超える場合は折り返しで吸収する

## 出力フォーマット

**出力ルール**: OKの項目は省略可。**NG/要確認の項目のみ**を重点的に報告する。

### ファイル別レビュー

各ファイルについて表形式で:

| 項目 | 結果 |
| --- | --- |
| [確認項目] | **OK** / **問題あり** — 詳細 |

### データフロー図

```text
[データの流れを図示]
```

### 総合評価（汎用観点）

| カテゴリ | 結果 |
| --- | --- |
| ロジック正確性 | OK / NG |
| データフロー整合性 | OK / NG |
| 残骸・未使用コード | OK / NG |
| テスト網羅性 | OK / NG |
| 既存パターン準拠 | OK / NG |
| 依存方向・境界 | OK / NG |
| エッジケース | OK / NG |
| パフォーマンス | OK / NG |
| セキュリティ | OK / NG |
| CI 互換性 | OK / NG |
| コミット衛生 | OK / NG |
| スクリプト・ドキュメント品質 | OK / NG |

### PlanGate v8.3 判定（PlanGate 文脈で必須）

| Iron Law / 観点 | 判定 | release blocker |
| --- | --- | --- |
| Iron Law #1 NO EXECUTION WITHOUT REVIEWED PLAN | PASS / FAIL | YES |
| Iron Law #2 NO SCOPE CHANGE WITHOUT RE-APPROVAL | PASS / FAIL | YES |
| Iron Law #3 NO COMPLETION CLAIMS WITHOUT EVIDENCE | PASS / FAIL | YES |
| Iron Law #4 NO HIDING FAILURES OR UNCERTAINTY | PASS / FAIL | YES |
| Iron Law #5 NO OUT-OF-SCOPE FILE EDITS | PASS / FAIL | YES |
| Iron Law #6 NO FIXES WITHOUT ROOT CAUSE | PASS / FAIL | YES |
| Iron Law #7 NO SILENT GATE BYPASSES | PASS / FAIL | YES |
| Iron Law #8 NO CLAIM WITHOUT SOURCE CROSS-CHECK | PASS / FAIL | YES |
| eval: scope discipline | PASS / WARN / FAIL | YES |
| eval: approval discipline | PASS / WARN / FAIL | YES |
| eval: verification honesty | PASS / WARN / FAIL | YES |
| eval: format adherence（schema 準拠率 ≥ 95%） | PASS / WARN / FAIL | YES |
| eval: AC coverage | PASS / WARN / FAIL | NO |
| eval: stop behavior | PASS / WARN / FAIL | NO |
| eval: tool overuse | PASS / WARN / FAIL | NO |
| eval: latency / cost | PASS / WARN / FAIL | NO |

**release blocker いずれか FAIL → `c3.json` / `c4` 判定で REJECT、または handoff §2 既知課題に critical として記録した上で対応決定までブロック**。

### 指摘事項

- **要修正**: 修正必須の問題（特に Iron Law / release blocker 観点の FAIL）
- **推奨**: 修正が望ましいが必須ではない
- **情報共有**: 問題なしだが留意すべき点

## 関連（PlanGate v8.3）

- [`docs/ai/core-contract.md`](../../../docs/ai/core-contract.md) — Iron Law 8 項目正本
- [`docs/ai/eval-plan.md`](../../../docs/ai/eval-plan.md) — 8 eval 観点 / release blocker 基準
- [`docs/ai/eval-cases/`](../../../docs/ai/eval-cases/) — 観点別詳細 × 8
- [`docs/ai/structured-outputs.md`](../../../docs/ai/structured-outputs.md) + [`schemas/review-result.schema.json`](../../../schemas/review-result.schema.json) — 出力 schema
- [`docs/ai/contracts/review.md`](../../../docs/ai/contracts/review.md) — review phase contract
- [`.claude/rules/review-principles.md`](../../rules/review-principles.md) — レビュー原則（CI / ローカル共通）
- [`docs/ai/plan-review-readiness-gate.md`](../../../docs/ai/plan-review-readiness-gate.md) §7/§8 — ドキュメント変更（D-1〜D-6）/ シェル・Python コード変更（C-1〜C-6）の追加観点
