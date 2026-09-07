# #1226 — 承認手順の定義面を HO / CI の被覆に載せる（`git apply` 可能形 patch / **Human 適用**）

> 測定基点: **`origin/main` = `b3565b2`** / 2026-09-07。以下の実測はすべてこの ref のワークツリーに対するもの。
> 調査本体・全数照合・案の比較は [`1226-approval-surface-ho-coverage.md`](./1226-approval-surface-ho-coverage.md)。本書は **patch と適用手順だけ**を持つ。
> 位置づけ: **既存ギャップの是正**（退行ではない）。`scripts/hooks/*.sh` / `.claude/rules/*.md` / `.github/workflows/*.yml` はいずれも Hardening Override 対象のため、**AI は patch 提示まで・適用は Human-owned**。
> 本書で AI が作成したのは `docs/working/_reports/` 配下の `.md` 2 本のみ。`scripts/` / `tests/` / `.claude/` / `.codex/` / `.cursor/` / `bin/` / `schemas/` / `.github/` は **1 バイトも変更していない**。
> 先例と同じ marker 規則: [`1234-eh3-outside-repo-patch-applicable.md`](./1234-eh3-outside-repo-patch-applicable.md) / [`1278-log-event-fail-closed-patch-applicable.md`](./1278-log-event-fail-closed-patch-applicable.md)。

---

## 0. 結論先行

| 項目 | 結論 |
|---|---|
| **PATCH-A** | HO 9 カテゴリ → **12 カテゴリ**（パターン 15 → 20）。追加するのは**他 Provider の enforcement 配線 3 種**（`.codex/hooks.json` / `.cursor/hooks.json` / 両者の `hooks/*.sh`）と**承認トークンガード本体**（`scripts/check-approval-token-write.sh`）。`.claude/settings*.json` が既に HO であることとの**非対称の解消**にあたる |
| **PATCH-A の同時変更** | `.claude/rules/mode-classification.md` の HO 一覧（正本宣言側）。**case ブロックだけ変えると本 issue と同じ「正本を更新しない」状態を自作する**ため、同一 patch に含める |
| **PATCH-B** | `.codex/skills/**/SKILL.md` と正本 `.agents/skills/**/SKILL.md` の **byte 一致を PR CI で必須化**（既存 `plugin/plangate/` drift-check と同じ形）。`pull_request.paths` に `.codex/skills/**` を追加しないと**そもそも job が起動しない**ため、それも同一 hunk |
| **PATCH-B の前提（重要）** | **現 main で 40 skill 中 10 件が既に drift している**（§2 表）。patch だけ当てると CI は即 FAIL する。**`sh scripts/install-plangate-skills-to-codex.sh --force` を実行して結果をコミットする工程とセットで適用すること**（§5 手順 4） |
| **適用しても塞がらないもの** | Bash 経路（#1104）/ symlink・FS エイリアス（#1264 / #1234）/ worktree 配下（#1277）/ hook 未配線の導入先 / `PLANGATE_BYPASS_HOOK=1` / **CI が required check でないこと**（#928。§6 残存脅威モデル） |
| **`git apply --check`** | repo root で **rc=0**（§5 に実測を記載） |

---

## 1. PATCH-A が埋める非対称（実測）

HO 判定は `scripts/hooks/check-plan-hash.sh` の `_override=0` 直後の `case` ブロックが正本。同ブロックのパターン集合を Python の `fnmatch.fnmatchcase` で忠実に再現し（`case` の `*` は `/` を跨いで一致する。`fnmatchcase` も同じ）、対象パスを小文字化して照合した結果:

