# 品質コマンド実行証跡の必須化（仕様）

> Issue: [#683](https://github.com/s977043/plangate/issues/683)
> 位置づけ: PR / handoff ゲート（L-0 / V-1 相当）に、プロジェクト定義の品質
> コマンド群の**実行証跡**を必須化する仕様。実装（HO パスへの反映）は
> [`scripts/apply-quality-command-gate.sh`](../../scripts/apply-quality-command-gate.sh)
> で Human 適用する。

## 1. 背景と問題構造

notionnext-blog の直近マージ済み PR 20 件の監査で、**既存の検証スクリプトで
機械的に防げたはずの指摘が反復**していた。

| 指摘パターン | 出現 | 既存ガード |
|---|---|---|
| コードブロック言語指定なし | 3 PR / 13 件 | `pnpm test:markdown`（存在するが PR 前に未実行） |
| README / status / queue の随伴ファイル更新漏れ | 4 PR | CI の readme-sync-check で事後検知のみ |
| frontmatter 規約違反 | 2 PR | `validate_frontmatter.py`（同上） |

**構造原因は「ガードの不在」ではなく「ガードの実行がゲート条件になっていない」
こと**である。ワークフロードキュメントに必須ステップとして明記する対処は、
エージェントが読み飛ばせば効かない（ドキュメント指示はソフト強制であり、
[`hybrid-architecture.md`](../../.claude/rules/hybrid-architecture.md) の
CLAUDE.md / Skill / Hook 境界ルールに従えば「絶対に通さない」制御は Hook /
機械ゲート側に置くべき）。本仕様は「実行の有無」を機械的に判定可能な
ゲート条件へ格上げする。

## 2. プロジェクト定義の品質コマンド宣言

### 2.1 宣言場所

プロジェクトごとの品質コマンド群は `pbi-input.md` の
Estimation Evidence 節、または専用設定ファイル
`docs/working/quality-commands.yaml`（存在すればリポジトリ全体の既定値、
`pbi-input.md` 側の宣言があれば PBI 単位で上書き）のいずれかで宣言できる。

```yaml
# docs/working/quality-commands.yaml（例）
pre_pr_commands:
  - id: markdown-lint
    command: "pnpm test:markdown"
    required: true
  - id: frontmatter-validate
    command: "python3 scripts/validate_frontmatter.py"
    required: true
  - id: readme-sync-check
    command: "pnpm test:readme-sync"
    required: false   # WARN 止まり（block しない）
```

| フィールド | 必須 | 説明 |
|---|---|---|
| `id` | Yes | evidence-ledger の `EvidenceItem.id` と対応させる一意識別子 |
| `command` | Yes | 実行するコマンド文字列（シェル実行可能な形） |
| `required` | Yes | `true` = 未実行/FAIL でゲート block、`false` = WARN のみ |

宣言が存在しない場合、本ゲートは **no-op**（既存挙動を変えない。opt-in）。

### 2.2 判定は安全側

`quality-commands.yaml` の構文エラー・パース不能・`id` 重複は **block**
（安全側。silent skip しない）。

## 3. 実行証跡の必須化

### 3.1 記録先

各コマンドの実行結果は
[`evidence-ledger`](../../plugin/plangate/skills/evidence-ledger/SKILL.md)
の `EvidenceItem`（`type: "command"`, `phase: "verification"`）として
`docs/working/TASK-XXXX/evidence/verification/quality-commands-ledger.json`
に記録する。スキーマは evidence-ledger 正本の `EvidenceItem` /
`EvidenceLedger` をそのまま使う（追加スキーマを増やさない）。

```json
{
  "claim": "PR 前品質コマンド（quality-commands.yaml 宣言分）を実行した",
  "status": "passed",
  "evidence": [
    {
      "id": "markdown-lint",
      "type": "command",
      "phase": "verification",
      "command": "pnpm test:markdown",
      "exitCode": 0,
      "outputExcerpt": "0 problems",
      "conclusion": "markdown lint は全ファイルで違反なし",
      "createdAt": "2026-07-03T10:00:00+09:00"
    }
  ],
  "missingEvidence": []
}
```

### 3.2 ゲート判定ロジック

PR 作成フェーズ（および WF-05 handoff 完了判定）の前提条件として、
以下を機械チェックする。

| 状態 | 判定 |
|---|---|
| `quality-commands.yaml` 宣言なし | ゲート no-op（PASS 扱い） |
| 全 `required: true` コマンドの `EvidenceItem` が存在し `exitCode == 0` | PASS |
| `required: true` のいずれかが未実行（`EvidenceItem` 欠落） | **block**（`missingEvidence` に対象 `id` を列挙） |
| `required: true` のいずれかが `exitCode != 0` | **block** |
| `required: false` のいずれかが未実行 or `exitCode != 0` | WARN（handoff の既知課題として記録、block しない） |
| `EvidenceItem.createdAt` が対象コミットの直近実装以前（stale） | **block**（古い証跡の使い回しを防ぐ。判定不能な場合は安全側で block） |

「未実行・FAIL のまま PR 作成フェーズへ遷移しようとしたら block」という
issue #683 の要求は、上記の `missingEvidence` 判定と
`exitCode != 0` 判定の 2 条件で機械的に表現する。

### 3.3 block 時の解除経路

1. 欠落 / FAIL したコマンドを実行し `EvidenceItem` を追加・更新する
2. 再度ゲート判定を実行し PASS を確認する
3. `required: false` の WARN は `handoff.md` の既知課題一覧（6 要素の 1 つ）
   に記録すれば PR 作成へ進める（block しない設計）

## 4. 既存 evidence-ledger / review-feedback-loop（#667）との統合

### 4.1 evidence-ledger との関係

本仕様は evidence-ledger の**利用者**であり、新しい証跡フォーマットを
発明しない。`quality-commands.yaml` の `id` を `EvidenceItem.id` に
1:1 で対応させることで、既存の `EvidenceLedger.missingEvidence` 判定
ロジック（[`evidence-ledger/SKILL.md`](../../plugin/plangate/skills/evidence-ledger/SKILL.md)
§ステップ 3）をそのまま流用できる。TDD 証跡（`tdd_red` / `tdd_green` /
`refactor_verify`）とは phase が異なる別トラック（`phase: "verification"`）
として扱い、混同しない。

### 4.2 review-feedback-loop（#667）との関係

[`review-feedback-loop.md`](../workflows/ai-loop/review-feedback-loop.md)
の 6 ステップフロー（収集→分類→還元先判定→反映→事前適用→効果測定）と
本仕様は補完関係にある。

- review-feedback-loop は「**過去の指摘**をどう事前チェックへ還元するか」
  を扱う学習ループ（PoC 段階、ai-loop-workflow 限定）
- 本仕様は「**宣言済みの品質コマンドの実行**をどう機械ゲート化するか」
  を扱う実行保証（PlanGate 本流 WF-00〜WF-05 に接続）

還元先判定（review-feedback-loop §2-3）で「skill / gate 観点ドキュメントで
捕捉できる指摘」に分類された項目のうち、**機械コマンドとして表現できる
もの**（lint / validate 系）は `quality-commands.yaml` への追加を優先候補
とする。これにより review-feedback-loop の「反映」ステップが本ゲートの
宣言更新という具体的な着地点を持つ。

### 4.3 plan-review-readiness-gate.md との接続

[`plan-review-readiness-gate.md`](./plan-review-readiness-gate.md) は
C-1 前の「計画がレビュー可能か」を判定するゲートであり、本仕様は
その後段（PR 作成前 / handoff 完了前）に位置する。両者は判定時点が
異なり重複しない。

```text
plan-review-readiness-gate (C-1 前)
  -> C-1 -> C-2 -> C-3 -> D[exec] -> L-0
  -> quality-command-evidence gate (PR 作成前 / handoff 完了前) ← 本仕様
  -> V-1 -> ... -> PR 作成 -> C-4
```

## 5. Hardening Override との関係（責務分界）

本ゲートの**仕様**（本ドキュメント）は非 HO パス（`docs/ai/`）に置く。
ただし、本ゲートを **working-context.md の handoff / V-1 DoD へ組み込む**
反映は HO パス（`.claude/rules/*.md`）の変更にあたるため、
[`responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
の 4 分類に従い以下のように分割する。

| 操作 | 担当 |
|---|---|
| 本仕様ドキュメントの作成・更新 | AI-owned |
| `quality-commands.yaml` 宣言の作成・編集（プロジェクト設定） | AI-owned |
| evidence-ledger への `EvidenceItem` 記録 | AI-owned（コマンド実行と記録自体） |
| working-context.md への DoD 追記（dry-run 提示） | AI-owned（`scripts/apply-quality-command-gate.sh` の作成・dry-run 実行まで） |
| working-context.md への DoD 追記の**実適用**（`--apply`） | **Human-owned**（HO パス実適用は AI 不可侵） |

適用スクリプトは [`apply-mode-classification-doc-light.sh`](../../scripts/apply-mode-classification-doc-light.sh)
と同型のパターン（dry-run 既定 / `--apply` で書き込み / アンカー消失時 fail
/ 既適用なら no-op）に従う。

## 6. 除外条件（安全側フォールバック）

以下のいずれかに該当する場合、本ゲートは block せず WARN に留める
（誤 block による作業停止を避ける安全弁）。

- `quality-commands.yaml` 自体が存在しない、または `pre_pr_commands` が
  空配列（プロジェクトが品質コマンドを未宣言 = 対象外）
- ultra-light mode かつ変更ファイル数 1（[`mode-classification.md`](../../.claude/rules/mode-classification.md)
  の最小規模。ただし `required: true` コマンドの宣言がある場合はこの除外を
  適用しない = 明示宣言が規模判定より優先）

## 7. 関連

- [`plugin/plangate/skills/evidence-ledger/SKILL.md`](../../plugin/plangate/skills/evidence-ledger/SKILL.md) — EvidenceLedger スキーマ正本
- [`docs/ai/plan-review-readiness-gate.md`](./plan-review-readiness-gate.md) — C-1 前ゲート（本仕様の前段）
- [`docs/workflows/ai-loop/review-feedback-loop.md`](../workflows/ai-loop/review-feedback-loop.md) — レビュー指摘還元ループ（#667）
- [`.claude/rules/working-context.md`](../../.claude/rules/working-context.md) — V-1 / handoff DoD（本仕様の反映先、Human 適用）
- [`.claude/rules/responsibility-classes.md`](../../.claude/rules/responsibility-classes.md) — AI/Human/CI/Workflow 4 分類
- [`scripts/apply-quality-command-gate.sh`](../../scripts/apply-quality-command-gate.sh) — HO 適用スクリプト（dry-run 既定）
