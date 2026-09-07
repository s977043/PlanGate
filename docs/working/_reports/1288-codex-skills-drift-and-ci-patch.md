# #1288 — `.codex/skills` の正本乖離: 全数照合・正否判定・再発防止 CI（`git apply` 可能形 patch / **Human 適用**）

> 測定基点: **`origin/main` = `bd2da8a5`**（PR #1292 マージ後）/ 2026-09-07。以下の件数・rc はすべてこの ref のワークツリー、および `git clone --no-hardlinks --no-local` で作った **repo 外サンドボックス複製**に対する実測。
> 位置づけ: **既存ギャップの是正**（退行ではない）。`.github/workflows/*.yml` は Hardening Override 対象のため、**AI は patch 提示まで・適用は Human-owned**。
> 本書で AI が作成したのは本ファイル 1 本のみ。`.codex/` / `.agents/` / `scripts/` / `tests/` / `.claude/` / `bin/` / `schemas/` / `.github/` は **1 バイトも変更していない**（同期スクリプトも repo 上では実行していない。実行はサンドボックス複製のみ）。
> 先例と同じ marker 規則: [`1226-approval-surface-patch-applicable.md`](./1226-approval-surface-patch-applicable.md) / [`1278-log-event-fail-closed-patch-applicable.md`](./1278-log-event-fail-closed-patch-applicable.md)。
> 関連: issue #1288（本書）/ #1226（承認手順の定義面が HO 外 — PR #1287 で **PATCH-B として同種の CI 検査案が既にマージ済み・未適用**。§4）/ #1263 / #1086 / #928（CI が required check でない）。

---

## 0. 結論先行

| 項目 | 結論 |
|---|---|
| **乖離の全数（自分で数え直した）** | `SKILL.md` は **40 対中 10 件** が byte 不一致（issue 本文と一致）。ただし **`SKILL.md` だけを見るのは過小**で、`.codex/skills/**` 全体では **11 ファイル**が生成結果と不一致（+`plan-normalization/agents/openai.yaml`）。§1 |
| **どちらが正しいか** | **10 件すべて `.agents/skills/`（正本）が正しい**。`.codex` 側にしかない行は合計 **102 行**あるが、その全部が「正本が新版へ差し替えた旧版の段落」であり、**正本に無い独自の内容は 1 行も無い**。§2 |
| **単純上書きしてよいか** | **10 件すべて可**。§2 の 3 つの独立根拠（履歴・行単位・全ツリー再生成）で裏取り済み。**正本へ取り込むべき差分は 0 件**。PR #1212 が意図的に除外した `plan-review-gate` の「`.codex` 独自節 34 行」は、その後 PR #1221 が両レーンへ入れており **現時点では解消済み**（codex-only 行は 1 行のみ・旧表記）。§2.2 |
| **承認手順の欠落（機械照合）** | 「**CLI / 機械 block が無いことを理由に手順を黙って省略し、実施済みと読める記録を残してはならない**」系の規範文は `.agents` の **8 skill** にあり、`.codex` には **0 件**。うち `plan-review-gate` の「**機械 block が無いことを理由に C-3 を省略しない**」は正本 1 件・codex 0 件。§3 |
| **再発防止 CI** | 2 層（層 1 = installer 非依存の byte 照合・双方向 / 層 2 = 全ツリー再生成して差分ゼロ）。**`pull_request.paths` に `.codex/skills/**` を含める**（含めないと起動しない）。§5・§6 |
| **positive control** | 層 2 は 3 クラス（内容改竄 / skill 内の余剰ファイル / 正本に無い skill ディレクトリ）を、層 1 は 3 分岐（欠落 / 余剰 `references` / 余剰 skill ディレクトリ）を仕込んで **すべて検出（rc=1）**。無改竄では両層とも **rc=0（PASS）**。サンドボックス実測。§5.4 / §5.5 |
| **`git apply --check`** | repo root で **rc=0**（§6.2 に実測コマンドと出力） |
| **適用しても塞がらないもの** | CI が **advisory**（required status check ではない）ので赤でもマージできる / installer 自体の改竄（層 2 が空振り。層 1 が緩和） / `.agents/skills/**` 正本そのものの改変（HO 外・#1263） / hook 未配線の導入先。§8 |

---

## 1. 全数照合（件数は自分で数えた。issue 本文の転記ではない）

### 1.1 母集団

```sh
ls -d .agents/skills/*/ | wc -l          # 40
ls -d .codex/skills/*/  | wc -l          # 40
ls -d plugin/plangate/skills/*/ | wc -l  # 40
ls .agents/skills/*/SKILL.md | wc -l     # 40（.codex / plugin も同じく 40）
```

### 1.2 `SKILL.md` の双方向照合

```sh
# 方向 A: .codex -> .agents（欠落 / 乖離）
for f in .codex/skills/*/SKILL.md; do
  n=$(basename "$(dirname "$f")"); s=".agents/skills/$n/SKILL.md"
  if [ ! -f "$s" ]; then echo "ONLY-IN-CODEX: $n"; else cmp -s "$f" "$s" || echo "DIFFER: $n"; fi
done
# 方向 B: .agents -> .codex（配布漏れ）
for f in .agents/skills/*/SKILL.md; do
  n=$(basename "$(dirname "$f")"); [ -f ".codex/skills/$n/SKILL.md" ] || echo "MISSING-IN-CODEX: $n"
done
```

