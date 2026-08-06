# TASK-0928: 承認境界の技術層ガード（#928 AI 担当範囲）

> 実測日: 2026-08-06 / base: `origin/main` (862dd05)
> 本ディレクトリは **証跡と patch のみ**。`scripts/hooks/*.sh` 等の
> Hardening Override 対象パスは AI が編集していない。

## 1. スコープと責務境界

| 項目 | 担当 | 本 TASK での状態 |
|------|------|----------------|
| EH-9 発火の実証 | AI-owned | 完了（`evidence/t1-eh9-firing.log`） |
| 自己承認ガードの実装 patch 生成 | AI-owned | 完了（`patches/`） |
| sandbox での挙動実証・変異注入 | AI-owned | 完了（`evidence/t3-*.log`） |
| patch の本体適用 | Human-owned | **未実施** |
| `.claude/settings*.json` 適用 | Human-owned | 触れていない |
| GitHub ruleset 変更 | Human-owned | 触れていない |

## 2. T-1 EH-9 発火実証（AC-2）

- 配線: `PreToolUse[0]` / `matcher: "Bash"` /
  `sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/check-delegation-commit-boundary.sh`
- 入力仕様: stdin JSON `.tool_input.command`（jq 優先・grep フォールバック）。
  `PLANGATE_HOOK_CMD` は stdin 不在時のみの CLI テスト用。
- 判定出力: **stdout JSON**（`{"continue":false,"stopReason":...}`）。exit code は常に 0。

**結果**: `gh pr merge` / `git commit` / `git push` は
`PLANGATE_DELEGATION_NOCOMMIT=1` 下で block された（発火する）。

**重要な限界（実測で判明）**: EH-9 は `PLANGATE_DELEGATION_NOCOMMIT=1` が
宣言されている委譲コンテキストでのみ動作する。未宣言時は `gh pr merge` も
素通りする。したがって **EH-9 は「常時有効な merge/approve ガード」ではない**。
issue #928 の Suggested files が EH-9 を指しているが、AC-5/AC-6 の恒常ガードを
EH-9 に置くと **既定 OFF のガード**になる。

## 3. T-2 自己承認ガード patch（AC-5 / AC-6）

- patch: `patches/0928-self-approve-guard.patch`
- 追加先: **`scripts/check-approval-token-write.sh`**（EH-9 ではない）

### 追加先の判断理由

1. 責務一致 — 当該 hook は既に「AI は自分の承認トークンを発行できない」を
   強制する承認境界ガード。`gh pr review --approve` は C-4 承認の自己発行であり
   同一クラス。
2. 常時有効 — env 宣言によるゲートが無い（EH-9 と対照的）。
3. 既配線 — `PreToolUse` の `Bash` matcher に既に登録済みで、
   settings.json への追加配線（Human 作業）が不要。
4. HO 外 — `scripts/` 直下であり `scripts/hooks/*.sh` の Hardening Override
   glob に該当しない（`scripts/hooks/check-plan-hash.sh` L124-134 の 9 カテゴリで確認）。
   通常 PR の差分としてレビュー可能。

### patch に含まれる 4 つの変更

| # | 変更 | 理由 |
|---|------|------|
| 1 | `gh pr review --approve` 系の block を追加 | AC-5 / AC-6 本体 |
| 2 | stdin を**無条件に 1 回だけ**読むよう是正 | 旧実装は `PLANGATE_HOOK_FILE` が env に設定されていると stdin を読まず、Bash matcher 側の検査が silent に無効化されていた（既存バグ） |
| 3 | block の exit code を `1` → `2` に是正 | Claude Code の PreToolUse は **exit 2 が blocking error**。`exit 1` は non-blocking error 扱いで実際には止まらない（既存バグ） |
| 4 | JSON 取得に grep フォールバックを追加 | 旧実装は jq 不在環境で Bash 検査が丸ごと fail-open していた（EH-9 と同方式で補完） |

変更 2 / 3 / 4 は既存の承認トークン書き込みガードにも効く。実測比較は
`evidence/t3-before-after.log`（本 README §5）。

### 塞いだ回避経路（全 23 件・`evidence/t3-sandbox-guard-tests.log`）

| ID | 経路 |
|----|------|
| P01 | `gh pr review --approve 123` |
| P02 | `-a` 短縮形 |
| P03 | フラグ割り込み `--repo X --approve` |
| P04 | 位置引数 + `--body` 併用 |
| P05 | 連続空白・タブ |
| P06 | `--approve=true`（`=` 結合形） |
| P07 | 環境変数前置 `GH_TOKEN=xxx gh ...` |
| P08 | `command gh ...` |
| P09 | 絶対パス `/opt/homebrew/bin/gh` |
| P10 | `sh -c "..."` 二段実行 |
| P11 | `eval "..."` |
| P12 | `&&` 連結 |
| P13 | `;` 連結 |
| P14 | コマンド置換 `$(which gh) pr review --approve` |
| P15 | 変数間接 `X=--approve; gh pr review $X` |
| P16 | 短縮フラグ束 `-ab "text"`（pflag の結合形） |
| P17 | REST 直叩き `gh api .../pulls/1/reviews -f event=APPROVE` |
| P18 | GraphQL 直叩き `addPullRequestReview` |
| P19 | 改行区切り |
| P20 | verdict 無指定 `gh pr review 123`（対話モードで approve 可能 → fail-closed で block） |
| P21 | クォート `gh "pr" "review" "--approve"` |
| P22 | `xargs gh pr review --approve` |
| P23 | バッククォート置換 |

