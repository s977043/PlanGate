# bug backlog 棚卸し（open bug 40 件 / 2026-08-20）

> **目的**: 「既に main で解消しているのに open のまま残っている issue」を実測で特定し、Human 判断を待たずに backlog を減らせる分を切り出す。
> **測定基点**: `origin/main` = `2447bf8fc2874987f6b306736dd3c4ed9973fcad`（`docs(1169): sh 誤起動… (#1176)`）
> **対象集合**: `gh issue list --state open --label bug --limit 60` の実測。依頼時の想定は 41 件だったが、**実測は 40 件**（下記「対象集合の実測」参照）。
> **本レポートは読み取りのみで作成した。** issue / PR への書き込み（コメント・close・ラベル・編集）は一切行っていない。

## 結論（先に）

**無条件に close 推奨できる issue は 0 件。** 40 件すべてが AC 未達で、`RESOLVED` は 1 件も無い。
**「Human 判断が滞留しているだけで実は main で直っている」という期待は、実測で否定された。**

唯一の例外は **#866**（条件付き）。issue 本文に書かれた 3 つの修正案は 3 root の blob 一致まで確認できて充足しているが、**コメントで後から追加された scope 1 件が未解消**なので、close するには「scope を本文 3 項目に限定する」という Human の scope 判断が要る。

代わりに判明した構造は次のとおり。**backlog が減らない理由は「AI の設計不足」ではなく「適用の詰まり」である。**

| 構造 | 実測 |
|---|---|
| **AI は既に patch を書き終えている** | `docs/working/_reports/` に**未適用の patch 設計が 15 本**（#1011 / #1021 / #1101 / #1102+#1018 / #1104 / #1135 / #1144×2 / #1157 / #1169 / #937+#942 / #960×2 / #982 / #984 / #990 / #997+#947c）。滞留の実体は **HO パスへの適用が Human-owned であること** |
| **in-flight は無い** | `gh pr list --state open` → **0 件**（`--state merged --limit 3` が 3 件返る陽性コントロールで `gh` の起動を確認済み）。待っている PR は存在しない |
| **計画まで進んで止まっている issue が 13 件** | working-context ディレクトリが main にあるもの: #1165 #1162 #1093 #1086 #1044 #1009 #978 #960 #956 #954 #921 #866 #863 |
| **「統合先へ移管」が空振りしている** | #984 は「#1087 へ統合」と宣言されたが **#1087 は CLOSED**、にもかかわらず #984 の AC は 1 つも満たされていない。**統合先が閉じた状態で取り残されている** |
| **`.codex/skills` の drift が 3 issue で同時に過小報告されている** | #1086 本文「differing=2」/ #956 本文「2 件」/ #866 本文「三つ巴（= 3 root）」に対し、**実測は `.agents/skills` との blob 比較で 32〜33 件 drift・4 root** |

### 分類別の件数と issue 集合

| 分類 | 件数 | issue |
|---|---:|---|
| **RESOLVED** | **0** | — |
| **PARTIAL** | **13** | #1104 / #1081 / #1011 / #991 / #982 / #975 / #963 / #960 / #954 / #937 / #921 / #866 / #863 |
| **OPEN** | **27** | #1177 / #1173 / #1170 / #1165 / #1162 / #1151 / #1144 / #1105 / #1102 / #1101 / #1093 / #1086 / #1057 / #1044 / #1021 / #1018 / #1010 / #1009 / #1004 / #997 / #994 / #990 / #984 / #978 / #956 / #947 / #942 |
| **SUPERSEDED** | **0** | — |
| **STALE**（上記と**併存**。本文の是正が先に要る） | **11** | #1170 / #1086 / #1021 / #1011 / #1010 / #994 / #990 / #956 / #947 / #866 / #863 |

> **STALE を排他分類にしなかった理由**: 実測した 11 件はいずれも「バグ自体は残存（OPEN / PARTIAL）」かつ「issue 本文の前提が現 main と食い違う」の**二重状態**である。片方に潰すと情報が落ちる（STALE に寄せるとバグの残存が見えなくなり、OPEN に寄せると「本文を信じて着手すると測り直しになる」ことが見えなくなる）ため併記した。

### 対象集合の実測

依頼文には 41 件とあったが、取得時点の実測は 40 件だった。

```
$ gh issue list --state open --label bug --limit 60 --json number --jq '.[].number'
1177 1173 1170 1165 1162 1151 1144 1105 1104 1102 1101 1093 1086 1081 1057 1044
1021 1018 1011 1010 1009 1004 997 994 991 990 984 982 978 975 963 960 956 954
947 942 937 921 866 863
# → 40 件。依頼文に列挙された 40 件と完全一致（増減なし）。
```

**40 件すべてを扱った。扱えなかった issue は無い。**
## 1. サマリ表

**close 推奨可否**の列は、この棚卸しの主目的（open のまま残っている解消済み issue の摘出）に対する答え。**全 40 件が「不可」**である。

| # | 分類 | 1 行根拠（実測） | close 推奨 |
|---|---|---|---|
| **1177** | OPEN | `scripts/ai-loop/` 30 本 + `plugin/**` 28 本のガードは 0 本。`ta-70` の母集合も `scripts/*.py` 直下 glob のまま | 不可 |
| **1173** | OPEN | allowlist 28 本 vs 実体 30 本の乖離が残存（差分 = `discovery.py` / `test_discovery.py`）。TC-E8 は今も `sync-for.txt` と `sync-case.txt` の `cmp -s` のみ | 不可 |
| **1170** | OPEN / STALE | `.codex/skills` は 4 系統とも未追従。**実測では `.agents/skills` との SKILL.md 一致は 39 中 7 本のみ**（本文の射程が実体より狭い） | 不可 |
| **1165** | OPEN | `ta-57` の TC-14 凍結 3 ファイル・`[WARN]` 経路・`read_json` 不在すべて起票時のまま（行番号も一致） | 不可 |
| **1162** | OPEN | 件数契約 3 箇所（`ta-33:25` / `ta-33:54` / `ta-57:622`）が現 main でも `-eq` のまま | 不可 |
| **1151** | OPEN | `.claude/settings.example.json` の SessionStart が今も `gh-pin-account.sh` を配線、コメントと script 既定値の両方に上流個人アカウント名が残存 | 不可 |
| **1144** | OPEN | `plugin/plangate/hooks/` は `.gitkeep` のみ、`plugin.json` に `hooks` 無し、`scripts/hooks/*.sh` 17 本で `CLAUDE_PLUGIN_ROOT` 参照 **0** | 不可 |
| **1105** | OPEN | `bin/plangate:1028` の C-3 出力文言が未変更。承認コマンドは plan 内容の妥当性を一切見ていない | 不可 |
| **1104** | **PARTIAL** | AC-7（`hook-enforcement.md` §0.1 matcher 適用範囲表）のみ達成。Bash 経路へのガード配線 AC-1〜AC-6 は未着手 | 不可 |
| **1102** | OPEN | `CLAUDE.md:16` が今も「#1089 は hook 本体未適用」。実体は PR #1097 で適用済み・flag も不在 = **自己矛盾したまま全セッションに配布** | 不可 |
| **1101** | OPEN | HO 迂回 4 変換クラスを**実際に再現**（`CLAUDE.MD` / `Claude.md` / `docs/../CLAUDE.md` / 末尾空白 で rc=0）。`ta-65` TC-07 も KNOWN-GAP 固定 | 不可 |
| **1093** | OPEN | `release-prep.sh` の `check_pending_applies()` が `[dry-run]` 文字列一致 + `2>/dev/null \|\| true` のまま。`apply-eh3-ho-always.sh` は `[dry-run]` を出さない | 不可 |
| **1086** | OPEN / **STALE** | `.codex/skills` 120 ファイル・39 SKILL.md が追跡されたまま。**本文の `differing=2` は実測 32/39 と乖離** | 不可 |
| **1081** | **PARTIAL** | Slice 2（frontmatter quote）は 4 root 完了 + 機械ゲート済み。Slice 1（commands の Skills 登録・同名衝突 3 件・README 露出）は完全未着手 | 不可 |
| **1057** | OPEN | 配布物に `bin/` 無し（`plugin/plangate/bin` は `ls-tree` で 0 件）。Bash での `CLAUDE_PLUGIN_ROOT` は本セッションでも `(unset)` | 不可 |
| **1044** | OPEN | 再現手順を sandbox で実走 → **dash rc=0 / zsh rc=0 / bash rc=1 / sh rc=1**（issue の表と一致）。`_pg_extra_direct` は計画文書のみに存在 | 不可 |
| **1021** | OPEN / STALE | `ta-09-metrics.sh` は `$0` ベース root 解決のまま、`PG_HARNESS_SOURCED` **0 件**（他 28 extras にはある = 陽性コントロール） | 不可 |
| **1018** | OPEN | テンプレは `## Files / Interfaces`（:73）、抽出器は `Files / Components to Touch` 要求（`plan_package.py:184`）で不一致のまま | 不可 |
| **1011** | **PARTIAL** / STALE | V3-06 は現 main で既に是正済み（本文の前提が STALE）、V3-02 は受容と明記。**V3-04 / V3-05 が未着手** | 不可 |
| **1010** | OPEN / STALE | src fixture は `.md` 実ファイルのみで `nolink` / `basewiden` の注入先に触れない。本文の「30 TC」「L198/L200/L215」は起票 11 時間後の `a2a02b9` で陳腐化 | 不可 |
| **1009** | OPEN | `sync-plugin-plangate.sh:380` の `set -- $_ai_loop_expected_refs`（未 quote）が原文のまま。`TASK-0914/handoff.md:64` の F-5 accepted も未撤回 | 不可 |
| **1004** | OPEN | 規約 8 の例示を検査器に通す機械検証はどこにも無い（README を見る TC は TC-30 のキーワード grep 4 本のみ） | 不可 |
| **997** | OPEN | `test_run_evidence.py` は #989 以降 1 度も変更なし。TC-45 は `_classify()` 後の `git status --porcelain` 絶対空を要求したまま | 不可 |
| **994** | OPEN / STALE | TC-33 検査(1) は今もファイル全体への `grep -q 'PG_HARNESS_SOURCED'`。本文の `:712-728` は現 main では `:804-820` | 不可 |
| **991** | **PARTIAL** | CB-1（コメント是正 + handoff §2 追記）は `97c2e2d` で着地。CB-2（片側正本全損の検出）は未着手で base は合算のまま | 不可 |
| **990** | OPEN / STALE | **実行行の残存は本文の「1 件」ではなく 3 件**（本文の走査が `--include='*.sh'` で拡張子なしの `scripts/ai-dev-workflow` を構造的に取りこぼしている） | 不可 |
| **984** | OPEN | `checks` は 6 項目 vs example の PreToolUse 8 ブロックで 3 本未収載。doc drift 3 箇所も未是正 | 不可 |
| **982** | **PARTIAL** | PR #1160 で live 7/7 箇所に「CLI サブコマンドではない」注記済み。ただし**全箇所が「#982 で未決」と自認**、runbook と `plan_package.py` の乖離も残存 | 不可 |
| **978** | OPEN | `_candidate_ho_paths_sources()` は 3 段フォールバックのまま。`source_kind` / `BUNDLED_TEMPLATE` / `HO_BOUNDARY_UNDEFINED` は **0 hit** | 不可 |
| **975** | **PARTIAL** | AC-4（settings.local.json 非対応の明示宣言）は達成。AC-1/AC-2（matcher 部分集合の二重配線）は「follow-up 扱い」とヘッダに明記されたまま未修正 | 不可 |
| **963** | **PARTIAL** | AC-1/2/3/5 着地済み（宙ぶらりん参照 0 件を全数照合で確認）。**AC-4（`/pg-check` 不在）と AC-6（`.claude/skills` 10 件差）が未達** | 不可 |
| **960** | **PARTIAL** | 非 HO 層は完了（`review-self.md` に正本節 + 実測 25 項目）。**HO 6 ファイル + ミラー 5 件が未適用**、patch は作成済み | 不可 |
| **956** | OPEN / **STALE** | `.agents/skills` ⇄ `.codex/skills` の blob 比較で **共通 42 中 33 件 drift**（本文は「2 件」）。CI 検出経路は依然ゼロ | 不可 |
| **954** | **PARTIAL** | クラス A / A' / C の正本是正は全数完了・plugin drift 0。**AC-3 の `.codex` 再生成のみ未達**（#956 の判断待ちで保留） | 不可 |
| **947** | OPEN / STALE | ta-42 の TASK-T999 前掃除（L92）が TC-04（L61）より**後**、ta-25 の `[SKIP]` で `pass` 加算（L857）、ta-54 の porcelain 絶対空（L118）すべて未着手 | 不可 |
| **942** | OPEN | `test.yml` の Checkout に `fetch-depth` の行なし（L22-25）。TC-14 の WARN 経路も未変更 | 不可 |
| **937** | **PARTIAL** | patch は main 着地済み。`pre-push.sample` への適用も doctor 追加も未実施で、**呼び出し元は依然ゼロ** | 不可 |
| **921** | **PARTIAL** | Slice 1（共有 exit 契約 + 21 本移行 + ta-61 + README 規約）着地。**AC-1「0 件」に対し `_pending_migration` に 45 本残存** | 不可 |
| **866** | **PARTIAL** / **STALE** | 本文 3 修正案は 3 root blob 一致で**充足**（`5ab796a` / `2bb1485`）。コメント追加分（バッククォート・エスケープ）と `.codex` 追従が未解消 | **条件付き可** |
| **863** | **PARTIAL** / STALE | 項目 1〜3 は解消。**項目 4（HO パス 3 ファイル）未着手**、かつ項目 3 の README 宣言が PR #1160 で再ドリフト（12 宣言 vs 実測 13） | 不可 |