| 観点 | 実測 |
|---|---|
| `DIFFER`（内容乖離） | **10 件**: `ai-dev-brainstorm` / `ai-dev-exec` / `ai-dev-plan` / `ai-dev-verify` / `ai-loop-cycle` / `intent-classifier` / `local-exec-handoff` / `plan-review-gate` / `plangate-setup` / `working-context` |
| `ONLY-IN-CODEX`（正本に無い skill） | **0 件** |
| `MISSING-IN-CODEX`（配布漏れ） | **0 件** |
| 対照: `plugin/plangate/skills/*/SKILL.md` vs 正本 | **40/40 byte 一致・差分 0**（`PLUGIN-DIFFER` / `PLUGIN-ONLY` とも 0 件） |

**空振りでないことの確認（positive control）**: 同じループが 10 件を実際に出力している（述語が常に真を返す実装ではない）。さらに `plugin` レーンでは同じループが 0 件を返す — 述語は入力によって値が変わる。

### 1.3 `SKILL.md` 以外を含めた全数（issue の「10 件」より広い）

`.codex/skills/**` に置かれる tracked ファイルは 3 種類ある:

```sh
find .codex/skills -type f | sed 's|.*/||' | sort | uniq -c | sort -rn
#   40 SKILL.md / 40 plangate-small.svg / 40 openai.yaml
#    1 ui-ux-lane.md / 1 review-default.md / 1 design-principles.md   （= references/ 配下 2 skill 分）
```

サンドボックス複製で `sh scripts/install-plangate-skills-to-codex.sh --force` を 1 回実行した結果（`git status --porcelain`）:

```text
 M .codex/skills/ai-dev-brainstorm/SKILL.md
 M .codex/skills/ai-dev-exec/SKILL.md
 M .codex/skills/ai-dev-plan/SKILL.md
 M .codex/skills/ai-dev-verify/SKILL.md
 M .codex/skills/ai-loop-cycle/SKILL.md
 M .codex/skills/intent-classifier/SKILL.md
 M .codex/skills/local-exec-handoff/SKILL.md
 M .codex/skills/plan-normalization/agents/openai.yaml      ← SKILL.md 比較では見えない 11 件目
 M .codex/skills/plan-review-gate/SKILL.md
 M .codex/skills/plangate-setup/SKILL.md
 M .codex/skills/working-context/SKILL.md
```

**11 件目**の中身（`short_description` は installer が正本 frontmatter から 64 文字で切り詰めて生成する。正本の description が更新されたのに `.codex` 側が古い）:

```diff
-  short_description: "C-3 前に plan.md を Canonical Plan へ正規化する"
+  short_description: "C-2 の確定反映後・C-3 承認前に plan.md を最終合意状態へ正規化し、履歴依存を除去した Canonical ..."
```

`references/*.md` の乖離は **0 件**（`diff -r` を 2 skill に対して実行し rc=0 を実測）:

```sh
diff -r .agents/skills/skill-creator/references .codex/skills/skill-creator/references   # rc=0
diff -r .agents/skills/review-gate/references  .codex/skills/review-gate/references      # rc=0
```

> **含意**: `SKILL.md` だけを照合する検査（#1226 PATCH-B の対象範囲）では、この 11 件目を**検出できない**。§4 / §5.2。

---

## 2. 乖離 10 件の正否判定（どちらが正しいか / 単純上書きの可否）

### 2.1 判定表

「差分行」は `diff <canon> <mirror> | grep -c '^[<>]'`（`<` と `>` の合計）。`codex_only` は `^>` の行数。

| # | skill | 差分行 | `agents_only` | `codex_only` | 差分の要旨 | 正しいのは | 単純上書き可 |
|---|---|---|---|---|---|---|---|
| 1 | `ai-dev-plan` | 128 | 101 | 27 | #1232/#1249 の bundled resources 節・参照解決順 4 段化・`references/` 一覧・#934 の test-cases 出所必須化が `.codex` に未伝播。`.codex` 側は旧 3 段版と `docs/**` 直参照 | **`.agents`** | **可** |
| 2 | `ai-dev-verify` | 98 | 72 | 26 | 同上（参照解決順・同梱 references・handoff テンプレの扱い） | **`.agents`** | **可** |
| 3 | `ai-dev-exec` | 87 | 69 | 18 | 同上 + c3-prime 契約の参照先が `docs/workflows/ai-loop/c3-prime-contract.md`（旧）→ 同梱 `references/c3-prime-contract.md`（新） | **`.agents`** | **可** |
| 4 | `ai-loop-cycle` | 81 | 70 | 11 | 「CLI 依存の分離（`bin/plangate` は配布されない）」節（#1144）と `<skill_dir>` パス表記規約が `.codex` に未伝播 | **`.agents`** | **可** |
| 5 | `ai-dev-brainstorm` | 79 | 60 | 19 | 参照解決順の 4 段化・同梱 references 表・#1249 MINOR-3 の例外注記 | **`.agents`** | **可** |
| 6 | `plan-review-gate` | 15 | 14 | 1 | **C-3 の規範ブロック 3 本が `.codex` から欠落**（§3）。codex-only の 1 行は `bin/plangate exec` 表記（#1237 で CLI 名非依存表記へ更新済みの旧版） | **`.agents`** | **可** |
| 7 | `plangate-setup` | 9 | 9 | 0 | `doctor` の #1144 前提ブロック（「CLI が無いことを理由に検証を黙って省略し『doctor PASS』と読める記録を残してはならない」）が欠落 | **`.agents`** | **可** |
| 8 | `intent-classifier` | 8 | 8 | 0 | #1144 前提ブロック（CLI 不在時の degrade 規範）が欠落 | **`.agents`** | **可** |
| 9 | `local-exec-handoff` | 8 | 8 | 0 | 同上 | **`.agents`** | **可** |
| 10 | `working-context` | 8 | 8 | 0 | 同上 | **`.agents`** | **可** |
| — | （11 件目）`plan-normalization/agents/openai.yaml` | — | — | — | 生成物 `short_description` が旧 description 由来 | **`.agents` 由来の再生成** | **可** |

