# #1104 / PR #1267 hotfix — Bash レーンの明示 no-op（機械適用可能な patch）

> 測定基点: **`origin/main` = `3f0cadd`**（PR #1267 マージ後）/ 2026-08-28。以下の rc・出力はすべてこの ref に対する実測。
> 関連: [`1104-bash-route-guard-patch-applicable.md`](./1104-bash-route-guard-patch-applicable.md)（元の適用可能化設計。**Step 3 = 配線のみ**を patch 化し、Step 1 / Step 2 は「Human 判断未確定」として patch 化していない）
> 位置づけ: **main にマージ済みの critical の hotfix**。`.claude/settings.example.json` はテンプレートであり、実配線 `.claude/settings.json` は `scripts/apply-claude-settings.sh` を実行した時点で更新される。**apply した利用者から順に Bash が止まる。**
> 本書で AI が編集したのは `docs/` と `tests/` のみ。`.claude/` / `scripts/` / `bin/` / `schemas/` / `.github/` は **1 バイトも変更していない**（Hardening Override）。

---

## 0. 結論先行

| 項目 | 結論 |
|---|---|
| **何が起きたか** | PR #1267 が **Step 3（配線）だけ**を入れた。Step 1（write-intent 検出器の切り出し）と Step 2（HO ガードの Bash 分岐）は未実装のまま。元設計書が「配線だけ先に入ると配線検査は緑・Bash 経路は素通り」と警告していた状態が、そのまま main に入っている |
| **採った方針** | **方針 1（最小・安全側）**。Bash レーンで対象パスが与えられていない場合に **明示的に何もしない**（`BASH_LANE_NOOP` で `exit 0`）。**#1104 は open のまま** |
| **採らなかった方針** | 方針 2（`tool_input.command` から書き込み先を抽出して HO 判定に掛ける）。理由は §3 |
| **patch 対象** | `scripts/hooks/check-plan-hash.sh`（+29 行）/ `.claude/settings.example.json`（`_comment_` 1 行の是正） |
| **配線自体は残す** | `scripts/apply-claude-settings.sh` は **「不足のみ取り込む・削除しない」** 冪等 merge（同スクリプト冒頭に明記）。すでに apply した利用者の `.claude/settings.json` からは、example 側を戻しても Bash エントリは**消えない**。したがって **hook 側の是正が必須**であり、example 側の配線を剥がしても救済にならない |
| **回帰テスト** | `tests/extras/ta-77-eh3-bash-lane.sh`（新規）。Bash 形状の PreToolUse payload を hook に流して rc を実測する |

---

## 1. 実測（`origin/main` = `3f0cadd` の hook にそのまま PreToolUse payload を流す）

hook は `$0` 由来で `REPO_ROOT` を決めるため、サンドボックス複製で実 repo を汚さずに測れる（`tests/extras/README.md` 規約 3 / 「できること / できないこと」節）。

| # | payload | rc | 出力（1 行目） |
|---|---|---|---|
| 1 | `Bash` / no-task / `PLANGATE_SKIP_REASON` 未設定 / `echo hi` | **2** | `[Hook EH-3] SKIP 拒否: SKIP_REASON 未設定。` |
| 2 | `Bash` / no-task / `PLANGATE_SKIP_REASON` 未設定 / `echo x >> bin/plangate` | **2** | 同上（**HO 判定は発火していない**） |
| 3 | `Bash` / no-task / `PLANGATE_SKIP_REASON=probe` / `echo hi` | 0 | `[Hook EH-3 SKIP] no task_id; non-plan target (unknown) — skipped (SKIP_REASON 記録済・要人間追認)` |
| 4 | `Write` / `bin/plangate`（対照） | 2 | `[Hook EH-3] HARDENING_OVERRIDE: bin/plangate は maintenance 窓内でも常時 block` |
| 5 | `Write` / `docs/foo.md`（対照） | 0 | `[Hook EH-3 DOC_LIGHT_SKIP] ...` |
| 6 | `Write` / `docs/working/TASK-9999/plan.md`（対照） | 2 | `[Hook EH-3] BLOCK: plan.md edited without TASK context.` |

### 何が壊れているか

`check-plan-hash.sh` の対象パス抽出は `tool_input.file_path`（`:63-72`）だけを見る。Bash の PreToolUse payload が持つのは `tool_input.command` なので、**`target_file` は必ず空**になる。その結果:

1. **#1104 が塞ごうとした穴は塞がっていない** — #2 のとおり HO 判定は一度も一致しない（`_norm_target` が空）
2. **適用すると全 Bash コマンドが止まる** — #1 のとおり no-task セッションでは `exit 2`
3. **回避すると CI が落ちる** — #3 の経路は `docs/working/_audit/skip-decision-log.jsonl` へ `event: "EH-3_SKIP"` を **Bash 1 コマンドごとに 1 行**追記する。`scripts/check-skip-acknowledged.sh:23` は `EH-3_SKIP` で `acknowledged_by` が空のものを FAIL にするため、**人間が Bash を打つたびに CI 落ちの負債が積み上がる**

つまり現状は **「防御を足さずに摩擦だけ足した」** 状態である。

### `_comment_` が実測と一致しない

`.claude/settings.example.json` の EH-3b ブロックには次の記述がある:

> Hook EH-3b (#1104): Bash route HO / plan.md guard. Applies the same HO decision as EH-3 to write-intent Bash commands.

実測では **HO 判定は発火せず**、**write-intent の判別はコードのどこにも存在しない**（`check-plan-hash.sh` に `command` を読む箇所は無い）。本 patch はこの記述も実測どおりへ直す。

---

## 2. 方針 1 の設計

**Bash レーンで対象パスが与えられていない場合に限り、明示的に何もしない。**

適用条件は 3 つの AND:

| 条件 | 理由 |
|---|---|
| `target_file` が空 | `PLANGATE_HOOK_FILE` / `$2` で対象が明示されていれば、従来どおり HO / plan.md 判定を通す |
| `task_id` が空 | `PLANGATE_HOOK_TASK` があるときの **plan_hash 突合は `target_file` を必要としない**。Bash レーンでも意味があるので殺さない |
| stdin JSON の `.tool_name` が `"Bash"`（jq で厳密抽出） | Edit/Write の payload を誤って早期 `exit 0` にしないため。**jq 不在時は本分岐を発火させない**（判定を緩める側へ倒さない） |

`log_event "BASH_LANE_NOOP"` を出すので `docs/working/_audit/hook-events.log` には残るが、**`skip-decision-log.jsonl` には書かない**（人間追認を要求しない = CI 負債を作らない）。

### 何が変わり、何が変わらないか

| 経路 | patch 前 | patch 後 |
|---|---|---|
| Bash / no-task / SKIP_REASON なし | `exit 2`（全 Bash が止まる） | **`exit 0`** |
| Bash / no-task / SKIP_REASON あり | `exit 0` + `EH-3_SKIP` 追記（CI 負債） | **`exit 0` / 追記なし** |
| Bash / no-task / HO パスへの書き込み命令 | `exit 2`（HO 由来ではなく SKIP_REASON 由来）| **`exit 0`（既知の穴。#1104 open）** |
| Bash / TASK 文脈あり | plan_hash 突合 | **不変**（plan_hash 突合） |
| Bash / `PLANGATE_HOOK_FILE` 明示 | 従来判定 | **不変** |
| Edit / Write 全経路 | — | **不変** |

---

## 3. 方針 2 を採らなかった理由（実測に基づく）

方針 2 は `tool_input.command` から書き込み先パスを抽出して HO 判定に掛けるもの。既存の字句器 `scripts/check-approval-token-write.sh` の再利用可否を実測で確認した。

| 観点 | 実測 |
|---|---|
| 抽出器は path 非依存か | **非依存ではない**。`_redirect_writes_token()` は抽出と判定が一体で、末端で `_is_token_path "$_rw_t"` を呼ぶ。外側ゲート `_cmd_may_target_token()` も同様に token path 専用 |
| 判定述語を HO に差し替えられるか | **そのままでは不可**。`_may_expand_to_token_path()` の P1 / P2 は **「保護ディレクトリ 2 種（`approvals/` / `_maintenance/`）× `.json`」と「保護名リテラル 4 語（`maintenance.json` / `c3.json` / `parent-c3.json` / `parent-integration.json`）を 1 文字を除いて pin する」** という **basename リテラル前提**の幅ガード。HO は `.claude/rules/*.md` / `scripts/hooks/*.sh` のような **ディレクトリ glob 9 カテゴリ**で、pin 幅の概念が成立しない |
| 既存実装の戦歴 | 同じ領域で `#1045`（非書き込みリダイレクトの除去）→ `#1110`（リダイレクト先の相関判定・fail-closed 5 条件）→ `#1115`（glob / brace bypass・照合方向の反転）と少なくとも 3 回作り直されている。元設計書も Step 1 の切り出しについて「元設計書の 2 関数は現 main では閉包として不足」と結論している |
| fail-closed 側の副作用 | 既存の EH-13 は「解決不能な先は block」で fail-closed にしている。同じ方針を **HO 9 カテゴリ**に広げると、`exit 2` になる Bash コマンドの母数が桁違いに増える。誤 block の実害は **#1267 と同じ「全 Bash が止まる」** |

**結論**: 中途半端な抽出ロジックを新規に書くのは、この repo の履歴からして最も危険。方針 1 で「摩擦も防御も足さない」状態へ戻し、**方針 2 は #1104 の本体として別 PBI で扱う**（Step 1 の閉包の再設計 + HO 用述語 + 敵対レビュー 2 ラウンド以上 =
[`review-principles.md`](../../../.claude/rules/review-principles.md) §7-quater の外部作用層に該当）。

---

## 4. 残存脅威モデル（完全性を主張しない）

**守るもの**

- Edit / Write レーンの HO 9 カテゴリ block（不変）
- Edit / Write レーンの `plan.md` no-task block（不変）
- TASK 文脈がある場合の plan_hash 突合（Bash レーンでも不変）
- 「Bash を打つと止まる / CI が落ちる」という **可用性側の穴**（本 patch で塞ぐ）

**守らないもの（既知の残存 = #1104 open）**

- `echo x >> bin/plangate` のような **Bash 経由の HO パス書き込み**。EH-3 は Bash コマンド文字列を解析しない
- `sh -c` / エディタ起動 / スクリプト経由など、Bash から間接的に HO パスへ到達する一切

**この層以外で当該脅威を担っているもの**（本 patch で新たに担保したものではない。既存の多層防御の列挙）

| 層 | 何を担うか |
|---|---|
| EH-13 `scripts/check-approval-token-write.sh` | **承認トークン系ファイル**（`maintenance.json` / `c3.json` / `approvals/*.json`）への Bash 書き込み。**HO 9 カテゴリは対象外** |
| C-4 Human レビュー / branch protection | HO パスの変更が main へ入る経路 |
| 規範層（`.claude/rules/mode-classification.md` 承認境界節） | HO パスに触れる PBI の `lite_eligible=false` + Standard 同期 C-3 強制 |

**測っていないもの**: 実 Claude Code セッションでの 1 周（実 payload 形状・hook 起動タイミング）。本書の実測はすべて **手書き fixture payload** による。実 API 形状・タイミング由来の失敗は未検証。

---

## 5. patch（`git apply` 可能）

patch 本体は下の **`<!-- PG-PATCH-BEGIN -->` / `<!-- PG-PATCH-END -->` に挟まれた fenced block**。
抽出は marker 基準で行う（fence ラベルで探すと、本節の説明文中の fence 自身に誤ヒットする）。

````sh
# repo root で実行（Human-owned: HO パスへの書き込み）
sed -n '/^<!-- PG-PATCH-BEGIN -->$/,/^<!-- PG-PATCH-END -->$/p' \
  docs/working/_reports/1104-bash-lane-noop-patch-applicable.md \
  | sed -e '1d' -e '$d' | sed -e '1d' -e '$d' > /tmp/1104-bash-lane.patch
git apply --check /tmp/1104-bash-lane.patch && git apply /tmp/1104-bash-lane.patch
````

（行アンカー `^...$` を付けるのは、本節の説明文・コマンド自身に含まれる同じ文字列へ誤ヒットさせないため。`sed` を 2 回通すのは marker 行と fence 行を外側から 1 組ずつ落とすため（1 回の sed で `1d` を 2 度書いても同じ行にしか当たらない）。）

`tests/extras/ta-77-eh3-bash-lane.sh` は **同じ marker 規則**でこの block を抽出し、
サンドボックス複製へ適用して挙動を実測する（= **この block が壊れたらテストが FAIL する**）。

<!-- PG-PATCH-BEGIN -->
```diff
diff --git a/scripts/hooks/check-plan-hash.sh b/scripts/hooks/check-plan-hash.sh
--- a/scripts/hooks/check-plan-hash.sh
+++ b/scripts/hooks/check-plan-hash.sh
@@ -71,6 +71,35 @@
         | head -1 \
         | sed 's/.*"\([^"]*\)"$/\1/')
     fi
+  fi
+fi
+
+# ===== EH-3b: Bash レーンの明示 no-op（#1104 / PR #1267 の実測是正）=====
+# `.claude/settings.example.json` は PreToolUse matcher "Bash" にも本 hook を
+# 配線しているが、Bash の PreToolUse payload が持つのは tool_input.command で
+# あり tool_input.file_path ではない。したがって上の抽出は必ず空になり、
+# 以降は「対象パス不明」のまま進むため、実測では次の 3 点だけが起きる:
+#   - HO 判定は 1 度も一致しない（#1104 が塞ごうとした穴は塞がっていない）
+#   - no-task セッションでは SKIP_REASON 未設定として **全 Bash が exit 2**
+#   - SKIP_REASON を設定すると Bash 1 回ごとに skip-decision-log へ未追認
+#     エントリが増え check-skip-acknowledged.sh が FAIL する
+# 「防御を足さずに摩擦だけ足す」状態を避けるため、Bash レーンで対象パスが
+# 与えられていない場合は **明示的に何もしない**。
+# Bash コマンド文字列からの書き込み先抽出（= #1104 本来の意図）は未実装で
+# あり、**#1104 は open のまま**（既知の残存ギャップ）。詳細と残存脅威モデル:
+#   docs/working/_reports/1104-bash-lane-noop-patch-applicable.md
+# 適用範囲は **「対象パス未指定」かつ「TASK 文脈なし」の Bash payload のみ**:
+#   - PLANGATE_HOOK_FILE / $2 で対象が明示されていれば従来どおり HO / plan.md 判定
+#   - PLANGATE_HOOK_TASK が設定されていれば従来どおり plan_hash 突合を行う
+#     （plan_hash 検証は target_file を必要としないため、Bash レーンでも有効）
+# jq 不在時は本分岐を発火させない（誤って判定を緩めないための安全側）。
+if [ -z "$target_file" ] && [ -z "$task_id" ] && [ -n "${_stdin:-}" ] && command -v jq >/dev/null 2>&1; then
+  _tool_name=$(printf '%s' "$_stdin" | jq -r '.tool_name // empty' 2>/dev/null || true)
+  if [ "${_tool_name:-}" = "Bash" ]; then
+    reason="Bash lane without target path: EH-3 does not parse Bash commands (#1104 open)"
+    log_event "BASH_LANE_NOOP" "$reason"
+    printf '[Hook EH-3 BASH_LANE_NOOP] %s\n' "$reason"
+    exit 0
   fi
 fi
 
diff --git a/.claude/settings.example.json b/.claude/settings.example.json
--- a/.claude/settings.example.json
+++ b/.claude/settings.example.json
@@ -45,7 +45,7 @@
         ]
       },
       {
-        "_comment_": "Hook EH-3b (#1104): Bash route HO / plan.md guard. Applies the same HO decision as EH-3 to write-intent Bash commands.",
+        "_comment_": "Hook EH-3b (#1104, 未完 / no-op): Bash レーンの seam。check-plan-hash.sh は tool_input.file_path しか見ず Bash payload は tool_input.command なので、対象パスは常に空になる。実測上この配線は HO 判定も write-intent 判定も行わず BASH_LANE_NOOP で exit 0 する（防御効果はまだ無い）。Bash コマンドからの書き込み先抽出が入るまで #1104 は open。PLANGATE_HOOK_FILE を明示した場合のみ従来の EH-3 判定が働く。",
         "matcher": "Bash",
         "hooks": [
           {
```
<!-- PG-PATCH-END -->

### 適用後にやること

1. `tests/fixtures/eh3-bash-lane-pending-1104.flag` を **削除**する（既知ギャップの明示 opt-in。残したままだと `ta-77` TC-00b が stale 宣言として FAIL する）
2. `sh tests/extras/ta-77-eh3-bash-lane.sh`（standalone 実行可）で全 PASS を確認する
3. `sh scripts/apply-claude-settings.sh` を実行して `.claude/settings.json` へ反映する（Human-owned）

---

## 6. 検証済みであること / 未検証であること

| 項目 | 状態 |
|---|---|
| `git apply --check` が `origin/main` = `3f0cadd` で成功 | ✅ 実測 rc=0 |
| patch 適用後の hook が `sh -n` を通る | ✅ 実測 rc=0 |
| patch 適用後の settings.example.json が valid JSON | ✅ `json.load` 成功 |
| §1 の 6 ケースが patch 後に §2 の表どおりになる | ✅ `ta-77` が実測（サンドボックス複製） |
| `ta-77` の検出力 | ✅ 変異注入 4 種で実証（`ta-77` TC-08、結果は同ファイル冒頭コメント） |
| 実 Claude Code セッションでの 1 周 | ❌ 未実施（§4 の「測っていないもの」） |
| `tests/run-tests.sh` 全体の実走 | ❌ 未実施（ローカル 25 分超のため。`ta-77` は standalone 実行で確認） |
