# Hook Enforcement — runtime で強制すべき不変条件

> **Status**: v5（**Implementation: 10/10 hooks Done — #169 完走** — #157 で 3 hook、#169 セッション A で 2 / B で 3 / C で 2 = 計 10 hook、3 mode 設計）
> **Hook 数の現状（v8.7.0 以降）**: 本書は **v8.5.0 時点の 10/10 hooks** スナップショット。
> v8.6.0 で **EH-8**（`check-metrics-privacy.sh`、metrics privacy 強制）、
> v8.7.0 で **EH-9**（`check-delegation-commit-boundary.sh`、TASK-0073 F2）を追加し、
> 現状は **EH-1〜EH-9 + EHS-1〜EHS-3 = 12/12**（+ **EH-12 / EH-13**（追加分・別記、下記注記参照））。本書本文の表は v8.5.0 構成のまま
> 維持し、追加分の詳細はそれぞれの実装 PR / CHANGELOG / `bin/plangate doctor` 出力を参照。
>
> **EH-12（追加・配線は Human apply 待ち）**: protected branch 上の破壊的 git 操作
> block（`check-git-destructive.sh`）。**hook 本体（非 HO の `scripts/` 直下）は
> 実装・テスト済み**だが、PreToolUse 配線は
> `scripts/apply-eh-git-destructive-guard.sh --apply`（**Human-owned**）の実行後に
> 有効化される。番号は **EH-10 / EH-11 が既に予約済み**（#760 PostToolUse 軽量品質
> チェック / #762 Stop 軽量 verify の「候補」名として
> [`.claude/settings.example.json`](../../.claude/settings.example.json) のコメントで使用、
> かつ EH-10 は [`docs/rfc/ai-self-set-gate-hook-enforcement.md`](../rfc/ai-self-set-gate-hook-enforcement.md)
> の RFC Draft が保持）のため、衝突しない最小の空き番号として **EH-12** を採番した。
>
> **EH-13（採番のみ・配線済み）**: 承認トークン直書き block
> （[`scripts/check-approval-token-write.sh`](../../scripts/check-approval-token-write.sh)、TASK-0123 で導入・TASK-1023 #1023 で
> fail-closed 化）。`settings-wiring-contract.md` 旧記載の「EH-10」は上記予約
> （#760 / #762）と衝突していたため、TASK-1023 G-6（Human 裁定 2026-08-10）で
> 衝突しない最小の空き番号 **EH-13** へ改番した。

