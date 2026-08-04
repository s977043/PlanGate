# AGENT_LEARNINGS.md

> このファイルは、Codex がこのリポジトリで再利用できる知見だけを蓄積するための記録先。

## 目的

- 次回以降の作業でそのまま使える、検証済みの知見を残す
- プロジェクト固有の事実、運用上の注意、再現可能な手順を集約する
- 一時メモや作業ログを増やさず、学びの再利用性を保つ

## 書いてよいもの

- 実際に確認できたコマンド、ファイル配置、実行入口
- 何度も繰り返し使う判断基準や例外ルール
- 既存構成に合わせるための具体的な補足
- secrets や個人情報を含まない、共有可能な運用知見

## 書かないもの

- その場限りのメモ、進捗、未確定の仮説
- タスク固有で再利用できない詳細
- secrets、API キー、認証情報、個人情報
- README や AGENTS.md と重複するだけの内容

## 記録ルール

1. 1件につき 1つの再利用可能な知見だけを書く
2. 事実ベースで短く書く
3. その知見を「いつ再利用するか」を明示する
4. 不確実な内容は書かず、確認後に追記する
5. 内容が古くなったら上書きし、履歴を膨らませすぎない

## 記録フォーマット

```md
- [YYYY-MM-DD] 見出し
  - 事実:
  - 再利用条件:
  - 根拠:
```

## 運用メモ

- このファイルは学びの保管庫であり、作業日誌ではない
- 迷ったら「次回の Codex がそのまま使えるか」で判断する

## 学び

- [2026-05-16] PR 後処理の破壊操作はマージ確定検証の後だけ
  - 事実: 「マージした」発言を信用しマージ未確定のまま `git push origin --delete` を実行し PR #240 を未マージ CLOSE させた（reopen で復旧、作業ロストなし）
  - 再利用条件: PR のローカル/リモートブランチ削除・cleanup を行う前に必ず `sh scripts/verify-pr-merged.sh <PR>`（state==MERGED かつ mergedAt/mergeCommit non-null）で確定検証する
  - 根拠: GitHub は head ブランチ削除時に未マージ PR を自動 CLOSE する。単独運用 repo はブランチ保護で BLOCKED が常態化し「押したが通っていない」が起きやすい

- [2026-05-16] マージブロック時にバイパスしない
  - 事実: ブランチ保護でマージ不能時に admin override / 別アカウント承認（sock-puppet）を試行し auto-classifier と運用方針で都度ブロックされた
  - 再利用条件: マージが BLOCKED のとき、agent はバイパス（--admin / 別アカウント承認 / ruleset 改変）を行わない。状況を報告しユーザーの GitHub Web 正規操作に委ねる
  - 根拠: ブランチ保護は意図的セーフガード。workflow 上の C-4 APPROVE は GitHub の formal approving review とは別物

- [2026-05-16] workflow-conductor は top-level 起動が前提（**TASK-0072 で恒久対処済 / 下記に更新**）
  - 事実: `/ai-dev-workflow exec` が conductor を subagent 起動 → Task ツール不可で implementer 委譲が破綻
  - 再利用条件（更新後）: exec router（`/ai-dev-workflow exec`）が conductor 起動**前**にサブエージェント起動（`Agent`/`Task`）可否をツール存在検査で判定する。委譲可能なら conductor 起動、不可/判定不能なら conductor を起動せず **direct-implementer-mode**（router 自身が implementer。C-3/plan_hash/allowed_files/V-gates/C-4 は不変）。「subagent 検知→停止→メイン代行」という旧手動回避は撤廃
  - 根拠: Task is not available inside subagents。判定主体を conductor 内から router 層へ移し、フォールバックを正規フロー化（core-contract §5-bis / contracts/execute.md / #237 #238 #239 #234-E / TASK-0072）

