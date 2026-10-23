# #1586 保守コスト削減機会レポート

## 0. 前提

- 基準 SHA: `5fcdb2e3279aed1cf8a02416d5e48bab5a3b191f`（2026-10-17 時点の `origin/main`。`git ls-remote` で確認）
- CI 観測窓: 2026-10-08T02:52Z〜2026-10-17 の 1000 run（GitHub API の上限）。それより前の CI は Unknown
- 数値は基準 SHA 時点の測定値。ローカル HEAD は基準 SHA と一致しないため、着手前に再測定すること
- 完全性は主張しない。網羅していない領域は §6 に記載

## 1. サマリ（期待効果×リスクの上位 5 件）

1. **CI で .md のみの変更を skip する**（ci.yml に changes job を追加、codeql.yml に paths-ignore）
   - 効果: Test 以外の CI 時間を削減できる
   - 対象が HO 該当のため、適用は Human
2. **CLAUDE.md の是正**: 16 行目（1 行 2912 文字）を縮約し、24 行目の「6/12」を「11/12」に直す
   - 効果: 常時ロードされる指示の負債が減る
   - HO 該当
3. **AGENTS.md の Codex 節の重複を統合する**（28-36 行目と 45-49 行目）
   - 効果: 2 か所の記述が乖離するリスクがなくなる
   - HO 該当
4. **skills の写しの乖離を解消する**（intent-classifier / plangate-setup）
   - HO 対象外だが、ta-77 台帳の DECL に該当する
5. **静的参照 0 件の scripts を削除候補として提示する**（add-codeql-workflow.sh / add-slsa-attestation.sh）
   - 未使用である確度は高い。削除するかは Human が判断する

## 2. 候補表

HO 判定は `scripts/hooks/check-plan-hash.sh` の `_override=0` 直後の case ブロックで行った。`.claude/skills` は対象外（同ファイル 500 行目で確認）。

