# EXECUTION PLAN — TASK-1109 (#1109)

> `scripts/check-codex-skill-spec.sh` の「**見ていないのに緑**」を潰す。
> 欠落 `agents/openai.yaml` を violation にし、配布物 `plugin/plangate/skills` を
> 検査対象へ加え、`--warn-only` の rc 契約を実挙動と一致させる。
> **`.github/workflows/*` は HO のため AI は編集しない**（patch 提示まで）。

## Goal

`sh scripts/check-codex-skill-spec.sh` が **rc=0 を返したとき「検査した結果、問題が無い」**
と言える状態にする。現状の rc=0 は「openai.yaml がある skill だけを見た」または
「`--warn-only` で握り潰した」のいずれかであり、検出器として成立していない。

## 調査結果（実測）

| ID | 事実 | 根拠 |
|----|------|------|
| **F-1** | 旧実装は `if not os.path.exists(yaml_path): continue` で欠落を silently skip | ソース読解 + 実測（`--target plugin/plangate/skills` → Checked 35 / 欠落 4 件は未報告） |
| **F-2** | 配布物 `plugin/plangate/skills` で `agents/openai.yaml` が **4 件欠落**（`ai-loop-cycle` / `breakdown-gate` / `ref-integrity-scan` / `subagent-delegation-brief`） | `find plugin/plangate/skills -path '*/agents/openai.yaml'` の集合と `SKILL.md` 集合の差 |
| **F-3** | `plugin/plangate/scripts/install-plangate-skills.sh` は `agents` を bundled resource 同期の**対象外**（`_is_managed_subdir`）とし、**target 側で `openai.yaml` を SKILL.md frontmatter から再生成**する | ソース読解 + 実測（`--target <tmp>` 展開物を spec check → **Checked 39 / All PASS**） |
| **F-4** | したがって **欠落 4 件の実害は install 経路には無く、配布物をそのまま読む marketplace / plugin cache 経路に限定される** | F-3 の実測。severity = **major → minor 寄り**（配布物のメタデータ欠落） |
| **F-5** | `sync-plugin-plangate.sh` は `plugin/plangate/skills/*/agents/openai.yaml` を**同期対象にしていない**（`SKILL.md` と `references/` のみ） | ソース読解。配布物の openai.yaml は手書き資産であり drift は構造的に発生する |
| **F-6** | `.codex/skills` の 8 violations は全て `short_description too long`。**`install-plangate-skills-to-codex.sh --force` の再生成で全て解消**する（旧版が 64 文字切り詰めロジック導入前に生成した stale 資産） | 実測（再生成後 `Checked 39 / All PASS`） |
| **F-7** | 呼び出し元は `origin/main` 時点で **`.github/workflows/sync-plugin-plangate.yml`（`--warn-only`）と `tests/extras/ta-30-install-skills.sh` TC-05（`--target <tmp>`）の 2 箇所のみ**。**本 PR 後は `tests/extras/ta-68-*.sh` が 3 経路目**になり、`.github/workflows/test.yml`（`on: pull_request` → `run-tests.sh`）経由で **PR 段階のブロック経路**を担う（`Refs: R-006`） | `grep -rn "check-codex-skill-spec"`（他は CHANGELOG / docs / evidence ログ） |
| **F-9** | `sync` job は `if: github.event_name != 'pull_request'` 配下にあるため、`--warn-only` を外しても **その経路の強制力は post-merge のみ**。PR 段階の強制は F-7 の `ta-68` × `test.yml` が担う（`Refs: R-007`） | workflow 読解 |
| **F-10** | `check_fields` の `icon_small` / `icon_large` は部分文字列一致で、**値のパス実在は見ない**。配布物 root に `assets/` は無いが `install-plangate-skills.sh` が install 時に materialize するため install 経路では実在する。**marketplace 直読み経路での解決可否は本 PBI では判定不能**（`Refs: R-005`） | `find plugin/plangate/skills -name plangate-small.svg` → 0 件 / installer 読解 |
| **F-8** | `.codex/skills` は `.agents/skills` に対して **SKILL.md が 4 件 stale**（`ai-dev-exec` / `ai-loop-cycle` / `local-exec-handoff` / `plan-review-gate`） | 再生成時の diff。**本 PBI では触らない**（#1086 領域）。スコープ外の報告事項 |

## Constraints / Non-goals

### Constraints

