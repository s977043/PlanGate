# TASK-1593 apply-* スクリプト適用状態の棚卸し

Refs #1593 / #1586（report.md C-15）

## 前提

- 照合した ref: `origin/main` = `a274bbaf`（2026-11-02 時点）
- 判定は読み取りだけで行った。`apply-*` スクリプトは `--dry-run` / `--verify` を含めて 1 本も実行していない
- 方法: 各スクリプトの冪等判定（「適用済み」と見なす marker）と置換対象（旧文字列）を読み取り、
  `git show origin/main:<path> | grep -cF '<marker>'` で件数を数えた。履歴は
  `git log origin/main -S'<marker>' -- <path>` で確認した
- 状態の定義
  - **BASE のまま**: 生成後の marker が無く、置換元（アンカー）が残っている
  - **生成後＝適用済み**: スクリプト自身の冪等判定が「適用済み」になる
  - **どちらでもない**: 一度適用されたあと後続の変更で上書きされた、または実効行は入っているが文面が異なる
  - **判定不能**: 対象ファイルが追跡外などで、読み取りだけでは照合できない

## 件数

| 項目 | 本数 |
|------|------|
| `git ls-files \| grep -E '(^\|/)apply-[^/]*$'`（`a274bbaf`） | 44 |
| 同じコマンドを `5fcdb2e3`（#1586 の基準）で実行 | 44 |
| うち `scripts/apply-*.sh`（#1586 の 41 本） | 41 |
| うち `docs/working/` の evidence ファイル（スクリプトではない） | 3 |

44 本と 41 本の差は `docs/working/TASK-1089/evidence/` と `TASK-1093/evidence/` にある 3 件。これらは
証跡ファイルで、適用対象を持たないため本表では対象外とした（末尾に記載）。

| 状態 | 本数 |
|------|------|
| BASE のまま | 6 |
| 生成後＝適用済み | 22 |
| どちらでもない | 12 |
| 判定不能 | 1 |

| 推奨 | 本数 |
|------|------|
| 削除候補 | 32 |
| 残置 | 1 |
| 要 Human 確認 | 8 |

## 棚卸し表