| ファイル | 役割 | 現状 |
|---|---|---|
| `.claude/settings.example.json` | Claude Code の EH-2 / EH-3 / EH-13 配線 | **HO**（`.claude/settings.example.json` に一致） |
| `.codex/hooks.json` | Codex CLI の EH-1 / EH-2 / EH-3 / EH-6 / EH-9 配線 | **非 HO** |
| `.codex/hooks/eh-bridge.sh` | Codex の rc → allow/deny 翻訳（未知 rc は **allow**） | **非 HO** |
| `.cursor/hooks.json` | Cursor の EH-1 / EH-2 配線（`failClosed: false`） | **非 HO** |
| `.cursor/hooks/plangate-eh2-c3.sh` | Cursor の EH-2 入口（`scripts/hooks/cursor-adapter.sh` へ exec） | **非 HO** |
| `scripts/hooks/cursor-adapter.sh` | Cursor 用アダプタ本体 | **HO**（`scripts/hooks/*.sh` に一致） |
| `scripts/check-approval-token-write.sh` | **EH-13**（`c3.json` / `maintenance.json` への AI 書込を block する承認トークンガード） | **非 HO**（`scripts/hooks/` ではなく `scripts/` 直下にあるため） |

つまり **Claude レーンの配線は HO で守られているが、Codex / Cursor レーンの配線は 1 つも守られていない**。`.cursor/hooks/plangate-eh2-c3.sh` を `exit 0` の 1 行に書き換えれば、HO を 1 つも踏まずに Cursor セッションの EH-2 を無効化できる。EH-13 も同様で、**承認トークンを守るガードそのものが AI 編集可能**な位置にある。

これは本 issue の型（HO を踏まずに承認の中身を変えられる）と同一である。

### 追加候補から外したもの（副作用評価）

| 候補 | 外した理由 |
|---|---|
| `.agents/skills/**/SKILL.md`（承認手順の散文正本） | (1) `.cursor/skills/plan-review-gate` は `.agents/skills/plan-review-gate` への **symlink**（`git ls-files -s` で mode `120000`）であり、EH-3 の正規化は字句のみで symlink を解決しない（#1101 Non-goal）。`.agents/...` を HO にしても `.cursor/...` 経由の書込は素通りする＝**塞いだつもりになる**。(2) HO は c3 + plan_hash 承認下でも**常時 block** であり、40 skill の通常保守がすべて Human patch 経由になる。**代わりに PATCH-B の内容 drift 検査で扱う** |
| `plugin/plangate/**` | **生成物**。正本を編集すれば同期スクリプトが再生成する。HO にすると AI の `Edit/Write` は止まるが、`Bash` から同期スクリプトを走らせる経路は EH-3 の Bash レーンが no-op（#1104）で止まらない。**「正直な編集だけ止めて回避経路は残る」**逆進的な防御になる。#1263 の担当範囲でもある |
| `.claude/skills/**` | 現行 override パターン外であることが `mode-classification.md` に明示（R-003/R-006）。本 patch で方針変更しない |

---

## 2. PATCH-B が埋めるギャップ（実測）

`.codex/skills/<name>/SKILL.md` は `scripts/install-plangate-skills-to-codex.sh` が `.agents/skills/<name>/SKILL.md` を **無変換 `cp`** した結果である（同スクリプト内、`cp "$skill_file" "$target_skill_file"`。frontmatter の正規化は `agents/openai.yaml` 側にのみ適用される）。したがって両者は byte 一致であるべきだが、現 main では一致していない。

```sh
for d in .agents/skills/*/; do n=$(basename "$d"); cmp -s "$d/SKILL.md" ".codex/skills/$n/SKILL.md" || echo "DIFFER $n"; done
```

| skill | 差分行数（`diff -u` の `+`/`-` 行） | 承認手順を定義するか |
|---|---|---|
| `ai-dev-plan` | 116 | **YES**（`plan_hash` 整合検証の CLI 不在フォールバック / AC-11） |
| `ai-dev-verify` | 94 | **YES**（V-1 の `plan_hash` 突合を必須と定義） |
| `ai-dev-exec` | 82 | **YES**（exec 入口条件: `c3.json` 存在 + `approval_kind` 別条件） |
| `ai-dev-brainstorm` | 75 | NO |
| `ai-loop-cycle` | 68 | **YES**（C-3′ 経路） |
| `plan-review-gate` | 13 | **YES**（C-3 の必須手順そのもの） |
| `plangate-setup` | 8 | NO |
| `intent-classifier` | 7 | **YES**（「AI は c3.json を代理発行しない」） |
| `local-exec-handoff` | 7 | **YES**（「`approvals/c3.json` の APPROVED 確認は省略不可」） |
| `working-context` | 7 | NO |