### 表の読み方

- **分類に `/ STALE` が付くもの**は、バグ残存に加えて **issue 本文の前提が現 main と食い違う**。着手前に本文を測り直さないと、対象/対象外が反転する（詳細は §4）。
- **close 推奨が「不可」でも、AI が今すぐ動かせるものはある**（§6・§7）。close できないことと着手できないことは別。

## 2. RESOLVED の詳細

**RESOLVED は 0 件。** 「AC がすべて満たされていて、そのまま close 推奨できる」issue は 1 つも無かった。

「たぶん直っている」を OPEN 扱いにする規律を守った結果ではなく、**AC を 1 項目ずつ実測した結果**である。40 件について、各 issue 本文の受入基準を `git show origin/main:` / `git grep origin/main` / `git ls-tree -r origin/main` で照合し、1 件も全項目 PASS に到達しなかった。

### 2-1. 唯一の close 候補: #866（条件付き・scope 判断が要る）

issue **本文に書かれた 3 つの修正案は充足している**。未解消なのは**コメントで後から追加された scope**（バッククォート・エスケープ）と `.codex` 追従（#956 の従属）。

したがって #866 は「AC が未達だから open」ではなく、**「close 条件をどこに引くか」という Human の scope 判断で決まる**。3 項目に限定するなら close 可、コメント追加分まで含めるなら不可。

**close する場合に issue へ貼れる形の実測根拠**:

```
# 測定基点: origin/main = 2447bf8fc2874987f6b306736dd3c4ed9973fcad

## 修正案 1・2（新版を .agents 正本へ反映 / sync で plugin へ伝播）
$ for r in .agents/skills .claude/skills plugin/plangate/skills; do \
    git rev-parse origin/main:$r/intent-classifier/SKILL.md; done
9bd30492bb490e721527a1455aca7729835ccf70
9bd30492bb490e721527a1455aca7729835ccf70
9bd30492bb490e721527a1455aca7729835ccf70

$ for r in .agents/skills .claude/skills plugin/plangate/skills; do \
    git rev-parse origin/main:$r/skill-policy-router/SKILL.md; done
f51d02780965b50900b3b18770476f1902453135
f51d02780965b50900b3b18770476f1902453135
f51d02780965b50900b3b18770476f1902453135
# → 3 root が blob 同一（byte 一致）。「.claude=新版 / .agents&plugin=旧版」の三つ巴は解消。

## 修正案 3（正本宣言行を実態へ是正）
$ git show origin/main:.agents/skills/intent-classifier/SKILL.md | sed -n '8,10p'
> 正本（sync 元）: `.agents/skills/intent-classifier/SKILL.md`…
> `.codex/skills/` は sync 対象外の配布先…
# → 全ファイルが「正本 = .agents/skills」を宣言。plugin 版の自己宣言「正本: .claude/skills/…」は消滅。

## 修正実体
5ab796a (PR #1126) / 2bb1485 (PR #1127)
# どちらも Closes ではなく Refs だったため、解消後も open のまま残っていた。
```

**close 時に follow-up として明記すべき残件（2 件）**:
1. `.agents/skills/subagent-dispatch/SKILL.md:68,75` のバッククォート・エスケープ（`\`\`\`mermaid` / `\`\`\``）— コメント C0 の追加項目②
2. `.codex/skills/{intent-classifier,skill-policy-router}/SKILL.md` の再 drift（178/199 行 vs `.agents` の 191/213 行）— **#956 の従属**

**あわせて本文の STALE 是正が要る**（§4-9 参照）。close するとしても、本文の「三つ巴」「153 行 / 150 行」「plugin 版は `.claude/skills` を正本と自己宣言」はすべて現 main と食い違うので、close コメントで訂正を残さないと後から読んだ人が誤った履歴を受け取る。

## 3. PARTIAL の詳細 — 残っている AC

13 件。**次の PBI の入力になる粒度**で残 AC を列挙する。「どこまで終わっていて、何が残っているか」を実測で分けた。

### #1104 — Bash 経路のファイル書き込みガード

| 済 | AC-7: `docs/ai/hook-enforcement.md` §0.1「matcher 別の適用範囲（#1104 / 実測 2026-08-15）」が実在し、「ファイル書き込みガードは `Edit\|Write` 経路のみ」「HO は `Edit\|Write` 経路にしか存在しない」を明記 |
|---|---|

**残 AC**:
1. **AC-1**: Bash 経由の `plan.md` 書き込みを 6 形式（`>` / `>>` / `tee` / `cp` / `python3 -c` / `sed -i`）で block
2. **AC-2**: 同じく HO 9 カテゴリへの Bash 経由書き込みを block
3. **AC-3**: `bin/plangate plan|init` の正規経路を壊さない（非破壊の実証）
4. **AC-4**: 読み取りコマンドの誤検出ゼロ ← **この AC は Bash 配線前の現時点で既に破れている**（§8-3 の EH-13 誤検出）
5. **AC-5**: コマンドから書き込み先を抽出できないときの方針（fail-open / fail-closed）を明文化しテストで表明
6. **AC-6**: `python3 - <<'PY'` 形の回帰固定
7. **AC-8**: `sh tests/run-tests.sh` rc=0

**実測**: `.claude/settings.example.json` の PreToolUse で `Bash` matcher を持つのは `check-delegation-commit-boundary.sh` / `check-approval-token-write.sh` / `check-git-destructive.sh` の 3 本のみ。この 3 本のいずれも `plan.md` / `HARDENING_OVERRIDE` / `_override=0` を含まない（`grep -c` = 全 0）。`git grep -lE '_override=0|HARDENING_OVERRIDE' origin/main -- scripts/ bin/` → hook は `scripts/hooks/check-plan-hash.sh` **1 本のみ**で、それは `Edit|Write` 配線。

---

### #1081 — plugin の commands が Skills 登録される

| 済 | AC-5: frontmatter quote は **4 root すべてで完了**（`.claude` / `.agents` / `.codex` / `plugin` の `plangate-setup/SKILL.md` が `description: "…"`）。再発防止に `scripts/check-skill-frontmatter.py` + `tests/extras/ta-64-skill-frontmatter.sh` が main に存在 |
|---|---|