> 参考: #1226 の調査（PR #1287）も同じ 10 件・同じ差分行数（128/98/87/81/79/15/9/8/8/8）を報告している。**本書は数値を転記せず独立に測って一致を確認した**（10 件すべて一致）。

### 2.2 「消してはいけない差分」は無い — 3 つの独立根拠

**根拠 A（履歴）**: 直近の完全再同期は PR #1212（`1e629fb9` / 2026-08-24）。それ以降に `.codex/skills` を触った commit は **2 本**（`6b8ab457` #1221 / `ecfef5b3` #1254）で、**どちらも同じ commit で `.agents/skills` も触っている**。一方 `.agents/skills` にはその後 `#1233` `#1237` `#1249` `#1251` `#1261` 等が入り `.codex` へ伝播していない。**再同期以降に `.codex` 単独で入った変更は 0 件。**

```sh
git log --format='%h %ad %s' --date=short -25 -- .codex/skills    # 最新は ecfef5b3 (2026-08-27)
git log --format='%h %ad %s' --date=short -25 -- .agents/skills   # 最新は 69588edf (2026-08-28)
```

**根拠 B（行単位）**: codex-only 行は合計 102 行（10 件の `^>` の和）。全行を読み、いずれも **正本が新版に差し替えた段落の旧版**であることを確認した。例（`plan-review-gate` の唯一の codex-only 行）:

```text
> 詳細は `.claude/rules/working-context.md` の C-3 ゲート節と条件付き降格節を正本とする。`bin/plangate exec` は APPROVED の c3.json のみ受理。
```

これは正本側で「`bin/plangate exec`」→「PlanGate CLI の `exec`」へ更新された行（#1237: 配布 skill から `bin/plangate` 依存を分離）の旧表記であり、**独自の規範ではない**。

**根拠 C（全ツリー再生成）**: サンドボックスで `.codex/skills` を丸ごと削除してから `--force` で再生成し、commit 済みツリーと `diff -rq` した:

```sh
cp -R .codex/skills /tmp/committed
rm -rf .codex/skills
sh scripts/install-plangate-skills-to-codex.sh --force     # rc=0
diff -rq /tmp/committed .codex/skills                      # rc=1
```

出力は **上記 11 ファイルの `... differ` のみ**。`Only in ...`（片側にしかないファイル / ディレクトリ）は **0 行**。すなわち `.codex/skills/**` は **全体が生成物**であり、生成元から復元できない情報は含まれていない。

**再同期スクリプトは 1 回で収束する**（冪等性）: 再実行しても変更ファイル集合は 11 件のまま増えない（2 回目実行後の `git status --porcelain | wc -l` = 11、1 回目と同一）。

### 2.3 PR #1212 が除外した `plan-review-gate` の扱い（現時点の再判定）

PR #1212 は人間裁定 Q6=B により `plan-review-gate` を再同期対象から除外していた（`.codex` 側にだけある独自節 34 行を先に `.agents` へ取り込む方針）。**その前提は現時点では成立しない**:

- `.agents/skills/plan-review-gate/SKILL.md` はその後 `6b8ab457`（#1221 / 2026-08-25）と `8ad37067`（#1237 / 2026-08-26）で更新されており、#1221 は `.codex` 側も同時に更新している。
- 現在の codex-only 行は **1 行のみ**（上記 §2.2 根拠 B）で、独自節は残っていない。

したがって **`plan-review-gate` を除外する理由は消滅している**。ただしこれは Q6=B の裁定を AI が撤回するものではない — **再同期を実施する Human が「除外理由の消滅」を確認したうえで判断する事項**として §9 に送る。

---

## 3. 承認手順の定義面: 何が欠落し、Codex セッションの挙動に何が起きるか

### 3.1 機械照合（不在の主張には positive control を付ける）

```sh
grep -rl "黙って省略"           .agents/skills   # 8 ファイル
grep -rl "黙って省略"           .codex/skills    # 0 ファイル
grep -rl "実施済みと読める記録を" .agents/skills   # 7 ファイル
grep -rl "実施済みと読める記録を" .codex/skills    # 0 ファイル
grep -rl "機械 block が無いことを理由に" .agents/skills  # 1（plan-review-gate）
grep -rl "機械 block が無いことを理由に" .codex/skills   # 0
```

- **positive control**: 同じ述語が `.agents` 側で 8 / 7 / 1 件を返す。0 件が「述語が常に空振り」ではないことの確認。
- **表記揺れの確認**: 最初に `"実施済みと読める記録を残してはならない"`（1 行に閉じた形）で引いたときは **6 件**しかヒットしなかった。`intent-classifier` は原文が「…実施済みと読める記録を\n> 残してはならない。」と行折り返しされているためである。**行折り返しをまたぐ語で数え直して 7 件**、より広い `"黙って省略"` で **8 件**。行単位 grep の取りこぼしをそのまま「不在」と書かないこと。
- **削除であって言い換えではない**ことの確認: 各ファイルの `grep -c "省略"` は `.agents` > `.codex` で、`.codex` 側に代替表現は現れていない。

| skill | `省略` 出現数（agents / codex） |
|---|---|
| `ai-dev-exec` | 3 / 2 |
| `ai-dev-plan` | 2 / 1 |
| `ai-dev-verify` | 1 / 0 |
| `intent-classifier` | 3 / 2 |
| `local-exec-handoff` | 2 / 1 |
| `plan-review-gate` | 3 / 1 |
| `plangate-setup` | 2 / 1 |
| `working-context` | 2 / 1 |