**10 / 40 が drift。うち 7 件が承認手順の定義面。** 対照として `plugin/plangate/skills/*/SKILL.md` は 40/40 が byte 一致である（既存 CI の drift-check が効いているため）。**同じ配布メカニズムでも、CI で照合しているレーンだけが一致している。**

### drift の中身（最も短い実例 / `plan-review-gate`）

`.codex/` 版には正本にある次の 2 つの規範ブロックが**無い**:

- 「機械 block が無いことを理由に C-3 を省略しない。」
- 「CLI が無いことを理由に手順を黙って省略し、実施済みと読める記録を残してはならない。」

**Codex セッションは、弱められた C-3 定義を読んでいる。** これは #1226 が予測した事象が既に main で実現している証拠である。

### なぜ既存の検査が見つけないか

| 既存の検査 | 何を見るか | なぜ見つけないか |
|---|---|---|
| `.github/workflows/sync-plugin-plangate.yml` の `drift-check` job | `sh scripts/sync-plugin-plangate.sh` 後の `git diff --quiet -- plugin/plangate/` | 対象が `plugin/plangate/` のみ。`.codex/` は同期スクリプトの出力先ではない |
| 同 workflow の `pull_request.paths` | `.claude/**` / `.agents/skills/**` / `plugin/plangate/**` 等 | **`.codex/**` を含まない** → `.codex/` だけ変える PR では job が起動すらしない |
| `scripts/check-codex-skill-spec.sh` | ディレクトリ集合の **presence** と `SKILL.md` / `agents/openai.yaml` の対応 | **内容を一切見ない**。さらに CI では `--warn-only` で呼ばれる |

---

## 3. 設計判断

| 判断 | 理由 |
|---|---|
| PATCH-A で `case` ブロックと `mode-classification.md` を**同一 patch** にする | 片方だけ変えることが本 issue の病名そのもの。正本宣言（rules）と実装（hook）の同時変更を patch の単位で強制する |
| PATCH-A のパターンを `.codex/hooks/*.sh` のように**ディレクトリ限定 glob**にする | `case` の `*` は `/` を跨ぐため `.codex/**` 相当になる。`.codex/skills/**` まで巻き込まないよう `hooks/` に限定する |
| PATCH-B を**新規 workflow ではなく既存 `drift-check` job のステップ**として足す | 実行環境・permissions・concurrency を再定義しない。既存の「同期漏れを PR で落とす」規約の素直な延長 |
| PATCH-B で **missing も FAIL** にする | 現 main は 40/40 対応が成立しており（`.agents/skills` に symlink は 0 件、`.codex/skills/.system` も不在）、正当な除外が無い。`continue` で見逃すと「削除すれば検査が消える」穴になる |
| PATCH-B は `cmp` で照合し、**installer を CI で走らせない** | installer を走らせて `git diff` を見る方式は installer 自身の変更で検査が空振りする。`cmp` は installer とは独立に「正本 = 配布物」を主張する |
| EH-13 の Codex / Cursor 配線追加は**本 patch に含めない** | `.codex/hooks.json` に `check-approval-token-write.sh` が配線されていない非対称は実在するが、**新しい block クラスを増やす** Human 判断事項。§7 に送る |

---

## 4. 検出力（変異注入）

| 変異 | 期待 | 実測 |
|---|---|---|
| M-1: PATCH-A の `.cursor/hooks/*.sh` 行を削除 → `.cursor/hooks/plangate-eh2-c3.sh` を照合 | `non`（block されない） | `non`（fnmatch 再現。patch 適用形では `HO`） |
| M-2: PATCH-A の `scripts/check-approval-token-write.sh` 行を削除 → 同パスを照合 | `non` | `non`（適用形では `HO`） |
| M-3: PATCH-A 適用形で `.codex/skills/plan-review-gate/SKILL.md` を照合 | `non`（skills は意図的に対象外） | `non` — **偽陽性なし**（AC-4 相当） |
| M-4: PATCH-B の `cmp` を `cmp -s ... \|\| true` に変異 | 常に rc=0 | 現 main の 10 件 drift を検出しなくなる |
| M-5: PATCH-B の missing 分岐を `continue` のみに変異 | `.codex/skills/plan-review-gate/` を削除しても PASS | 削除が素通り |
| M-6: PATCH-B を適用し `pull_request.paths` の `.codex/skills/**` 追加を外す | `.codex/` のみの PR で job 不起動 | 検査が存在しても発火しない（#1259 と同型） |