- **`.github/workflows/*.yml` は HO パス — AI は編集しない**（patch 提示まで）
- **`.codex/skills` の削除・`git rm` を行わない**（#1086 の領域）
- **絶対件数（39 / 35 / 8）を契約値にしない** — 集合の同値照合で書く
- **行番号アンカーを使わない** — 関数名・記号で参照する（#1089 教訓）
- **fail-closed 方向を緩めない** — `--warn-only` の rc=0 は既存契約であり、
  違反を握り潰す新しい経路を増やさない
- `sh tests/run-tests.sh`（フルスイート）は実行しない（`ta-61` の入れ子再実行により
  並走ワーカーが完走できないため）。個別 extras の直接実行で検証する

### Non-goals

- `.codex/skills` の untrack 判断（#1086）
- `commands/*.md` の Skill 登録問題（#1081）
- `--warn-only` 除去の実適用（Human-owned）
- 配布物 openai.yaml の**生成**を sync 経路へ組み込むこと（follow-up）
- `brand_color` / `display_name` の新規 field 検査追加（現行検査項目を変えない）

## Approach Overview

### 1. 「見ていない」を構造的に消す（presence の同値照合）

target 直下の
**「`SKILL.md` を持つディレクトリ」集合** と **「`agents/openai.yaml` を持つディレクトリ」集合**
を比較し、差分を双方向で violation にする:

- `SKILL.md` あり / `openai.yaml` なし → `agents/openai.yaml missing`
- `openai.yaml` あり / `SKILL.md` なし → `openai.yaml exists but SKILL.md missing`（逆方向の穴）

件数（39/35）は出力にしか使わず、**判定はすべて集合演算**で行う。

### 2. 検査対象外にしたものを必ず出力する

dotfile / 非ディレクトリ（例: `plugin/plangate/skills/README.md`）/ どちらのファイルも
持たないディレクトリは検査対象外だが、**`ignored=N` と 1 件ごとの理由**を出力する。
「skip したことが出力に出ない」状態を作らない。

### 3. 既定 target を 2 root にする

既定 = `.codex/skills` + `plugin/plangate/skills`。`--target` を 1 回でも指定したら
既定を置き換える（複数指定可）。既存呼び出し元 `ta-30` は `--target <tmp>` なので影響なし。

### 4. target 不在は既定・明示を問わず violation にする（v2 / `Refs: R-001 R-003`）

> **v1 では「既定 target の不在は violation にしない」設計だった。V-3 で棄却された。**

| 状況 | v1（棄却） | **v2（採用）** |
|------|-----------|--------------|
| 明示 `--target` が不在 | violation | **violation** |
| 既定 target が不在 | 理由つき SKIPPED（緑） | **violation** |
| 1 つも検査できなかった | violation | violation（belt） |

v1 の狙いは「#1086 で `.codex/skills` が消えても検出器が壊れない」ことだったが、
実測（レビューア変異 M-A）で **片方の root が消えると検査母数が 78 → 39 に半減しても
rc=0 / `ta-68` 12/12 PASS のまま**であることが示された。これは #1109 が潰そうとしている
「見ていないのに緑」の**同じクラスの再生産**であり、しかも #1086 の (A′) 承認により
**確実に起きる未来**だった。「1 つも検査できなければ violation」だけでは
**片方消失を捕まえられない**（もう片方が生きていれば `inspected_targets>=1`）。

**v2 の設計 = 既定 root を「宣言」にして、宣言と実体の不一致を violation にする。**

- `check-codex-skill-spec.sh` の `DEFAULT_TARGETS` が既定 root の**宣言（正本）**
- 宣言した root が存在しなければ **violation**（fail-closed）
- したがって `explicit` は **メッセージの文言にしか使わない**。不在判定は既定・明示で共通
  （分岐が消えたので「片方の経路だけ穴が空く」構造そのものが無くなる）

#### #1086 で `.codex/skills` を untrack した後の挙動（いま決める）

**`DEFAULT_TARGETS` の宣言から `.codex/skills` の 1 行を削除する。**

- 削除しない限り CI は赤くなる → **気づかないうちに検査範囲が半減することはない**
- 削除は 1 行の**意識的なコード変更**として diff とレビューに必ず現れる
- スクリプト冒頭の宣言ブロックにこの手順をコメントで明記した（#1086 の担当者が読む場所）

`os.listdir` の前に `os.path.isdir` で判定するため **traceback は出ない**。
予期せぬ例外も try/except で violation 化する（traceback を rc の一次情報にしない）。

### 4-bis. 既定経路（`explicit=False`）を負側 TC で押さえる（`Refs: R-003`）

v1 の負側 TC は**すべて `--target` 経由**で、CI が実際に通る既定経路の検出力が
**ゼロ**だった（変異 M-B が 12/12 PASS で生存）。