### 3.2 欠落している規範の内容と、Codex セッションへの影響

issue 本文と #1226 は「承認手順の定義面 **7 件**」と数えている（`ai-dev-plan` / `ai-dev-verify` / `ai-dev-exec` / `ai-loop-cycle` / `plan-review-gate` / `intent-classifier` / `local-exec-handoff`）。本書の機械照合では「**黙って省略しない**」規範を持つのは **8 skill**（上表）で、集合は完全一致ではない（`ai-loop-cycle` は当該規範文を持たず別種の欠落、`plangate-setup` / `working-context` は当該規範文を持つが #1226 の分類では NO）。**どちらの数え方も間違いではない**（分類軸が「承認手順の定義面か」と「規範文の有無」で違う）。以下は skill 単位で、**欠落内容と影響**を書く。

| skill | `.codex` から欠落している規範 | Codex セッションの挙動への影響 |
|---|---|---|
| **`plan-review-gate`**（C-3 の手順そのもの） | (1)「**機械 block が無いことを理由に C-3 を省略しない。**」(2)「CLI が無い環境では判定基準そのものは不変で『APPROVED 以外では exec に進まない』を人手で維持する」(3) CLI 呼び出し節の #1144 前提ブロック | Codex セッションには **hook による物理 block が無い**（`.codex/hooks.json` は parse 拒否で hook 0 件登録 = 正本の実測）。その環境で「機械 block が無いことを理由に C-3 を省略しない」が読まれないと、**「block されないなら通ってよい」という誤読を止める文が 1 つも無い**状態になる。C-3 を skip して exec に進む経路が、規範上も止まらない |
| **`ai-dev-exec`**（exec 入口条件） | #1144 前提ブロック（CLI・hook は配布されない／到達したら明示停止する／黙って省略して実施済みと読める記録を残さない）。加えて c3-prime 契約の参照先が旧 `docs/**`（Codex 導入先では **必ず解決不可**） | `c3.json` の `approval_kind` 別受理条件の**正本に辿り着けない**まま、「参照できなかった」と明示する義務も落ちる。結果として **exec 入口の全数検証（`plan_hash` / `artifact_hashes` 6 要素 / `plan_package_hash` / `source_sha`）を確認したかどうかが記録に残らない** |
| **`ai-dev-plan`** | 同前提ブロック + **#934 の test-cases 出所必須化**（規約由来の期待値は実値突合を残す／不一致なら AC に採用せず人間確認へ）+ 同梱 `references/` 一覧 | `plan_hash` 機械検証の代替手順が「省略してよい」と読める。さらに **規約 ≠ 実値のときに AI が黙って片側へ寄せない**という安全側規範が丸ごと無い |
| **`ai-dev-verify`**（V-1） | 同前提ブロック + handoff 6 要素テンプレが解決できない環境での正本指定 | V-1 の `plan_hash` 突合と handoff 6 要素を、**未参照のまま「実施済み」と書ける** |
| **`ai-loop-cycle`**（C-3′ 経路） | 「CLI 依存の分離」節（どの手順が CLI 必須／不要かの表 + 「**`plangate ai-loop run …` は存在しない**」+ CLI 必須作業に到達したら明示停止）+ `<skill_dir>` パス表記規約 | 導入先で **存在しない CLI サブコマンドを叩いて失敗** → その失敗を「環境の問題」として飛ばす余地が生まれる。どの手順が担保層（arbiter 裁定と実行者の規律）で守られているかの表も無い |
| **`intent-classifier`** | 同前提ブロック（「分類を `ops` 以外にすり替えない」を含む degrade 規範） | CLI が無いことを理由に **分類そのものを緩める**（＝承認が要る作業を軽い分類へ落とす）経路の抑止が消える |
| **`local-exec-handoff`** | 同前提ブロック | `approvals/c3.json` の APPROVED 確認を「実行できない」で飛ばし、**実施済みと読める handoff を残せる** |
| **`plangate-setup`** | 「CLI が無いことを理由に検証を黙って省略し『**doctor PASS**』と読める記録を残してはならない」 | settings タスクロック（V-1 / handoff の前提）を **未検証のまま PASS と記録**できる。Shadow Config 防止の構造がここで崩れる |
| **`working-context`** | 同前提ブロック（CLI 呼び出し節） | 上と同じ経路で、`status.md` に degrade を残さず完了扱いにできる |
| `ai-dev-brainstorm` | 規範文ではなく参照解決順・同梱 references の未伝播 | 承認境界そのものへの影響は小（`docs/**` 直参照で空振りする分の劣化） |

**共通の構造**: 欠落しているのはいずれも「**実行できないときに、黙って飛ばして『やった』と書くな**」という規範である。Codex レーンは物理 hook が効いていないレーンであり、**規範だけが担保層**であるにもかかわらず、その規範が選択的に落ちている。これが #1226 の予測（承認手順の定義面が HO 外にあるため、正本を踏まずに承認手順を弱められる）が **提案上のリスクではなく main 上の実害**であることの根拠になる。

---

## 4. 既存資産との関係（重複を作らない）