**HO 判定の再現方法の妥当性**: `case` の glob と `fnmatch.fnmatchcase` の一致は、現行 15 パターンに対する positive control（`.claude/rules/working-context.md` / `scripts/hooks/check-plan-hash.sh` / `bin/plangate` / `schemas/c3-approval.schema.json` / `CLAUDE.md` / `AGENTS.md` / `.claude/agents/orchestrator.md` / `.github/workflows/ci.yml` / `.claude/commands/ai-dev-workflow.md` の 9 件すべてが `HO`）と negative control（`docs/ai/plan-normalization-gate.md` / `README.md` が `non`）で確認した。**hook 本体を `sh` で実走した測定ではない**（本セッションの実行環境が `sh` 起動を拒否する）。この点は §6 に残存として記載する。

---

## 5. patch（`git apply` 用 / **検証済**）

抽出は marker 基準（#1104 / #1234 と同じ規則。marker 行と fence 行の 2 行ずつを落とす）:

````sh
sed -n '/^<!-- PG-PATCH-BEGIN -->$/,/^<!-- PG-PATCH-END -->$/p' \
  docs/working/_reports/1226-approval-surface-patch-applicable.md \
  | sed -e '1d' -e '$d' | sed -e '1d' -e '$d' > /tmp/1226-approval-surface.patch
git apply --check /tmp/1226-approval-surface.patch   # b3565b2 で rc=0 実測
git apply --stat  /tmp/1226-approval-surface.patch
````