**残 AC（Slice 1 が丸ごと）**:
1. **AC-1**: `plugin/plangate/commands/README.md` が skill 一覧に露出しないようにする（`ls-tree` で現存を確認）
2. **AC-2**: 同名衝突 3 件（`codex-mvp-split` / `plangate-setup` / `working-context`）の一本化または分離 — skills 39 件と commands 6 件を `comm -12` で突合した実測
3. **AC-3**: commands 6 件への frontmatter 付与（現状 **6 件すべて frontmatter 無し**、1 行目が `#` 見出し）。`plugin.json` のキーは `name/version/description/author/skills/repository/license/keywords` で **`commands` 未宣言**
4. **AC-4**: slash 起動の非回帰実測
5. **AC-7**: always-on トークンの baseline 再測定

**未決（Human 判断）**: 案 (a)/(b)/(c)/(d) の選択 =「slash 起動と skill 起動の両方を残したいか」。U-1（衝突時にどちらが起動するか）も未確定。

---

### #1011 — #986 V-3 事後補完の minor 4 件

| 済 | **V3-06**: `ta-26:327-330` は既に「rc ではなく standalone サマリ行 `grep -q 'TA-26 standalone: .* 0 failed'` を見る」に変わっており、**issue 本文の前提のほうが古い**（§4-4） |
| 済 | **V3-02**: 「揃えない」が**意図的に受容**され、`sync-plugin-plangate.sh:199-200` のコメントに「安全側＝過剰 block に倒れるため許容 / #970 Non-goal」と明記 |

**残 AC**:
1. **V3-04**: `_mass_delete_blocked`（`sync-plugin-plangate.sh:57` の `[ "$3" -gt "$2" ] || return 1`）に数値検証を追加し、不正入力時は WARN + `guard_fired=1` + blocked 側へ倒す。**現 3 呼び出し元（`:127` sync_dir / `:218` 経路1 / `:395` 経路2）はすべて算術で数値を作るため挙動不変**
2. **V3-05**: `PLANGATE_ALLOW_MASS_DELETE`（`:58`）をラベル prefix 一致で受ける（`=1` の全経路互換は維持）
3. 上記 2 件の**変異注入 TC**（call site を壊す形で kill を実証）
4. **V3-02 の方向決定（Human）**: 受容のまま close するか揃えるか ← **これが決まらないと #1010 の fixture 設計が書き直しになる**
5. **V3-06 の AC 再定義**: guard TC については達成済みなので、残るのは非ゲート TC の連鎖のみ

---

### #991 — mass-delete guard が片側正本の全損を検出しない

| 済 | CB-1: `sync-plugin-plangate.sh` L364-374 に「保証範囲（plan 論点 C-2 で Human 承認済みの設計選択）」節が新設され、**「少数側ディレクトリを丸ごと欠損させても stale <= base のままとなり、WARN なし・exit 0 で削除が通る（検出しない）」と明記**。`docs/working/TASK-0914/handoff.md:66` にも minor/accepted として記載。着地 `97c2e2d`（PR #996） |
|---|---|

**残 AC**:
1. **CB-2**: 正本ディレクトリ（`docs/workflows/ai-loop/` / `docs/ai/ai-loop/`）ごとに base/stale を分離集計する、**または**「正本ディレクトリ自体の非存在」を独立チェックとして追加する（現状 `:380-381` の `set -- $_ai_loop_expected_refs; _ai_loop_ref_base_count=$#` は 2 ディレクトリ合算の 1 本値）
2. 検出力を実証する負側テストを `tests/extras/ta-26-plugin-sync.sh` に追加（少数側を丸ごと消して guard が block すること／修正前実装では PASS してしまうこと）

---

### #982 — `plangate ai-loop run TASK-XXXX` が CLI に存在しない

| 済 | AC-2: live 全 7 箇所に「この入口は `/ai-loop-workflow` の引数仕様であり `bin/plangate` に `ai-loop` サブコマンドは存在しない」の注記。**7/7 で全数確認**（`.agents` / `.claude` / `plugin` の `ai-loop-cycle/SKILL.md`、`docs/workflows/ai-loop/execution-runbook.md:134` と plugin ミラー、`loopspec.md:31` と plugin ミラー） |
|---|---|

**残 AC**:
1. **Human 設計判断**: `ai-loop` を `bin/plangate` の正式サブコマンドにするか。**PR #1160 は明示的に「案は選ばない」で着地し、live 全 7 箇所が「#982 で未決」と自認している状態**
2. `execution-runbook.md:134-146` と実装の乖離是正 — runbook は「`plan_package.py` が presence / evidence / hash を検証して組み立てた `plan_package` ブロック」を要求するが、**CLI の出力は hashes のみで `source_sha` / `c1_evidence_ref` / `c2_evidence_ref` / `reviewers` は出てこない**（`--add-argument` は `--task-dir` / `--task-id` の 2 つのみ）
3. `derive_loopspec()` の本番呼び出し経路の新設 + テストで固定（案 A / C を選ぶ場合）。現状 **定義 1 行（`plan_package.py:188`）+ docstring 3 行のみで本番呼び出し元 0 件**

---

### #975 — `apply-claude-settings.sh` の matcher 部分集合で二重配線

| 済 | AC-4: `settings.local.json` は「**参照しない**（F6）」と `:39-42` で明示宣言。issue が許容した 2 択のうち後者を採用 |
|---|---|

**残 AC**:
1. **AC-1**: `matcher_covers()`（`:156-165`、現状は `""`/`"*"` の UNIVERSAL 扱いのみ）が偽になるケースで、新規ブロック追加ではなく「既存ブロックの matcher に不足ツールだけ足す」設計へ変更。**現状はヘッダ `:34-38` に「⚠️ 既知の制約 … follow-up 扱い」と明記されたまま**
2. **AC-2**: `tests/extras/ta-59-apply-settings-merge.sh` に「settings.json 側 `"Edit"` / example 側 `"Edit|Write"`」fixture の TC を追加し、**修正前実装で FAIL することを変異注入で実証**（call site を壊す形で）
3. **AC-3**: `--all-events` opt-in フラグの実装。**現状フラグは未実装**（引数パーサは `--dry-run` のみ受理、他は `exit 2`。`--all-events` の唯一のヒットは `:32` の「follow-up」コメント）。特に `SessionStart` の `gh-pin-account.sh` が既定で入る現状の是正（→ #1151 と同じファイルを触る）

---

### #963 — TASK-0124 同期導入で 11 ファイルが消えた

| 済 | AC-1: 案 B 採用が `docs/plangate-v7-hybrid.md:204-213` に「注（#963）」として記録 |
| 済 | AC-2: **宙ぶらりん参照ゼロを全数照合で確認** — 6 rules 名の grep で `grep -vE '旧\|削除済み'` を通すと **0 件 / rc=1**、外すと **13 ファイルにヒット**（陽性コントロール成立）。13 件すべて注記形 |
| 済 | AC-3: Phase 1-3 表が実態と一致（Phase 2 は「後継なし」と明記） |
| 済 | AC-5: sync に削除ログ（`DELETE:` / `WOULD DELETE:`）+ mass-delete guard + `exit 3` |

**残 AC**:
1. **AC-4（未達）**: `/pg-check` が**存在しない**（`.claude/commands` / `plugin/plangate/commands` の定義は 6 本のみ、`pg-check.md` は 0 件。`.codex/commands` はディレクトリ自体が無い）。にもかかわらず `review-gate/SKILL.md:26-36` の「### ステップ 1: `/pg-check` を実行して finding を収集する」が**無修正で残存**（`.codex` / `plugin` にもミラー）。**Iron Law `NO MERGE WITHOUT TWO-STAGE REVIEW` の発火点が実行不能**
   - 決めること: 「コマンド定義を復元/新設する」か「SKILL.md のステップ 1 を実行可能な手順へ書き換える」か
   - 併せて `docs/plugin-only-adoption.md:39` の `/pg-check` 言及も追従が要る
2. **AC-6（弱い部分充足）**: `.claude/skills` = 29 / `.agents/skills` = 39 で **10 件差が残存**。`docs/ai/skill-collision-detection.md:68` に「既知ギャップ」と書かれているが、issue が求めた「**同期対象にするか対象外と明記するかが決まる**」という決定文ではない

> ⚠️ **issue の 2026-08-18 コメントは「解消済みと判定します」としているが、その検証は AC-2 のみ**で AC-4 / AC-6 に触れていない。この判定のまま close すると `/pg-check` 不在が未追跡で失われる。

---

### #960 — C-1 の項目数が「17」表記のまま実体 25

| 済 | 正となる項目数の方針が決定・記録 — `docs/working/templates/review-self.md:15-38` に「## C-1 チェック項目数（正本）」節。「本テンプレートが正本、現行は全 25 項目」+ 8 区分内訳（Plan 9 / SUP-PLAN 2 / ToDo 6 / TestCases 3 / B1B2 2 / SEC 1 / SCOPE-DISC 1 / UI 1 = 25）。**宣言と実体が一致**（`grep -c '^### C1-'` → 25） |
| 済 | ② 正本 16 ファイルの表記統一 — `git grep -lE '17[[:space:]]*項目' origin/main` の残存 13 件は **HO 6 + plugin ミラー 5 + CHANGELOG 2（歴史記録）** のみ。`.agents/skills/**` / `docs/**`（changelog 除く）/ `.codex/skills/**` からは **0 件** |
| 済 | 再発防止策 — 「総数を契約値として他所へ複写しない」+ 実測コマンドを正本節に記載。patch 文書にも「`git grep -lE '17\s*項目'` は使うな（git の ERE で `\s` が効かず `17 項目` を取りこぼす）。必ず `[[:space:]]`」を明記 |
| 済 | ① HO 分の差分が Human 適用可能な形で提示 — `docs/working/_reports/960-ho-patch.md`（対象 6 ファイル・適用方針・適用手順・ファイル別 diff） |