| パス | 対象ファイル | 状態 | 根拠 | 推奨 |
|------|------------|------|------|------|
| `scripts/apply-1101-ho-normalization.sh` | `scripts/hooks/check-plan-hash.sh` | 生成後＝適用済み | 冪等判定 `_ho_key=` と `# >>> PG-FOLD-PATH BEGIN (#1101)` の両方: count=1 / 1 | 削除候補 |
| `scripts/apply-ai-loop-phase1-command.sh` | `.claude/commands/ai-loop-workflow.md` | どちらでもない | 旧文言 `対象変更が低リスク帯（docs 等・可逆）か`=0、新文言 `4 軸〔変更規模…〕を満たしうる変更。`=0。新文言は `efb1b5e0`（#808）で入り、`4c5d1e65`（#881）で消えた | 削除候補 |
| `scripts/apply-ai-loop-workflow-command.sh` | `.claude/commands/ai-loop-workflow.md`（SRC: `docs/working/_prompts/ai-loop-workflow-command.md`） | どちらでもない | 判定は DST と SRC の差分。blob は DST=`00da2079` / SRC=`594aa7de` で不一致。DST は `41ab0a79`（#777）で作成され、その後に編集されている | 削除候補 |
| `scripts/apply-approve-hardening.sh` | `bin/plangate` | 生成後＝適用済み | `TASK-0139 AC-04: abort if c3.json exists and --force not given`=1 | 削除候補 |
| `scripts/apply-ci-lint-wiring.sh` | `.github/workflows/ci.yml` | 生成後＝適用済み | MARKER `shell-lint:`（先頭に空白 2 つ）=1 | 削除候補 |
| `scripts/apply-claude-md-law-tone.sh` | `CLAUDE.md` | 生成後＝適用済み | 旧 `<law>` の第1原則文=0、新 `<law>` の `このリポジトリは承認ゲートそのものを開発・検証している`=1。`db91ed16`（#1433）で入った | 要 Human 確認（`--rollback` 経路を残すかを決める） |
| `scripts/apply-claude-md-v8160.sh` | `CLAUDE.md` | どちらでもない | 旧見出し v8.13.0=0、新見出し v8.16.0=0。`881a7cf0`（#791）で入り、`5db51004`（#859）で上書き。現行は v8.24.0 見出し | 削除候補 |
| `scripts/apply-claude-md-v8171.sh` | `CLAUDE.md` | どちらでもない | 新見出し v8.17.1=0。`5db51004`（#859）で入り、`2da97294`（#948）で上書き | 削除候補 |
| `scripts/apply-claude-md-v8180.sh` | `CLAUDE.md` | どちらでもない | 新見出し v8.18.0=0。`2da97294`（#948）で入り、`304518bb`（#1075）で上書き | 削除候補 |
| `scripts/apply-claude-md-v8190.sh` | `CLAUDE.md` | どちらでもない | 新見出し v8.19.0=0。`304518bb`（#1075）で入り、`70de3ded`（#1096）で上書き | 削除候補 |
| `scripts/apply-claude-md-v8200.sh` | `CLAUDE.md` | どちらでもない | 新見出し v8.20.0=0。`70de3ded`（#1096）で入り、`684949ec`（#1190）で上書き | 削除候補 |
| `scripts/apply-claude-md-v8210.sh` | `CLAUDE.md` | どちらでもない | 新見出し v8.21.0=0。`684949ec`（#1190）で入り、`74c76aa0`（#1340）で上書き | 削除候補 |
| `scripts/apply-claude-md-v8220-date.sh` | `CLAUDE.md` | どちらでもない | 旧 `**v8.22.0**（2026-09-11）`=0、新 `**v8.22.0**（2026-09-23）`=0。`b2234bd1`（#1373）で入り、`bc48b9a5`（#1502）で上書き | 削除候補 |
| `scripts/apply-claude-md-v8220.sh` | `CLAUDE.md` | どちらでもない | 新見出し v8.22.0=0。`74c76aa0`（#1340）で入り、`bc48b9a5`（#1502）で上書き | 削除候補 |
| `scripts/apply-claude-md-v8230.sh` | `CLAUDE.md` | どちらでもない | 新見出し v8.23.0=0。`bc48b9a5`（#1502）で入り、`e8b27201`（#1560、v8.24.0）で上書き | 削除候補 |
| `scripts/apply-claude-settings.sh` | `.claude/settings.json`（入力: `.claude/settings.example.json`） | 判定不能 | `git cat-file -e origin/main:.claude/settings.json` → 存在しない（追跡外）。対象は利用者ごとのローカルファイルで、リポジトリからは照合できない。doctor（`--check-settings`）が前提にしている常用ツール | 残置 |
| `scripts/apply-conductor-dynamic-phase.sh` | `.claude/agents/workflow-conductor.md` / `plugin/plangate/agents/workflow-conductor.md` | 生成後＝適用済み | MARKER `#### plan 再実行ガード（ScheduleWakeup ポーリング中の誤再投入防止）`: 2 ファイルとも count=1 | 削除候補 |
| `scripts/apply-diff-audit-rename.sh` | `.claude/agents/implementation-agent.md` / `.claude/agents/workflow-conductor.md` | 生成後＝適用済み | 置換元 `self-review`: 0 / 0、置換後 `diff-audit`: 1 / 2 | 削除候補 |
| `scripts/apply-eh-git-destructive-guard.sh` | `.claude/settings.example.json`（あれば `.claude/settings.json` も） | 生成後＝適用済み（追跡対象分） | `check-git-destructive.sh`=1 in example。`3a372d47`（#985）で入った。`.claude/settings.json` は追跡外のため未照合 | 要 Human 確認（ローカル settings.json の配線に使う可能性） |
| `scripts/apply-eh3-doc-light.sh` | `scripts/hooks/check-plan-hash.sh` | 生成後＝適用済み | 冪等判定 `EH-3_DOC_LIGHT_SKIP`=1 | 削除候補 |
| `scripts/apply-eh3-ho-always.sh` | `scripts/hooks/check-plan-hash.sh` / `.claude/rules/mode-classification.md` | 生成後＝適用済み | hook: 冪等判定の `_override=0`（488 行）が `if [ -z "$task_id" ]; then`（548 行）より前。rules: `RULES_OLD`（`L124-134 case 文 = **9 カテゴリ**`）は無く、記号アンカー（`_override=0` 直後の `case` ブロック）がある。カテゴリ数はその後 12 に増えた（#1226） | 削除候補 |
| `scripts/apply-pr-issue-link-comment-removal.sh` | `.github/workflows/check-pr-issue-link.yml` | 生成後＝適用済み | `APPLIED_MARKERS` 3 本（`Annotate WARN` / `Annotate NOTICE` / `Cleanup stale warning comment`）がすべて count=1 | 削除候補 |
| `scripts/apply-precompact-guard.sh` | `scripts/hooks/precompact-memory-guard.sh`（新規）/ `.claude/settings.example.json` | BASE のまま | DST `scripts/hooks/precompact-memory-guard.sh` は存在しない。SRC `scripts/precompact-memory-guard.sh` は追跡あり。example の `precompact-memory-guard.sh`=0、`git log -S` の履歴も 0 件 | 要 Human 確認（適用するか撤回するか） |
| `scripts/apply-quality-command-gate.sh` | `.claude/rules/working-context.md` | BASE のまま | marker `品質コマンド実行証跡ゲート`=0（履歴も 0 件）。ANCHOR `### improvement-seeds.md（WF-06 Retro / opt-in・append-only）`=1 | 要 Human 確認 |
| `scripts/apply-rnnn-c4-extension.sh` | `.claude/rules/working-context.md` / `.claude/rules/review-principles.md` | BASE のまま | marker `P-NNN`=0 / `C-2 と C-4 の責務分界`=0（いずれも履歴 0 件）。アンカー（wc の `review-finding → plan-revision` 行、rp の `## 7-ter.` 見出し）はともに count=1 | 要 Human 確認 |
| `scripts/apply-subagent-delegation-wiring.sh` | `.claude/rules/orchestrator-mode.md` / `.claude/rules/responsibility-classes.md` / `CLAUDE.md` / `AGENTS.md` | 生成後＝適用済み | marker `docs/ai/subagent-delegation`: 4 ファイルとも count=1 | 削除候補 |
| `scripts/apply-subagent-team-design-rename.sh` | `.claude/commands` / `agents` / `rules` 配下の `*.md` | 生成後＝適用済み | 3 ディレクトリの `*.md` のうち `setup-team` を含むものは 0 本（スクリプトの SKIP 条件が成立）。`6b4e04c5`（#806）で改名された | 削除候補 |
| `scripts/apply-task-0123-patches.sh` | `schemas/maintenance.schema.json` / `scripts/hooks/check-plan-hash.sh` / `bin/plangate` / `.github/workflows/check-maintenance-provenance.yml`（新規） | BASE のまま | `hmac_signature`=0、`PLANGATE_MAINTENANCE_KEY`=0 / 0（いずれも履歴 0 件）。workflow は存在しない。patch 2〜4 のアンカーが残っているかは未照合 | 要 Human 確認 |
| `scripts/apply-task-0124-patches.sh` | `.github/workflows/sync-plugin-plangate.yml`（新規） | 生成後＝適用済み | 冪等判定はファイルの有無だけ。ファイルは存在し、`304f2f0a`（TASK-0124 HO 適用）で作成された。その後 #860 / #1225 で編集されているため、heredoc の内容とは一致しない | 削除候補 |
| `scripts/apply-task-0128-p0-hardening.sh` | `bin/plangate` | どちらでもない | marker `PLANGATE_TEST_MODE=1 のときのみ honor する（#550 P0）`=0。`gate_old`（TEST_MODE 条件なし）の行=0。実効行 `if [ "${PLANGATE_TEST_MODE:-0}" = "1" ] && [ -n "${PLANGATE_FAKE_PPID_COMM:-}" ]; then …` は 1587 行と 2472 行にあるが、コメントの文面が違う（`762ab07b`、#550）。スクリプトは marker で SKIP せず、`gate_old` の assert で失敗する | 削除候補 |
| `scripts/apply-task-0129-schema.sh` | `schemas/c3-approval.schema.json` | BASE のまま | 冪等判定 `review_decision`=0（履歴 0 件） | 要 Human 確認 |
| `scripts/apply-task-0129-wc.sh` | `.claude/rules/working-context.md` | 生成後＝適用済み | 冪等判定 `C1-LOOP-01`=1 | 削除候補 |
| `scripts/apply-task-0130-working-context.sh` | `.claude/rules/working-context.md` | BASE のまま | 冪等判定 `Stop Condition / Resume Condition / Replan Triggers`=0（履歴 0 件）。ANCHOR `- Testing Strategy（Unit / Integration / E2E / Verification Automation）`=1 | 要 Human 確認 |
| `scripts/apply-task-0134-progress.sh` | `bin/plangate` | 生成後＝適用済み | 冪等判定 `_rp_progress`=2 | 削除候補 |
| `scripts/apply-task-0141-eh2-strict.sh` | `scripts/hooks/check-c3-approval.sh` / `scripts/hooks/check-plan-exists.sh` | 生成後＝適用済み | 新ブロックの識別子 `_eh2_stdin`=5、`PYC3`=2（check-c3-approval.sh）。`_eh1_stdin`=5（check-plan-exists.sh） | 削除候補 |
| `scripts/apply-task-0143-eh457-wiring.sh` | `bin/plangate`（`scripts/_apply_task_0143_patches.py` 経由） | 生成後＝適用済み | P1_NEW `Checking EH-4: test-cases.md present`=1、P2_NEW `Checking EH-5: verification evidence present`=1、`check-verification-evidence`=3 | 削除候補（`_apply_task_0143_patches.py` も同時に） |
| `scripts/apply-task-0144-c3-mode.sh` | `schemas/plangate-config.schema.json`（新規）/ `schemas/c3-approval.schema.json` / `scripts/hooks/check-plan-hash.sh` / `bin/plangate`（`_apply_task_0144_patches.py` 経由） | 生成後＝適用済み | config schema が存在する。`C3_CONVERSATION_SKIP`=4（hook）、`=== C-3 Approval Mode ===`=1、BIN_5_NEW の行=1（bin）。`c3-approval.schema.json` の C3_NEW は個別に照合していない | 削除候補（`.py` も同時に） |
| `scripts/apply-task-0145-ehs-wiring.sh` | `bin/plangate`（`_apply_task_0145_patches.py` 経由） | 生成後＝適用済み | P1_NEW `EHS-1 (TASK-0145 / #527): validation_bias=strict は V-3 合格を必須化`=1 | 削除候補（`.py` も同時に） |
| `scripts/apply-task-0147-bias-export.sh` | `bin/plangate` / `.claude/agents/workflow-conductor.md`（`_apply_task_0147_patches.py` 経由） | 生成後＝適用済み | `--profile=*) profile_flag=`=1、`_handoff_profile=""`=1、`## validation_bias の供給（TASK-0147 / #527・非強制の補足）`=1 | 削除候補（`.py` も同時に） |
| `scripts/apply-ui-v1-crossref.sh` | `.claude/rules/mode-classification.md` | 生成後＝適用済み | 冪等判定 `UI 変更時の visual evidence 規約」（#797）`=1 | 削除候補 |
| `scripts/apply-workflow-hygiene.sh` | `.github/workflows/` の 6 本（check-pr-issue-link / codeql / metrics-privacy / release-docs-sync / schema-validate / slsa-attestation） | 生成後＝適用済み | 6 本とも `timeout-minutes:`=1、`concurrency:`=1。check-pr-issue-link.yml の `pull-requests: write`（先頭に空白 6 つ）=1（(C) の適用済み判定）。冪等判定はジョブ単位だが、件数はファイル単位で数えた | 削除候補 |