<!-- PG-PATCH-BEGIN -->
```diff
diff --git a/scripts/hooks/check-plan-hash.sh b/scripts/hooks/check-plan-hash.sh
--- a/scripts/hooks/check-plan-hash.sh
+++ b/scripts/hooks/check-plan-hash.sh
@@ -361,18 +361,23 @@

 # (ii) Hardening Override 物理先頭判定（R-003/R-015、maintenance より上）
 # 判定対象は _ho_key（小文字化済み）。したがって case は**小文字側で受ける**。
-# ラベル 9 行 / パターン 15 個。9 カテゴリの正本は
+# ラベル 12 行 / パターン 20 個。12 カテゴリの正本は
 # .claude/rules/mode-classification.md の Hardening Override 節（内容は不変）。
 _override=0
 case "$_ho_key" in
   .claude/rules/*.md) _override=1 ;;
   .claude/settings.json|.claude/settings.local.json|.claude/settings.example.json) _override=1 ;;
   .claude/commands/*.md|.claude/commands/*/*.md) _override=1 ;;
   .claude/agents/*.md|.claude/agents/*/*.md) _override=1 ;;
   scripts/hooks/*.sh) _override=1 ;;
   bin/plangate) _override=1 ;;
   schemas/*.schema.json) _override=1 ;;
   .github/workflows/*.yml|.github/workflows/*.yaml) _override=1 ;;
   agents.md|claude.md) _override=1 ;;
+  # (#1226) 他 Provider の enforcement 配線と承認トークンガード本体。
+  # .claude/settings*.json が HO であることとの非対称の解消。skills は対象外。
+  .codex/hooks.json|.cursor/hooks.json) _override=1 ;;
+  .codex/hooks/*.sh|.cursor/hooks/*.sh) _override=1 ;;
+  scripts/check-approval-token-write.sh) _override=1 ;;
 esac
 if [ "$_override" = "1" ]; then
diff --git a/.claude/rules/mode-classification.md b/.claude/rules/mode-classification.md
--- a/.claude/rules/mode-classification.md
+++ b/.claude/rules/mode-classification.md
@@ -46,7 +46,7 @@
 - データベーススキーマ変更 → 最低でも「高」
 - 公開 API の破壊的変更 → 最低でも「超高」
 - **承認境界周辺の変更 → 最低でも「高」** (TASK-0106 Retrospective Try 由来 / TASK-0112)
-  - 対象パス (Hardening Override 対象と完全一致 / [`scripts/hooks/check-plan-hash.sh`](../../scripts/hooks/check-plan-hash.sh) の **`_override=0` 直後の `case` ブロック**（`esac` まで）= **9 カテゴリ** 正本。行番号で参照しないこと — 行番号アンカーは実装の移動で黙って別ブロックを指す / #1089):
+  - 対象パス (Hardening Override 対象と完全一致 / [`scripts/hooks/check-plan-hash.sh`](../../scripts/hooks/check-plan-hash.sh) の **`_override=0` 直後の `case` ブロック**（`esac` まで）= **12 カテゴリ** 正本。行番号で参照しないこと — 行番号アンカーは実装の移動で黙って別ブロックを指す / #1089):
     - `.claude/rules/*.md`
     - `.claude/settings.json` / `.claude/settings.local.json` / `.claude/settings.example.json`
     - `.claude/commands/*.md`
@@ -56,5 +56,8 @@
     - `schemas/*.schema.json`
     - `.github/workflows/*.yml` / `.github/workflows/*.yaml`
     - `AGENTS.md` / `CLAUDE.md`
+    - `.codex/hooks.json` / `.cursor/hooks.json` (#1226)
+    - `.codex/hooks/*.sh` / `.cursor/hooks/*.sh` (#1226)
+    - `scripts/check-approval-token-write.sh` (#1226 / EH-13 本体)
   - (注: `.claude/skills/` と `scripts/_*.py` は現行 override パターン**外**、本ルールでも追加しない — R-003/R-006)
   - 上記パスに touch する PBI は **`lite_eligible=false` 強制 + Standard C-3 同期固定** ([`working-context.md`](./working-context.md) C-3 条件付き降格 §AC-10 Hardening Override と整合 / R-007)
diff --git a/.github/workflows/sync-plugin-plangate.yml b/.github/workflows/sync-plugin-plangate.yml
--- a/.github/workflows/sync-plugin-plangate.yml
+++ b/.github/workflows/sync-plugin-plangate.yml
@@ -19,7 +19,8 @@
   pull_request:
     paths:
       - '.claude/**'
       - '.agents/skills/**'
+      - '.codex/skills/**'
       - 'docs/ai/ai-loop/**'
       - 'docs/workflows/ai-loop/**'
       - 'scripts/ai-loop/**'
@@ -58,6 +59,24 @@
             git diff --stat -- plugin/plangate/
             exit 1
           fi
           echo "plugin/plangate/ is in sync with sources."
+
+      - name: Verify .codex/skills SKILL.md match .agents/skills canon (#1226)
+        run: |
+          rc=0
+          for _d in .agents/skills/*/; do
+            _n=$(basename "$_d")
+            if [ ! -f ".codex/skills/$_n/SKILL.md" ]; then
+              echo "::error::.codex/skills/$_n/SKILL.md missing (canon: ${_d}SKILL.md)"
+              rc=1
+              continue
+            fi
+            if ! cmp -s "${_d}SKILL.md" ".codex/skills/$_n/SKILL.md"; then
+              echo "::error::.codex/skills/$_n/SKILL.md diverges from ${_d}SKILL.md -- run 'sh scripts/install-plangate-skills-to-codex.sh --force' and commit the result"
+              diff -u "${_d}SKILL.md" ".codex/skills/$_n/SKILL.md" | head -40
+              rc=1
+            fi
+          done
+          exit "$rc"

   sync:
```
<!-- PG-PATCH-END -->

### 適用手順（Human / repo root で実行）

1. 上記 `sed` で patch を抽出し、`git apply --check` が rc=0 であることを確認する
2. `git apply /tmp/1226-approval-surface.patch`
3. `sh tests/run-tests.sh` を実行し、**適用前に取った baseline と比較**して新規 FAIL が無いことを確認する（絶対件数を契約値にしない）
4. **`sh scripts/install-plangate-skills-to-codex.sh --force` を実行し、`.codex/skills/` の差分をコミットする**（これを飛ばすと PATCH-B の新ステップが既存 10 件の drift で即 FAIL する）
5. `sh scripts/apply-claude-settings.sh` は**不要**（settings 変更なし）
6. PATCH-A 適用後は `.codex/hooks.json` / `.cursor/hooks*` / `scripts/check-approval-token-write.sh` が **AI から編集不能**になる。以後これらの変更は本書と同形の patch 文書経由になる

---

## 6. 残存脅威モデル（完全性を主張しない）

### 守る（PATCH-A / PATCH-B 適用後）

- `Edit`/`Write` 経路での、字句上の表記揺れを含む Codex / Cursor 配線ファイルおよび EH-13 本体への書込（#1101 の正規化が効く範囲で）
- `.codex/skills/**/SKILL.md` が正本 `.agents/skills/**/SKILL.md` から乖離した状態での PR マージ（CI が赤くなる範囲で）

### 守らない

| 残存 | 内容 | 追跡 |
|---|---|---|
| Bash 経路 | `Bash` matcher は `file_path` を持たず `target_file` が空になるため HO 判定に一致しない。`sed -i` / heredoc での書換は止まらない | #1104 |
| symlink / FS エイリアス | EH-3 の正規化は字句のみ。`.cursor/skills/plan-review-gate` が実在する symlink であることが具体例 | #1264 / #1234 |
| worktree 配下 | `_ho_key` が `REPO_ROOT` 前置きに固定される | #1277 |
| **CI が advisory** | 実測（`gh api repos/s977043/plangate/rulesets/14939019`）: required status check は **`Markdown lint` 1 本のみ**、`required_approving_review_count: 0`。**PATCH-B の検査が赤でもマージできる** | #928 |
| 導入先 | plugin 配布物に `scripts/hooks/` も CLI も含まれない。導入先では HO そのものが存在しない | #1144 |
| `PLANGATE_BYPASS_HOOK=1` | 常時 exit 0 | 既知 |
| 散文正本の面 | `.agents/skills/**` / `docs/**` / `workflows/*.yaml` は依然 HO 外。PATCH-B が守るのは「正本とコピーの一致」であって「正本そのものの改変」ではない | 本 issue の残り・#1263 |
| hook 実走での確認 | 本書の HO 判定は `fnmatch` 再現による静的照合であり、`sh scripts/hooks/check-plan-hash.sh` の rc を実測していない | §4 |

EH-3 の HO block は**多層防御の 1 層**にすぎない。承認境界の最終的な保証主体は **C-4 Human レビュー**と **GitHub ruleset** である。

---

## 7. Human 判断に送る事項

1. **EH-13 を Codex / Cursor にも配線するか**（現在は `.claude/settings.example.json` のみ。新しい block クラスを増やす判断）
2. **`.codex/hooks/eh-bridge.sh` の未知 rc = `allow`（fail-open）を `deny` に倒すか**（可用性とのトレードオフ）
3. **PATCH-B の検査を required status check に加えるか**（#928 の一部。ruleset 操作は Human-owned）
4. **`.cursor/hooks.json` の `failClosed: false` を `true` にするか**
5. **`.agents/skills/**` の散文正本を HO に入れるか**（本書は symlink 迂回と保守コストを理由に入れない設計にした。入れる場合は symlink 解決を先に片付ける必要がある — #1264）

---

## 8. 適用チェックリスト

| # | 項目 | 結果 |
|---|---|---|
| 1 | repo root で `git apply --check` | §5 の実測に記載 |
| 2 | HO 判定の before/after | §1 表 + §4 変異 |
| 3 | `.codex/skills` drift の実測 | §2 表（10 / 40） |
| 4 | 偽陽性の確認（skills を HO にしない） | §4 M-3 |
| 5 | `#1234` / `#1278` の patch との併用順 | **不問**（hunk 非重複。いずれも `scripts/hooks/check-plan-hash.sh` を触るが、#1234 は `@@ -358` 付近への挿入、#1278 は `log_event`（`:26-32`）、本 patch は `@@ -361` の `case` ブロック。**#1234 を先に当てると本 patch の行番号が動くため、`git apply -3` もしくは本 patch を先に当てること**） |
| 6 | `tests/extras` の新規 TC | **未作成**（`.sh` は本セッションで作成不可）。仕様は §4 の変異表 |
| 7 | `docs/ai/hook-enforcement.md` 残存脅威モデルへの追記 | **未**（HO 外だが本 PR の scope 外。follow-up） |