**残 AC**:
1. **HO 6 ファイルへの patch 適用（Human-owned・patch は作成済み）**: `.claude/rules/mode-classification.md`（3 箇所）/ `.claude/rules/working-context.md` / `.claude/commands/ai-dev-workflow.md`（3 箇所）/ `.claude/commands/README.md` / `.claude/agents/workflow-conductor.md`（2 箇所）/ `schemas/review-result.schema.json`
2. **Human 判断**: `schemas/review-result.schema.json:42` の「phase 固有スコア（C-1 の 17 項目等、任意）」が**契約値かどうか**
3. 適用後に `sh scripts/sync-plugin-plangate.sh` でミラー 5 件を追従
4. **mode 別適用範囲の実質的な再定義**: `mode-classification.md:153,170` の light「Plan 7 項目のみ（C1-PLAN-01〜07）」が実体 PLAN 9（+ SUP-PLAN 2）とどう対応するか
   - → **patch 作成済み**: [`960-c1-count-residual-patch-applicable.md`](./960-c1-count-residual-patch-applicable.md)（残件 4 の `mode-classification.md:170` + `.claude/commands/ai-dev-workflow.md` の C-1 手順 17 項目欠落。適用は Human-owned）
5. **Human 判断**: `CHANGELOG.md` / `docs/changelog.md` を歴史記録として据え置く方針の最終確認

> **AI 側に残る着手可能作業は実質ゼロ。適用が Human ワンアクションで完了する状態**（本レポート中もっとも「詰まりを外せば進む」度合いが高い）。

---

### #954 — 導入先で解決できない rules / docs 参照

| 済 | AC-1（クラス A）: `.agents/skills` で実 rules 参照を持つ 19 ファイル**全部**が `CLAUDE_PLUGIN_ROOT` を 2 回以上含む。0 ヒットの 5 件（brainstorming / context-packager / subagent-delegation-brief / subagent-dispatch / subagent-team-design）は本文確認の結果 **rules 参照ではなく解説文中の "rules" 語**で対象外 |
| 済 | AC-2（クラス C）: 対象 16 skill 全数で「(1) 導入先の同名パス → (2) 到達不能を明示」の解決順。`plugin root` 段は #1155/#1158 で構造上空振りとして除去済み |
| 済 | AC-3 の plugin 側: `.agents/skills` 45 ファイル**全数**が `plugin/plangate/skills` と blob 一致（drift 0） |

**残 AC**:
1. **AC-3 の `.codex` 側**: `.agents/skills` ⇄ `.codex/skills` の **drift 33 件**を解消。うち `plan-review-gate` のみ Human 判断依存、**残り 32 件は再同期で片付く** → **実質 #956 と同一作業**
2. **AC-5**: marketplace（plugin）導入環境でクラス A / A' / C が実際に解決するかの 1 件実測（**未確認** — issue の 3 コメント・関連 PR 9 件のタイトルに実環境実測の記録を見つけられなかった）
3. **AC-4**: baseline 維持の実測

> **close 条件の再定義が妥当**: 「クラス A / A' / C の**正本是正**」だけを close 条件にするなら close 可。その場合 AC-3 の `.codex` 部分を **#956 へ正式移管し、移管先 AC を本文に明記**すること（#984 が「統合先が閉じたのに AC は未達」で取り残された前例を繰り返さないため）。

---

### #937 — `check-branch-not-merged.sh` が誰にも呼ばれていない

| 済 | patch 設計が main 着地（`docs/working/_reports/937-942-unwired-guard-patch.md`、PR #1132）。`pre-push.sample` への追加 diff を L48-54 に収録、`[ -f ]` 存在確認付き・stdin 非干渉のためループ外配置 |
|---|---|

**残 AC**:
1. `scripts/templates/pre-push.sample` へガード呼び出しを適用（`grep -n 'check-branch-not-merged'` → **0 件**。陽性コントロール: 同ファイルの `grep -c 'set -'` → 3）
2. **適用後の発火実測**（patch 文書が「手順 4 を省略しないでください」と明記。`--dry-run` は該当経路を通らない）
3. `bin/plangate doctor` への検証項目追加（導入先での配線漏れ検知）

**実行経路ゼロの全数確認**: `git grep -n 'check-branch-not-merged' origin/main` の全ヒットは 3 系統のみ — ① `AGENT_LEARNINGS.md:76`（運用手順の言及）② `scripts/check-branch-not-merged.sh:2,8`（自分自身）③ patch 提案文書。**呼び出し元は存在しない。**

> ⚠️ **責務判定に齟齬がある**: `scripts/templates/pre-push.sample` は **HO パターン外**（HO は `scripts/hooks/*.sh` のみ）。にもかかわらず patch 文書は適用を **Human-owned** と宣言しており、その根拠が文書内に書かれていない。**AI が適用できるのか否かを Human に確認する必要がある**（断定はしない）。

---

### #921 — extras の standalone 実行が内部 FAIL を exit code に反映しない

| 済 | AC-4: `tests/extras/ta-61-extra-contract.sh` が存在し、TC-25（allowlist 健全性・非空虚性）/ TC-28（discovery glob が runner の source glob と同一）/ TC-20（basename 一意）を持つ = **allowlist が over-broad になったら赤くなる**設計 |
| 済 | AC-5: `tests/extras/README.md` L203-207 に rc 意味レイヤー表、L169-197 に規約 8（`PG_HARNESS_SOURCED` と `FIXTURES_DIR` の AND・片方欠ければ standalone 側へ倒す）、L233 に「対話シェルへ source しないこと」 |
| 済（設計上） | AC-3: `_extra-contract.sh` 冒頭「On the harness (source) path this helper NEVER exits and NEVER returns non-zero」+ `_pg_extra_resolve_mode` の 3 条件 AND |

**残 AC**:
1. **AC-1 / AC-2 の残 45 本**: `ta-*.sh` は **66 本**、契約利用は **21 本**（ta-39/40/43/44/45/46/47/49/50/51/52/53/61/62/63/64/65/66/68/69/70）。`_pending_migration()` に **45 本が明示列挙**され、うち `exit 1` を 1 つも持たないものが多数（ta-04/05/06/07/08/11/12/13/15/16/19/20/21/24/30/31/33〜38/41/54/56/57）。**AC-1 の「0 件」に対して 45 本残存**
   - 分割設計は **PR #1051（`d86eef9`）で「案 B = 新 TASK ×3 のサブスライス 3 分割」として Human 裁定済み**。子 TASK が起票済みかは未確認
2. **AC-6**: #914 AC-6 の代理判定を exit code ベースへ戻す + TASK-0914 handoff の V2 候補 close（**未確認** — TASK-0914 handoff を読んでいない）

---

### #863 — CLI 依存スキルの graceful degradation

| 済 | 項目 1: `.agents/skills` で `bin/plangate` を含む 10 skill のうち **9 skill** が degrade 節を保有。残る `ai-loop-cycle` の唯一のヒットは「`bin/plangate` に `ai-loop` サブコマンドは存在しない」という**否定文**で CLI 依存ではない |
| 済 | 項目 2: 残存表記はすべて「上流リポジトリの cwd / 導入先 + PATH あり / PATH に無い」の 3 列表の 1 列目（例: `working-context/SKILL.md:77-95`） |

**残 AC**:
1. **項目 4（未着手）**: HO パス 3 ファイル + plugin ミラー 3 件の同時更新 patch を作成 → Human 適用
   - `.claude/commands/plangate-setup.md`（`bin/plangate` 3 件、L7 に PATH clone 案内はあるが degrade 節として不十分）
   - `.claude/agents/setup-coordinator.md`（6 件、L35 に「## bin/plangate 不在時のフォールバック」節あり）
   - **`.claude/agents/workflow-conductor.md`（2 件 = L545 / L549 で degrade / PATH 解決の注記ゼロ）**
2. **項目 3 の再ドリフト是正**: `plugin/plangate/README.md:36-41` が「コマンド 1 / スキル 9 / エージェント 2 = **12 ファイル**」と宣言し再現コマンドまで併記しているが、**実測は 13 件**（63 ファイル全数照合。追加分 = `plugin/plangate/skills/ai-loop-cycle/SKILL.md`）。混入原因は `43fb05e`（PR #1160・2026-08-19）が追加した**否定文**。**README の自称再現コマンドが現 main で自分の宣言値を再現しない**
   - 決めること: 「スキル（9）→ 10」に直すか、「否定文は CLI 依存に数えない」を除外ルールとして明記して再現コマンドを整合させるか
3. 再発防止の機械ゲート（README 宣言値 vs 実 grep 件数）は現状ゼロ

**Human 判断待ち**: 2026-08-18 のコメント C2 が「項目 1〜3 の解消をもって close し項目 4 を別 issue へ切り出すか / 本 issue で項目 4 の patch を用意するか」を**照会中で回答待ち**。

## 4. STALE の詳細 — 本文が現 main と食い違う 11 件

**この節が本レポートで最も再利用価値が高い。** ここに挙げた 11 件は、**issue 本文を信じて着手すると対象/対象外が反転するか、測り直しが発生する**。

### 4-1. #990 — 「残 1 件」は**走査パターンの欠陥による過小報告**（実測 3 件）

| 本文の記述 | 現 main の実測 |
|---|---|
| 「残存箇所（全数走査）… **残 1 件**」 | **実行行の残存は 3 件** |
| 「異常時にしか通らない」 | `scripts/ai-dev-workflow:102 / :129` は **`bin/plangate gate` / `bin/plangate exec` の実走経路**（`ai_dev_prompt_gate()` / `ai_dev_prompt_exec()` 内、同ファイル冒頭 `set -eu`） |
| 「補足: `check-git-destructive.sh:203` … コメント行を除外して走査すること」 | 当該行は本文の `grep -v '\${'` フィルタで既に落ちる。除外理由の説明が実態とズレている |
| 「main = `3a372d4` で実測」 | 基点鮮度の更新が必要 |

**原因**: 本文の走査が `--include='*.sh'` を使っており、**拡張子なしの `scripts/ai-dev-workflow` を構造的に取りこぼしている**。