- [2026-05-22] PlanGate setup 機能（`/plangate-setup`）は Claude Code と Codex CLI の両環境で動作可能
  - 事実: `.claude/{commands,agents,skills}/plangate-setup*` (Claude Code) と `.agents/skills/plangate-setup/SKILL.md` + `.codex/agents/setup_coordinator.toml` (Codex CLI) の二重配置。共用 skill 正本は `.agents/skills/plangate-setup/SKILL.md`。設計原則（Iron Law: AI は提示のみ / doctor 単一検証源 / Workflow-owned 永続ロック）は両環境で同一
  - 再利用条件: 責務境界が曖昧な setup 系 PBI で、Human-owned 操作の追跡が必要な場合の参照実装。三層構成（Command + Agent + Skill）の責務分離パターンとして転用可能
  - 根拠: TASK-0107 (PR #312 / #313 / #316 merged), `docs/working/TASK-0107/handoff.md` / `contract-notes.md`

- [2026-06-16] 承認境界機構は「best-effort 多層防御」と「物理 block」を区別して表現する
  - 事実: `plangate approve` の L1-L4 (isatty/env/ppid/nonce) を当初「AI 自己承認を物理的に封じる」と記述したが、疑似 TTY を持つ自動化が表示 nonce を読んで応答すれば突破可能と Codex レビューで判明。docs を best-effort へ訂正し out-of-band 化を #550 に隔離
  - 再利用条件: 承認/認証/ガード機構を説明する際、「絶対防御(物理 block)」と「best-effort(多層・抑止)」を必ず区別する。絶対表現は「agent が観測・応答できない out-of-band 操作」(署名鍵/keychain/GitHub Approve)に限る
  - 根拠: #546 approve / Codex review / #550 #553 設計ノート。auto-mode classifier も AI 名義の承認トークン発行を impersonation として拒否(二層 governance)

- [2026-06-16] push 前にマージ削除済ブランチの再作成を確認する
  - 事実: #558 マージ後に追加修正をローカル旧ブランチ(`feat/render-flow-diagram-548`)へ commit→push し、マージ削除済ブランチを誤再作成。cleanup + follow-up PR #561 の手戻り
  - 再利用条件: マージ済 PR の後に追加修正が出たら、旧ブランチを使わず `git checkout -b fix/<topic> origin/main` で main 起点に切り直す。push 前に `sh scripts/check-branch-not-merged.sh` で「現ブランチが MERGED+remote削除済」を検知
  - 根拠: 既存学び[2026-05-16 PR後処理]の延長(マージ確定検証)。本セッションで guard script を新設

- [2026-07-12] checkout/restore でファイルを戻す前に「自分が作った変更か」を確認する
  - 事実: Human が適用済みの未コミット HO 変更（`apply-subagent-delegation-wiring.sh` による 4 ファイル追記）が作業ツリーに残る状態で、AI が該当 4 ファイルに対し `git checkout main -- <path>` を実行し Human 適用済み変更を上書き消失させた（Human にスクリプト再実行を依頼して復旧）
  - 再利用条件: `git checkout [<branch>] -- path` / `git restore [--source <ref>] path` 等、ファイルを既存 ref の内容へ戻す操作の前に、対象ファイルの未コミット差分を `git diff path` で確認し、「自分が作った変更でない」場合は上書きしない（既存学び「名指し外 tracked 変更は破棄しない」の checkout -- path 形への拡張）
  - 根拠: 2026-07-12 セッション実害。既存 rule（`.claude/rules/responsibility-classes.md` HO 適用は Human-owned）と一貫

- [2026-07-12 初出 / 2026-08-02 追記] ブランチ作成失敗後の commit・破壊的操作は current branch を必ず verify する
  - 事実: `set -e` 付き複合コマンド内で `git checkout -b <branch> origin/main` が untracked ファイル衝突で失敗した後、後続の `git add`/`git commit` が main 上で実行され main へ直接コミットが作られた（push 前に検知し branch 退避 + `reset --hard origin/main` で復旧）
  - 事実（2026-08-02 追記 / 同型再発）: `git checkout -q <branch> 2>/dev/null || git checkout -q -b <branch> origin/<branch>` の**両側が失敗**（同名ブランチ既存で `-b` が `fatal: already exists`）したが、`||` で連結したため `set -e` が発火せず次行の `git reset --hard -q origin/<branch>` が main 上で実行された。ローカル `main` が別コミットへ移動し、**他セッションの未コミット変更（tracked ファイル）が破棄**された（`git fsck --lost-found` の dangling blob から復旧できたが、stage されていなければ完全に失われていた）
  - 再利用条件: ブランチ作成と後続の変更操作（`git add` / `git commit` 等）を同一複合コマンドに含める場合、最初の変更操作の直前に `[ "$(git rev-parse --abbrev-ref HEAD)" = "<expected>" ] || exit 1` を必ず挟む
  - 再利用条件（2026-08-02 追記 1・`||` フォールバックは `set -e` を無効化する）: `A || B` の形は A の失敗を `set -e` の対象外にするため、B も失敗したときに**エラーが後段へ伝播せず次行が実行される**。checkout をフォールバック付き（`||`）で書く場合、その同じコマンド列に破壊的操作（`git reset --hard` / `git push --force` 等）を**含めない**。なお上記 verify 行の `|| exit 1` は「失敗時に明示 exit する」ための意図的な `||` であり、この禁止に該当しない（verify 行はそのまま維持する）
  - 再利用条件（2026-08-02 追記 2・破壊的操作は verify と実行を分ける）: `git reset --hard` / `git push --force` 等の**非可逆操作**は、branch verify と同一コマンド列に詰め込まず、**verify の出力を確認した次のステップで実行する**。`git add` / `git commit` は「作るだけ」で復旧が容易だが、`reset --hard` は他セッションの未コミット変更まで巻き込むため被害が非可逆になる
  - 根拠: INC-2026-05-26-001 P-3（push 前 verify）の commit 前 verify への拡張。`.claude/rules/responsibility-classes.md` の Bash 連結コマンド error guard と一貫（同節 1「`&&` で連結する」/ 2「`set -e` を冒頭に書く」/ 3「`git push` 前に必ず current branch を verify」を、`||` フォールバックと破壊的操作へ適用した具体化）。2026-08-02 セッションで同型事故が再発したため既存エントリを補強。ファイル単位で戻す操作（`git checkout -- path` / `git restore`）は既存学び［2026-07-12 checkout/restore］が扱い、本エントリはブランチ単位の破壊的操作を扱う

- [2026-06-16] Bash 作成 doc の EH-3 skip は merge 前に追認する
  - 事実: #544 系 doc(rev.3 AEE / TASK-0130)を未追認の EH-3 skip エントリ付きでマージし main CI(`SKIP_REASON 追認`)が累積 RED(1→2)。main 赤は新規 PR 全てに波及
  - 再利用条件: Bash heredoc で discussions/ 等の doc を作り EH-3 skip を手動記録した場合、PR マージ前に `python3 scripts/batch-acknowledge-skip-decisions.py --apply --acknowledged-by <human>`(acknowledged_by は人間専任)で追認を済ませる。根治は #528 doc-light(skip 自体を出さない)
  - 根拠: 本セッション #560/#562。check-skip-acknowledged.sh が CI required

- [2026-06-16] 達成に人間操作必須の目標を /goal に設定しない
  - 事実: 「ロードマップ(PR merge/HO 適用/C-3 承認 含む)完了」を /goal に設定したが、これらは承認境界ガバナンスで AI が代行不可。Stop hook が達成不可能条件を待ち ~9 回空回りし harness が強制終了
  - 再利用条件: /goal の条件は「AI が単独完結できる範囲」に限定する。人間の merge/HO 適用/C-3 承認/監査追認を含む条件は goal にしない(構造的に満たせず Stop hook が空転)。設定済なら `/goal clear`
  - 根拠: 本セッション。harness 通知「check stop_hook_active」「CLAUDE_CODE_STOP_HOOK_BLOCK_CAP」。responsibility-classes(merge/HO/承認は人間専任)

- [2026-06-16] HO ファイルの小修正は 1 回の apply-script に集約する
  - 事実: approve/render の bin/plangate(HO)修正が小刻みに発生し、その都度 apply-script 作成→人間再適用の往復が増えた
  - 再利用条件: HO ファイル(bin/plangate/settings/hooks)への修正は、レビュー指摘を1ラウンド束ねてから 1 つの apply-script にまとめ、人間の再適用回数を最小化する。レビュー前に self-review/Codex で先回り検出して往復を減らす
  - 根拠: 本セッション #552/#555/#558 系の HO 再適用

- [2026-06-22] コミット author 書き換えは /tmp へ fresh clone してから実行する
  - 事実: 元のローカルリポジトリ（non-fresh clone）に対し `git filter-repo` を実行すると「Parsed 1 commits」しか処理されず書き換えが行われない（既に filter 済みと判断されるため）
  - 再利用条件: author/committer 書き換えが必要な場合は (1) `/tmp` に fresh clone、(2) `--commit-callback` で email ベースで書き換え、(3) 実行後 remote が自動削除されるので `git remote add` を再実行、(4) push は `--force`（`--force-with-lease` は SHA 不一致で拒否される）、(5) force push は Human-owned（branch protection 解除が必要）
  - 根拠: 2026-06-22 kominem-unilabo → s977043 書き換え作業。filter-repo の「already filtered」スキップ仕様による失敗から確立

- [2026-08-04] EH-3 で Edit/Write がブロックされたときの経路は「起動時 env > インライン SKIP_REASON > Bash 直書き」の順
  - 事実: EH-3 (check-plan-hash.sh) の matcher は `Edit|Write` のみで Bash には未配線。`PLANGATE_HOOK_TASK` 未設定だと非 plan.md でも「SKIP 拒否: SKIP_REASON 未設定」で止まり、**パス非依存**（repo 外・scratchpad への Write も止まる）。後から spawn したサブエージェントにも波及する。Bash 経由は hook が発火しないので通るが、**skip-decision-log に記録が残らない**
  - 再利用条件: (1) まず `PLANGATE_HOOK_TASK=TASK-XXXX claude` で起動し直す（plan.md 新規作成も通る唯一の経路・監査面でも最良）。(2) 起動し直せないときは `PLANGATE_SKIP_REASON='<理由>' <書込コマンド>` のインライン形式＋対象を名指しした承認（skip-log に残る）。(3) Bash 直書きは HO 非対象に限り、記録が残らないことを明示したうえで使う。加えて**承認境界の配線変更と、同セッションで続く編集作業を並べない**
  - 根拠: 2026-06-22 Codex スキル追加時は (3) で解決／2026-08-04 apply-claude-settings.sh 適用後にメイン・サブエージェントとも全 Edit/Write が block され、PR #986 の CI 修正が適用できずセッション再起動が必要になった

- [2026-06-22] リリース前に Plugin キャッシュ同期チェックを実行する
  - 事実: `scripts/sync-plugin-installed.sh` を `release-prep.sh` に組み込み、Claude Code プラグインキャッシュ（`~/.claude/plugins/`）と Codex スキル（`~/.codex/skills/`）の同期状態をリリース前チェックの 1 項目として自動検出する。`--dry-run` オプションで差分のみ確認可能
  - 再利用条件: リリース前（`sh scripts/release-prep.sh` 実行時）に「plugin インストール済みキャッシュ同期済み」が NG なら `sh scripts/sync-plugin-installed.sh` を実行する。差分なし時は `[sync-installed] no-op` を出力して正常終了
  - 根拠: 2026-06-22 セッション。Claude Code プラグインキャッシュ 13 ファイル乖離・Codex スキル 9 件不足を発見し自動化（PR #597）

- [2026-07-12] squash-merge されたPRのブランチから新ブランチを切ると必ずコンフリクトする
  - 事実: PR #824（D-2）が squash-merge された後、そのブランチ起点で作った #825（D-3）が `rebase --onto` でコンフリクト（squash されたコミット群と個別コミットが同一内容でも別 SHA 扱いになるため）。パッチ抽出（`git diff <base>..<head> -- <files> | git apply`）で新ブランチに適用し直して解決
  - 再利用条件: 前提 PR がまだマージされていないブランチから派生作業を始める場合、必ず `git fetch origin main` 後の `origin/main` 起点で新ブランチを切る。既に squash-merge 済みの旧ブランチから派生してしまった場合は、rebase でなく実差分のみパッチ抽出して新ブランチに適用する
  - 根拠: 2026-07-12 EPIC #822 discovery D-3 実装時（PR #825→#826）

- [2026-08-04] 全体量化子を含む AC の鮮度は「接触ファイル交差 0」では担保できない
  - 事実: TASK-0914 の handoff は「main 前進とブランチ接触 48 ファイルの交差 0」を V-1 PASS の鮮度根拠にしていたが、AC-9（`FIXTURES_DIR` 単独判別の残存 0）はリポジトリ全体の不変条件で、main 側が無関係な extras を 1 本追加するだけで破れる。実際 ta-58(#967) / ta-59(#976) が入って破れ、PR #986 の CI 2 failed の実体になった
  - 再利用条件: AC に「すべて / 残存 0 / 一本化 / 全件」等の全体量化子が含まれるなら、鮮度判定に差分ベース（接触ファイル交差・変更ファイル一覧）を使わない。base 更新のたびに機械ゲートを再実行して判定し、plan / handoff に「この AC は全体不変条件であり base 更新ごとに再実行が要る」と明記する
  - 根拠: 2026-08-04 PR #986 敵対レビュー。TC-33 という機械ゲート自体は正しく検知しており、壊れていたのは鮮度推論のほう

- [2026-08-04] CI / テスト / bot の指摘も「名指しされた対象」が真因とは限らない
  - 事実: TC-33 が特定ファイルの `unset` 欠落 4 件を名指ししたが、そのファイルは 7 env すべて unset 済みで、真因は検査側パーサが行継続（`\`）を読まないことだった。字面どおり unset を足すと既存 unset を重複させる誤修正になる
  - 再利用条件: 機械の指摘でも、修正着手前に「その判定を出したロジック」を読む。とくに静的検査が特定ファイルを名指ししたときは、検査側の抽出規則が対象ファイルの記法（行継続・複数行・コメント）を扱えるかを先に確認する
  - 根拠: 2026-08-04 PR #986 の CI FAIL 診断。既存学び「ワーカー報告の症状は真・原因帰属は誤りうる」の機械指摘版