| 既存 | 何を見るか | 本書との関係 |
|---|---|---|
| `.github/workflows/sync-plugin-plangate.yml` の `drift-check` | `sh scripts/sync-plugin-plangate.sh` 後に `git diff --quiet -- plugin/plangate/` | **`.codex` は対象外**。`pull_request.paths` にも `.codex/**` を含まない（実測: 同 workflow の paths は `.claude/**` / `.agents/skills/**` / `docs/{ai,workflows}/ai-loop/**` / `scripts/ai-loop/**` / `scripts/_ai_loop_link_rewrite.py` / `scripts/sync-plugin-plangate.sh` / `plugin/plangate/**`） |
| `scripts/check-codex-skill-spec.sh` | ディレクトリ集合の presence と `SKILL.md` / `agents/openai.yaml` の対応 | **内容を見ない**。CI では `--warn-only` |
| `tests/extras/ta-77-approval-surface-gate.sh` + `tests/fixtures/ta-77/approval-surfaces.tsv`（読取のみ） | 承認手順の**宣言ブロック**（宣言行 + 連続非空行ブロック）の sha256 先頭 12 桁 | **ファイル全体を見ない**ため、宣言ブロックの外側の乖離を素通りする（下記の実測） |
| **#1226 PATCH-B**（`1226-approval-surface-patch-applicable.md` / PR #1287 マージ済・**未適用**） | `.codex/skills` の `SKILL.md` + `references/*.md` を `cmp` で双方向照合し、`sync-plugin-plangate.yml` の既存 job にステップ追加 + `paths` に `.codex/skills/**` 追加 | **本書の層 1 とほぼ同じ**。ただし同書は `agents/openai.yaml` と `assets/` を**意図的に対象外**（同書 §6「新規（follow-up 候補）」）としており、**§1.3 の 11 件目を検出しない**。本書はその残存を実測で顕在化させ、層 2 で塞ぐ |

### 4.1 ta-77 台帳の digest は一致しているのに、ファイルは乖離している（自分で照合した）

台帳（54 行 / `.codex/skills` 由来のエントリは **5 件**）を読み、`.agents` 側の同名エントリと digest を突き合わせた:

| path | class | digest（`.agents` / `.codex`） | §2 の差分行 |
|---|---|---|---|
| `.../ai-dev-plan/SKILL.md` | DECL | `79c0d8551308` / **同一** | 128 |
| `.../intent-classifier/SKILL.md` | DECL | `9014dac9caec` / **同一** | 8 |
| `.../local-exec-handoff/SKILL.md` | DECL | `8b368bb3f212` / **同一** | 8 |
| `.../plan-review-gate/SKILL.md` | CHAIN | `17e7ed953b6c` / **同一** | 15 |
| `.../plangate-setup/SKILL.md` | DECL | `3ff5b08b9abc` / **同一** | 9 |

**5 対すべて digest 一致、5 対すべてファイルは乖離。** ta-77 の digest は「宣言行 + その行を含む連続非空行ブロック」だけの sha256 であり、今回落ちている #1144 前提ブロックや `plan-review-gate` の C-3 規範ブロックは**その外側**にあるため、台帳は緑のまま drift が通過する。**ta-77 は本検査を代替しない**（逆も同様）。残り 5 件（`ai-dev-verify` / `ai-dev-exec` / `ai-loop-cycle` / `ai-dev-brainstorm` / `working-context`）は `.codex` 側エントリが台帳に無い。

**したがって本書の新規性は次の 3 点に限る**（既存の再掲は避ける）:

1. 乖離 10 件の**正否判定を 3 根拠で確定**（正本へ取り込むべき差分 0 件 / `plan-review-gate` の除外理由が消滅していること）
2. `SKILL.md` 比較では見えない **11 件目（生成物 `openai.yaml`）の実在**
3. **層 2（全ツリー再生成 → 差分ゼロ）**の設計と positive control 実測

---

## 5. CI 検査の設計

### 5.1 起動条件（`paths`）

`pull_request` / `push(main)` の両方に、次の 5 パターンを置く:

| パターン | 理由 |
|---|---|
| `.codex/skills/**` | **これが無いと `.codex/` だけを変える PR で job が起動しない**（検査があっても発火しない） |
| `.agents/skills/**` | 正本が動けば mirror は drift する |
| `scripts/install-plangate-skills-to-codex.sh` | 生成規則が変われば生成物も変わる |
| `plugin/plangate/assets/**` | installer は `plugin/plangate/assets` から `assets/` をコピーする（実測: `ASSETS_SRC="$ROOT_DIR/plugin/plangate/assets"`） |
| `.github/workflows/codex-skills-drift.yml` | 検査自身の変更で検査が走らない状態を作らない |

**この 5 つ以外の変更では `.codex/skills/**` の drift は原理的に発生しない**（installer の入力がその 3 種 + 生成規則しかないため。§2.2 根拠 C で全体が生成物であることを実測済み）。

### 5.2 照合の方向と対象範囲

| 層 | 何を照合するか | 方向 | installer 依存 |
|---|---|---|---|
| **層 1** | 無変換 `cp` で配られる 2 種（`SKILL.md` / `references/*.md`）の byte 一致 + 欠落 + 余剰 | **双方向**（canon→mirror で欠落・乖離、mirror→canon で余剰 skill ディレクトリと余剰 `references/*.md`） | **非依存**（`cmp` のみ。installer が no-op に改竄されても主張が立つ） |
| **層 2** | `.codex/skills/**` **全体**（`agents/openai.yaml` / `assets/*` / 余剰ファイルを含む） | **双方向**（`rm -rf` してから再生成するので、生成されないファイルは `D` として現れる） | **依存**（installer を実行する） |

2 層にする理由: 層 1 だけでは §1.3 の 11 件目（生成物）と skill ディレクトリ内の余剰ファイルを見逃す。層 2 だけでは **installer 自体を no-op に改竄されると空振り**する。**片方が他方を代替しない。**