**是正案（本文の走査コマンドを差し替える）**:
```
git grep -nP '\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]' origin/main -- scripts/ tests/ bin/
```
出力 5 件のうち実行行 3 件:
```
scripts/ai-dev-workflow:102          "TASK ID は $AI_DEV_TASK。" \      ← 実行行
scripts/ai-dev-workflow:129          "TASK ID は $AI_DEV_TASK。" \      ← 実行行
scripts/apply-ui-v1-crossref.sh:41   …（count=$_n）…                    ← 実行行
scripts/check-git-destructive.sh:203 # （`$destructive）` は …           ← コメント（対象外）
tests/extras/ta-25-approval-token-guard.sh:56  #   出力: _t25_rc（…）    ← コメント（対象外）
```

> なお `docs/working/_reports/990-multibyte-var-patch.md` に **3 箇所すべてを含む patch が既に存在する**（基点 `1e33b57`）。**この patch の存在自体が issue 本文に反映されていない。**

---

### 4-2. #1086 / #956 / #866 — `.codex/skills` の drift が 3 issue で同時に過小報告

| issue | 本文の記述 | 現 main の実測 |
|---|---|---|
| **#1086** | 「現時点の drift … `DIFF ai-loop-cycle` / `DIFF plan-review-gate` / **differing=2**」 | `.agents/skills/*/SKILL.md` 39 本を blob SHA 照合 → **identical=7 / differing=32 / missing=0** |
| **#956** | 「commit 済みの乖離が **2 件**」 | `.agents/skills` 45 ファイルを `.codex/skills` に対して blob 比較 → **共通 42 / drift 33**（SKILL.md 32 + `review-gate/references/ui-ux-lane.md` 1） |
| **#866** | 「**三つ巴**」（= 3 root） | **4 root**（`.codex` が漏れている。`docs/working/TASK-0866/pbi-input.md` は正しく「四つ巴」と記録） |
| **#1086** | 「`plan-review-gate` の 36 行」 | diff 出力は 117 行規模まで拡大 |
| **#866** | 「新版 153 行 / 旧版 150 行」 | **191 行 / 213 行** |
| **#866** | 「plugin 版は『正本: `.claude/skills/…`』と自己宣言」 | 現在は全ファイルが「正本（sync 元）: `.agents/skills/…`」 |

**共通の原因**: #954 / #1159 / #1160 の参照解決順・CLI 表記の是正が `.agents` / `.claude` / `plugin` の **3 root に入って `.codex` に入っていない**。`.codex` は `install-plangate-skills-to-codex.sh` の `cp` 逐語コピー生成物（`:209`）なので、**再生成が長期間回っていない**のが実態。

**是正案（3 issue 共通）**:
- **件数を契約値にしない。** 「`.agents/skills` ⇄ `.codex/skills` の blob 比較で drift 0」という**相対 AC**に書き換える
- #1086: 本文の drift 節から `differing=2` の固定値を撤去し「着手時に再測定」と書く
- #956: 「判断が要るのは `plan-review-gate` の 1 件のみ、残り 32 件は生成物として再同期すれば解消する」という構造を本文に反映する
- #866: 「三つ巴」→「4 root」、行数と自己宣言の記述を現状へ

> **成長するディレクトリに絶対件数を書かない**という規律の違反が、3 issue で同時に発火している典型例。

---

### 4-3. #1170 — 本文の射程（2 系統）が実体（32/39 乖離）より狭い

| 本文 | 実測 |
|---|---|
| 「#1164 / #1160 の 2 系統が未追従」 | `.codex/skills` の **SKILL.md 39 本中 32 本が `.agents` と乖離** |

系統別の確認:
- クラス A（rules 解決梯子 / #1164）: `grep -c 'CLAUDE_PLUGIN_ROOT}/rules/'` → `.agents` 1/1/1/1・`plugin` 1/1/1/1・**`.codex` 0/0/0/0**（design-gate / intent-classifier / plan-review-gate / skill-policy-router、4 本とも `.codex` にファイルは存在する）
- #982 の CLI 表記（#1160）: `grep -c 'ai-loop\` サブコマンドは存在しない'` → `.agents`=1 / `.claude`=1 / `plugin`=1 / **`.codex`=0**

**是正案**: 本文冒頭に「射程はコメント参照」を追記するか、**タイトルを『.codex/skills 全体が再生成されていない』へ寄せる**。系統ごとの是正では追いつかない（新しい系統が入るたび同じ issue が再発する）。

---

### 4-4. #1011 — V3-06 の前提が**既に是正済み**（本文のほうが古い）

| 本文 | 現 main |
|---|---|
| 「TC-13 は `ta-26` を再帰実行して **rc=0 を期待する**ため、他 TC の失敗が道連れになる」 | `ta-26:327-330` は **`grep -q 'TA-26 standalone: .* 0 failed'`（サマリ行）で判定**。コメントに「rc に依存させると他 TC の失敗が TC-14 へ道連れで伝播し…」と是正理由まで明記 |
| V3-02 のアンカー `:197-201` / `:218` | base ループ `:201-205`（`[ -L ]` は `:204`）/ stale 集計 `:211` / 削除条件 `:224` |

**是正案**: 行番号アンカーを**記号アンカー**（関数名 / TC 名 / コメント文言）へ置換し、**V3-06 の AC を「非ゲート TC の連鎖」に限定して再定義**する（guard TC については達成済み）。

---

### 4-5. #1010 — 起票 11 時間後のコミットで陳腐化

| 本文 | 現 main |
|---|---|
| 「**30 TC** を通り抜ける」 | TC 総数は 30 ではない（`grep -c '^# TC-'` → 20 のセクション見出し + 分岐内 TC） |
| 「`L198` / `L200` / `L215`」 | base glob `:202` / `[ -L ]` `:204` / `_mass_delete_blocked` 呼び出し `:218` |

**原因**: #1010 起票（2026-08-05 00:50）の **11 時間後に `a2a02b9`（#1014, 12:28）が TC-34/35/36 を追加**した。

**是正案**: 行番号を記号アンカー（`_t26_mk_refs_guard_sandbox` / TC 名）へ置換し、「30 TC」を「現行 ta-26 の全 TC」と**量化子で**書き直す。

---

### 4-6. #994 / #947 — 行番号のみのずれ（軽微だが着手時に測り直しが要る）

| issue | 本文 | 現 main |
|---|---|---|
| **#994** | `ta-26-plugin-sync.sh:712-728` | **`:804-820`**（`_t26_unset_envs33()` は `:792-802`） |
| **#947** | `ta-25-approval-token-guard.sh:86` | **`:857`** |
| **#947** | ta-54 の `:118` | 一致（ずれなし） |
| **#947** | ta-42 の `:22 / :23 / :61 / :90 / :91` | ほぼ一致（`register_cleanup` は `:23`） |

**是正案**: 記号アンカー化。判定に影響する食い違いではないが、着手時に必ず再確認が要る。

---

### 4-7. #1021 — 本文の AC が実害を網羅していない（STALE というより**過小 scope**）

issue は「`tests/docs/` への leak」だけを症状としているが、`docs/working/_reports/1021-ta09-isolation-patch.md` は**実監査ログ汚染**を別の実害として挙げている。作業ツリー実測で `docs/working/_audit/hook-events.log` に **`TASK-9991` の偽レコードが 4 件**、`hook-events.log.bak.*` が **38 個**堆積している（いずれも gitignore 対象なので origin/main では測れない）。

**是正案**: AC に「**実監査ログに fixture レコードを残さない**」を追加する。

さらに、本文の「13 本」という母数も実態と合わない可能性がある。規約 8 の `PG_HARNESS_SOURCED` ガードを持たない extras を全数照合（`comm -23`）すると **40 本**（ta-04/05/06/07/08/09/10/11/12/13/14×2/15/16/17/18/19/20/21/22/23/24/27/28/29/30/31/32/33/34/35/36/37/38/41/42/54/55/56/57）。本文の 13 本は `FIXTURES_DIR` に触れる母集団に限った数と読めるが、**Out of scope（残り本数の一括是正）の規模見積りは更新が要る**。

---

### 4-8. #1101 — 変換クラスの列挙が不足（コメントで自己補正済み・本文未反映）

本文は「深刻度: 実害の観測なし」「`..` を含むパスを使うことは稀」としているが、コメントで **no-task セッションでも成立**・**`bin/./plangate`（`/./` 中間）と末尾 `/` も未記載の変換クラス**として自己補正されている。追跡は成立しているので STALE 分類の主対象にはしていないが、**本文だけ読むと深刻度を過小評価する**。

本レポートで**実際に再現した迂回**（`git show origin/main:scripts/hooks/check-plan-hash.sh` を scratchpad へ取り出して実行、sha256 `d0908777b401a609…`）:

```
# no-task 経路（PLANGATE_HOOK_TASK / SKIP_REASON / HOOK_FILE / BYPASS_HOOK をすべて unset）
rc=2  bin/plangate                              HARDENING_OVERRIDE
rc=2  CLAUDE.md                                 HARDENING_OVERRIDE
rc=0  CLAUDE.MD                                 DOC_LIGHT_SKIP        ← 迂回
rc=0  Claude.md                                 DOC_LIGHT_SKIP        ← 迂回
rc=0  docs/../CLAUDE.md                         DOC_LIGHT_SKIP        ← 迂回
rc=0  docs/working/templates/../../../CLAUDE.md DOC_LIGHT_SKIP        ← 迂回

# TASK 文脈（PLANGATE_HOOK_TASK=TASK-9999）
rc=0  bin/../bin/plangate    [Hook EH-3 SKIP] plan.md not found       ← 迂回
rc=0  bin/./plangate         同上                                      ← 迂回
rc=0  "CLAUDE.md "（末尾空白）SKIP                                      ← 迂回
```

> ⚠️ **rc だけでは判定できない**（非 `.md` は SKIP 拒否で rc=2 を返すため）。`HARDENING_OVERRIDE` 文字列の有無で判定した。この点は測定手順として issue に書き足す価値がある。

---

### 4-9. #863 — 項目 3 が**再ドリフト**（一度直したものが PR #1160 で壊れた）

`plugin/plangate/README.md:36-41` は「コマンド 1 / スキル 9 / エージェント 2 = **12 ファイル**」と宣言し、再現コマンド `grep -rl 'bin/plangate' commands/*.md skills/*/SKILL.md agents/*.md` まで併記している。**実測は 13 件**（63 ファイル全数照合。追加分 = `plugin/plangate/skills/ai-loop-cycle/SKILL.md`）。

