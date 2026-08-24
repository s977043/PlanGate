# required status checks の是正提案 + workflow 衛生（2026-08-24）

> 実測 ref: `origin/main` = `8a5cd5601a0ff3efec7807eb9965b6081e9aec7e`
> 実行主体: worktree ワーカー（`gh` active account = `s977043`）
> 本書は **提案**。ruleset / branch protection の変更 API は **Human-owned**
> （[`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) 権限操作）。
> AI は payload と検証コマンドを提示するのみで、**一切実行していない**。

## 0. 結論サマリ

| # | 項目 | 結論 |
|---|------|------|
| 1 | required checks が守っているもの | **`Markdown lint` 1 本だけ**。テストが 1 件も required でない |
| 2 | 追加すべき check | 既存 workflow から `plangate CLI tests` / `settings wiring drift` / `SKIP_REASON 追認` / `Analyze (python)` の **4 本**、本 PR が追加する `shellcheck (shell static analysis)` / `actionlint (workflow static analysis)` の **2 本** = 計 **6 本追加**（required は合計 7 本） |
| 2b | **順序依存（必読）** | 新 2 本は **`ci.yml` への適用（`apply-ci-lint-wiring.sh --apply`）が main に入るまで required にしてはならない**。未適用の context を required にすると check run が生成されず **永久 pending**（§3.2 の paths-filter 罠と同じ失敗形）。§4 は 2 段階に分けている |
| 3 | 追加しない check | `check` / `privacy` / `validate` / `drift-check` / `Scorecard analysis` / `CodeQL`（理由は §3） |
| 4 | `strict`（up-to-date 必須） | **既に `true`**（変更不要）。追加はするが strict の値は触らない |
| 5 | 残る穴（本提案の対象外） | `required_approving_review_count: 0` / `bypass_actors` に admin ロールが `always` |

## 1. 現状（実測）

```sh
gh api repos/s977043/plangate/rulesets --jq '.[]|{id,name,target,enforcement}'
# => {"enforcement":"active","id":14939019,"name":"Protect default branch","target":"branch"}

gh api repos/s977043/plangate/branches/main/protection
# => 404 Branch not protected   ← classic branch protection は不使用。ruleset のみが正
```

`gh api repos/s977043/plangate/rulesets/14939019` の要点:

| 項目 | 実測値 |
|------|-------|
| `conditions.ref_name.include` | `["~DEFAULT_BRANCH"]` |
| rules | `deletion` / `non_fast_forward` / `pull_request` / `required_status_checks` |
| `pull_request.required_approving_review_count` | **0** |
| `pull_request.required_review_thread_resolution` | `true` |
| `required_status_checks.strict_required_status_checks_policy` | **`true`（既に有効）** |
| `required_status_checks.required_status_checks` | **`[{"context":"Markdown lint","integration_id":15368}]`** |
| `bypass_actors` | `[{"actor_id":5,"actor_type":"RepositoryRole","bypass_mode":"always"}]` |

**実害**: `Markdown lint`（実測 p50 7s / max 10s）さえ緑なら、`tests/run-tests.sh` が
全滅していても、settings wiring が drift していても、EH-3 SKIP が未追認でも
main へマージできる。テストは 1 本も required になっていない。

## 2. check 表示名の実測（推測していない）

required checks の `context` は **GitHub の checks 上の表示名**（= job の `name:`、
無ければ job id）と一致していなければならない。実体を 2 経路で確認した。

```sh
gh pr checks 1201 --repo s977043/plangate
gh api "repos/s977043/plangate/commits/583c23fe/check-runs?per_page=100" \
  --jq '.check_runs[]|"\(.app.id)\t\(.app.slug)\t\(.name)"' | sort -u
```

実測結果（PR #1201 head `583c23fe`）:

| 表示名（= context 候補） | app.id | app.slug |
|---|---|---|
| `Markdown lint` | 15368 | github-actions |
| `settings wiring drift` | 15368 | github-actions |
| `SKIP_REASON 追認` | 15368 | github-actions |
| `plangate CLI tests` | 15368 | github-actions |
| `Analyze (python)` | 15368 | github-actions |
| `check` | 15368 | github-actions |
| `CodeQL` | 57789 | github-advanced-security |

### 2.1 本 PR が追加する 2 job の表示名（**まだ実測できない**）

`shell-lint` / `workflow-lint` は `scripts/apply-ci-lint-wiring.sh` が `ci.yml` へ
追加する job であり、**適用前なので check-runs 実測は存在しない**。表示名は
同スクリプトの `JOBS` 文字列（`name:` 行）から確定した値であり、推測ではないが
**実測でもない**:

| 表示名（= context 候補） | job id | 由来 | 実測 |
|---|---|---|---|
| `shellcheck (shell static analysis)` | `shell-lint` | `apply-ci-lint-wiring.sh` の `JOBS` `name:` | **未（未適用）** |
| `actionlint (workflow static analysis)` | `workflow-lint` | 同上 | **未（未適用）** |

`app.id` は `ci.yml` 内の job なので他の GitHub Actions check と同じ **15368**
（`github-actions`）になる。**適用後の最初の PR で `gh pr checks` により
表示名を 1 回実測してから** required に入れること（§4 Step 0）。

`Analyze (python)` は `codeql.yml` の `jobs.analyze.name`。`check` は
`check-pr-issue-link.yml` の job id（`name:` を持たないため id がそのまま表示名）。
`CodeQL`(2s) は Advanced Security 側の集約チェックで、Actions 側の
`Analyze (python)` とは **別 app・別 check**。

## 3. required にしてよいかの判定（各 check の実測根拠）

安定性・所要時間は **直近 25 run の job 単位実測**（`gh api .../actions/runs/<id>/jobs`
の `started_at` / `completed_at` 差分）。

| 表示名 | workflow / job | 全 PR で発生するか | paths filter | ok/fail | p50 / max | 判定 |
|---|---|---|---|---|---|---|
| `Markdown lint` | ci.yml / markdown | ○ | なし | 25 / 0 | 7s / 10s | **維持**（既 required） |
| `plangate CLI tests` | test.yml / plangate-cli | ○ | なし | 17 / 3 | 290s / 309s | **追加** |
| `settings wiring drift` | ci.yml / settings-drift | ○ | なし | 25 / 0 | 6s / 8s | **追加** |
| `SKIP_REASON 追認` | ci.yml / skip-ack | ○ | なし | 25 / 0 | 6s / 10s | **追加** |
| `Analyze (python)` | codeql.yml / analyze | ○ | なし | 25 / 0 | 73s / 87s | **追加** |
| `shellcheck (shell static analysis)` | ci.yml / shell-lint（**本 PR で追加**） | ○ | なし | — （未適用） | — | **追加**（ci.yml 適用後） |
| `actionlint (workflow static analysis)` | ci.yml / workflow-lint（**本 PR で追加**） | ○ | なし | — （未適用） | — | **追加**（ci.yml 適用後） |
| `CodeQL` | (Advanced Security 集約) | ○ | — | — | 2s | 追加しない |
| `check` | check-pr-issue-link.yml / check | ○ | なし | 25 / 0 | 8s / 12s | **追加しない** |
| `privacy` | metrics-privacy.yml / privacy | **×** | **あり** | 25 / 0 | 6s / 9s | **追加しない** |
| `validate` | schema-validate.yml / validate | **×** | **あり** | 24 / 1 | 10s / 16s | **追加しない** |
| `drift-check` | sync-plugin-plangate.yml / drift-check | **×** | **あり** | 14 / 2 | 6s / 16s | **追加しない** |
| `Scorecard analysis` | scorecard.yml / scorecard | **×**（PR トリガ無し） | — | 18 / 0 | 40s / 48s | **追加しない** |
| `sync` / `provenance` | release-docs-sync / slsa-attestation | **×**（release 起動のみ） | — | — | — | **追加しない** |

### 3.1 追加する 4 本の根拠

- **`plangate CLI tests`** — 本提案の主目的。`ci.yml`/`test.yml` は
  `on: pull_request`（paths / branches フィルタ無し）なので **全 PR で必ず発生**する。
  直近 25 run のうち failure 3 件はすべて同一ブランチ `fix/954-classc-remaining` の
  実バグで、後続コミットで green 化している（flaky ではなく **検出力が働いた事例**）。
  実測 p50 290s / max 309s と最長だが、これを required にしない限り
  「テスト全滅でもマージできる」構造は解けない。現行 `timeout-minutes: 10`
  （600s）に対し max 309s なので余裕は約 2 倍。
- **`settings wiring drift` / `SKIP_REASON 追認`** — 同 `ci.yml` 内。25/25 success、
  max 8s / 10s。承認境界（EH-3 SKIP 追認・settings 契約）を守る check であり、
  `Markdown lint` だけが required という現状の非対称が最も不自然な 2 本。
- **`shellcheck (shell static analysis)` / `actionlint (workflow static analysis)`** —
  `apply-ci-lint-wiring.sh` は両 job を **`ci.yml` に**追加する。`ci.yml` は
  `on: pull_request`（paths / branches フィルタ無し）＝ **全 PR で必ず発生**するので
  §3.1 の採用基準（paths-filter を持たない / 全 PR で発生）を満たす。
  required にしないと「新しい gate が赤くなるが merge は止まらない」状態になり、
  静的解析を入れた意味が消える。
  **ただし順序依存がある**: `ci.yml` への適用が main に入るまでは check run が
  生成されないため、先に required 化すると永久 pending になる（§4 Step 0）。
  所要時間は未実測（適用後の最初の run で測る）。`ci.yml` の既存 job と同じ
  `timeout-minutes: 10` を持ち、ローカル実測では shellcheck 179 ファイルが数秒、
  actionlint 10 workflow が数十秒。
- **`Analyze (python)`** — `codeql.yml` は
  `on.pull_request.branches: [main]`。ruleset は `~DEFAULT_BRANCH` すなわち
  **main 向け PR にしか適用されない**ので、「required なのに発生しない」は起きない。
  docs のみの PR #1193（`03616ba3`）でも実際に発生していることを check-runs で確認済み。
  25/25 success、max 87s。

### 3.2 追加しない理由

- **`privacy` / `validate` / `drift-check`（paths-filter 罠）** — 3 本とも
  `on.pull_request.paths:` を持つ。該当 path を触らない PR では
  **check run 自体が生成されない**ため、required にすると `Expected — Waiting for
  status to be reported` の **永久 pending** になりマージ不能になる。
  実測（陰性/陽性コントロール）:
  - 陰性: PR #1193（docs のみ / `03616ba3`）の check-runs に `privacy` `validate`
    `drift-check` は **1 件も無い**。PR #1201（workflow yml のみ / `583c23fe`）にも無い。
  - 陽性: `gh run list --workflow=metrics-privacy.yml` は
    `pull_request` / branch `fix/1180-m1-tc-c6-fixture` の run を返す（json 変更 PR）。
    `schema-validate.yml` も `fix/1169-...` `docs/1078-...` 等で PR run が存在する。
    → 「0 件」はコマンドが空振りしたのではなく **paths 条件で発生していない**。
  したがって **現状のまま required にしてはならない**。恒久解は §6 の Phase 2。
- **`check`（check-pr-issue-link）** — 2 つの理由で追加しない。
  1. `scripts/check-pr-issue-link.sh` は仕様上 **常に exit 0**（`WARN` は stdout の
     文字列でしか表現しない。同スクリプト冒頭 `Exit code: 常に 0`）。job が落ちる
     のは gh API 失敗時だけなので、required にしても **強制力がほぼゼロ**。
  2. fork からの PR では `GITHUB_TOKEN` が read-only になり、`WARN` 時の
     `gh pr comment`（`pull-requests: write` 必要）が失敗して job ごと落ちる。
     required にすると **外部コントリビュータの PR を機械的にブロック**する。
  「issue link を強制したい」なら、まずスクリプトの exit code 設計と
  fork 時の挙動を直すのが先で、required 化はその後。
- **`CodeQL`（app 57789）** — `Analyze (python)` と同じ解析の集約表示。
  両方 required にしても検出力は増えず、`integration_id` が別（57789）で
  設定ミスの温床になるため 1 本（`Analyze (python)`）に絞る。
- **`Scorecard analysis`** — `scorecard.yml` は `push`(main) / `schedule` /
  `workflow_dispatch` のみで **`pull_request` トリガを持たない**。required 化＝永久 pending。
- **`sync` / `provenance`** — `on: release` 起動。PR では発生しない。

### 3.3 `strict`（up-to-date 必須）の判断

**変更不要。既に `strict_required_status_checks_policy: true`。**
そのうえで required を 1 本 → 5 本に増やす影響を明記しておく:

- strict=true では base 更新のたびに PR を最新化して再実行が要る。最長 check が
  7s（`Markdown lint`）から **306s（`plangate CLI tests`）** に伸びるため、
  main への連続マージ時の待ち時間が実質 5 分単位になる。
- それでも **true を維持すべき**。本リポジトリは「テストが通っていない状態で
  main に入る」ことのコストが待ち時間より高く（NO MERGE BY AI / HO 系ガードの正本を
  抱えている）、かつ PR の同時進行数が少ない。false に落とすと
  「個別には green だが合流すると壊れる」を required で捕まえられなくなる。

## 4. 適用コマンド（Human-owned。AI は実行していない）

### Step 0: 順序依存（**先にこれを満たすこと**）

`shellcheck (shell static analysis)` / `actionlint (workflow static analysis)` は
**まだ `ci.yml` に存在しない**。この 2 本を required に入れる前に:

1. 本 PR を merge する（`scripts/lint-shell.sh` / `scripts/lint-workflows.sh` /
   `scripts/apply-ci-lint-wiring.sh` が main に入る）
2. Human が `ci.yml` へ適用する（HO パスなので apply スクリプト経由）:

   ```sh
   sh scripts/apply-ci-lint-wiring.sh --dry-run          # 差分を目視（AI が実行してよいのはここまで）
   PLANGATE_APPLY_CONFIRM=1 sh scripts/apply-ci-lint-wiring.sh --apply
   sh scripts/lint-workflows.sh                          # 編集後 ci.yml が actionlint を通ること
   ```

   `PLANGATE_APPLY_CONFIRM` は **実 HO パスへの書き込みだけ**に要求される確認
   （AI は設定しない）。
3. 適用 PR が main に入り、**次の PR で 2 本の check run が実際に生成され表示名が
   一致することを実測**する:

   ```sh
   gh pr checks <N> --repo s977043/plangate | grep -E 'shellcheck|actionlint'
   # 期待: 'shellcheck (shell static analysis)' / 'actionlint (workflow static analysis)' が pass
   ```

**Step 0 未了のまま §4 Step 2 の 7 本 payload を適用してはならない。**
未生成の context は `Expected — Waiting for status to be reported` のまま止まり、
main へのマージが機械的に不能になる（§3.2 の paths-filter 罠と同じ失敗形）。
Step 0 が終わっていない段階で required を先に増やしたい場合は、**既存 4 本のみ**
（`Markdown lint` を含め 5 本）を入れる payload に留めること。

ruleset の更新は `PUT /repos/{owner}/{repo}/rulesets/{ruleset_id}`。
**現在値を手で書き写すと `bypass_actors` や `pull_request` ルールを取りこぼす**ので、
ライブ状態から payload を生成する。

### Step 1: 現在値をバックアップ

```sh
gh api repos/s977043/plangate/rulesets/14939019 > /tmp/ruleset-14939019.before.json
```

### Step 2: payload を生成（required_status_checks だけを差し替える）

```sh
jq '
  {
    name: .name,
    target: .target,
    enforcement: .enforcement,
    conditions: .conditions,
    bypass_actors: .bypass_actors,
    rules: [
      .rules[]
      | if .type == "required_status_checks"
        then .parameters.required_status_checks = [
          { context: "Markdown lint",         integration_id: 15368 },
          { context: "plangate CLI tests",    integration_id: 15368 },
          { context: "settings wiring drift", integration_id: 15368 },
          { context: "SKIP_REASON 追認",       integration_id: 15368 },
          { context: "Analyze (python)",      integration_id: 15368 },
          # 以下 2 本は Step 0（ci.yml への適用 + 表示名の実測）完了後にのみ含める
          { context: "shellcheck (shell static analysis)",     integration_id: 15368 },
          { context: "actionlint (workflow static analysis)",  integration_id: 15368 }
        ]
        else . end
    ]
  }' /tmp/ruleset-14939019.before.json > /tmp/ruleset-14939019.payload.json

# 差分を目視（strict / pull_request / bypass_actors が保存されていることを確認）
diff <(jq -S . /tmp/ruleset-14939019.before.json) <(jq -S . /tmp/ruleset-14939019.payload.json)
```

### Step 3: 適用

```sh
gh api --method PUT repos/s977043/plangate/rulesets/14939019 \
  --input /tmp/ruleset-14939019.payload.json
```

### Step 4: 適用後の検証（期待値との一致を機械判定）

```sh
gh api repos/s977043/plangate/rulesets/14939019 \
  --jq '[.rules[] | select(.type=="required_status_checks")
         | .parameters.required_status_checks[].context] | sort'