`PLANGATE_SKIP_TOKEN_GUARD=1` を設定しても自己承認ガードは block する
（承認境界は env で緩和させない = fail-closed。実測 rc=2）。

### 偽陽性を出さないこと（負側 16 件・全て通過）

`gh pr review --comment` / `-c -b` / `--request-changes` / `-r -b` /
`gh pr view` / `gh pr list` / `gh pr create` / `gh pr diff` /
`gh pr review --help` / `git commit` / `gh api .../reviews`（読み取り） /
`gh pr comment` / `--repo o/r --comment` / `gh pr checks` /
`grep -rn "pr review"` / `--comment --body "-a is banned"`。

### 塞げなかった経路（既知の限界）

| # | 経路 | 理由 |
|---|------|------|
| L1 | `gh alias set ap 'pr review --approve'` → `gh ap` | alias は gh の設定ファイル側に解決され、コマンド文字列に `pr review` が現れない。EH-9 の git alias と同型の構造的限界 |
| L2 | base64 / rot13 等でエンコードして復号実行 | 文字列走査では原理的に不可 |
| L3 | Claude Code の Bash tool を経由しない経路（別プロセス・別セッション・MCP `pull_request_review_write`） | PreToolUse hook は Bash tool しか見ない。MCP 経由の approve は本 hook の対象外（`permissions.deny` か MCP 側の制限が必要） |
| L4 | `gh pr merge` そのもの | 本 patch のスコープ外（AC-5/6 は approve）。EH-9 は委譲宣言下のみ。**常時有効な merge ガードは未充足のまま** |
| L5 | GitHub Web UI からの承認 | 技術層の対象外（ruleset 側の話） |

L1-L3 は `scripts/ai-loop/gh_exec.py` が既に指摘している
「in-process allowlist はプロセス外を守らない」ギャップと同型。最終防衛線は
ruleset（repo-wide 層）に残る。

## 4. `git apply --check`

`git apply --check docs/working/TASK-0928/patches/0928-self-approve-guard.patch`
→ **exit 0**（base = `origin/main` 862dd05）。

## 5. T-3 sandbox 実証

sandbox は `mktemp -d` に `git ls-files -z` → 中間 tar 経由で複製し、
そこで patch を実適用した（repo 本体は書き換えていない）。

| 条件 | 未適用 | 適用後 |
|------|-------|-------|
| token write（`PLANGATE_HOOK_FILE` 未設定） | rc=1（非ブロッキング） | rc=2（block） |
| token write（`PLANGATE_HOOK_FILE` 設定時） | rc=0（**検査が無効化**） | rc=2（block） |
| `gh pr review --approve 928` | rc=0（素通り） | rc=2（block） |
| 同上 + `PLANGATE_SKIP_TOKEN_GUARD=1` | rc=0 | rc=2（env で緩和されない） |
| 同上 + PATH から jq を除外 | rc=0 | rc=2（fail-open しない） |

テスト総数 41（正側 23 / 負側 16 / 既存回帰 2）→ **全 PASS**。

### 変異注入（call site を破壊）

| 変異 | 内容 | 結果 |
|------|------|------|
| M1 | `_hit=$(_scan_self_approve "$_CMD" \| head -1)` の呼び出しを `_hit=""` に | 正側 23 件が FAIL（kill） |
| M4 | `_is_api_approve()` の `elif` 分岐を削除 | P17 / P18 のみ FAIL（kill・検出が特異的） |
| M2 | `_CMD=$(_json_get '.tool_input.command')` を `_CMD=""` に | 正側 23 件 + 既存回帰 R01 が FAIL（kill。stdin 読み取り是正が既存検査にも効いていることの裏取り） |

復元後は再び 0 FAIL。ログ: `evidence/t3-mutation.log`。

## 6. T-4 現状実測

`evidence/t4-current-state.log` 参照。要点:

- `bin/plangate doctor --check-settings` = **PASS**（exit 0）
- hooks: `SessionStart 1` / `PostToolUse 1` / `Stop 1` / **`PreToolUse 8`**
  → **AC-1 は解消済み**（issue 記載の「PreToolUse 未配線」は過去の状態）
- `.claude/settings.json` に `permissions` キーは**存在しない**（deny 0 件）
- ruleset `id=14939019` は未変更:
  `required_approving_review_count: 0` /
  `dismiss_stale_reviews_on_push: false` /
  `require_last_push_approval: false` /
  `required_review_thread_resolution: true` /
  required status checks は `Markdown lint` 1 件のみ
- **追加で検出**: `bypass_actors` に
  `{"actor_type": "RepositoryRole", "actor_id": 5, "bypass_mode": "always"}`
  が設定されている（admin ロールが常時 bypass 可能）。repo-wide 層の
  実効強度に直結するため Human 判断が要る
- `grep -rn "pr review --approve" scripts/hooks/` → ヒット 0 件（ガード不在）

## 7. Human へのフォローアップ（AI 実施不可）

1. `patches/0928-self-approve-guard.patch` の適用可否判断と適用
   （`scripts/check-approval-token-write.sh` は HO 外のため通常 PR で扱える）
2. ruleset `id=14939019` の強化判断
   （`required_approving_review_count` / `require_last_push_approval` /
   `bypass_actors`）
3. `.claude/settings.json` の `permissions.deny` 追加判断
   （L3 の MCP 経路を塞ぐには hook ではなく deny が必要）
4. 常時有効な `gh pr merge` ガード（L4）の要否判断