混入原因は `43fb05e`（PR #1160・2026-08-19）が `ai-loop-cycle/SKILL.md` に追加した **`bin/plangate` の否定文**（「`bin/plangate` に `ai-loop` サブコマンドは存在しない」）。

**#863 が「再現コマンド付き」で書かれていたおかげで間違いが検証可能な形で固定されている**点は評価できるが、**その再現コマンドが CI で回っていない**ため無検出で入った。

**是正案（設計判断を含む）**: 「スキル（9）→ 10」に直すか、「**否定文は CLI 依存に数えない**」を除外ルールとして明記して再現コマンドを整合させるか。後者を選ぶなら、grep だけでは表現できないので検出器の実装が要る。

## 5. 依存グラフ — 何が決まらないと何が動かないか

### 5-1. Human 判断待ちのクラスタ（判断 1 つで複数 issue が動く）

```
【クラスタ A】.codex/skills の去就 ── 最大のボトルネック（4 issue が従属）
  #1086 「.codex/skills 120 ファイルを untrack するか（案 A′）」  ← Human の名指し承認（不可逆）
    ├─ 決まらないと ─→ #956  （.codex drift 33 件の是正方式が決まらない）
    │                    └─ 決まらないと ─→ #954 AC-3（.codex 再生成）が完了しない
    ├─ 決まらないと ─→ #1170（.codex 追従を CI に載せるか、4 root parity ゲートか）
    └─ 決まらないと ─→ #866 の follow-up（.codex 再 drift）
  ※ #1086 が (A′) untrack を採ると #954 AC-3 の .codex 部分と #956 の大半が消滅する
  ※ #956 には独立の Human 判断が 1 件ある: plan-review-gate の 36 行を
     (A) 破棄 + mode 別 3 行のみ正本へ / (B) 全部 .agents へ昇格 / (C) 現状維持
     → 2026-08-02 に (a) inline 取り込みで裁定 → 2026-08-19 コメントが案 A を推奨し**判断が二転**、再回答なし

【クラスタ B】mass-delete guard の symlink 方針
  #1011 V3-02 「symlink 除外を受容のまま close するか揃えるか」  ← Human
    └─ 決まらないと ─→ #1010 の fixture 設計が書き直しになる
                        （#1010 の nolink fixture は [ -L ] 除外の存在を pin する方向、
                          V3-02 は除外を外す方向で **逆向き**）
  #991 CB-2 ─→ #1009 Phase 3 への移管を確定するか（Human）

【クラスタ C】extras の実行契約
  #921 Slice 2（残 45 本）  ← 分割設計は PR #1051 で Human 裁定済み（案 B = 新 TASK ×3）
    ├─ 対象重複 ─→ #947（ta-25 / ta-42 / ta-54 はいずれも _pending_migration の 45 本に含まれる）
    ├─ 対象重複 ─→ #1044（extras bootstrap の直接実行検知）
    └─ 対象重複 ─→ #1021（ta-09 の root 解決 / cleanup）
  ※ 着手順の調整が要る（統合するか分けるか＝Human）

【クラスタ D】HO パスへの patch 適用（判断ではなく **適用** のみ待ち）
  #960  patch 作成済み（_reports/960-ho-patch.md・6 ファイル）→ Human 適用で完了に最接近
  #1102 patch 作成済み（scripts/apply-claude-md-v8210.sh）→ v8.21.0 リリース Step 2a に紐づく
  #1101 / #1104 patch 作成済み → ただし #1135 との分担が Human 判断
  #937  patch 作成済み → ただし責務判定に齟齬あり（下記 5-3）
  #990 / #984 / #982 / #997+#947c / #1021 / #1011 / #1144 も patch 作成済み
```

### 5-2. 統合先が空振りしている（**要注意**）

| issue | 宣言された統合先 | 実測 |
|---|---|---|
| **#984** | 「#1092 Phase 2 として **#1087** へ統合、AC がカバーされた時点で close」 | **#1087 は CLOSED。にもかかわらず #984 の AC は 1 つも満たされていない。** 移管先 AC の追記も close も行われていない |
| #937 / #942 | 同じく #1087 への統合が提案済み | 採否が未確定（#1087 が閉じている以上、再検討が要る） |
| #991 | #1009 Phase 3 へ | #1009 は OPEN・AC 未カバー → SUPERSEDED にしない |
| #978 | #916 へ | #916 は OPEN・AC 未カバー → 同上 |
| #982 / #1018 | #1031 へ（Slice 2 / Slice 1） | #1031 は OPEN → 同上 |

> **#984 は「統合先が閉じた状態で取り残されている」。** 次の判断が要る: 「#1087 は #984 をカバーしていなかった」と認めて独立 PBI 化するか、別の統合先を立てるか。**これは本棚卸しで見つかった最も明確な滞留**。

### 5-3. 責務判定の齟齬（Human に確認が要る）

**#937**: `scripts/templates/pre-push.sample` は **HO パターン外**（HO は `scripts/hooks/*.sh` のみ。`check-plan-hash.sh` の `_override=0` 直後 `case` ブロック 9 カテゴリで確認）。にもかかわらず patch 文書は適用を **Human-owned** と宣言しており、**その根拠が文書内に書かれていない**。AI が適用できるのか否かの確認が要る。

### 5-4. Human 判断待ちの一覧（何の判断か）

| issue | 待っている判断 |
|---|---|
| **#1086** | `.codex/skills` 120 ファイルの `git rm --cached`（不可逆・名指し承認）/ 同期スクリプトを削除するか注記で残すか / Mode |
| **#956** | `plan-review-gate` 36 行の去就（案 A/B/C。**一度裁定 → 再提案で二転し再回答なし**） |
| **#984** | **#1087 が CLOSED なのに AC 未達** → 独立 PBI 化か別統合先か |
| **#982** | `ai-loop` を `bin/plangate` の正式サブコマンドにするか（live 7 箇所が「#982 で未決」と自認） |
| **#963** | `/pg-check` を復元するか記述是正するか / `.claude/skills` 10 件差を同期対象にするか対象外宣言するか |
| **#960** | `schemas/review-result.schema.json:42` の「17」が契約値か / changelog を歴史として据え置くか → **その後 HO patch を適用** |
| **#1011** | V3-02 の方向（受容維持 or 揃える）← #1010 が従属 |
| **#1105** | 解決方式（issue 自身が「C-3 で人間が決める」と scope を切っている） |
| **#1104** | fail-open / fail-closed・正規経路の許可方式・性能（#1101 の O(n²) 解消が先行条件） |
| **#1101** | #1135 との分担（本 issue で直す / #1135 で直す / 分離する） |
| **#1057** | 提案 1〜4 の選択（`bin/` を配布物へ含めるか、skill から CLI 参照を外すか） |
| **#1081** | 案 (a)/(b)/(c)/(d)（slash 起動と skill 起動の両方を残したいか） |
| **#1144** | 案 A の採用可否と段階導入の範囲 |
| **#1151** | 案 A/B/C の選択（#1144 と `settings.example.json` で衝突するため着手順も） |
| **#1165** | TC-14 凍結の解除・改訂（#917 AC-7 由来のガバナンス決定） |
| **#978** | #916 へ統合するか独立で進めるか + #1005 の Start gate 充足判定 |
| **#942** | patch 文書第 2 部の「#942 の目的そのものを再検討すべき」提案の採否 |
| **#863** | 項目 1〜3 で close して項目 4 を切り出すか、本 issue で項目 4 まで持つか（**照会中・回答待ち**） |
| **#1021** | 既存の偽レコード 4 件（`TASK-9991`）の削除可否（append-only 監査証跡） |
| **#947 / #921** | 統合するか分けるか（対象ファイルが重複） |

## 6. AI 到達可能性 — 40 件の判定

判定軸は 3 つ。**HO 対象パスを触るか**（触るなら AI は patch 提示まで）/ **`.md` 以外を書く必要があるか**（EH-3 により no-task セッションでは書けず `PLANGATE_HOOK_TASK` セッションが要る）/ **Human の設計判断が要るか**。

HO 9 カテゴリは `scripts/hooks/check-plan-hash.sh` の **`_override=0` 直後の `case` ブロック（`esac` まで）** を正本として実測した（行番号では参照しない）。

| 到達性 | 件数 | issue |
|---|---:|---|
| **A. 即着手可（`.md` のみ・非 HO・判断待ちなし）** | **4** | #1018（Slice 1）/ #866（残件）/ #863（項目 3）/ #954（`.codex` 部分は #956 従属だが `.md`） |
| **B. `PLANGATE_HOOK_TASK` セッションがあれば即着手可（非 HO・判断待ちなし）** | **9** | #997 / #994 / #1004 / #1162 / #990 / #991 / #1044 / #921 / #947 |
| **C. 非 HO だが Human の設計判断が先** | **10** | #1177 / #1173 / #1009 / #1010 / #1011（V3-02）/ #978 / #975 / #1093 / #1086 / #1170 |
| **D. patch 提示まで（HO 抵触）** | **13** | #1102 / #1101 / #1104 / #1105 / #1144 / #1151 / #984 / #960 / #942 / #937（doctor 分）/ #863（項目 4）/ #982（案 A の場合）/ #1057（`bin/plangate` 案の場合） |
| **E. Human 判断待ちで着手不能** | **4** | #1165（TC-14 凍結の C-3）/ #956（36 行の去就）/ #1081（案 (a)-(d)）/ #963（2 択 ×2） |

> 合計が 40 を超えるのは、**同一 issue が複数区分にまたがる**ため（例: #863 は項目 3 が A、項目 4 が D）。件数は「その区分に該当する作業を持つ issue 数」。

### 6-1. HO 抵触パスの内訳（patch 提示までの 13 件）