# 期待 (sort 済み / Step 0 完了後の 7 本):
# ["Analyze (python)","Markdown lint","SKIP_REASON 追認","actionlint (workflow static analysis)","plangate CLI tests","settings wiring drift","shellcheck (shell static analysis)"]
#
# Step 0 未了で既存 4 本のみ入れた場合の期待 (5 本):
# ["Analyze (python)","Markdown lint","SKIP_REASON 追認","plangate CLI tests","settings wiring drift"]

# strict が維持されているか
gh api repos/s977043/plangate/rulesets/14939019 \
  --jq '.rules[] | select(.type=="required_status_checks")
        | .parameters.strict_required_status_checks_policy'
# 期待: true

# 他ルール（pull_request / deletion / non_fast_forward）が消えていないか
gh api repos/s977043/plangate/rulesets/14939019 --jq '[.rules[].type] | sort'
# 期待: ["deletion","non_fast_forward","pull_request","required_status_checks"]

# bypass_actors が消えていないか
gh api repos/s977043/plangate/rulesets/14939019 --jq '.bypass_actors'
```

### ロールバック

```sh
gh api --method PUT repos/s977043/plangate/rulesets/14939019 \
  --input /tmp/ruleset-14939019.before.json
```

### 適用直後にやること

適用後の最初の PR で `gh pr checks <N>` を確認し、required の全本（Step 0 完了後は 7 本 / 未了なら 5 本）が
`pass` になり **`Expected` のまま止まる check が無い**ことを 1 回だけ実測する。
`Expected` が残ったら §3.2 の paths-filter 罠に踏み込んでいるので即ロールバック。

## 5. workflow 衛生（P2）— `scripts/apply-workflow-hygiene.sh`

`.github/workflows/*.yml` は **Hardening Override パス**のため AI は直接編集しない。
[`docs/ai/ho-change-workflow.md`](../../ai/ho-change-workflow.md) の標準フローに従い、
apply スクリプト [`scripts/apply-workflow-hygiene.sh`](../../../scripts/apply-workflow-hygiene.sh)
（非 HO）を用意した。既定 `--dry-run` / 冪等 / 引数 strict 検証 / アンカー未検出は
**全体 exit 1（部分適用しない）**。`--apply` の実行は Human-owned。

### (A) `timeout-minutes` 欠落 6 job

値は勘ではなく **直近 25 run の job 実測 max** から決めた（下表）。

| workflow / job | 実測 p50 | 実測 max | 設定値 | 余裕 |
|---|---|---|---|---|
| check-pr-issue-link.yml / check | 8s | 12s | 5 | 25x |
| codeql.yml / analyze | 73s | 87s | 10 | 7x |
| metrics-privacy.yml / privacy | 6s | 9s | 5 | 33x |
| release-docs-sync.yml / sync | 7s | 11s | 10 | 54x（push + PR 作成の外部 I/O） |
| schema-validate.yml / validate | 10s | 16s | 10 | 37x（pip install 変動） |
| slsa-attestation.yml / provenance | 12s | 14s | 10 | 42x（OIDC 署名の外部 I/O） |

外部 I/O を伴う 3 本（sync / validate / provenance）は max が小さくても
ネットワーク待ちで跳ねうるので 5 ではなく 10 にした。既存 job（ci 5 / test 10 /
scorecard 15 / sync-plugin 10）とも粒度が揃う。

### (B) `concurrency` 欠落 7 workflow

`cancel-in-progress` は **event 別に安全側**で決めた（一律 true にしない）:

| workflow | cancel-in-progress | 理由 |
|---|---|---|
| check-pr-issue-link / codeql / metrics-privacy / schema-validate / sync-plugin-plangate | `${{ github.event_name == 'pull_request' }}` | PR の再 push は cancel してよい。main push / schedule では **走り出した run が途中で殺されない**（in-progress cancel をしない） |
| release-docs-sync / slsa-attestation | `false` | `on: release`。リリース処理を途中で殺すと asset / attestation が欠ける |

**`cancel-in-progress: false` の正確な意味論（誤読しやすい）**:
`cancel-in-progress` が制御するのは **in-progress run を cancel するか**だけ。
GitHub は同一 concurrency group に新しい run が queue されると、値に関わらず
**それ以前の pending run を cancel** する。つまり「同一 group の run はすべて
完走する」という保証にはならない。

本件で実際に同一 group に同居しうるのは **`codeql.yml` の push(main) と
schedule** である（schedule の `github.ref` は既定ブランチ＝`refs/heads/main`
なので `${{ github.workflow }}-${{ github.ref }}` が一致する）。ただし
**実害は無い**: 後勝ちした run が最新の main を解析するため、SARIF は最新状態に
なる（古い pending が消えても検出力は落ちない）。`release-docs-sync` /
`slsa-attestation` は `on: release` で `github.ref` が tag ref のため
リリースごとに group が別になり、同居しない。

### (C) `check-pr-issue-link.yml` の最小権限

top-level の `pull-requests: write` を job スコープへ移す
（top-level は `contents: read` のみ）。`codeql.yml` が既に採っている
「top-level は read、job で必要分だけ加算」の形に揃える。

### 実測した検証（サンドボックス）

```sh
sh scripts/apply-workflow-hygiene.sh --dry-run                      # exit 0（14 件 WILL CHANGE の unified diff）
sh scripts/apply-workflow-hygiene.sh --bogus                        # exit 1（unknown argument）
sh scripts/apply-workflow-hygiene.sh --dry-run extra                # exit 1（too many arguments）

SB=$(mktemp -d); mkdir -p "$SB/.github/workflows"; cp .github/workflows/*.yml "$SB/.github/workflows/"
actionlint -shellcheck= -pyflakes= "$SB"/.github/workflows/*.yml    # exit 0（適用前ベースライン）
PLANGATE_WF_DIR="$SB/.github/workflows" sh scripts/apply-workflow-hygiene.sh --apply   # exit 0
actionlint -shellcheck= -pyflakes= "$SB"/.github/workflows/*.yml    # exit 0（適用後）
PLANGATE_WF_DIR="$SB/.github/workflows" sh scripts/apply-workflow-hygiene.sh --apply   # exit 0 / already applied（冪等）
```

- 適用後 10 workflow すべてが `yaml.safe_load` で parse でき、**`timeout-minutes` を
  持たない job は 0 件**、全 workflow に `concurrency` あり。
- **actionlint の陽性コントロール**: 適用後ファイルの `timeout-minutes: 10` を
  `"abc"` に壊すと `actionlint` は
  `expecting a single ${{...}} expression or float number literal ... [syntax-check]`
  を出して **exit 1**。上の exit 0 は空振りではない。
- **アンカー未検出の負側**: 別 sandbox で `codeql.yml` の `  analyze:` を
  `  analyze-renamed:` に改名して `--apply` すると
  `error: anchor not found in codeql.yml: job 'analyze'` で **exit 1**、
  かつ他ファイル（metrics-privacy.yml / check-pr-issue-link.yml）の md5 は
  **不変**＝部分適用していない。
- 実 repo の `.github/` は無変更（`git status --porcelain .github/` が空）。

### 適用順序（衝突の扱い）

1. **PR #1201（dependabot）を先に merge**。`codeql.yml` / `scorecard.yml` の action SHA
   更新。本スクリプトは `codeql.yml` の header（`on` / `permissions` / `jobs` 直下）
   しか触らず `uses:` 行と行が重ならないため textual conflict は起きないが、
   HO 適用は 1 回で済ませたい。
2. **`scripts/apply-pr-issue-link-comment-removal.sh`（#1159 系。ブランチ
   `fix/1159-pr-issue-link-refs` に commit 済み・未 push）との順序は
   どちらでもよい**。同じ `check-pr-issue-link.yml` の **steps** を差し替える
   スクリプトだが、本スクリプトは **header（`on` / `permissions` / `jobs` 直下）
   のみ**を触るため textual conflict は起きない。

   **`pull-requests: write` は comment-removal 適用後も必要**（実測:
   `scripts/apply-pr-issue-link-comment-removal.sh` の 31 行目に
   「`permissions: pull-requests: write` は (2) の削除操作に必要なため維持する」と
   明記され、置換後の step は `gh api -X DELETE repos/$REPO/issues/comments/$id`
   を 1 箇所で呼ぶ）。したがって comment-removal を先に適用しても **(C) の内容は
   変わらない**。

   ⚠️ **(C) をスキップしてはならない**。(C) は「`write` を消す」変更ではなく
   「`write` の適用範囲を top-level から job へ絞る」変更である。write を落とすと
   cleanup step が 403 で落ちる。
3. 本スクリプトを `--dry-run` → Human が差分確認 → `--apply`。
4. `actionlint .github/workflows/*.yml` を実行して exit 0 を確認。

## 6. Phase 2 提案（本 PR では実装しない）: paths-filter を外して required 化する

`privacy` / `validate` / `drift-check` を required にできない唯一の理由は
`on.pull_request.paths:` である。一方、**3 本とも既に workflow 内部に
「対象ゼロなら何もしない」経路を持っている**:

- `metrics-privacy.yml`: `Determine files to scan` → `count == '0'` なら
  `No JSON / NDJSON to scan` step でスキップ
- `schema-validate.yml`: `Determine changed JSON files` → `count == '0'` なら
  `No JSON to validate` step でスキップ
- `sync-plugin-plangate.yml` / `drift-check`: sync スクリプトを流して差分ゼロを確認するだけ

つまり `paths:` は **二重の防御であり、外しても意味論は変わらない**（対象ゼロなら
数秒で緑になる）。実測 p50 は 6s / 10s / 6s なので常時実行のコストも小さい。

提案: `paths:` を外して常時実行にし、その上で required に追加する。
ただし本 PR のスコープ外（トリガ条件の変更は挙動変更であり、独立した PBI で
mode 判定と C-3 を通すべき）。**先に §4 の 4 本を入れてから**、別 PBI で扱う。

## 7. P3: CI 出力の機械可読化（設計メモ）

> **注**: `tests/run-tests.sh` 本体は別ワーカーが同時に改修中のため、本節は
> **workflow 側の設計提案のみ**。スクリプト本体には一切触れていない。

### 問題

`test.yml` の `Run CLI tests` は `sh tests/run-tests.sh` の生ログを Actions の
step ログに流すだけ。失敗テスト名を知るには **ログを開いて目視 grep** するしかなく、
PR 上のサマリにも JSON 成果物にも残らない。required 化して落ちる頻度が上がるほど
このコストが効いてくる。

### 設計（workflow 側だけで完結する最小案）

```text
jobs.plangate-cli.steps:
  - Run CLI tests
      run: sh tests/run-tests.sh | tee test-output.log     # 本体は不変
      # ※ 終了コードを握り潰さないよう pipefail 相当（set -o pipefail が使えない sh の場合は
      #    出力を tee してから ${PIPESTATUS} 相当を明示評価する）
  - Summarize failures        if: always()
      # test-output.log から失敗行を抽出し
      #   (a) $GITHUB_STEP_SUMMARY へ Markdown 表として append
      #   (b) test-results.json（失敗テスト名 / 件数 / exit code）を生成
  - Upload test results       if: always()
      uses: actions/upload-artifact@<pinned sha>
      with: { name: test-results, path: test-results.json, retention-days: 14 }
```

### 決めておくべきこと（次 PBI の入力）

| 論点 | 案 |
|---|---|
| 失敗行の抽出規約 | `run-tests.sh` の出力フォーマット（`[FAIL] <name>` 等）に依存する。**1 サンプルから全称規則を作らない** — 全テストランナーの出力を数えてから決める |
| JSON schema | `schemas/` に置くか、artifact 限定の非契約 JSON に留めるか。後者から始める |
| 抽出ロジックの置き場 | workflow inline ではなく `scripts/summarize-test-results.sh`（非 HO）に切り出す。workflow は呼ぶだけ（Rule 1 相当） |
| 適用範囲 | まず `test.yml` の 1 job のみ。`ci.yml` の 3 job へ広げるのは効果を測ってから |
| HO 経路 | `test.yml` は HO パス。実装時も apply スクリプト経由（本書 §5 と同じ手順） |

依存: `tests/run-tests.sh` の出力フォーマット確定（別ワーカー担当）を待つ。

## 8. 本提案の対象外だが記録しておく穴

| # | 内容 | 実測 | 扱い |
|---|---|---|---|
| 1 | `pull_request.required_approving_review_count: 0` | ruleset 実測 | C-4（人間レビュー）が **ruleset では強制されていない**。規範層のみで支えている。required checks とは独立の判断なので本提案には含めない |
| 2 | `bypass_actors: [{actor_type: RepositoryRole, actor_id: 5, bypass_mode: always}]` | ruleset 実測 | admin ロールが required checks を常時バイパスできる。`current_user_can_bypass: "always"` |
| 3 | `check` job の名前が `check` | check-runs 実測 | required にするなら他 app と衝突しにくい固有名（`name:` 明示）にすべき。ただし §3.2 の通り required 化自体を推奨しない |
| 4 | `schema-validate.yml` の failure 1 件（2026-08-19 push to main） | `gh run list` 実測 | PR 側 run は同時刻に success。push 側のみ失敗しており未調査 |
| 5 | **actionlint の shellcheck 連携が決定論的にハングする** | `actionlint -no-color -oneline .github/workflows/schema-validate.yml` が 60s x3 とも rc=124（actionlint が 100% CPU で spin、shellcheck の子プロセスは 0 個）。`-shellcheck=` を付ける / PATH から shellcheck を外すと rc=0 / 0s。ハングする 4 本 = check-pr-issue-link / release-docs-sync / schema-validate / sync-plugin-plangate。step 単位では schema-validate.yml の `Determine changed JSON files` 単体で再現（actionlint 1.7.12 + shellcheck 0.11.0 / darwin-arm64） | `scripts/lint-workflows.sh` は **既定で `-shellcheck=`**（+ `PG_LINT_TIMEOUT` 既定 120s のハング検出）。結果として **inline `run:` ブロックの shell lint は誰も行っていない**（`.sh` / shebang スクリプトは `lint-shell.sh` がカバー）。恒久解は版固定または upstream 修正で **別 PBI**。有効化は `PG_ACTIONLINT_SHELLCHECK=1` |
| 6 | **shellcheck 本体のバージョンが非固定** | `apply-ci-lint-wiring.sh` の `JOBS`（`shellcheck --version` を出すだけ） | `shell-lint` job は runner プリインストールの shellcheck を使う。runner 側の版が上がると新規 check の追加で gate が落ちうる（actionlint は version + sha256 固定済み）。**別 PBI**。`shell-lint` を required にすると影響が出るため、required 化と同時期に版固定を検討する |

## 9. 参照

- ruleset: <https://github.com/s977043/plangate/rules/14939019>
- apply スクリプト: [`scripts/apply-workflow-hygiene.sh`](../../../scripts/apply-workflow-hygiene.sh)
- HO 変更の標準フロー: [`docs/ai/ho-change-workflow.md`](../../ai/ho-change-workflow.md)
- 責務 4 分類: [`.claude/rules/responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md)