テスト専用 env の seam は増やさない。スクリプトは `REPO_ROOT` を
**自分の置かれた場所**（`dirname $0/..`）から求めるため、**fixture repo へ
スクリプトを複製するだけ**で既定経路をそのまま実行できる（新しい API 面はゼロ）。
これで TC-13（正側）/ TC-14（欠落検出）/ TC-15（宣言 root 不在）を既定経路で押さえた。

### 5. rc 方針を 1 箇所に集約する（変異検出力の確保）

python 側は「violation があれば必ず `exit 1`」だけを担い、
**`--warn-only` による rc=0 化は shell 側の 1 箇所だけ**が行う。

> 初版は python と shell の両方に `--warn-only` 分岐を置いたが、
> **M-2 変異（shell 側の rc=0 保証を削除）が python 側に吸収されて生き残った**。
> 二重実装は「片方を壊しても他方が隠す」構造であり、退行を検出できない。
> 契約の実装点を 1 つにして、壊せば必ず TC が落ちるようにした。

### 6. 既存 violation を解消してから `--warn-only` を外す（適用順序）

**この順序を守らないと CI が赤で固定される。**

1. （本 PR）`.codex/skills` の 8 violations を `install-plangate-skills-to-codex.sh --force`
   の再生成で解消
2. （本 PR）配布物の欠落 4 件 + `diff-audit` の 66 文字 short_description を解消
3. （本 PR）検出器を強化し、既定 2 root で `rc=0` を実測
4. （**Human-owned / merge 後**）`docs/working/TASK-1109/patches/0001-*.patch` を適用して
   workflow から `--warn-only` を外す

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|-----|
| **S-1** | 呼び出し元の全数確認 | F-7 | agent | 低 | `grep -rn "check-codex-skill-spec"` の非 docs ヒットが 2 経路のみ |
| **S-2** | `install-plangate-skills.sh` の `agents/` 扱いを実読で確認 | F-3 / F-4 | agent | 低 | 一時 target への展開物が spec check を **PASS**（欠落 4 件が再生成される） |
| **S-3** | `.codex/skills` の 8 violations を再生成で解消 | 8 ファイル | agent | 中 | `sh scripts/check-codex-skill-spec.sh --target .codex/skills` が rc=0。**SKILL.md の stale 差分は revert してスコープ外に出す** |
| **S-4** | 配布物の欠落 4 件 + `diff-audit` を解消 | 5 ファイル | agent | 低 | 既存の手書き英語 description のスタイルを踏襲（25–64 文字） |
| **S-5** | 検出器の実装（§1〜§5） | `scripts/check-codex-skill-spec.sh` | agent | 中 | 既定 2 root で rc=0 / 明示不在で rc=1 / `--warn-only` 不在で rc=0 |
| **S-6** | 回帰テスト新設 | `tests/extras/ta-68-skill-spec-presence.sh` | agent | 低 | standalone 12 TC 全 PASS |
| **S-7** | 変異注入（call site）で検出力を実証 | `evidence/mutation/` | agent | 低 | M-1 / M-2 / M-3 が **それぞれ TC を落とす**。復元後 全 PASS |
| **S-8** | workflow patch の作成と**実適用テスト** | `patches/0001-*.patch` | agent | 低 | 隔離コピーへ `git apply` して結果ファイルを確認（`--check` 単独で終わらせない） |
| **S-9** | 既存呼び出し元の回帰確認 | `evidence/test-runs/` | agent | 低 | `ta-30` 9 TC 全 PASS / `sync-plugin-plangate.sh --dry-run` が no changes |

## Files / Components to Touch

| ファイル | 変更 | HO |
|---------|------|----|
| `scripts/check-codex-skill-spec.sh` | 検出器本体 | 外（rc=0 実測済） |
| `tests/extras/ta-68-skill-spec-presence.sh` | 新規 12 TC | 外 |
| `plugin/plangate/skills/{ai-loop-cycle,breakdown-gate,ref-integrity-scan,subagent-delegation-brief}/agents/openai.yaml` | 新規 4 件 | 外 |
| `plugin/plangate/skills/diff-audit/agents/openai.yaml` | 66 → 50 文字 | 外 |
| `.codex/skills/*/agents/openai.yaml`（8 件） | 再生成 | 外 |
| `docs/working/TASK-1109/**` | Plan Package / evidence / patch | 外 |
| **`.github/workflows/sync-plugin-plangate.yml`** | **patch 提示のみ（AI 適用不可）** | **HO** |

> `ta-67` は TASK-1093 が予約済みのため **`ta-68`** を使う。

