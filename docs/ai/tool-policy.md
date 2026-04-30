# Tool Policy — phase 別 allowed tools + Model Profile 射影

> **Status**: v1（PBI-116-06 で初版確立、Phase 2 / PBI-116）
> 関連: [`responsibility-boundary.md`](./responsibility-boundary.md) / [`hook-enforcement.md`](./hook-enforcement.md) / [`model-profiles.md`](./model-profiles.md)
> Interface preflight: [`docs/working/PBI-116/interface-preflight.md`](../working/PBI-116/interface-preflight.md)

## 1. 目的

PlanGate の各 phase で **使用可能な tool セットを制限** する。これにより:

- plan phase で誤って production code を編集することを防止
- approve-wait phase で write tool を全禁止（C-3 ゲート遵守の二重防御）
- exec phase で必要な tool を許可
- review / handoff phase は read 中心

Model Profile（[`model-profiles.md`](./model-profiles.md)）の `tool_policy` 値を本ファイルの phase 射影で具体化する。

## 2. Phase 別 allowed tools（標準）

`tool_policy: allowed_tools_by_phase`（gpt-5_5 / legacy_or_unknown のデフォルト）の場合の射影:

| Phase | allowed tools | 禁止 tools |
|-------|--------------|----------|
| **classify** | read / search / web-search | edit / test / build / shell write |
| **plan** | read / search / web-search / read-only shell | edit / test / build / write tools |
| **approve-wait** | read / search のみ | **すべての write tool** |
| **exec** | read / edit / write / test / build / shell（scope 内）| scope 外 file 編集 / 承認改竄 |
| **review** | read / test / diff / search | edit / write / build |
| **handoff** | read / write（docs のみ）/ search | code edit / test / build |

## 3. tool_policy 値ごとの射影

Model Profile の `tool_policy` 値（[`model-profiles.md`](./model-profiles.md) § 7）に応じて allowed tools を変える:

### `narrow`（gpt-5_mini）

軽量モデル向け。広範な tool 探索を抑制:

| Phase | allowed tools |
|-------|--------------|
| classify | read のみ |
| plan | read / search のみ |
| approve-wait | read のみ |
| exec | read / edit（scope 内）/ test |
| review | read / diff |
| handoff | read / write（docs のみ）|

### `allowed_tools_by_phase`（gpt-5_5 / legacy_or_unknown）

§ 2 の標準セット。

### `expanded`（gpt-5_5_pro）

強力推論モデル向け。広範な探索を許容:

| Phase | allowed tools |
|-------|--------------|
| classify | read / search / web-search / シェル探索 |
| plan | read / search / web-search / read-only shell / 並列タスク発注 |
| approve-wait | read / search のみ（write 禁止は変わらず）|
| exec | 標準セット + 並列タスク / シェル拡張 |
| review | 標準セット + 並列レビュー |
| handoff | 標準セット |

## 4. validation_bias による補正

Model Profile の `validation_bias` 値（[`model-profiles.md`](./model-profiles.md) § 8）が `strict` の場合、本ファイルの allowed tools に加えて [`hook-enforcement.md`](./hook-enforcement.md) の追加 Hook 条件が適用される。

- `lenient`: 上記射影のまま
- `normal`: 上記射影のまま
- `strict`: 上記射影 + [`hook-enforcement.md`](./hook-enforcement.md) の追加条件で更に制限

## 5. 違反時の挙動（境界定義のみ、実装は別 PBI）

- Tool Policy 違反は **Hook で runtime block**（[`hook-enforcement.md`](./hook-enforcement.md) の不変条件として実装、別 PBI）
- ソフト警告（プロンプト内記述）と組み合わせて二重防御

## 6. 既存ガードレール（Plugin 配布版）との関係

`plugin/plangate/rules/` には v8.1 配布形態固有のガードレール（`completion-gate.md` / `design-gate.md` / `evidence-ledger.md` / `review-gate.md` / `subagent-roles.md` / `worktree-policy.md`）がある。本ファイルはこれらと **共存**:

- 本ファイル: ai/* レベルで一般化された tool policy
- Plugin 限定 rules: 配布形態固有の追加ガードレール
- 矛盾時は **Plugin 限定が優先**（配布形態の追加制約として）

## 関連

- 親計画: [`docs/working/PBI-116/parent-plan.md`](../working/PBI-116/parent-plan.md)
- 責務境界: [`responsibility-boundary.md`](./responsibility-boundary.md)
- Hook enforcement: [`hook-enforcement.md`](./hook-enforcement.md)
- Model Profile: [`model-profiles.md`](./model-profiles.md)
- Phase 1 成果: [`core-contract.md`](./core-contract.md)