| # | Candidate | Evidence | Unknown | Expected Impact | Risk | Owner | HO該当 | 必要承認 | Verification | Rollback区分 | Recommendation |
|---|-----------|----------|---------|-----------------|------|-------|--------|----------|--------------|--------------|----------------|
| 1 | ci.yml: 変更が .md のみのとき、shell-lint / workflow-lint / interactive-feedback-tests / interactive-browser-e2e を skip する | changes job 方式（fetch-depth 2、差分が取れなければ code=true）。required check は ruleset 14939019 の `Markdown lint` 1 件のみ | 削減される分数（未測定） | 中〜高 | 中（偽の緑が出うる。差分取得や changes job 自体が失敗したら、迷わず実行側に倒して job を skip しない） | Human（適用）/ AI（スクリプト作成） | 該当（`.github/workflows/*.yml`） | C-3 同期 + HO 適用 | `--verify` を実行し、.md のみの PR とコード変更を含む PR の両方で実走する | repo内 | HO 適用スクリプトとして提示 |
| 2 | codeql.yml: pull_request に paths-ignore `**/*.md` を追加 | CodeQL は 210 run・平均 1.39 分 | push 側の扱い | 低〜中 | 低 | Human | 該当 | C-3 + HO 適用 | .md のみの PR で CodeQL が起動しないことを確認 | repo内 | #1 と同じスクリプトで提示 |
| 3 | test.yml は変更しない | ta-77 などは .md の変更でも落ちうる（skip すると偽の緑になる） | — | — | 変更する方がリスクが高い | — | 該当 | — | — | — | 維持 |
| 4 | Scorecard の push 起動 | push で 42 run、別に週次 cron あり | push 起動が必要か | 低 | 低 | Human | 該当 | C-3 + HO | — | repo内 | README に判断材料を書くだけにとどめる |
| 5 | CLAUDE.md 16 行目（2912 文字）を縮約 | 一次照合済み | — | 中（常時ロード） | 低（apply-claude-md-v*.sh 互換の見出し形を維持する） | Human | 該当（`CLAUDE.md`） | C-3 + HO | `<law>` と「承認境界の適用順」が BASE と完全一致することを確認 | repo内 | HO 適用スクリプトとして提示 |
| 6 | CLAUDE.md 18-27 行目の v8.6 期の箇条書きを「## 機能索引（v8.6〜v8.9 初出）」の下に移す | 一次照合済み | — | 低〜中 | 低 | Human | 該当 | C-3 + HO | 同上 | repo内 | 同上 |
| 7 | CLAUDE.md 24 行目「物理配線 6/12」を 11/12 に修正 | docs/ai/hook-enforcement.md 28 行目は 11/12（照合済み） | — | 中（事実誤り） | 低 | Human | 該当 | C-3 + HO | 両ファイルの値が一致することを確認 | repo内 | 同上 |
| 8 | AGENTS.md の Codex 節の重複（28-36 行目と 45-49 行目。CLAUDE.md 29-34 行目とも重複） | 一次照合済み | 「EH-1/2/3/6/9 物理発火」が事実か（§7） | 中 | 低（文面は動かすだけ） | Human | 該当（`AGENTS.md`） | C-3 + HO | 移した後に重複が 0 であることを確認 | repo内 | 45-49 行目を 36 行目の後ろに移し、重複を削除する |
| 9 | skills の写しの乖離: intent-classifier（`.claude` 84d23ea6 / 他 3b87c86b）、plangate-setup（c4cfc874 / ff20aa82） | blob 比較 | どちらが正しい版か | 中 | 中（plugin の配布物に影響しうる） | AI | 非該当（`.claude/skills` は対象外） | C-3 | blob の一致と ta-77 を確認 | 配布物影響 | 正しい版を決めて同期する。ta-77 台帳の DECL に該当（注） |
| 10 | working-context.md（559 行・35KB）が常時ロードされている | 測定済み | 分割した場合の影響 | 中 | 高（承認に関する規定を含む） | Human | 該当（`.claude/rules/*.md`） | C-3 + HO | ta-77 | repo内 / 配布物影響 | 別 issue で設計から検討する。ta-77 台帳の CHAIN に該当（注） |
| 11 | hook-enforcement.md 7 行目が自ら「v8.5.0 構成のまま」と書いている | 一次照合済み | — | 低 | 低 | AI | 非該当 | C-3 | ta-77 | repo内 | 文面を更新する。ta-77 台帳の DECL に該当（注） |
| 12 | `.claude/rules` と `plugin/plangate/rules` に同じ 6 ファイルがある | blob は一致（乖離なし） | — | 低 | 低 | — | `.claude/rules` 側のみ該当（`plugin/` は HO 対象外） | — | — | 配布物影響 | 現状維持（乖離が出ないか監視する） |
| 13 | 静的参照 0 件の scripts: add-codeql-workflow.sh / add-slsa-attestation.sh（確度 高）、acknowledge-skip-log.sh / fix-workflow-security.sh（確度 中） | 静的参照は 0 件。glob での参照は scripts/hooks/* と ai-loop 配下にしかない | 手動で使われているか、既に適用済みか | 低〜中 | 低〜中 | Human | 非該当 | C-3 + 削除対象を名指しした承認 | run-tests.sh と doctor の存在検査を確認 | repo内 | 削除候補として提示 |
| 14 | 弱い参照しかないもの: add-auto-approve-workflow.sh / run-tests-safe.sh / fix-eh3-doc-light-maint-guard.sh / tests/fixtures/gate-events/sample-normalized.ndjson | CHANGELOG と docs/working からしか参照されていない | 手動のラッパとして使われているか | 低 | 中 | Human | 非該当 | C-3 + 削除対象を名指しした承認 | 同上 | repo内 | 削除候補として提示する。先に用途を確認する |
| 15 | apply-* スクリプト 41 本 | 一覧を作っただけ | 個々に適用済みかどうか | 低〜中 | 中 | Human | 個別に判定 | Human の判断 | 各スクリプトの `--verify` | repo内 | 別 issue で棚卸しする |
| 16 | Test workflow の実行時間（job は 1 つで 425 秒、paths filter なし。run 数・内訳・合計は §8.3 を正とする: 窓 2026-10-08T03:02:28Z〜10-17T17:46:14Z で 210 run、success / cancelled / failure = 138 / 66 / 6、elapsed（`updated_at - run_started_at`）合計 1,197.55 分。旧記載の「平均 10.26 分・合計 2155 分・cancelled 61」は 2026-10-23 の再取得で再現しないため撤回） | test.yml 照合済み | job を分割した場合の効果 | 中 | 中 | Human | 該当 | C-3 + HO | — | repo内 | #3 と整合を取ったうえで別 issue にする |

注: ta-77 台帳（DECL / CHAIN）の tsv は AI が書き換えない。該当ファイルを変えると digest が変わるので、台帳の更新は Human が行う。

### flaky / 個別 run

| 対象 | 状態 | 扱い |
|------|------|------|
| Interactive Review Browser E2E | #1556 は OPEN。`fix/1556-chromium-cold-start` で別に作業中 | 本 issue では扱わない |
| #1578 | run 38330052668 は修正が入る前の run（is-ancestor の rc=1）。修正後の main の Test 4 run は success 3 / cancelled 1 / attempt>=2 が 0 | 経過観察 |
| run 38714254251（fix/1496） | 2 回の attempt が同じ失敗 | branch 側の実バグの可能性が高いので、flaky としては扱わない |

## 3. HO 適用スクリプトの型

- 状態の判定: 対象が BASE と一致すれば未適用、生成後の内容と一致すれば適用済み、どちらでもなければ停止する
- `<law>` と「承認境界の適用順」が変わっていないことは、生成後の内容の sha256 を固定することで担保する（law 検査はその二重化）
- モード: `--dry-run` / `--apply` / `--verify` / `--rollback`。main ブランチ上では書き込みを拒否する
- 影響: plugin への影響はなく、version bump は不要。ai-loop の corpus_hash は変わる。CLAUDE.md / AGENTS.md は ta-77 台帳の対象外
- fixture `tests/fixtures/apply-baseline/workflows/ci.yml` は凍結スナップショットなので追従させない。ta-71 TC-13b は ci.yml に `  shell-lint:` の行が残っていれば緑になる
- スクリプト本体（`.sh`）はこの PR では未同梱。手順と検証は `ho/README.md` を参照（理由は handoff.md §1）

## 4. 作業ツリーの残骸（Owner = Human）

出典: 2026-10-19 に `git status --porcelain=v1 -uall` で取得し、基準 SHA `5fcdb2e3` と照合した（Phase0 の照合は 2026-10-17）。

| 区分 | 件数 | 内容 |
|------|------|------|
| 変更（M） | 12 | すべて基準 SHA と差分がある |
| 未追跡（??） | 47 | すべて基準 SHA に存在しない |
| 合計 | 59 | — |

未追跡の内訳:

| 置き場所 | 件数 | 備考 |
|----------|------|------|
| `.agents/skills/` | 14 | — |
| `.codex/agents/*.toml` | 15 | — |
| `docs/working/TASK-*` | 11 | TASK-1393・TASK-APPROVE-HARDEN-TEST・TASK-FORCE-OVERWRITE-TEST の承認トークン c3.json 3 件を含む |
| `docs/working/ai-loop-runs/` | 6 | — |
| `docs/philosophy.md` | 1 | — |

承認トークンの c3.json 3 件は、AI が作成・削除・移動しない。残すかどうかは Human が判断する。AI は、名指しで指示されていない tracked / untracked の変更を破棄しない。

## 5. 付録: HITL→HOTL ロードマップ

### 人が介入している箇所の現状（測定値）

| 介入点 | 測定値 |
|--------|--------|
| C-3 の c3.json | 90 件（APPROVED 82 / CONDITIONAL 7 / 不明 1、2026-04-28〜08-15）。このうち approved_by が AI の代筆（`human-s977043-via-claude-on-explicit-instruction-*`）のものが 13 件 |
| status.md の C-3 記録 | APPROVED 37 / AUTONOMOUS APPROVED 7 / CONDITIONAL 1 |
| ai-loop-runs | 35 件（AUTO_APPROVED 20 / HUMAN_ESCALATED 13 / BLOCKED 2、07-02〜08-20） |
| 人間に回った 15 件の内訳 | lite_check=false（clean で W は両者 approve）7 / W の判定が不一致 4 / 両者 reject で BLOCKED 2 / HO に触れた 2 / 原因不明 1 |
| skip-decision-log | 254 件（DOC_LIGHT_SKIP 241 / SKIP 13）。すべてに acknowledged_by があり、人間が事後に確認している |

### 段階

| Phase | 内容 | 前提条件 | 監視指標 | ロールバック | Human の承認点 |
|-------|------|----------|----------|--------------|----------------|
| 1 | lite.size_ok を機械で算出する（#780 slice C、期待効果 高） | 算出規則が C-3 で承認されていること | lite_check=false による escalate の件数（基準値 7） | 自己申告に戻す | C-3 |
| 2 | W の判定が不一致（documentation）のとき自動修正して W をやり直す（期待効果 中） | Phase 1 が安定していること | W 不一致の件数（基準値 4）、やり直し後の不一致率 | 自動修正を止める | C-3 |
| 3 | AI が代筆した C-3 を Autonomous APPROVE の枠に統合する（期待効果 中） | 判定マトリクスと整合していること | 代筆の件数（基準値 13）、即停止条件の発火 | 人間による C-3 に戻す | C-3（承認境界に関わるため同期で） |
| 4 | DOC_LIGHT_SKIP を自動で受理し、確認はサンプリングにする（期待効果 中） | hook が HO の可能性があるため、適用は Human | サンプル中に誤って受理された件数 | 全件を人間が確認する運用に戻す | HO 適用 + C-3 |
| 5 | standard モードの C-3 を機械化する（期待効果 低） | #822 で本番は HITL を維持すると決めており、これと矛盾する | — | — | 着手前に Human が方針を判断する |
| 他 | #1269（EH-13 の偽陽性）/ #1197・#1575（no-task の ai-loop 経路）/ #1435（リリース手順の簡素化） | 各 issue の結論 | 各 issue に従う | 各 issue に従う | 各 issue の C-3 |

### 維持する（R）ゲート

次はどの Phase でも自動化しない: C-4 / merge、HO、承認トークン、settings の適用、tag / Release。

### Unknown

- c3_status が不明な 1 件の中身
- status.md の 45 件と c3.json の 90 件が食い違う理由
- tag / Release で人が介入している件数

## 6. 残存脅威モデル

| 守るもの | 守らないもの |
|----------|--------------|
| 基準 SHA 時点の静的参照・blob 比較と、観測窓内の CI 実績にもとづく候補の提示 | 基準 SHA 以降の変更、観測窓より前の CI の傾向 |
| HO や ta-77 台帳に該当するかの明示 | 削除候補が本当に使われていないことの保証（動的な参照や手動での運用は拾えない） |

調べていない領域:

- run-tests.sh がテストを組み立てる規則の全体
- doctor による存在検査（削除候補が検査対象に入っていないか）
- 2026-10-08 より前の CI
- billable minutes
- Codex 側の hook が実際に登録されているか（§7）

このレポートは多層防御の 1 層にすぎない。保証するのは C-3 / C-4 の Human レビューと CI である。

## 7. ユーザー判断の記録

- 2026-10-19: AGENTS.md / CLAUDE.md の Codex 節にある「EH-1/2/3/6/9 物理発火」は、hook-enforcement.md の #1078（Codex hook の登録は 0 件）と矛盾している疑いがある（W2 の指摘で、まだ照合していない）。判断は **a**。HO 適用スクリプトでは文面をそのまま移し、事実の照合は別 issue で行う

## 8. 追補: PR #1588 の実測値（2026-10-18 測定、基準 main `1d624d95e597c711ec7f659868d4e1bf49d87d7a`）

Human の判断で本 PR を #1586 の正本とし、PR #1588（head `6ece24c4`）にあって本書に無かった実測値を、測定時点と一緒に元の値のまま取り込んだ。§0 の基準 SHA `5fcdb2e3` とは別の時点の値である。†印は 2026-10-23 に一次ソースで再確認した値。

### 8.1 skills の写し（`1d624d95` 時点の Git blob）

| Skill | `.agents` / `.codex` / `plugin/plangate` | `.claude` |
|-------|------------------------------------------|-----------|
| intent-classifier | `3b87c86bffda710331159b659d5372b3afce83db`（3 経路一致）† | `84d23ea62c980db7ac0cca008e84ca2093fdd60c` † |
| plangate-setup | `ff20aa82530465aec5c477752270554442c38fb6`（3 経路一致） | `c4cfc8748c53a115f869d196a8abae886b9932af` |

- 配布の正本は `scripts/sync-plugin-plangate.sh` の `SKILLS_DIR="$REPO_ROOT/.agents/skills"`（#1588 の照合）
- #1588 の行単位比較: intent-classifier は `.agents` 版 78〜84 行（CLI・enforcement は配布対象外、CLI が無ければ明示停止・silent skip 禁止）が Claude 版に無い。plangate-setup は `.agents` 版 41〜67 行（#1497 で検証済みの downstream 操作の範囲、CLI 未配布の注意）が Claude 版では 41〜48 行に短縮されている。Claude 版にも停止・`doctor --fix` の rc=2 / no-write の記述は残っている
- blob の不一致は危険な動作の証明ではない（判断: DIFF_CONFIRMED / BEHAVIOR_UNKNOWN / NEEDS_APPROVAL）

### 8.2 Test workflow

- run [39028937133](https://github.com/s977043/PlanGate/actions/runs/39028937133): `Test`、headSha `1d624d95`、2026-10-17T11:30:11Z〜11:37:12Z、421 秒、success †
- 比較: main `5fcdb2e3` の run [38872144619](https://github.com/s977043/PlanGate/actions/runs/38872144619) は 429 秒、success
- `.github/workflows/test.yml`（`1d624d95` の blob `e33f57940d07da745a110e0c9df0b609a305cb15`）12〜14 行目に `concurrency.group: test-${{ github.workflow }}-${{ github.ref }}` / `cancel-in-progress: true` †

### 8.3 Actions 1,000 run の再集計（`GET /actions/runs?per_page=100&page=1..10`、全 branch・全 workflow）

| スナップショット | 窓（created_at） | Test 一意 run | success / cancelled / failure | elapsed 合計（`updated_at - run_started_at`） |
|------------------|------------------|---------------|-------------------------------|----------------------------------------------|
| 1 回目（2026-10-18 閲覧） | 2026-10-08T03:02:28Z〜10-17T17:46:14Z | 210 | 138 / 66 / 6 | 71,853 秒 = 1,197.55 分（success のみ 約 1,016.88 分） |
| 2 回目（後続取得） | 2026-10-08T03:03:25Z〜10-17T19:13:16Z | 209 | 139 / 64 / 6 | 約 1,203.87 分（success 約 1,024.20 / cancelled 約 136.63 / failure 約 43.03） |

- 2 回目の cancelled 64 件の内訳: pull_request 59 件（約 100.58 分）/ push 5 件（約 36.05 分）
- 件数 210 は §2 #16 の値と一致する。一方、合計 2,155 分は同じ run 集合・elapsed の定義では再現しない（差 957.45 分）。billable の Runner 時間とは別物であり、2,155 分の分母は Unknown
- 2026-10-23 再取得†（`gh api --paginate repos/s977043/PlanGate/actions/workflows/test.yml/runs?created=…` を両窓で集計）: 1 回目の窓は 210 run・138 / 66 / 6・1,197.55 分、2 回目の窓は 209 run・139 / 64 / 6・1,203.87 分で上表と一致。待ち時間を含む `updated_at - created_at` でも 2,140.15 分 / 2,146.47 分で 2,155 分にならず、cancelled 61 もどちらの窓でも再現しない。§2 #16 の旧値はこの結果に基づき撤回した
- 2 つのスナップショットは母集団の境界が違うため、片方の値でもう片方を上書きしない
- main の cancelled の 2 例は、次の run が開始した後に終わっており、concurrency による置き換えと整合する: [38226105171](https://github.com/s977043/PlanGate/actions/runs/38226105171)（08:50:51〜08:58:17）→ [38226863850](https://github.com/s977043/PlanGate/actions/runs/38226863850)（08:58:13 開始、success）、[38870521020](https://github.com/s977043/PlanGate/actions/runs/38870521020)（07:57:39〜08:04:48）→ [38871258689](https://github.com/s977043/PlanGate/actions/runs/38871258689)（08:04:26 開始、success）（2026-10-12 / 10-16、UTC）。64 件すべての原因は実証していない。cancel をそのまま flaky や削減できる費用とみなさず、`cancel-in-progress` は変更しない

### 8.4 後続 issue

- #1592: Codex 節の事実照合（§7 の判断 a）
- #1593: apply-* 41 本の棚卸し（§2 #15）
- #1594: Test workflow の分割（§2 #16。§8.2 / §8.3 の値を入力にする）