## 対象外（grep に一致するがスクリプトではないもの）

| パス | 種別 | 扱い |
|------|------|------|
| `docs/working/TASK-1089/evidence/apply-script-guards-results.txt` | 実行結果の証跡 | 対象外（完了資産として残置） |
| `docs/working/TASK-1089/evidence/apply-script-guards.sh` | 検証用スクリプトの証跡（`apply-*` 本体ではない） | 対象外（完了資産として残置） |
| `docs/working/TASK-1093/evidence/apply-dryrun-matrix.txt` | dry-run 結果の証跡 | 対象外（完了資産として残置） |

## 判定不能と、照合しきれていない箇所

- **判定不能**: `apply-claude-settings.sh` だけ。対象の `.claude/settings.json` が追跡外のため
- **照合が部分的なもの**（状態の判定は表のとおりだが、すべての patch は見ていない）
  - `apply-eh-git-destructive-guard.sh`: ローカルの `.claude/settings.json` 側
  - `apply-task-0123-patches.sh`: patch 2〜4 のアンカーが残っているか
  - `apply-task-0144-c3-mode.sh`: `c3-approval.schema.json` への C3_NEW
- 「生成後」は、スクリプト自身の冪等判定（marker）で判定した。生成後の全文がバイト単位で一致することまでは確かめていない