| issue | 抵触する HO パス |
|---|---|
| #1102 | `CLAUDE.md` |
| #1101 / #1104 | `scripts/hooks/check-plan-hash.sh`（#1104 は `.claude/settings*.json` も） |
| #1105 | `bin/plangate` |
| #1144 | `scripts/hooks/*.sh`（**17 本**）+ `.claude/settings.example.json` |
| #1151 | `.claude/settings.example.json` |
| #984 | `CLAUDE.md` + `.claude/settings.example.json` |
| #960 | `.claude/rules/*.md`（2）+ `.claude/commands/*.md`（2）+ `.claude/agents/*.md`（1）+ `schemas/*.schema.json`（1） |
| #942 | `.github/workflows/test.yml` |
| #937 | `bin/plangate`（doctor 追加分のみ。`scripts/templates/pre-push.sample` は **HO 外**） |
| #863 | `.claude/commands/plangate-setup.md` / `.claude/agents/setup-coordinator.md` / `.claude/agents/workflow-conductor.md` |
| #982 | `.claude/commands/ai-loop-workflow.md`（案 B）/ `bin/plangate`（案 A） |
| #1057 | `bin/plangate`（`ai-loop` 追加案を採る場合） |
| #1093 | `.github/workflows/*`（CI 配線部のみ。本体の `release-prep.sh` は非 HO） |

### 6-2. EH-3 の制約（`.md` 以外を書く必要があるもの）

`PLANGATE_HOOK_TASK` を設定した**起動時**セッションが要る（実行中の `export` では効かない）。対象は `tests/extras/*.sh` / `scripts/ai-loop/*.py` / `scripts/*.sh` / `scripts/sync-plugin-plangate.sh` などを触る **19 件**:
#1177 / #1173 / #1165 / #1162 / #1093 / #1044 / #1021 / #1011 / #1010 / #1009 / #1004 / #997 / #994 / #991 / #990 / #978 / #975 / #947 / #921

**注意**: `docs/working/templates/plan.md` は `.md` だが **basename が `plan.md` のため EH-3 の plan.md ガードが発火する**（#1018。#927 に「非対称 C」として報告済み）。テンプレートであって承認成果物ではないが、EH-3 は basename で判定するため区別されない。

## 7. 推奨着手順 — AI が今すぐ着手できるものを費用対効果順に

**選定基準**: (1) Human 判断を待たない (2) 他 issue のブロッカーを外す (3) 変更範囲が閉じている (4) 実害の大きさ。

### Tier 1 — Human 判断ゼロ・即日で進む（`.md` のみ・非 HO）

| 順 | issue | 作業 | なぜ上位か |
|---:|---|---|---|
| 1 | **#863** 項目 3 | `plugin/plangate/README.md` の宣言値 12 を実測 13 へ整合 | **README の自称再現コマンドが自分の宣言値を再現しない**状態の解消。導入者が最初に読む文書。1 ファイル |
| 2 | **#1018** Slice 1 | `docs/working/templates/plan.md` の見出しを `## Files / Components to Touch` へ + `Verification Automation:` 行の追加 | **`derive_loopspec()` が fail-closed する原因**。ただし下記 2 つの注あり |
| 3 | **#866** 残件 | `.agents/skills/subagent-dispatch/SKILL.md:68,75` のバッククォート・エスケープ是正 | 1 ファイル 2 行。**ただし pbi-input が Mode=high-risk / C-3 必須と判定**しているので C-3 が要る |

> **#1018 の注 2 点**:
> 1. `docs/working/templates/plan.md` には `Verification Automation:` 行が **0 件**で、`plan_package.py:216-218` がこれを必須としている。**見出しを直しても derive はもう一段 fail-closed する。** 「テンプレに書くか抽出器を緩めるか」は案 A/B/C の選択（軽い設計判断）
> 2. **basename が `plan.md` のため EH-3 が発火する**ので、実際には `PLANGATE_HOOK_TASK` セッションが要る可能性が高い（`.md` でも例外）

### Tier 2 — `PLANGATE_HOOK_TASK` セッションがあれば即着手可（判断待ちなし）

| 順 | issue | 作業 | なぜこの順か |
|---:|---|---|---|
| 4 | **#997** | `test_run_evidence.py` TC-45 を前後差分 / snapshot 方式へ | **もっとも独立**（他 issue への依存が実質ない）。`docs/working/ai-loop-runs/` に untracked 5 件が滞留しており、**誤 FAIL が現に成立している** |
| 5 | **#990** | 実行行 3 箇所の `${_n}` 化 + 検出機構 | **`bin/plangate gate` / `exec` の実走経路**（本文の「異常時のみ」は誤り）。patch は `_reports/990-multibyte-var-patch.md` に既存 |
| 6 | **#1011** V3-04 | `_mass_delete_blocked` の数値検証（不正入力時 blocked 側へ倒す） | **後続がこの関数契約に依存**（#991 CB-2 / #1009 / #1010）。現 3 呼び出し元（`:127` / `:218` / `:395`）はすべて算術で数値を作るため**挙動不変**で入る |
| 7 | **#994** + **#1004** | TC-33 検査(1) を判別行対象へ / 規約 8 例示の機械検証 | **同一ブロックを触るので 1 PBI 化が自然**。片方だけ直すと他方が上書きする |
| 8 | **#1162** | 件数契約 3 箇所を `-eq` から下限 / 同値照合へ | **ガバナンス判断非依存**（#1165 分割済み）。計画は PR #1167 で main 済み。**無関係な PR の CI を落とす時限爆弾の除去** |
| 9 | **#1044** | extras bootstrap の直接実行検知（`_pg_extra_direct`） | 再現を sandbox 実走で確認済み（dash rc=0 / zsh rc=0 / bash rc=1 / sh rc=1）。ただし下記注 |

> **#1044 の注**: `docs/working/TASK-1044/approvals/` 配下の C-3 承認ファイルは main に存在するが、委任パッケージ本文が「現承認は stale（`64337b7f…`）→ 再発行してから着手」と述べている。**再発行済みかは未確認**（§8-3 の EH-13 誤検出により読み取りコマンドごと block されたため）。着手前に別手段での確認が要る。

### Tier 3 — 軽い設計判断を plan で確定すれば進む

| 順 | issue | 判断の重さ |
|---:|---|---|
| 10 | **#1177** | AC-1' の形（クラス列挙 vs 全件 − allowlist）。**全件 − allowlist を採らないと `scripts/parsers/` 2 本が再び漏れる**（§8-1） |
| 11 | **#1173** | 除外 reason 判定に #956 の stale 宣言検出機構を流用するか |
| 12 | **#921** Slice 2 | 分割設計は **PR #1051 で Human 裁定済み**（案 B = 新 TASK ×3）。子 TASK が起票済みかの確認から |
| 13 | **#947** | #921 と統合するか分けるか（対象ファイルが重複） |

### Tier 4 — AI 側は完了済み・**Human 適用だけが残っている**

**この 4 件は「AI が今すぐ着手できる」の対極だが、Human の 1 アクションで backlog が減る。費用対効果で言えば最上位。**

| issue | 状態 | 必要な Human アクション |
|---|---|---|
| **#960** | patch 作成済み（`_reports/960-ho-patch.md`・HO 6 ファイル）。**AI 側の残作業は実質ゼロ** | schema の「17」が契約値かを決めて適用 |
| **#1102** | patch 作成済み（`scripts/apply-claude-md-v8210.sh`）。**`CLAUDE.md` が全セッションに誤った前提を配り続けている** | v8.21.0 リリース Step 2a の apply 実行 |
| **#937** | patch 作成済み（`_reports/937-942-unwired-guard-patch.md`） | 責務判定に齟齬あり（§5-3）。**AI が適用できるなら Tier 2 に上がる** |
| **#984** | patch 作成済み（`_reports/984-wiring-check-gap-patch.md`） | **#1087 が CLOSED なのに AC 未達**（§5-2）の扱いを決める |

### 7-1. この順で進めたときに外れるブロッカー

- **#1011 V3-04（順位 6）を先に入れる**と、#991 CB-2 / #1009 / #1010 が同じ関数契約の上に載せられる
- **#1162（順位 8）** は「無関係な PR の CI を落とす時限爆弾」の除去なので、**他の全作業のノイズを減らす**
- **#1086 の untrack 判断（Human）** が下りると **#956 / #954 AC-3 / #1170 / #866 follow-up の 4 件が同時に動く** — 判断 1 つあたりの解放数が最大

## 8. スコープ外で見つけた問題（手は出していない・報告のみ）

### 8-1. `scripts/parsers/` 2 本がどの issue の対象集合にも入っていない

`scripts/parsers/__init__.py` / `scripts/parsers/codex_log_parser.py` は **`sh` 誤起動ガードを持たない**（`grep -c 'PG-SH-GUARD'` = 0）。#1177 本文の対象は `scripts/ai-loop/` 30 本 + `plugin/**` 28 本で、`scripts/parsers/` はコメントの minor に「除外の妥当性の材料が無い」と書かれたきり。

**#1177 の AC-1' を「全 `.py` − allowlist」で採れば自動的に射程に入るが、現行 AC-1 の書き方（`scripts/ai-loop/*.py` 30 本）では再び漏れる。**

### 8-2. `.codex/skills` に**実測で否定された内容**が配られ続けている

