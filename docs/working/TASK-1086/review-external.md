# TASK-1086 外部レビュー（C-2 相当 / 検証レビュー）

> 対象: `docs/working/TASK-1086/investigation.md`（382 行）
> 対象ブランチ: `origin/docs/1086-dual-root-investigation` / head = `a15faad`
> レビュー branch: `review/1086-verify`（base = `a15faad`）
> 実施日: 2026-08-15 / codex-cli **0.144.1** / macOS 15.6 (darwin 25.6.0)
> 測定 worktree: `/Users/user/Documents/GitHub/plangate/.claude/worktrees/agent-a3f05789ac0184b98`（= `main` `0385457`）
> 判定フレーム: [`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md) §2〜4（5 観点 / 4 段階）
> レーン: **設計妥当性レーン**（本 doc は実装 plan ではなく調査報告のため、主眼は「記載された事実主張が再現するか」）

## 判定

**VERDICT: REJECT** — critical=0 / **major=2** / minor=2 / info=1

調査の**中核的な事実主張（二重 root の因果・fixture・導入先無影響・件数）はすべて再現した**。
一方で、**推奨案 (A′) が「新しい穴を作らない」と論証している 2 本の柱**が実測で成立しない。
どちらも doc 本体の修正で解消でき、推奨案そのものの棄却は求めない。

---

## 1. 検証項目ごとの再現可否

| # | 主張 | 判定 |
|---|---|---|
| 1 | root 登録の因果（既定 project-scoped 探索。`CODEX_HOME` 隔離でも r0 が出る） | **再現した**（反証も試みて棄却） |
| 2 | 合成 fixture: `.codex/skills` を消すと r0 が消え `.agents/skills` は残る | **再現した** |
| 3 | 導入先ユーザーへの影響ゼロ（install 導線） | **再現した**（ただし機構の記述に欠落 → R-004） |
| 4 | 「壊れうるもの 48 ファイル」の全数性 | **件数は再現・分類は不完全**（→ R-003） |
| 5 | drift 4 件の実在と向き | **実在は再現。向きは doc 未判定で、1 件が逆向き**（→ R-002） |
| 6 | 推奨案 (A′) が新しい穴を作らないか / 順序問題の認識 | **順序問題は認識済みだが理由が誤り。穴の回収機構が機能しない**（→ R-001） |

---

## 2. 指摘

### R-001 — `major` — 「検査対象を配布物へ付け替えれば検査は強くなる」が成立しない

**観点**: 保守性 / 拡張性（是正案の有効性）
**該当**: §6 推奨理由 5「穴 1」（L304）、§6 実装スケッチ 手順 3（L314）、§6 注意（L321）、§7 S-1（L329）

doc は (A′) の副作用「`check-codex-skill-spec.sh` が対象を失い openai.yaml の仕様検査が消える」に対し、
**対象を `plugin/plangate/skills` に付け替えれば §7 の 35/39 ギャップも同時に埋まり「検査は消えるどころか強くなる」**
と論証している。実測ではこれが**逆**になる。

`check-codex-skill-spec.sh` は **openai.yaml が無い skill を violation にせず silently skip する**:

```python
yaml_path = os.path.join(target_dir, name, 'agents', 'openai.yaml')
if not os.path.exists(yaml_path): continue     # ← 欠落は検出されない
checked += 1
```

実測:

```console
$ sh scripts/check-codex-skill-spec.sh --target plugin/plangate/skills ; echo rc=$?
[spec-check] Checked 35 skills in plugin/plangate/skills
[spec-check] VIOLATIONS (1):
  - diff-audit: short_description too long (66 chars, max 64): "Audit a change diff across multiple review phases before commit/PR"
rc=1

$ sh scripts/check-codex-skill-spec.sh ; echo rc_default=$?
[spec-check] Checked 39 skills in <worktree>/.codex/skills
[spec-check] VIOLATIONS (8):
  ... (short_description too long × 8)
rc_default=1
```

帰結（3 点とも doc の記述と食い違う）:

1. **付け替えは検査を弱くする**。検査対象 skill が **39 → 35** に減り、**openai.yaml が無い 4 件は検査から消える**。
   「§7 の既存ギャップ（35/39）も同時に埋める」は起こらない — 検査は 4 件の欠落を**報告しない**。
2. **§6 注意 L321「4 件が openai.yaml 欠落で即 FAIL する」は誤り**。rc=1 の要因は
   `diff-audit` の `short_description` 66 文字であり、欠落 4 件は無関係。
3. **CI は赤くならない**。workflow が実行するのは `--warn-only` 付き:

```console
$ sh scripts/check-codex-skill-spec.sh --warn-only --target plugin/plangate/skills ; echo rc=$?
[spec-check] Checked 35 skills in plugin/plangate/skills
[spec-check] VIOLATIONS (1): ...
[spec-check] --warn-only: continuing despite violations
rc=0
```

つまり §6 注意が警告する「付け替えだけ先に入れると CI が赤になる」順序問題は**そもそも発生しない**
（`.github/workflows/sync-plugin-plangate.yml:73` は `--warn-only`）。順序制御を書いた動機自体が誤った前提に立っている。

**推奨対応**: §6 手順 3 に「**skill 数と openai.yaml 数の一致を assert する presence 検査を追加する**」を明記し、
「強くなる」の根拠を「対象を替える」から「**欠落検出を新設する**」へ差し替える。
§6 注意 L321 と §7 S-1 の「即 FAIL」記述を実測（silently skip / `--warn-only` で rc=0）に是正する。
なお副産物として、**配布物に未検出の実 violation が 1 件ある**（`diff-audit` short_description 66 文字）。

---

### R-002 — `major` — drift 4 件の「向き」が未判定で、1 件は派生側が新しく内容が消える

**観点**: 保守性 / 安全性
**該当**: F-8（L21）、§1.3（L72-84）、§6 比較表「#956 との関係」（L291）、§6 推奨理由 3（L301）、§6 実装スケッチ（L310-319）

doc は drift 4 件を **「派生コピーは放っておくと腐る」という一方向の物語**として提示し
（F-8 / §1.3）、(A′) で「drift（現在 4 件）も構造的に消える」（L301）と結論している。
**4 件それぞれの向きは一度も判定されていない。** 実測すると **1 件は逆向き**である。

```console
$ sh <scratch>/drift.sh <worktree>
DIFF ai-dev-exec (4 行)
DIFF ai-loop-cycle (22 行)
DIFF local-exec-handoff (4 行)
DIFF plan-review-gate (37 行)
differing=4
rc=0
```

各件の向き（最終更新コミット日 + 内容）:

| skill | `.agents`（正本） | `.codex`（派生） | 新しい側 | (A′) untrack の影響 |
|---|---|---|---|---|
| `ai-dev-exec` | `7621c3a` 2026-08-13 | `1bb5bad` 2026-08-02 | **`.agents`** | なし（派生が stale。#1078 の是正が正本のみに入っている） |
| `ai-loop-cycle` | `721edcb` 2026-07-20 | `0050ece` 2026-07-11 | **`.agents`** | なし |
| `local-exec-handoff` | `7621c3a` 2026-08-13 | `1bb5bad` 2026-08-02 | **`.agents`** | なし |
| **`plan-review-gate`** | `b86a649` **2026-05-24**（60 行） | `d144ac4` **2026-06-22**（96 行） | **`.codex`** | **36 行が skill から消える** |

`plan-review-gate` の差分は `.codex` 側にのみ存在する 1 節
**「C-1 追加品質ゲート: Plan 実行可能性」**（Task Sizing Rules / No Placeholders Rule / mode 別判定）である。

```console
$ grep -rl "No Placeholders Rule" --exclude-dir=.git .
.codex/skills/plan-review-gate/SKILL.md      # ← skill としてはここだけ
docs/working/templates/review-self.md
docs/working/TASK-{0871,0873,0877,0914,0917,0970,0981,1012,1036,1045}/review-self.md
```

**緩和要因（severity を critical に上げなかった理由）**:

- 同等内容は `docs/working/templates/review-self.md` の **C1-SUP-PLAN-01 / C1-SUP-PLAN-02**（#581 由来）として存在する
  → repo 全体からの知識喪失ではない。
- 配布物 `plugin/plangate/skills/plan-review-gate/SKILL.md` は **60 行版**（= `.agents` と同じ）
  → 導入先ユーザーはもともとこの節を持っていない。回帰ではない。

それでも、**「腐った派生を捨てるだけ」という前提で untrack を実行すると、正本が持っていない 36 行を無自覚に破棄する**。
§6 実装スケッチ（手順 1〜8）には reconcile 手順が存在しない。

**推奨対応**: §1.3 に**向きの判定列**を追加し、F-8 の一方向な結論を「3 件は派生が stale / **1 件は派生が新しい**」に是正する。
§6 実装スケッチの手順 1（`git rm -r --cached`）の**前**に
「**`plan-review-gate` の 36 行を `.agents/skills` へ取り込む（または review-self テンプレートで足りると判断した根拠を残す）**」を追加する。
H-2（untrack の名指し承認）にもこの前提条件を明記する。

---

### R-003 — `minor` — 「全 48 ファイルを分類した」が実際は 39/48 しか表に無い

**観点**: 保守性（監査可能性）
**該当**: §4 冒頭（L221）「全ヒットを…分類した（全 48 ファイル）」

件数 **48 は完全に再現した**（自己ヒット 2 件を除外して 48）:

```console
$ grep -rl "\.codex/skills" --exclude-dir=.git . | wc -l
      50
$ grep -rl "\.codex/skills" --exclude-dir=.git . | grep -v "^\./\.codex/skills/" | wc -l
      48
```

しかし §4.1〜4.3 のどの表にも現れないファイルが **9 件**ある（さらに 2 件は §2/§3 で言及のみ・§4 の表には不在）:

| ファイル | 参照内容 | 独立判定 |
|---|---|---|
| `.agents/skills/acceptance-review/SKILL.md:188` | 導入先の参照解決に関する散文 | 壊れない |
| `.agents/skills/diff-audit/SKILL.md:330` | 同上 | 壊れない |
| `.claude/skills/acceptance-review/SKILL.md` | 同上 | 壊れない |
| `.claude/skills/diff-audit/SKILL.md` | 同上 | 壊れない |
| `plugin/plangate/skills/acceptance-review/SKILL.md` | 同上 | 壊れない |
| `plugin/plangate/skills/diff-audit/SKILL.md` | 同上 | 壊れない |
| `scripts/apply-diff-audit-rename.sh:13` | 一回限りの rename script のコメント | 壊れない |
| `scripts/apply-subagent-team-design-rename.sh:13` | 同上 | 壊れない |
| `docs/changelog.md:113,504,506` | 履歴 | 壊れない |
| （§4 表外・他節で言及）`install.sh:231` | 導入先での生成先 | §2.1/§3.1 で言及 |
| （同）`plugin/plangate/scripts/install-plangate-skills.sh` | 配布経路本体 | §3.1 で言及 |

**9 件すべてを独立に確認した結果、破壊されるものは無く、§4 の結論
「壊れるのは上流 repo 内部の 2 経路のみ」は維持される。** よって minor に留める。
ただし「全数」を掲げた表の網羅率は 39/48 であり、後続が §4 の表を漏れなき一覧として使うと取りこぼす。

**推奨対応**: §4 に「影響なし（散文・履歴のみ）」の行を 1 つ足して 9 件を明示的に収容し、
`install.sh` / `plugin/plangate/scripts/install-plangate-skills.sh` を §4 の表にも再掲する。

---

### R-004 — `minor` — §3.1 の install 経路記述が `openai.yaml` の「再生成」を落としている

**観点**: 可読性 / 保守性
**該当**: §3.1 の表（L198-201）、§7 S-1（L329）

§3.1 は `plugin/plangate/scripts/install-plangate-skills.sh` を
「source = `$PLUGIN_DIR/skills` → target へコピー」とだけ記述している。
実際にはこのスクリプトは **`agents/` を同期対象から除外し、target 側で `openai.yaml` を毎回生成し直す**:

```sh
_is_managed_subdir() {           # agents/assets は resource 同期の対象外
  case "$1" in agents|assets) return 0 ;; *) return 1 ;; esac
}
...
mkdir -p "$dst/agents"
cat > "$dst/agents/openai.yaml" << YAML     # ← 生成。source の openai.yaml は読まれない
```

帰結: **`install.sh --codex` 経路では配布物側の `openai.yaml` は一切消費されない**。
したがって §7 S-1 の「4 件欠落」が実害を持つのは
`.codex-plugin/plugin.json` の `"skills": "./skills/"` を使う **marketplace 経路に限られる**。
S-1 の重大性評価と R-001 の是正設計（どこに presence 検査を置くか）に直結する区別なので、明示すべき。

**推奨対応**: §3.1 の表に「`agents/openai.yaml` は target 側で再生成（source の値は使われない）」を注記し、
§7 S-1 に「実害は marketplace 経路」と scope を書く。

---

### R-005 — `info` — 現行の既定 target は既に 8 violations（CI が緑なのは `--warn-only` のため）

**観点**: 保守性
**該当**: §4.1（L228）、§6 手順 3

doc は既定 target が今は健全である前提で書かれているが、実測では既に違反がある:

```console
$ sh scripts/check-codex-skill-spec.sh ; echo rc=$?
[spec-check] Checked 39 skills in <worktree>/.codex/skills
[spec-check] VIOLATIONS (8):   # short_description too long × 8
rc=1
```

CI（`sync-plugin-plangate.yml:73`）が緑なのは `--warn-only` を付けているからである。
付け替え前後を比較するときの baseline としてこの数値を §2/§6 に残しておくと、
「付け替えたら violation が 8 → 1 に減った＝良くなった」という**誤った読み方を防げる**
（実際は対象集合が変わっただけ）。

**推奨対応**: §6 に付け替え前後の baseline（39 skills / 8 violations → 35 skills / 1 violation）を併記する。

---

## 3. 反証を試みて棄却した指摘候補

| 候補 | 棄却理由（実測） |
|---|---|
| §2.2 の `### Skill roots` / `r0`〜`r3` は `codex debug prompt-input` の実出力ではなく著者の要約ではないか | **棄却**。最小 fixture では compact 形式で出力されず一度は疑ったが、実 repo に対して実行すると `### Skill roots` と `r0`〜`r3` ラベルが**そのまま出力される**ことを確認（下記 §4 の repo probe）。doc の引用は忠実 |
| `CODEX_HOME` 隔離でも r0 が出るのは `scripts/codex-local.sh` / `.codex/config.toml` / 環境変数の副作用ではないか | **棄却**。`config.toml` も script も plugin も存在しない **bare fixture**（scratchpad 配下）に `CODEX_HOME=<scratch>` を与えて再現。`env \| grep -i codex` でも `CODEX_HOME` の漏れは無し（`CODEX_COMPANION_*` のみ）。親ディレクトリにも `.codex/skills` は無い |
| 案 (A′) は導入先ユーザーの skill 可用性を壊すのではないか | **棄却**。`install.sh:229-241` → `plugin/plangate/scripts/install-plangate-skills.sh`（source = `$PLUGIN_DIR/skills`）を実読で追跡。上流 repo の `.codex/skills` は配布経路に登場しない。marketplace 経路も `plugin/plangate/.codex-plugin/plugin.json` の `"skills": "./skills/"` を見る。**F-6 は成立** |
| doc は §6 手順 3 の順序問題を認識していないのではないか | **棄却**。L321 の注意書きと H-5 で認識・明記されている。ただし**その理由付けが誤り**なので R-001 として別に立てた |
| §4「48 ファイル」の件数自体が誤りではないか | **棄却**。独立 grep で 50 − 自己ヒット 2 = **48** が完全一致 |