対象範囲は installer の実装を読んで決めた（`cp SKILL.md` / `sync_refs`（`references/*.md` のコピー + 正本に無いものの削除）/ `cp` assets / `{ ... } > openai.yaml` の 4 種）。`assets/*` は per-skill の正本を持たない（出所は `plugin/plangate/assets`）ため層 1 の byte 照合には載せず、層 2 の再生成一致でのみ担保する。

### 5.3 なぜ「余剰」を見逃さないか

層 2 は `.codex/skills` を丸ごと削除してから再生成し、`git status --porcelain -- .codex/skills/` が空であることを要求する。したがって:

- 生成物と異なる内容 → `M`
- commit 済みだが生成されないファイル（skill 内の余剰ファイル / 正本に無い skill ディレクトリ） → `D`
- 生成されたが commit されていないファイル → `??`

の 3 クラスすべてが 1 つの述語で落ちる。

### 5.4 positive control（実測 / repo 外サンドボックス）

`git clone --no-hardlinks --no-local` した複製で実施。

**negative control（無改竄なら PASS することの確認）**: 再同期をコミットした状態で層 2 を実行 → `git status --porcelain -- .codex/skills/` は **0 行**（PASS）。

**positive control（3 クラスを仕込んで検出することの確認）**: 次の 3 つをコミットしてから層 2 を実行:

1. `.codex/skills/plan-review-gate/SKILL.md` に 1 行追記（内容改竄）
2. `.codex/skills/plan-review-gate/SURPLUS.md` を追加（skill 内の余剰ファイル）
3. `.codex/skills/zz-orphan-skill/SKILL.md` を追加（正本に無い skill ディレクトリ）

出力:

```text
 M .codex/skills/plan-review-gate/SKILL.md
 D .codex/skills/plan-review-gate/SURPLUS.md
 D .codex/skills/zz-orphan-skill/SKILL.md
```

**3 クラスすべて検出（rc=1）。**

### 5.5 patch 適用後の実走（両ステップ / GitHub Actions 既定シェル `bash -eo pipefail`）

patch をサンドボックスへ適用し、workflow の `run` ブロックを**そのまま**実行した（`yaml.safe_load` で抽出して `bash -eo pipefail -c` に渡す）。

| 状態 | 層 1 | 層 2 |
|---|---|---|
| 現 main（drift あり） | **rc=1**（10 件の `::error::drift` を出力） | **rc=1**（§1.3 の 11 ファイルを列挙） |
| 再同期をコミットした状態 | **rc=0**（`layer1: copied artifacts are in sync.`） | **rc=0**（`layer2: .codex/skills/ matches the generated tree.`） |
| 層 1 の 3 分岐へ変異注入（下記） | **rc=1**（3 件とも検出） | — |

層 1 の変異注入（**現 main が 0 件のため、空振りでないことを別途示す必要がある分岐**）:

1. `.codex/skills/plangate-setup/SKILL.md` を削除 → `::error::missing .codex/skills/plangate-setup/SKILL.md (canon: ...)`
2. `.codex/skills/review-gate/references/EXTRA.md` を追加（正本に無い `references`）→ `::error::surplus ... (no canon)`
3. `.codex/skills/zz-orphan/` を追加（正本に無い skill ディレクトリ）→ `::error::surplus skill dir ... (no canon)`

**3 分岐すべて検出。** また層 1 の `diff -u ... | head -40 || true` が `pipefail` 下でもステップを落とさず、10 件すべてを報告し切ることを実測した（`head` の早期終了で errexit が効く既知の罠を回避できている）。

---

## 6. patch（`git apply` 用）

### 6.1 抽出

marker 基準（#1104 / #1226 / #1278 と同じ規則。marker 行と fence 行を 2 行ずつ落とす）:

````sh
sed -n '/^<!-- PG-PATCH-BEGIN -->$/,/^<!-- PG-PATCH-END -->$/p' \
  docs/working/_reports/1288-codex-skills-drift-and-ci-patch.md \
  | sed -e '1d' -e '$d' | sed -e '1d' -e '$d' > /tmp/1288-codex-skills-drift.patch
git apply --check /tmp/1288-codex-skills-drift.patch
git apply --numstat /tmp/1288-codex-skills-drift.patch
````