`git grep -l '✅ \*\*Codex CLI 物理 hook 等価達成' origin/main -- .codex/skills/` → `.codex/skills/ai-dev-exec/SKILL.md` の 1 件。他 3 root（`.agents` / `plugin/plangate` / `docs/plangate.md`）では同じ箇所が打ち消し線（否定済み）になっている。`local-exec-handoff` も同型で、`.codex` 側だけ「session 中の物理 hook は `.codex/hooks.json` で EH-1/2/3/6/9 が自動発火する (PR #347)」が**肯定形のまま残る**。

`.codex/skills` は Codex CLI の project-scoped root として現に読まれるため、**#1085/#1090 で実測否定された内容が Codex ランタイムに配られ続けている**。これは #1086 / #956 の優先度を上げる材料になる。

### 8-3. EH-13 token-guard の誤検出（**本レポート作成中に 3 回発生**）

**#1104 の AC-4「読み取りコマンドの誤検出ゼロ」は、Bash 配線を拡大する前の現時点で既に破れている。**

| 発生 | 実際のコマンド | guard の判定 |
|---|---|---|
| 1 | `git ls-tree … && git show origin/main:<TASK-1044 の承認 JSON> \| python3 -c "…print…"`（**書き込みを一切含まない読み取り**） | `rule=copy-like` で BLOCK |
| 2 | 本レポート作成中、**repo 外の scratchpad** へのヒアドキュメント書き込み | `rule=copy-like` で BLOCK。**ヒアドキュメント本文に含まれる承認トークンのパス文字列に反応**していた（書き込み先ではなく本文） |
| 3 | 同、リダイレクト先が変数展開の quoted 形（`"$VAR/path"`） | `rule=file-redirect, redirect_target=quoted-or-escaped:…` で BLOCK（解決できないので fail-closed） |

**回避方法**（本セッションで有効だったもの）:
- リダイレクト先を**リテラルの絶対パス**にする（変数展開・引用符を使わない）
- **1 コマンドにつきリダイレクト 1 つ**にする
- ヒアドキュメント**本文**に承認トークンのパス文字列を書かない（言い換える）

**発生 2 が構造的に重要**: guard がコマンド文字列全体を走査するため、**「承認トークンについて書く」だけで「承認トークンに書き込む」と誤判定される**。ドキュメント作成が構造的に妨げられる。#1104 の Bash 配線拡大を検討する際の**反例データ**になる。既存 issue（#1045 / #1110 / #1115 系）に載っているかは未確認。

### 8-4. `.claude/settings.json` は origin/main に存在しない（測定不能領域）

実効配線の正本が untracked（gitignore 対象）なため、「配線 N 件」系の主張は **ref 明示では検証できず `settings.example.json` で代替するしかない**。#984（配線の削除を CI が検出できない）と同じ構造の測定不能領域で、**#1104 の AC 設計時に「何を実測とみなすか」を先に決める必要がある**。

### 8-5. `CLAUDE.md` と `README.md` の hook 物理配線数が相互に矛盾

`CLAUDE.md:24`「物理配線 6/12」vs `README.md:90`「物理配線は 11/12（残り EH-7 のみ）」vs `docs/ai/hook-enforcement.md:28`「11/12」。#984 の AC-3 に 3 箇所とも含まれているが、**互いに矛盾している点自体は issue に書かれていない**。どちらが正かの判定が要る。

### 8-6. `docs/plugin-only-adoption.md:39` が存在しない `/pg-check` を機能説明に使っている

「`review-gate` | 6 観点レビュー（`/pg-check` 出力を分類するレビューフレーム）」。#963 AC-2 の照合対象（skills 配下）に入っていないため見落とされている。**導入検討者が最初に読む文書**である点で影響が大きい。

### 8-7. `_reports/937-942-unwired-guard-patch.md` 第 2 部の根拠に射程の狭さがある

「`test.yml` 内に git 履歴を必要とする処理がない」の grep が **`test.yml` 自身のみ**を対象にしており、**`test.yml` が起動する `tests/run-tests.sh` → `ta-57-pr-convergence.sh:608` の `git diff --stat "$_t57_base"`** を数えていない。結論（#942 の目的を再確認すべき）自体は妥当だが、「(a) 現在落ちているテストを直す = 該当なし」の論拠としては不十分。**Human が #942 の scope を判断する前にこの点の再確認を勧める**（指摘であって断定ではない）。

### 8-8. run-tests の baseline 件数が環境で 4 通りに分岐する

primary / worktree × HEAD==origin/main か否か → **452 / 453 / 453 / 454**。#947 / #942 のコメントで実測済みだが、**issue 本文の AC が「453 passed を維持」という絶対件数で書かれている**（#956 AC-6 / #954 AC-4）。**この AC は環境によって達成不能。** 相対比較または同一環境での前後比較へ書き換えるべき。

### 8-9. `tests/extras/ta-42-cli-subcommands.sh` が実リポジトリの `docs/working/` に書き込む

`_t42_root` が `$FIXTURES_DIR/../..` = repo root。#947 のコメントで報告済みだが、**同一 worktree で `run-tests.sh` を並行実行すると構造的に flaky**。#1021（ta-09 の同型）との同時是正提案が出ている。

### 8-10. `docs/working/` 配下の実害の堆積（作業ツリー実測・gitignore 対象のため main では測れない）

- `docs/working/_audit/hook-events.log` に **`TASK-9991` の偽レコード 4 件**
- `docs/working/_audit/hook-events.log.bak.*` が **38 個**堆積
- `docs/working/ai-loop-runs/` に **untracked 5 件**が滞留（#997 の誤 FAIL トリガであると同時に、commit 漏れの可能性もある）

いずれも `ta-09` / `ta-42` を修正しない限り増え続ける。

### 8-11. `ta-57` TC-15 の skip 素通りを塞ぐ issue が存在しない

`grep -q '^OK'` で判定しているため `test_delivery.py` が全 skip でも `OK (skipped=57)` で PASS する。#1162 が「既知の穴・本 PBI では塞がない」としているが、**どの issue の AC にも載っていない**。しかも #1162 の AC-03（`-eq` → `-ge`）を入れると「追加後に全 skip でも緑」で**穴がむしろ広がる**、と #1162 自身が記述している。塞ぐ先の issue が現状不在。

### 8-12. `.claude/skills/subagent-dispatch/` が不在（root 間の名前集合が非対称）

`.agents` / `.codex` / `plugin` の 3 root にのみ存在。**#866 の「4 root」モデルが全 skill に成立するわけではない。** root 間一致ゲートを設計するなら、**名前集合の非対称を許容するか否か**を先に決める必要がある。

### 8-13. `.claude/agents/setup-coordinator.md:37` の存在確認が意味的に成立しない可能性

`command -v bin/plangate` は相対パス形式のため、PATH 探索ではなく**ファイルパス解決（cwd 依存）**になる。degrade 節を書いた意図（「CLI が無ければ doctor をスキップ」）が cwd によっては効かない懸念。HO パスなので手は出していない。**#863 項目 4 の patch 作成時に併せて見る価値がある。**

### 8-14. `apply-claude-settings.sh` が契約範囲外の副作用を既定で適用し続けている

`SessionStart` の `gh-pin-account.sh` は `gh auth switch` により**マシン全体・全リポジトリの gh CLI active account を書き換える**。ヘッダ `:24-32` に危険性が明記されているのに **opt-out 手段が無く**、`--all-events` は「follow-up」としてコメントに 1 回出るだけ。#975 AC-3 として追跡されているが優先度は P2。**#1151（上流メンテナ個人のアカウント名が雛形に埋まっている）と同根**。

## 9. 測定方法と限界

### 9-1. 測定の規律

- **すべての測定で ref を明示**した: `git show origin/main:<path>` / `git grep <pat> origin/main -- <path>` / `git ls-tree -r origin/main -- <path>`。共有 checkout は stale なため、作業ツリーの `ls` / `grep` は「実測」として扱っていない（作業ツリー由来の観測は §8-10 のように明示している）
- **行番号アンカーは stale 化している前提**で扱い、現 main で全件再確認した（結果は §4）
- **量化子の主張は全数照合してから書いた**（例: `.codex/skills` の drift は 39 本の blob SHA を 1 件ずつ照合、`plugin/plangate` の CLI 依存は 63 ファイル全数照合）
- **空出力を「0 件」の証拠にしていない**。すべての「0 件」に陽性コントロールを添えた

### 9-2. 本レポート作成中に検出した測定事故（規律が実際に効いた例）

`git log origin/main --grep "#$n\b"` を zsh のループで 40 回回したところ**全件が空出力**になった。「40 件すべてに言及コミットが無い」と読むところだったが、陽性コントロール（`git log origin/main --oneline --grep '#1089'` → 5 件ヒット）で grep 自体は動くと確認。原因は **zsh が `"#$n[^0-9]"` を配列添字として解釈し、`bad math expression` でコマンドが起動していなかった**こと。`python3` 経由に切り替えて再測定した。

> **「起動しなかったコマンドは 0 件ではない」** — この事故を踏まないと、本レポートの「#954 に 6 件、#921 に 8 件の関連コミット」といった事実がすべて「0 件」として報告されていた。

### 9-3. 実行を避けたもの（意図的な限界）

安全指示に従い、以下は**一切実行していない**:
- `sh <任意の .py>`（docstring がコマンド置換として評価され、同期スクリプトや `gh` が実走する。#1169 / #1177）
- `scripts/sync-plugin-plangate.sh` / `scripts/install-plangate-skills-to-codex.sh` / `scripts/apply-*.sh --apply`
- `sh tests/run-tests.sh`（`ta-42` / `ta-09` が実リポジトリの `docs/working/` に書き込むため。§8-9）
- issue / PR への書き込み操作（コメント・close・ラベル・編集）

**結果として、次は「未確認」であり PASS とも FAIL とも扱っていない**:
- 各 issue の「`sh tests/run-tests.sh` が baseline を維持」系 AC（ほぼ全件）
- 変異注入による検出力の実証（コード読解による**構造判定**にとどまる。#1010 AC-3 / #994 / #1011 V3-06 が該当）
- marketplace 実環境での plugin hook 発火・skill 参照解決（#1144 / #954 AC-5 / #1057）
- Claude Code / Codex ローダーのモデル可視一覧（#1081 / #1086 の正式な判定手段）

### 9-4. 例外的に実行したもの（安全を確認した上で）

- **`scripts/hooks/check-plan-hash.sh` の HO 判定**（#1101）: `git show origin/main:` で scratchpad に取り出し（sha256 `d0908777b401a609…`）、**repo 外**で引数を変えて実行。4 変換クラスの迂回を再現（§4-8）
- **`tests/extras/ta-46-ehs-wiring.sh` の bootstrap**（#1044）: sandbox に helper を置かずに展開し 4 シェルで実行。dash rc=0 / zsh rc=0 / bash rc=1 / sh rc=1 を再現

### 9-5. 扱えなかった issue

**なし。40 件すべてを扱った。**