---

## 4. 実行した検証コマンドと exit code

| # | コマンド | rc | 結果 |
|---|---|---|---|
| V-1 | `grep -rl "\.codex/skills" --exclude-dir=.git . \| wc -l` | 0 | 50（自己ヒット 2 を除き **48** = doc 一致） |
| V-2 | `sh <scratch>/drift.sh <worktree>` | 0 | `differing=4`、skill 名 4 件とも doc 一致 |
| V-3 | `git log -1 --format='%h %ad' --date=short -- .agents/skills/<n>/SKILL.md` ×4 / 同 `.codex` ×4 | 0 | 向き判定（R-002 の表） |
| V-4 | `sh <scratch>/probe.sh`（bare fixture + 隔離 `CODEX_HOME`、`codex debug prompt-input`） | 0 | before: `probe-a`×2 + `probe-c` / after(`.codex/skills` 削除): `probe-a`×1 → **§2.3 再現** |
| V-5 | `(cd <worktree> && CODEX_HOME=<scratch> codex debug prompt-input)` | 0 | roots = r0 `<wt>/.codex/skills` / r1 `~/.agents/skills` / r2 `<scratch>/…/.system` / r3 `<wt>/.agents/skills` → **§2.2 再現** |
| V-6 | `python3 <scratch>/count.py` | 0 | total **115** / unique **75** / duplicated names **39** / per-root `{r0:39, r1:32, r2:5, r3:39}` / combos `{(r0,r3):38, (r0,r2,r3):1}` → **F-4 完全一致** |
| V-7 | `sh scripts/check-codex-skill-spec.sh --target plugin/plangate/skills` | **1** | Checked **35**、violation は `diff-audit` の 1 件のみ（欠落 4 件は未報告）→ **R-001** |
| V-8 | `sh scripts/check-codex-skill-spec.sh --warn-only --target plugin/plangate/skills` | **0** | 「CI が赤になる」は不成立 → **R-001** |
| V-9 | `sh scripts/check-codex-skill-spec.sh`（既定 target） | **1** | Checked **39**、violations **8** → **R-005** |
| V-10 | `wc -l < .codex/config.toml` / `grep -n "skill" .codex/config.toml` | 0 | **105 行**、skill root を設定するキーは 0（`[agents.skill_designer]` とコメントのみ）→ **§2.1 再現** |
| V-11 | `find plugin/plangate/skills -maxdepth 3 -name openai.yaml \| wc -l` / `-name SKILL.md` | 0 | **35 / 39** → §7 S-1 の件数は再現 |
| V-12 | `sed -n '65,80p' .github/workflows/sync-plugin-plangate.yml` | 0 | `run: sh scripts/check-codex-skill-spec.sh --warn-only` を確認 → §4.1 の参照は正確 |
| V-13 | `grep -rl "No Placeholders Rule" --exclude-dir=.git .` | 0 | skill としては `.codex/skills/plan-review-gate` のみ → **R-002** |