> **実装と物理配線の区別（2026-06-10 棚卸し / 2026-06-27 更新）**: 12/12 は
> 「スクリプト実装 + 単体テスト済み」を指す。**発火経路（settings.json /
> .codex/hooks.json / CI / bin/plangate）への物理配線は 11/12**（PreToolUse/CI 配線 6
> + `bin/plangate` CLI 配線 5 = EH-4 / EH-5 / EHS-1 / EHS-2 / EHS-3。EH-7 のみ
> doctor 可視化 + 手動推奨）。残る配線の完全化は
> [#500 Wiring Integrity Enforcement](https://github.com/s977043/plangate/issues/500)
> （仕様策定済み）の実装範囲。
>
> ⚠️ **上記の「物理配線」は Claude Code 側（`.claude/settings*.json`）を数えた値であり、
> `.codex/hooks.json` を配線済みとして数えてはならない（#1078 実測 2026-08-13）**:
> `.codex/hooks.json` は top-level の仕様外キーにより **JSON 全体が parse 拒否**され、
> **Codex 側の hook 登録は 0 件**（`hooks/list` 実測）。**EH-1/2/3/6/9 は Codex
> セッションで一度も発火していない**。本注記の「発火経路」列挙に
> `.codex/hooks.json` を含めるのは**現時点では誤り**である。
> 正本: [`settings-wiring-contract.md`](./settings-wiring-contract.md) §Codex CLI parity。
> **一般則**: 配線の記述件数を「配線済み」と数える運用は、今回と同型の silent failure
> （設定は正しいがランタイムが受理していない）を見逃す。**ランタイム側の登録状態を
> 問い合わせた証跡**を伴って初めて配線済みと数えること。
>
> **発火条件の供給（EPIC #527 follow-up・配線済み）**: EHS-1/2/3 の発火条件
> `PLANGATE_VALIDATION_BIAS=strict` は、`bin/plangate verify` / `handoff --verify` が
> `--profile <key>` を受理し `model-profiles.yaml` の `validation_bias` を解決して内部
> export する（TASK-0147 / #644 で配線・適用済み）。env で明示注入済みなら尊重し、
> normal/lenient profile・無指定では非発火（既存挙動不変）。未知 key / yaml 欠落時は
> normal fallback + stderr 警告（[`scripts/_resolve_validation_bias.py`](../../scripts/_resolve_validation_bias.py)）。
>
> | 配線状態 | Hook | 発火経路 |
> |---------|------|---------|
> | ✅ 配線済み（6） | EH-1 / EH-2 / EH-3 / EH-6 / EH-9 | Claude PreToolUse ~~+ Codex hooks.json~~（**Codex 側は登録 0 件・未発火 / #1078**） |
> | | EH-8 | CI（metrics-privacy.yml）+ doctor + codex-guarded |
> | ✅ CLI 配線（5、apply 後） | EH-4 / EH-5 | `bin/plangate verify` —EH-4: V-1 前 strict / EH-5: V-1 後 warn（TASK-0143） |
> | | EHS-1 | `bin/plangate verify` —V-3 不合格時に `validation_bias=strict` で block（TASK-0145 増分1） |
> | | EHS-3 | `bin/plangate verify` —V-1 FAIL 時に fix-loop increment + `validation_bias=strict` で上限超過 block（TASK-0146 増分2） |
> | | EHS-2 | `bin/plangate handoff --verify` —handoff.md 6 要素不足を `validation_bias=strict` で block（TASK-0146 増分3） |
> | ⏳ doctor 可視化のみ（1） | EH-7 | `bin/plangate doctor` CLI Hook Wiring セクション + 手動推奨（#500 後続） |

> 関連: [`responsibility-boundary.md`](./responsibility-boundary.md) / [`tool-policy.md`](./tool-policy.md) / [`model-profiles.md`](./model-profiles.md)
> 実装: [`scripts/hooks/check-plan-exists.sh`](../../scripts/hooks/check-plan-exists.sh) / [`check-c3-approval.sh`](../../scripts/hooks/check-c3-approval.sh) / [`check-plan-hash.sh`](../../scripts/hooks/check-plan-hash.sh) / [`check-test-cases.sh`](../../scripts/hooks/check-test-cases.sh) / [`check-verification-evidence.sh`](../../scripts/hooks/check-verification-evidence.sh) / [`check-forbidden-files.sh`](../../scripts/hooks/check-forbidden-files.sh) / [`check-merge-approvals.sh`](../../scripts/hooks/check-merge-approvals.sh) / [`check-v3-review.sh`](../../scripts/hooks/check-v3-review.sh) / [`check-handoff-elements.sh`](../../scripts/hooks/check-handoff-elements.sh) / [`check-fix-loop.sh`](../../scripts/hooks/check-fix-loop.sh)
> 設定例: [`.claude/settings.example.json`](../../.claude/settings.example.json) / 単体テスト: [`tests/hooks/run-tests.sh`](../../tests/hooks/run-tests.sh)

## 0. 運用モード別の強制実態（CLI 依存度 / 2026-06-28 現状把握）

> 各強制は「いつ発火するか」が経路ごとに異なる。とくに **CLI（`bin/plangate`）を
> 通さない運用では、CLI 層の強制（EH-4 / EH-5 / EHS-1/2/3）は一度も発火しない**。
>
> **「ローカル強制」の前提に注意**: 層 A（Claude PreToolUse）/ 層 E（Codex hooks）は
> **Claude Code / Codex などの AI ツールを介して編集・コミットしたときのみ**ローカル発火する。
> エディタで直接ファイルを編集して `git` で直接コミットする**完全手動運用では層 A/E も
> 発火しない**（その場合の最終防壁は層 B の CI = PR/push トリガー）。以下の「手動 / AI 任せ」は
> 主に「AI ツールは使うが `bin/plangate` CLI は回さない」運用を指す。

### 発火層の分類

| 層 | 強制 | 発火契機 | CLI を使わない運用での実態 |
|----|------|---------|--------------------------|
| **A. Claude PreToolUse**（自動・bypass 不能）| EH-1 / EH-2 / EH-3 / EH-6 / EH-9 + **EH-13**（承認トークン直書き block / TASK-0123・TASK-1023）+ **EH-12**（apply 後）| Edit / Write / Bash のたび | ✅ 常時発火 |
| **B. CI**（自動・bypass 不能）| EH-8（metrics privacy）/ settings drift / schema-validate / skip-ack / pr-issue-link | PR / push | ✅ 常時発火 |
| **C. CLI**（`bin/plangate` 実行時のみ）| EH-4 / EH-5 / **EHS-1 / EHS-2 / EHS-3** | `verify` / `handoff --verify` を**実行したときだけ** | 🔴 **休眠**（CLI 未実行なら不発） |
| **D. 外部設定**| EH-7（マージ 2 段階レビュー）| main へのマージ | 🔶 GitHub branch protection 設定に依存（Human-owned admin）|
| **E. Codex hooks**| EH-3 / check-script-basename | Codex セッション中の apply_patch / Bash 等 | （Claude Code 運用では非該当）|

### 含意

- **承認境界（plan 未作成 / C-3 未承認 / plan_hash 改竄 / scope 逸脱 / 委譲境界）は
  CLI を使わなくても 100% 強制**される（層 A）。
- **検証品質ゲート（EH-4 / EH-5 / EHS-1 / EHS-2 / EHS-3）は CLI 駆動が前提**。
  手動 / AI 任せ運用では休眠する（層 C）。EHS-1/2/3 は配線済み（TASK-0145/0146/0147）
  だが、`bin/plangate verify` / `handoff --verify` を回さなければ実効しない。
- **マージ保護（EH-7）はリポジトリの branch protection 設定次第**（層 D）。

> 休眠ゲートを CLI 非依存で常時強制したい場合の選択肢（PR トリガーの CI 移植など）は
> 別途設計判断（新規 PBI / EPIC #527 の後続）とする。本節は現状把握であり方針は未確定。

## 1. 目的

PlanGate の **Iron Law のうち runtime 強制可能な不変条件**（現状 #1〜#7 相当）を、プロンプトに頼らず **runtime で決定論的にブロック** する。プロンプト薄型化（PBI-116-01 で達成）と両立して、強制力を維持する。なお Iron Law #8（出典照合）は決定論的 hook 化が困難なため、プロンプト + diff-audit（旧 self-review、ソフト面）で担保し runtime hook の対象外とする。

## 2. 強制すべき不変条件（一覧）

[`responsibility-boundary.md`](./responsibility-boundary.md) § 5 と整合。最低 6 件:

### EH-1: plan.md なし production code 編集ブロック

- **トリガー**: `docs/working/TASK-XXXX/plan.md` が存在しない状態で、production code（CLAUDE.md / AGENTS.md / `docs/ai/` / `.claude/` / `bin/` / `schemas/` / `plugin/` 等）を編集しようとした
- **対応**: Hook が即 block。「plan.md を作成してください」とユーザーに通知
- **基盤**: Iron Law #1（C-3 承認前 production 編集禁止）+ #5（承認済 plan との整合性）

### EH-2: C-3 承認なし exec ブロック

- **トリガー**: `approvals/c3.json` の `c3_status: APPROVED` がない、または存在しない状態で `exec` フェーズに進もうとした
- **対応**: Hook が即 block。Child C-3 ゲートを促す
- **基盤**: Iron Law #1（C-3 承認前 production 編集禁止）

### EH-3: plan_hash 改竄検知

- **トリガー**: `approvals/c3.json` 発行後、`plan.md` が変更されたが `c3.json` の `plan_hash` が更新されていない
> **#282 / TASK-0105 ハードニング**: c3.json の plan_hash 抽出を寛容
> `sed` から **strict JSON 解析**（`scripts/plan_hash_util.recorded_plan_hash`
> と意味一致）へ変更。不正 JSON / 非 object / prefix 不一致の c3.json は
> 承認記録として**信用せず空＝SKIP**（旧 sed は不正でも plan_hash を抽出し
> 比較続行＝不正記録を承認境界の根拠にしていた）。**承認境界はより厳格化
> ＝安全側**。正常系（PASS）・改竄検知（BLOCK）の挙動は不変（回帰なし）。

- **対応**: Hook が次の operation を block。再承認を要求
- **基盤**: Iron Law #5（承認済 plan と実装差分の整合性）

> **⚠️ 既知の制限 — Hardening Override は `PLANGATE_HOOK_TASK` 設定時に発火しない（#1089 / patch 未適用）**
>
> EH-3 は plan_hash 検知に加え **Hardening Override（HO）9 カテゴリの常時 block**
> （正本: [`.claude/rules/mode-classification.md`](../../.claude/rules/mode-classification.md)
> 承認境界周辺の変更節）を担う **唯一のガード**である
> （`check-forbidden-files.sh` は HO パスを守らない）。しかし現行実装では
> HO 判定が `task_id` 未設定分岐の内側にあるため、**`PLANGATE_HOOK_TASK` が
> 設定されたセッションでは 9 カテゴリすべてが block されない**（実測 9/9 で
> `rc=2 → rc=0`）。`PLANGATE_HOOK_TASK` は `plan.md` 編集の正規経路であり、
> **PlanGate 作業中のセッションこそ HO 保護が外れる**。
>
> - **是正の適用（Human-owned）**: `sh scripts/apply-eh3-ho-always.sh --dry-run` →
>   `--apply`（冪等 / アンカー検証つき。hook 変更 + 正本の行番号アンカー除去 +
>   KNOWN-GAP 宣言の削除を 1 オペレーションで行う）。参考差分は
>   `docs/working/TASK-1089/patches/check-plan-hash.ho-always.patch`
> - 回帰テスト: `tests/extras/ta-65-eh3-ho-task-context.sh`。**期待値の既定は
>   「TASK 文脈でも block される」**で、gap の受理は
>   `tests/fixtures/eh3-known-gap-1089.flag` という明示 opt-in を要する。
>   適用後にコードが元の構造へ戻ると CI が RED になる
> - `.claude/settings*.json` は Claude Code 自身の self-mod ガード（harness 層）でも
>   守られるが、**残る 8 カテゴリに同等の別ガードは確認されていない**
> - **適用後も「常時 block」は文字どおりには成立しない**: `docs/../CLAUDE.md`（`..` 未解決）/
>   `CLAUDE.MD`（大小文字）/ `"CLAUDE.md "`（末尾空白）の正規化は未実装で通過する
>   （未適用の no-task 経路でも同じ挙動。#1089 が作った穴ではない）。ta-65 TC-07 が
>   KNOWN-GAP として固定しており、塞いだ時点で RED になる。**別 PBI 候補**
>
> **本注記の退役条件**: 上記 apply スクリプトの適用後は本注記ブロックを削除し、
> EH-3 の説明を「HO は TASK 文脈の有無に依らず常時 block（正規化の穴を除く）」へ
> 更新すること。削除し忘れても ta-65 は fixed を要求するため CI は正しく動く。

### EH-4: test-cases.md なし V-1 ブロック

- **トリガー**: V-1（受入検査）を試みたが `test-cases.md` が存在しない
- **対応**: Hook が即 block
- **基盤**: Iron Law #3（検証証拠なし完了禁止）

### EH-5: 検証ログなし PR 作成ブロック

- **トリガー**: `evidence/verification.md` または同等のログがないまま子 PR を作成しようとした
- **対応**: Hook が PR 作成を block
- **基盤**: Iron Law #3（検証証拠なし完了禁止）

### EH-6: scope 外ファイル編集検知

- **トリガー**: 子 PBI YAML の `forbidden_files` に該当するファイルを編集
- **対応**: Hook が即停止
- **基盤**: Iron Law #2（PBI 外 scope 追加禁止）

### EH-7: 2 段階レビューなしマージブロック（推奨）

- **トリガー**: C-3 + C-4 のいずれかが APPROVED でない状態で main へマージ試行
- **対応**: GitHub branch protection / Hook で block
- **基盤**: Iron Law #7（2 段階レビューなしマージ禁止）

### EH-9: 委譲 commit/push 境界検知（F2 / TASK-0073）

- **トリガー**: 委譲タスクが `delegation_commit_boundary: no-commit` を宣言
  （env `PLANGATE_DELEGATION_NOCOMMIT=1`）した文脈で git commit / git push 試行
- **対応**: **default=block**（bypass・未宣言のみ従来動作=誤検出ゼロ。warn 廃止）。`git -c`/`-C`/env 前置/`command git`/`gh pr merge`/`sh -c` 等の回避形を網羅。信頼境界=stdin JSON 正本
- **基盤**: #239 問題2（委譲先 Behavior Rule 不遵守）の決定論ガード化

### EH-12: protected branch 上の破壊的 git 操作ブロック

- **トリガー**: **current branch が `main` / `master`** の状態で
  `git reset --hard` / `git push --force`（`-f` / `--force-with-lease` /
  `--force-if-includes` を含む）を実行しようとした
- **対応**: **default=block**。protected 以外のブランチ・detached HEAD・非 git
  ディレクトリでは常に allow（誤検出ゼロ優先）。`PLANGATE_BYPASS_HOOK=1` で常時 pass
- **スクリプト**: [`scripts/check-git-destructive.sh`](../../scripts/check-git-destructive.sh)
  （**`scripts/` ルート = HO 外**。配線は
  [`scripts/apply-eh-git-destructive-guard.sh`](../../scripts/apply-eh-git-destructive-guard.sh)）
- **単一ソース**: `scripts/hooks/` へ**複製しない**。`.claude/settings*.json` から
  `scripts/check-git-destructive.sh` を直接参照する。`scripts/hooks/` は tracked
  （17 ファイル）なので複製すると同一内容の tracked ファイルが 2 つ並び、両者の
  drift を検出する CI も存在しない（#956 の commit 済み drift と同一構造）。
  同方式の先例: [`scripts/check-approval-token-write.sh`](../../scripts/check-approval-token-write.sh)
  / `scripts/gh-pin-account.sh`（いずれも `scripts/` 直下から settings が直参照）。
  副次効果として apply が触る HO は `settings.json` / `settings.example.json` の
  2 ファイルだけになる
- **配線**: PreToolUse `matcher: "Bash"`（apply 後）。信頼境界は EH-9 と同じく
  **stdin JSON `tool_input.command` が正本**、env `PLANGATE_HOOK_CMD` は CLI テスト専用
- **複数行コマンドの扱い（重要）**: Bash tool の command は複数行になりうる。
  抽出時に **`head -1` を挟んではならない**（`jq -r` は JSON の `\n` を実改行へ
  展開するため、2 行目以降＝破壊的操作そのものが捨てられ allow に化ける）。
  実改行 / CR / tab に加え、jq 非搭載時の grep fallback で残る **literal な
  `\n`** も空白へ平坦化してから検査する。これにより `;` `&&` 改行 `\` 行継続
  ・行頭インデント・コメント行・heredoc 本文・CRLF が同一に扱われる。
  **jq あり / なしの両経路を必ずテストすること**（改行バグは jq 経路特有だった）
- **監査**: `docs/working/_audit/hook-events.log` に `class` + `sha256 hash` のみ記録
  （command 全文は記録しない。EH-9 と同方式）
- **基盤 / 出自**: 2026-08-02 の実害。
  `git checkout -q <b> 2>/dev/null || git checkout -q -b <b> origin/<b>` の
  **両側が失敗**（同名ブランチ既存で `-b` が `fatal: already exists`）したにも
  かかわらず `||` 連結ゆえ `set -e` が発火せず、次行の `git reset --hard` が
  **main 上で実行され他セッションの未コミット変更を破棄**した
  （`git fsck --lost-found` の dangling blob から復旧）。同型の学びは
  `AGENT_LEARNINGS.md` に 2026-07-12 から存在したが防げなかったため、
  規範層（[`responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
  「Bash 連結コマンド時の error guard」）を**技術層で補強**する
- **既存ガードとの関係**: pre-push hook（TASK-0114 / #360）は main への直接
  **push** を block するが、**ローカルで完結する `reset --hard` は捕捉できない**。
  EH-12 はその隙間を埋める（Defense in Depth の技術層を 1 段追加）
- **検出対象**: `git reset --hard` / `git push --force|--force-with-lease|
  --force-if-includes|-f` / `git push <remote> +<refspec>`（先頭 `+` の強制更新）
- **既知制約**: ユーザー定義 git alias は解決不能。`git -C <other-repo>` は
  cwd の branch で判定する（安全側＝過剰 block に倒れる）。最初の `git ` 以降を
  一括で見るため `git status; echo "reset --hard"` のような文字列も
  **main 上でのみ**過剰 block しうる（安全側・EH-9 と同じ緩さ）。
  worktree を壊す `git checkout -f` / `git clean -fd` は本 hook の対象外
- **テスト**: [`tests/extras/ta-58-git-destructive-guard.sh`](../../tests/extras/ta-58-git-destructive-guard.sh)
  （サンドボックス複製 + `git symbolic-ref` で branch を制御し、実 `docs/working/_audit` を汚染しない）

## 3. validation_bias: strict 時の追加条件（EHS）

> **設計ステータス**: **配線・適用済み**（TASK-0145 / 0146 / 0147）。スクリプト実装に
> 加え、発火条件 `validation_bias: strict` も `bin/plangate` に配線済み。発火条件の供給は
> `--profile <key>` → `model-profiles.yaml` の `validation_bias` 解決 →
> `PLANGATE_VALIDATION_BIAS` 内部 export（TASK-0147 / #644）。
> **CLI 依存度の注意**: これらは CLI 層（§0 の層 C）であり、`bin/plangate verify` /
> `handoff --verify` を実行したときのみ発火する（手動 / AI 任せ運用では休眠。CI 移植は
> TASK-0148 で検討）。

Model Profile の `validation_bias: strict` プロファイル（gpt-5_5_pro 等）では、
上記 EH-1〜EH-7 に加えて以下 3 件を追加で強制:

### EHS-1: V-3 外部レビュー必須化

- **トリガー**: `standard` 以上の mode で V-3 外部 AI レビュー (`review-external.md`) なしに PR 作成
- **対応**: Hook が PR 作成 block
- **スクリプト**: `scripts/hooks/check-v3-review.sh`
- **発火条件**: `validation_bias: strict` かつ `mode ∈ {standard, high-risk, critical}` かつ `review-external.md` が存在しない
- **配線**: `bin/plangate verify`（V-3 不合格時に strict で block。TASK-0145）。CLI 層（§0 層 C）

### EHS-2: handoff.md 必須 6 要素チェック

- **トリガー**: `handoff.md` が必須 6 要素（要件適合 / 既知課題 / V2 候補 / 妥協点 / 引き継ぎ文書 / テスト結果）を欠く状態での WF-05 完了宣言
- **対応**: Hook が WF-05 完了を block
- **スクリプト**: `scripts/hooks/check-handoff-elements.sh`
- **発火条件**: `validation_bias: strict` かつ handoff.md に 6 セクション未充足
- **配線**: `bin/plangate handoff --verify`（6 要素不足を strict で block。TASK-0146）。CLI 層（§0 層 C）

### EHS-3: V-1 fix loop 上限超過 escalation

- **トリガー**: V-1 FAIL → fix → V-1 のループが 5 回を超過
- **対応**: Hook が ABORT、ユーザー判断にエスカレーション
- **スクリプト**: `scripts/hooks/check-fix-loop.sh`
- **発火条件**: `validation_bias: strict` かつ fix-loop カウントが閾値超過
- **配線**: `bin/plangate verify`（V-1 FAIL 時に fix-loop increment + strict で上限超過 block。TASK-0146）。CLI 層（§0 層 C・CI 移植対象外）

### EHS 発火条件の供給（配線済み）

`validation_bias: strict` は `docs/ai/model-profiles.yaml` で定義され、**実行時の供給は
配線済み**（TASK-0147 / #644）: `bin/plangate verify` / `handoff --verify` が `--profile=<key>`
（等号形式）を受理し、`model-profiles.yaml` の `validation_bias` を
[`scripts/_resolve_validation_bias.py`](../../scripts/_resolve_validation_bias.py) で解決して
`PLANGATE_VALIDATION_BIAS` を内部 export する。env で明示注入済みなら尊重し、
normal/lenient・無指定では非発火（既存挙動不変）。未知 key / yaml 欠落時は normal
fallback + stderr 警告。

**残課題**: 上記は CLI 層（§0 層 C）のため、CLI を回さない運用では休眠する。PR トリガーの
CI へ EHS-1 / EHS-2 を移植して CLI 非依存で常時強制する案は TASK-0148 で検討（EHS-3 は
CLI プロセス計数のため CLI 維持）。

## 4. 実装（#157 で 3 hook + #169 で 7 hook = 計 10 hook、すべて完了）

| Hook | 種別 | 実装 | 由来 |
|------|------|------|------|
| **EH-1**（plan.md なし production code 編集 block）| PreToolUse hook | [`scripts/hooks/check-plan-exists.sh`](../../scripts/hooks/check-plan-exists.sh) | #169 セッション A / TASK-0056 |
| EH-2（C-3 未承認 exec block）| PreToolUse hook | [`scripts/hooks/check-c3-approval.sh`](../../scripts/hooks/check-c3-approval.sh) | #157 / TASK-0048 |
| **EH-3**（plan_hash 改竄検知）| PreToolUse hook + CLI | [`scripts/hooks/check-plan-hash.sh`](../../scripts/hooks/check-plan-hash.sh) | #169 セッション A / TASK-0056 |
| **EH-4**（test-cases.md なし V-1 block）| CLI（V-1 前で呼び出し）| [`scripts/hooks/check-test-cases.sh`](../../scripts/hooks/check-test-cases.sh) | #169 セッション B / TASK-0057 |
| **EH-5**（検証ログなし PR 作成 block）| CLI（PR 作成前で呼び出し）| [`scripts/hooks/check-verification-evidence.sh`](../../scripts/hooks/check-verification-evidence.sh) | #169 セッション B / TASK-0057 |
| **EH-6**（scope 外ファイル編集検知）| PreToolUse hook + CLI | [`scripts/hooks/check-forbidden-files.sh`](../../scripts/hooks/check-forbidden-files.sh) | #169 セッション B / TASK-0057 |
| **EH-7**（2 段階レビューなしマージ block）| CLI（マージ前で呼び出し）| [`scripts/hooks/check-merge-approvals.sh`](../../scripts/hooks/check-merge-approvals.sh) | #169 セッション C / TASK-0058 |
| **EHS-1**（V-3 外部レビュー必須化）| CLI（mode 連携）| [`scripts/hooks/check-v3-review.sh`](../../scripts/hooks/check-v3-review.sh) | #169 セッション C / TASK-0058 |
| EHS-2（handoff 必須 6 要素）| CLI（手動 / WF-05 で呼び出し）| [`scripts/hooks/check-handoff-elements.sh`](../../scripts/hooks/check-handoff-elements.sh) | #157 / TASK-0048 |
| EHS-3（fix loop 上限超過）| CLI（V-1 fix loop 内で increment / check）| [`scripts/hooks/check-fix-loop.sh`](../../scripts/hooks/check-fix-loop.sh) | #157 / TASK-0048 |
| **EH-9**（委譲 commit/push 境界検知）| PreToolUse hook（Bash 前）| [`scripts/hooks/check-delegation-commit-boundary.sh`](../../scripts/hooks/check-delegation-commit-boundary.sh) | #239 問題2 / TASK-0073 |
| **auth-preflight**（exec 前 認証三点検証）| CLI（exec 前で呼び出し）| [`scripts/hooks/check-auth-preflight.sh`](../../scripts/hooks/check-auth-preflight.sh) | #239 問題3 / TASK-0073 |
| **EH-12**（protected branch 上の破壊的 git 操作 block）| PreToolUse hook（Bash 前・**Human apply 後に有効**）| [`scripts/check-git-destructive.sh`](../../scripts/check-git-destructive.sh)（HO 外・単一ソース）+ 配線 [`scripts/apply-eh-git-destructive-guard.sh`](../../scripts/apply-eh-git-destructive-guard.sh) | 2026-08-02 main 上 `reset --hard` 実害 |

**残未実装**: なし（10/10 完了）。EH-7 の GitHub branch protection 自動連携は別 PBI 候補。

### 4.1 3 モード設計

| モード | 環境変数 | 挙動 |
|-------|---------|------|
| **default**（推奨初期値）| なし | 違反検出時は warning のみ、continue:true（block しない）。誤検出時の作業妨害を最小化 |
| **strict** | `PLANGATE_HOOK_STRICT=1` | 違反検出時に block / exit 1。本番運用 / CI 等で有効化 |
| **bypass** | `PLANGATE_BYPASS_HOOK=1` | 常時 pass。緊急対応 / 既知の例外時のみ使用、監査 log に必ず記録 |

### 4.2 監査ログ

すべての判定は `docs/working/_audit/hook-events.log` に append-only で記録される（タブ区切り）:

```text
<ISO8601 UTC>\t<level>\t<hook-name>\t<task-id>\t<message>
```

`level`: `PASS` / `VIOLATION` / `BYPASS` / `SKIP` / `INCREMENT`

### 4.3 設定方法（opt-in）

[`.claude/settings.example.json`](../../.claude/settings.example.json) を `.claude/settings.json` にコピーすると PreToolUse hook（**EH-1 + EH-2 + EH-3 + EH-6**）+ SessionStart（gh-pin-account）が有効化される。

**CLI 配線（TASK-0143 / apply-script 適用後）**: EH-4 は `plangate verify` V-1 前（strict=1）、EH-5 は V-1 後（warn）で発火。EH-7 / EHS-1 / EHS-2 / EHS-3 は引き続き手動呼び出し。

### 4.4 テスト

- 単体: `sh tests/hooks/run-tests.sh` → **42 件 PASS**（#157 で 12 + #169 セッション A で +9 + B で +12 + C で +9）
- 統合: `sh tests/run-tests.sh` の TA-06 で hook 子テストを呼び出し

### 4.5 全 10 hook 完了（#169 完走）

**Issue #169 完了**。10/10 hooks 実装済（CLI / PreToolUse 構成）。残課題は GitHub branch protection 自動連携（EH-7 の上位拡張、外部 GitHub API 操作を伴うため別 PBI）。

## 5. 既存 `.claude/settings.json` hooks との関係

本ファイルが定義する不変条件は、既存 hooks（もしあれば）と:

- **重複なし**: 既存 hooks は本ファイルの実装で参照すべき入口
- **追加**: EH-1〜EH-7 + EHS-1〜EHS-3 を新規実装
- **既存 v8.1 ガードレール（`plugin/plangate/rules/*-gate.md`）との関係**: Plugin 配布版の追加ガードレールとして共存（[`responsibility-boundary.md`](./responsibility-boundary.md) § 6 参照）

## 6. 「block 通知」の文言ガイド

Hook が block する際の通知文言:

```text
[Hook EH-1] plan.md がないため production code を編集できません。
docs/working/TASK-XXXX/plan.md を作成してください。
```

形式:
- `[Hook EH-N]` プレフィックスで該当条件を識別
- 1 行サマリ + 解消手順 1 行
- 詳細は本ファイルへリンク

## 関連

- 親計画: [`docs/working/PBI-116/parent-plan.md`](../working/PBI-116/parent-plan.md)
- 責務境界: [`responsibility-boundary.md`](./responsibility-boundary.md)
- Tool Policy: [`tool-policy.md`](./tool-policy.md)
- Model Profile: [`model-profiles.md`](./model-profiles.md)
- Iron Law 8 項目: [`core-contract.md`](./core-contract.md) § 4
- Phase 1 成果: [`core-contract.md`](./core-contract.md)