<!-- PG-PATCH-BEGIN -->
`````diff
diff --git a/.github/workflows/codex-skills-drift.yml b/.github/workflows/codex-skills-drift.yml
new file mode 100644
index 0000000..1111111
--- /dev/null
+++ b/.github/workflows/codex-skills-drift.yml
@@ -0,0 +1,105 @@
+name: codex-skills-drift
+
+# .codex/skills/ が生成元 .agents/skills/ と乖離していないことを PR で必須化する (#1288)。
+# 既存の plugin レーン (sync-plugin-plangate.yml の drift-check) と同じ思想だが、
+# 対象と起動条件が異なるため独立 workflow とする。
+#
+# paths に .codex/skills/** を含めること: 含めないと .codex/ だけを変える PR で
+# job が起動せず、検査が存在しても発火しない。
+
+on:
+  pull_request:
+    paths:
+      - '.codex/skills/**'
+      - '.agents/skills/**'
+      - 'scripts/install-plangate-skills-to-codex.sh'
+      - 'plugin/plangate/assets/**'
+      - '.github/workflows/codex-skills-drift.yml'
+  push:
+    branches: [main]
+    paths:
+      - '.codex/skills/**'
+      - '.agents/skills/**'
+      - 'scripts/install-plangate-skills-to-codex.sh'
+      - 'plugin/plangate/assets/**'
+      - '.github/workflows/codex-skills-drift.yml'
+  workflow_dispatch:
+
+permissions: {}
+
+concurrency:
+  group: codex-skills-drift-${{ github.workflow }}-${{ github.ref }}
+  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
+
+jobs:
+  drift-check:
+    permissions:
+      contents: read
+    runs-on: ubuntu-latest
+    timeout-minutes: 10
+    steps:
+      - name: Checkout
+        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
+        with:
+          fetch-depth: 1
+          persist-credentials: false
+
+      # 層 1: installer 非依存の byte 照合。installer が no-op へ改竄されても、
+      # 無変換 cp で配られる 2 種 (SKILL.md / references/*.md) の一致は独立に主張する。
+      # 双方向 (canon -> mirror の欠落・乖離 / mirror -> canon の余剰) で回す。
+      - name: Byte-compare copied artifacts (installer-independent, bidirectional)
+        run: |
+          rc=0
+          for src in .agents/skills/*/SKILL.md; do
+            n=$(basename "$(dirname "$src")")
+            dst=".codex/skills/$n/SKILL.md"
+            if [ ! -f "$dst" ]; then
+              echo "::error::missing $dst (canon: $src)"
+              rc=1
+              continue
+            fi
+            if ! cmp -s "$src" "$dst"; then
+              echo "::error::drift $dst differs from canon $src"
+              diff -u "$src" "$dst" | head -40 || true
+              rc=1
+            fi
+            srcref=".agents/skills/$n/references"
+            dstref=".codex/skills/$n/references"
+            [ -d "$srcref" ] || continue
+            for r in "$srcref"/*.md; do
+              [ -f "$r" ] || continue
+              b=$(basename "$r")
+              if [ ! -f "$dstref/$b" ]; then
+                echo "::error::missing $dstref/$b"
+                rc=1
+                continue
+              fi
+              cmp -s "$r" "$dstref/$b" || { echo "::error::drift $dstref/$b"; rc=1; }
+            done
+            for r in "$dstref"/*.md; do
+              [ -f "$r" ] || continue
+              b=$(basename "$r")
+              [ -f "$srcref/$b" ] || { echo "::error::surplus $dstref/$b (no canon)"; rc=1; }
+            done
+          done
+          for d in .codex/skills/*/; do
+            n=$(basename "$d")
+            [ -d ".agents/skills/$n" ] || { echo "::error::surplus skill dir $d (no canon)"; rc=1; }
+          done
+          if [ "$rc" -eq 0 ]; then echo "layer1: copied artifacts are in sync."; fi
+          exit "$rc"
+
+      # 層 2: 全ツリー再生成。層 1 が見ない生成物 (agents/openai.yaml) と
+      # skill ディレクトリ内の余剰ファイルまで含めて、commit 済みツリー == 生成結果 を要求する。
+      # rm -rf してから生成するので、生成されないファイルは D として現れ、片方向の見落としが出ない。
+      - name: Regenerate whole tree and require zero diff
+        run: |
+          rm -rf .codex/skills
+          sh scripts/install-plangate-skills-to-codex.sh --force >/dev/null
+          out=$(git status --porcelain -- .codex/skills/)
+          if [ -n "$out" ]; then
+            echo "::error::.codex/skills/ が生成結果と一致しません。ローカルで 'sh scripts/install-plangate-skills-to-codex.sh --force' を実行し、結果をコミットしてください。"
+            echo "$out"
+            exit 1
+          fi
+          echo "layer2: .codex/skills/ matches the generated tree."
`````
<!-- PG-PATCH-END -->

### 6.2 `git apply --check` の実測（repo root）

```text
$ sed -n '/^<!-- PG-PATCH-BEGIN -->$/,/^<!-- PG-PATCH-END -->$/p' \
    docs/working/_reports/1288-codex-skills-drift-and-ci-patch.md \
    | sed -e '1d' -e '$d' | sed -e '1d' -e '$d' > /tmp/1288-codex-skills-drift.patch
$ git apply --check /tmp/1288-codex-skills-drift.patch
$ echo $?
0
$ git apply --numstat /tmp/1288-codex-skills-drift.patch
105	0	.github/workflows/codex-skills-drift.yml
```

サンドボックス複製での実適用も rc=0。適用後の YAML は `yaml.safe_load` でパース可能で、`pull_request.paths` / `push.paths` の双方に `.codex/skills/**` が含まれることを機械確認した。

### 6.3 適用手順（Human / repo root で実行）

> **警告（順序を守ること）**: **この patch を先に当てると、`.codex/skills/**` または `.agents/skills/**` に触れる次の PR で CI が即 FAIL する。** 現 main には §1.3 の **11 ファイルの drift が残っている**ためである。**必ず「1. 再同期 → 2. patch」の順**、または**同一 PR で両方**を行うこと（先例: `1226-approval-surface-patch-applicable.md` §0 の PATCH-B 適用前提と同じ性質）。

```sh
# 0) 作業ブランチ（main へ直接 commit しない）
git fetch origin && git checkout -b fix/1288-codex-skills-resync origin/main

# 1) 再同期（§7）
sh scripts/install-plangate-skills-to-codex.sh --force
git status --porcelain -- .codex/skills/     # 11 ファイルが M で出ることを確認
git add .codex/skills/
git commit -m "fix(codex): .codex/skills を生成元 .agents/skills へ再同期 (#1288)"

# 2) patch 適用（Hardening Override 対象 = Human-owned）
sed -n '/^<!-- PG-PATCH-BEGIN -->$/,/^<!-- PG-PATCH-END -->$/p' \
  docs/working/_reports/1288-codex-skills-drift-and-ci-patch.md \
  | sed -e '1d' -e '$d' | sed -e '1d' -e '$d' > /tmp/1288-codex-skills-drift.patch
git apply --check /tmp/1288-codex-skills-drift.patch   # rc=0 を確認してから
git apply /tmp/1288-codex-skills-drift.patch
git add .github/workflows/codex-skills-drift.yml
git commit -m "ci: .codex/skills の drift 検査を追加 (#1288)"

# 3) 適用後の自己検査（CI と同じ述語をローカルで）
rm -rf .codex/skills && sh scripts/install-plangate-skills-to-codex.sh --force >/dev/null
git status --porcelain -- .codex/skills/      # 空であること
```