> 本レビューでは **repo ファイルを一切変更していない**（追加したのは本ファイルのみ）。
> fixture・`CODEX_HOME`・スクリプトはすべて scratchpad 配下に作成した。
> `tests/extras/ta-65-*` および `scripts/hooks/check-plan-hash.sh` には触れていない（#1101 と競合回避）。
> `sh tests/run-tests.sh` の baseline は**本レビューでも未取得**（doc の「未実施（正直な記録）」の姿勢は妥当と評価する。AC-6 は exec 開始時に単独実行で再測定すべき）。

---

## 5. doc の良かった点（維持すべき）

- **合成 fixture による決定的検証**（§2.3）。「消したら消える」を repo 非破壊で示しており、因果の立証として質が高い。独立に再現できた。
- **§2.4 の反証の扱い**。`totally_bogus_key_xyz=1` を対照に置き、「候補キーが無効」と「knob が存在しない」を**区別して結論を弱めている**のは正しい態度（#1078 と同型の false green を自ら回避している）。
- **§9「未実施（正直な記録）」**。run-tests baseline を取れなかったことを「rc=0 だったとは書けない」と明記している。実測していないものを書かない規律が守られている。
- **導入先影響の確認を最重要として先に置いた**構成（§3）。推奨案の崩れどころを自分で特定できている。