## Testing Strategy

- **Unit / Integration**: `tests/extras/ta-68-skill-spec-presence.sh`（12 TC。
  正側 2 / 負側 6 / 出力契約 2 / 同値照合 2）
- **Mutation**: call site を壊す 3 変異（M-1 presence / M-2 `--warn-only` rc / M-3 target 不在ガード）
  で TC の検出力を実証する
- **回帰**: `ta-30`（既存呼び出し元）/ `sync-plugin-plangate.sh --dry-run` /
  `check-skill-frontmatter.py`
- **フルスイート**: 本ワーカーは実行しない（オーケストレータが最後に 1 本走らせる）

## Risks & Mitigations

| リスク | 対策 |
|--------|------|
| 検査強化で CI が赤で固定される | 適用順序を明記（§6）。`--warn-only` 除去は既存 violation 解消の**後** |
| #1086 で `.codex/skills` が消えると既定実行が赤になる | **意図した挙動**（§4）。宣言から 1 行削除する手順をスクリプト冒頭に明記。TC-15 が宣言と実体の不一致を検出する |
| 二重実装で変異が生き残る | rc 方針の実装点を 1 箇所に集約（§5）。M-2 で実証 |
| 絶対件数を書くと将来の skill 追加で無関係 PR が落ちる | 判定はすべて集合演算。件数は出力のみ |
| `.codex/skills` 再生成が SKILL.md の stale 差分を巻き込む | openai.yaml 以外の差分は revert し、スコープ外の報告事項として残す（F-8） |

## Questions / Unknowns

- **Q-1**: 配布物 openai.yaml の**生成**を `sync-plugin-plangate.sh` に組み込むか。
  組み込めば drift が構造的に消えるが、手書きの英語 description（配布品質）が
  frontmatter 由来の切り詰め文字列に置き換わる。**Human 判断事項**（follow-up issue 候補）
- **Q-2**: `.codex/skills` の SKILL.md stale 4 件（F-8）をどこで直すか（#1086 と同時か）
- **Q-3**: `brand_color` は `plugin/plangate/README.md` の checklist と CHANGELOG では
  「検査対象」と書かれているが、実装は検査していない。doc 側を直すか実装側を足すか
- **Q-4**（`Refs: R-005`）: `icon_small` / `icon_large` の**値のパス実在検査**を足すか。
  install 経路では materialize されるため実害は確認できていないが、
  配布物 root を「marketplace がそのまま読む実体」と定義した以上、
  marketplace 直読み経路での解決可否は**判定不能**のまま残っている。follow-up issue 候補

## V-3 REJECT の反映（1 回確定 / `Refs: R-001 R-002 R-003 R-004 R-005 R-006 R-007`）

外部レビュー（V-3 相当）の判定は **REJECT**（critical 0 / major 3 / minor 2 / info 2）。
指摘の正本は [`review-external.md`](./review-external.md)、disposition は同ファイルの監査表。
本 plan への反映は §4 / §4-bis / F-7 / F-9 / F-10 / Risks / Q-4 の 1 回確定。

## Mode 判定

**モード**: **high-risk**

**判定根拠**:

- 変更ファイル数: 実装系 14 件（検出器 1 + テスト 1 + openai.yaml 12）→ **高**（6-15）
- 受入基準数: 8 → **高**（6-10）
- 変更種別: CI ゲートの検出器強化（fail-closed 方向の挙動変更）→ **高**
- リスク: 誤ると **main の CI が赤で固定**される。逆に緩めると false green が残る → **高**
- 影響範囲: CI job + 配布物 + repo 内 skill root の 3 レイヤー → **高**
- **承認境界周辺**: 完了には **HO パス（`.github/workflows/*.yml`）の変更が必要**
  （本 PR は patch 提示のみだが、変更の完成形が HO に到達する）
  → mode-classification「承認境界周辺の変更 → 最低でも高」を安全側で適用
- **最終判定**: **high-risk** / **`lite_eligible=false`**（HO 隣接につき強制）/
  **C-3 は同期・人間必須**（autonomous APPROVE 不可）

## 適用順序（Human 向けサマリ）

1. 本 PR を C-4 で承認・merge（検出器 + 既存 violation 解消がセット）
2. merge 後の main で `sh scripts/check-codex-skill-spec.sh` が rc=0 を返すことを確認
3. `git apply docs/working/TASK-1109/patches/0001-drop-warn-only-from-sync-workflow.patch`
4. 別 PR として `--warn-only` 除去を merge

> 2 を飛ばして 3 を先に当てると、sync workflow が恒久的に赤になる。