**#1226 PATCH-B と両方を適用する場合**: 層 1 の役割が重複する（PATCH-B は `sync-plugin-plangate.yml` の既存 job にステップを足し、`paths` に `.codex/skills/**` を加える）。**ファイル競合は起きない**（別ファイル）が、同じ照合が 2 回走る。どちらか一方に寄せるなら、**PATCH-B（層 1 相当）＋ 本 patch の層 2 ステップだけ**を残すのが最小構成。この取捨は §9 の Human 判断事項。

---

## 7. 再同期の手順（Human または `PLANGATE_SKIP_REASON` 付きセッション）

本 PR の AI セッションは **`PLANGATE_SKIP_REASON` 未設定**であり、EH-3 により `.md` 以外の書込が block される。`.codex/skills/**` の再同期は `SKILL.md`（`.md`）だけでなく `agents/openai.yaml` を書き換えるため、**本セッションでは実施していない**（Bash 経由で書けば技術的には通るが、それは #1104 の既知の穴を使った迂回であり規律上禁止）。

| 実行主体 | 手順 |
|---|---|
| **Human**（推奨） | §6.3 の手順 1 |
| `PLANGATE_SKIP_REASON` を設定して起動した AI セッション | 同上。**起動時に環境変数を設定する必要がある**（実行中の `export` は EH-3 に効かない） |

**再同期後の受入確認**（どちらも 0 であること）:

```sh
for f in .codex/skills/*/SKILL.md; do
  n=$(basename "$(dirname "$f")"); cmp -s "$f" ".agents/skills/$n/SKILL.md" || echo "DIFFER: $n"
done | wc -l                                  # 0
git status --porcelain -- .codex/skills/      # 再生成後に空
```

**再同期そのものは冪等**（§2.2）。`--force` を 2 回走らせても変更ファイル集合は増えない。

---

## 8. 残存脅威モデル（完全性を主張しない）

### 守る（再同期 + patch 適用後）

- `.codex/skills/**` の内容が生成元 `.agents/skills/**` と乖離した状態で PR が緑になること
- `.codex/skills/` にだけ存在する skill ディレクトリ / 余剰ファイル（正本に無い承認手順の持ち込み）
- 生成物 `agents/openai.yaml` の乖離（§1.3 の 11 件目のクラス）
- `.codex/skills/` だけを変える PR で job が起動しないこと（`paths` に含めるため）

### 守らない

| 残存 | 内容 | 追跡 |
|---|---|---|
| **CI が advisory** | 本検査は required status check ではない。**赤でもマージできる**（ruleset 操作は Human-owned）。「CI があるから担保されている」と書かないこと | #928 |
| **installer 自体の改竄** | 層 2 は installer を実行するため、installer を no-op にすれば空振りする。層 1（`cmp`）が `SKILL.md` / `references/*.md` については緩和するが、`openai.yaml` は層 2 のみ | 本書（follow-up 候補） |
| **正本そのものの改変** | `.agents/skills/**` は HO 外。本検査が守るのは「正本とコピーの一致」であって「正本の内容が正しいこと」ではない | #1226 / #1263 |
| **`.cursor/skills/plan-review-gate`** | `.agents/skills/plan-review-gate` への symlink であり、本検査の対象外 | #1226 §1 / #1264 |
| **Codex CLI の実セッション 1 周** | 「規範ブロックが復元されたことで Codex の挙動が実際に変わる」ことは fixture では測れない。§3 の影響欄は**記述の欠落と、その規範が担う役割**から導いた推論であり、実セッションでの挙動計測ではない | 本書 |
| **`.codex/skills/.system/`** | `.gitignore` 登録の実行時ディレクトリ。CI の fresh checkout には出現しないが、ローカルで層 1 を手動実行すると「余剰 skill ディレクトリ」の偽陽性になりうる | #1226 §2 |
| **二重 root 登録** | `.codex/skills` と `.agents/skills` が両方 root 登録され skill 一覧が水増しされる問題は本書の範囲外 | #1086 |

---

## 9. Human 判断に送る事項

1. **`plan-review-gate` を再同期対象に含めるか**。PR #1212 の Q6=B（`.codex` 独自節を先に `.agents` へ取り込む）の前提は §2.3 のとおり消滅しているが、裁定の撤回は Human の判断。
2. **#1226 PATCH-B と本 patch のどちらを採るか / 両方採るか**（§6.3 末尾）。
3. **本検査を required status check に加えるか**（#928 の一部。ruleset 操作は Human-owned）。
4. `openai.yaml` を層 1 側でも照合できるようにするか（installer 非依存にするには生成規則の独立実装が要る＝二重実装のコスト）。

---

## 付録: 本書作成時の実行環境

- 検証はすべて **repo 外サンドボックス**（`git clone --no-hardlinks --no-local` した複製）と、本 worktree の**読み取り専用コマンド**のみ。
- 本 worktree では `sh scripts/install-plangate-skills-to-codex.sh` を **実行していない**（`git status --porcelain` に `.codex/` の差分が出ないことを確認）。