---

## 6. 監査表

| R-NNN | status | reflected_in | notes |
|---|---|---|---|
| R-001 | **reflected** | `docs/1086-dual-root-investigation` の反映コミット（`Refs: R-001`） | major。**accepted（棄却なし）**。著者が `:35` の silently skip / Checked 35 / `--warn-only` rc=0 を独立再実測。§6 推奨理由 5 を差し替え表へ全面書き換え、手順 0′（presence 検査新設）を追加、「即 FAIL」「CI が赤」を除去し baseline 表で置換 |
| R-002 | **reflected** | 同上（`Refs: R-002`） | major。**accepted**。§1.3 に向き判定表を新設（`plan-review-gate` = `.codex` 96 行 / `.agents` 60 行）。§6 に手順 0（reconcile）を untrack の前に必須化、H-2 に前提条件、H-7 を新設 |
| R-003 | **reflected** | 同上（`Refs: R-003`） | minor。**accepted**。§4.4 を新設し 9 件を収容（48 件を 4 表で完全収容）。結論は維持 |
| R-004 | **reflected** | 同上（`Refs: R-004`） | minor。**accepted**。§3.1 に openai.yaml 再生成を注記。S-1 の scope を marketplace 経路に限定（marketplace 側の消費は未確認と併記） |
| R-005 | **reflected** | 同上（`Refs: R-005`） | info。**accepted**。§6 に付け替え前後 baseline（39/8 → 35/1）を併記し「改善ではない」と明記 |

### 反映結果サマリ（著者記入 / 2026-08-15）

- **棄却: 0 件**。5 件すべてを著者が一次実測で再現し、いずれも doc 側の記述が誤っていた。
- **推奨案は (A′) のまま維持**。R-001 / R-002 が崩したのは「副作用の回収手段」であり「(A′) を選ぶ根拠」ではない。
  F-6（導入先影響ゼロ）はレビューアも独立に再現しており無傷。回収手段を
  「対象の付け替え」→「**欠落検出の新設**」、および「**untrack 前の reconcile**」へ差し替えて (A′) の枠内で閉じた。
- **前提条件が 2 件増えた**: ① #1109 の presence 検査を先に入れる ② `plan-review-gate` の 36 行を reconcile してから untrack する。
- disposition の詳細は [`investigation.md` §10](./investigation.md) を参照。

> 反映は **1 回だけ確定**（`.claude/rules/working-context.md` の C-2 差分管理に従う）。
> 反映コミットには `Refs: R-001` 等を付す。
