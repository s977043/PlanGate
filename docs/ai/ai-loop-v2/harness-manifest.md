# HarnessManifest — Harness N / N+1 の同一性と Runtime Activation

> **Status**: Phase 0.1 canon（#1275）
> **North Star**: [`north-star.md`](./north-star.md) §10 / §14 / §15
> **Role**: 「その Run で実際に評価対象となった Harness」を再現可能な identity として固定し、RunEvidence / HarnessExperimentResult から参照できるようにする。V2 artifact budget の **9 件目**。

## 1. 問題

`harness_version` 文字列（Legacy RunEvidence schema の必須項目、#874 / #1025 / #894）は「どの版か」を名乗るだけで、次を再現できない。

- どの Skill / Agent / Flow / Verifier / Prompt が **どの内容（content sha）** で存在したか
- それが **install / register / select / fire** のどの段階まで到達したか
- Routing / Policy profile / Verifier set / Model profile が何だったか
- 実行 platform（claude-code / codex）と plugin version

したがって Harness N と N+1 の paired comparison（North Star §14）は、`harness_version` が異なることは言えても **何が違ったか**を言えない。Candidate が「効いた」という主張も、ファイルが存在した／plugin にコピーされた事実からは導けない。

## 2. HarnessManifest 契約

```yaml
schema_version: "1"
harness_id: sha256:<manifest canonical form の digest> # content-addressed。同じ内容なら同じ id
source_commit: <git sha> # Harness を構成した正本の commit
distribution_digest: sha256:<plugin 配布物の digest> # 配布経路が別なら別 digest
components:
  - type: skill | agent | flow | verifier | prompt | context | routing | eval | hook
    id: <安定 ID。例 skill:ai-dev-plan>
    content_sha: sha256:<ファイル集合の digest>
    installed: true | false # 実行環境のファイルシステムに存在する
    registered: true | false # ランタイムのレジストリ（hooks/list・skill 一覧等）に登録されている
routing_policy_sha: sha256:...
policy_profile_sha: sha256:... # C-3' 等 autonomy profile を含む Policy の digest
verifier_set_sha: sha256:... # Verifier pipeline の定義の digest
model_profiles: # role → model / effort。重みではなく選択の記録
  planner: { model: ..., effort: ... }
  builder: { model: ..., effort: ... }
  verifier: { model: ..., effort: ... }
runtime:
  platform: claude-code | codex
  plugin_version: <semver>
  captured_at: <ISO-8601>
```

原則:

- **Immutable**: 一度生成した Manifest は変更しない。変更は新しい `harness_id` になる。
- **Content-addressed**: `harness_id` は canonical 化した Manifest 本体の digest。名前や version 文字列ではない。
- **Run 開始時に固定**: RunState は開始時に `harness_manifest_ref: <harness_id>` を持ち、Active Run 中に変えない（North Star §10）。
- **`installed` と `registered` は Manifest が持つ**。`selected` 以降は Run 側の Evidence が持つ（§4）。
- `harness_version` は **人間向けラベル**として残してよいが、同一性の根拠にしない。

## 3. RunEvidence / HarnessExperimentResult からの束縛

```yaml
# RunEvidence（抜粋）
harness_manifest_ref: sha256:... # 必須。無ければ evidence_status は ready にならない
harness_version: "..." # 任意のラベル

# HarnessExperimentResult（抜粋）
baseline_manifest_ref: sha256:...
candidate_manifest_ref: sha256:...
```

- baseline と candidate の **両方**の `harness_manifest_ref` が取れない実験は `INCONCLUSIVE`（[`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) §5）。
- 同一 `harness_manifest_ref` を持つ Run 同士だけを同一 Harness の集計に含める。

## 4. Runtime Activation の 6 段階

「ファイルが存在する」「plugin にコピーされた」だけでは Component が効いたと主張できない。activation を次の 6 段階に分け、**どの段階まで Evidence があるか**を Run ごとに記録する。

| 段階                  | 意味                                                                         | Evidence の所在                                                     |
| --------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `installed`           | ファイルとして実行環境に存在する                                             | HarnessManifest                                                     |
| `registered`          | ランタイムのレジストリに登録されている（hooks/list・skill 一覧・agent 一覧） | HarnessManifest                                                     |
| `selected`            | その Run でルーティング／呼び出し対象に選ばれた                              | RunEvent（`component_selected`）                                    |
| `fired`               | 実際に実行された（hook 発火・skill 展開・agent 起動）                        | RunEvent（`component_fired`。hook-events.log 等の一次ログへの ref） |
| `produced_evidence`   | 実行結果が VerificationResult / FailureRecord / artifact として残った        | RunEvent + evidence refs                                            |
| `influenced_decision` | その evidence を Decision Engine が実際に参照して判断した                    | Decision record の `inputs`                                         |

原則:

- 上位段階は下位段階を含意しない方向には使えない（`fired` は `selected` を含意するが、`registered` は `fired` を含意しない）。
- HarnessExperiment の Activation Check（North Star §14）は **`fired` 以上**を要求する。`installed` / `registered` のみの Candidate 評価は `INCONCLUSIVE`。
- 「設定の存在は効いている証拠でない」（hooks.json の注記キー 2 つで全体 parse 拒否・登録 0 件を達成済みと書き続けた実害）を構造的に防ぐ。

## 5. 独立 Artifact にする理由（artifact budget review）

[`phase0-migration.md`](./phase0-migration.md) §6 の budget 8 件に対し、HarnessManifest を 9 件目として追加する。既存 artifact への additive 表現を検討した結果を残す。

| 候補                                                             | 却下理由                                                                                                                                                                                           |
| ---------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RunEvidence に埋め込む                                           | Manifest は **Run 横断**で共有される identity。Run ごとに複製すると同じ Harness が Run 数だけ存在し、drift を検出できない。RunEvidence は 1 Run の projection であり、Harness 定義の正本にならない |
| RunState に埋め込む                                              | RunState は mutable（revision で進む）。Manifest は immutable。寿命と可変性が異なる                                                                                                                |
| LoopContract に埋め込む                                          | LoopContract は Task / Plan 由来。Harness は Task に依存しない                                                                                                                                     |
| HarnessImprovementCandidate / HarnessExperimentResult に埋め込む | baseline 側の identity を Candidate が持つと、Candidate が baseline の記述を書き換えられる（Trust Boundary 違反）                                                                                  |

独立 artifact にすると、RunEvidence / RunState / ExperimentResult からは `*_manifest_ref`（digest 1 本）で束縛でき、既存 artifact への変更は additive な参照フィールド 1 つに留まる。

**判断**: 独立 artifact として採用。budget を 9 件へ更新（`phase0-migration.md` §6）。

## 6. Phase 0.1 で決めないこと

- Manifest の生成コマンド・保存場所（`docs/working/_harness/` 等）・canonical 化の具体アルゴリズム
- `components[].id` の命名規約の正本
- Legacy `harness_version` 生成コードの変更（Legacy は freeze。V2 実装で並走させる）
