# PBI INPUT PACKAGE — TASK-1093 (#1093)

> 出典: [issue #1093](https://github.com/s977043/plangate/issues/1093)
> `bug` / `priority:P1` / milestone v8.20.0

## Context / Why

`scripts/release-prep.sh --check` の readiness 検査に含まれる
**`check_pending_applies()` が「`--dry-run` の stdout に `[dry-run]` という
リテラルが含まれるか」だけで「適用待ち」を判定している**。

判定対象が「実態（適用済みか否か）」ではなく「たまたまその文字列を印字するか」
であるため、**緑も赤も信用できない**。本リポジトリで繰り返し検出されている
**「検査が無い」ではなく「検査はあるが実態と違うものを測っている」クラス**
（#1085 / #1087 / #1090 と同型）。

実害は 2 方向:

1. **リリースを止めるべき唯一の項目が検出器から不可視**（穴 (d)）
2. **報告された「適用待ち」に従って適用すると退行する**項目が混ざる（穴 (b)）

### 実測で確定した 4 つの穴（本 worktree / HEAD=`0385457` / 34 本全数）

証跡: [`evidence/apply-dryrun-matrix.txt`](evidence/apply-dryrun-matrix.txt)
（再現: `sh docs/working/TASK-1093/evidence/measure-apply-dryrun.sh <repo_root>`）

| ID | 穴 | 実測根拠 |
|----|----|---------|
| **(d)** | **検出漏れ（最重要）**: 未適用でも `[dry-run]` を印字しない script が pending に現れない | `apply-rnnn-c4-extension.sh` は `working-context.md` / `review-principles.md` への **未適用の追記 diff を印字**するが `[dry-run]` ヒット **0** → **pending に現れない**。`apply-task-0130-working-context.sh` も同型（ヒット 0・DRY-RUN 差分を印字）。`apply-eh3-ho-always.sh`（#1089）は **未適用時に `WILL CHANGE` + unified diff を出すが `[dry-run]` を印字しない**設計（本 HEAD では既適用のため `nothing to do`） |
| **(b)** | **誤検出 + 適用すると退行** | `apply-ai-loop-workflow-command.sh` はヒット 1 → pending 報告されるが **差分が逆方向**（#1093 の実測）。`apply-task-0146-ehs23-wiring.sh` はヒット 1 だが **`rc=1`**、`bin/plangate` に `# EHS-2 (TASK-0146 / #527)` 実装済み＝**無条件ヘッダによる誤検出** |
| **(a)** | **fail-open** | `2>/dev/null \|\| true` で rc を捨てている。実測で **rc≠0 が 6 本**（`claude-md-v8180`=1 / `claude-md-v8190`=1 / `precompact-guard`=1 / `task-0128-p0-hardening`=1(Python traceback) / `task-0134-progress`=1(`grep: unrecognized option`) / `task-0141-eh2-strict`=1 / `task-0146`=1）。**ERROR がすべて「適用待ちなし」に化ける** |
| **(c)** | **環境依存** | 本 worktree は `.claude/settings.json` 未配置。`apply-precompact-guard.sh` → `ERROR: .claude/settings.json not found` (rc=1)、`apply-eh-git-destructive-guard.sh` → `[skip] ... example only`。**通常 checkout では pending 側に載る**＝同一コミットで結果が変わる |

補足: `apply-task-0134-progress.sh` は **引数解析を持たず `F="${1:-bin/plangate}"`**
のため `--dry-run` が**対象ファイル名として解釈**される（`grep: unrecognized
option`）。偶然 rc≠0 で非破壊だが、`--dry-run` の契約が script 側に無い証拠。

### NG-2「plugin キャッシュ未同期」も設計誤り

`check_plugin_cache_sync()` が呼ぶ `sync-plugin-installed.sh` の同期先は
**`${HOME}/.claude/plugins/` と `${HOME}/.codex/skills/`＝リポジトリ外**であり、
**スクリプト自身が「リリース後に」と明記**している。リリース**前**の READY 条件に
置くと、実行しても**旧 version のキャッシュを同期するだけ**で意味がない。

## What (Scope)

### In scope

- **`check_pending_applies()` の判定を「stdout の文字列一致」から実態ベースへ差し替える**
- **`sync-plugin-installed.sh` の検査を リリース前 READY 条件から外す**（リリース後手順へ移設）
- **`--dry-run` の出力契約を apply スクリプト側にも定める**（検出器が依存できる形の正本化）

### Out of scope

- **個々の apply スクリプトの中身の是正**（`apply-ai-loop-workflow-command.sh`
  の逆方向差分・`apply-task-0146-ehs23-wiring.sh` の無条件ヘッダ・
  `apply-task-0134-progress.sh` の引数解析欠落 は **別 issue**）
- `bin/plangate` / `.github/workflows/` / `scripts/hooks/*` の変更（**HO パス**）
- apply スクリプトの `--apply` を AI が実行すること（**Human-owned**）
- 承認境界の緩和

## 受入基準（issue 原文）

- **AC-1（検出漏れの解消 / 正の証跡）**: 未適用の apply スクリプトが pending
  として報告されることを、**`apply-eh3-ho-always.sh` を含む未適用の全スクリプト**で実証する
- **AC-2（負の対照 / 空振り検査でないこと）**: 適用済みのスクリプトが pending に
  現れないことを、**実際に適用済みの状態を作って**実証する
- **AC-3（誤検出の解消）**: `apply-task-0146-ehs23-wiring.sh` が pending に現れないことを実証する
- **AC-4（fail-open の解消）**: apply スクリプトが ERROR で終了したとき、
  「適用待ちなし」ではなく **「判定不能」として READY を阻む**ことを、意図的に ERROR を起こして実証する
- **AC-5（環境非依存）**: 通常 checkout と worktree で同じ結果になることを、両方で実行して示す
- **AC-6（リリース後手順の分離）**: `sync-plugin-installed.sh` が READY 条件から外れ、
  リリース後の手順として記載されている
- **AC-7**: `sh tests/run-tests.sh` が **rc=0**（baseline 維持。件数は着手時に再測定し、
  **絶対値を契約値にしない**）

> issue 明記: **受入基準に「検出ロジックを書き換えた」を使ってはいけない** —
> 実際に検出される / されないことの**証跡**を条件にすること。

## Notes from Refinement

- `check_pending_applies()` は **行番号ではなく関数名で参照する**
  （行番号アンカーは実装移動で stale 化する / #1089 の教訓）
- `scripts/release-prep.sh` は **HO 9 カテゴリのいずれにも該当しない**（非 HO）。
  ただし**リリースプロセス保護**に関わるため Mode 判定は安全側に倒す
- 他セッションが #1101 を `plangate-wt-1101` で作業中。
  **`tests/extras/ta-65-*` と `scripts/hooks/check-plan-hash.sh` には触れない**
- 現行検出器が pending と報告するのは（本 worktree 実測・matrix から機械導出）
  `ai-loop-workflow` / `quality-command-gate` / `reviewer-silence-gate` /
  `task-0123-patches` / `task-0129-schema` / `task-0129-wc` /
  `task-0146-ehs23-wiring` / `ui-v1-crossref` の **8 本**（うち 2 本は誤検出、
  かつ真に未適用の `rnnn-c4-extension` / `task-0130-working-context` は**含まれない**）

## Estimation Evidence

### Risks

| ID | リスク | 影響 |
|----|-------|------|
| R-1 | 実態判定を強化すると **既存の pending 8 本 + 新規検出分が一斉に NG 化**し、リリースが止まる | 高 |
| R-2 | 判定の知識を release-prep 側に複製すると、apply script 側と **silent に drift** する | 中 |
| R-3 | `--dry-run` 出力契約を 34 本全部に適用すると **Out of scope（中身の是正）に踏み込む** | 中 |
| R-4 | AC-1/AC-2 の実証に **「未適用状態」「適用済み状態」の両方の fixture** が要る。`apply-eh3-ho-always.sh` は **HEAD で既適用**（#1089 CLOSED）のため、未適用側は sandbox 合成が必要 | 中 |
| R-5 | AC-5（環境非依存）は `.claude/settings.json` が **untracked / 環境依存**であることが原因。判定スコープの定義を誤ると解消できない | 中 |

### Unknowns

| ID | 不明点 | 解消方法 |
|----|-------|---------|
| U-1 | 一斉 NG 化時に、既存 pending を「リリースブロッカー」とするか「既知の未適用」として明示 acknowledge するか | **Human 判断（C-3）**。plan では acknowledge 台帳方式を提案 |
| U-2 | 出力契約を既存 34 本へ後付け適用するか、新規 script のみに課すか | plan では **新規のみ強制 + 既存は台帳で橋渡し**を提案（Out of scope 尊重） |

### Assumptions

- `docs/ai/ho-change-workflow.md`（非 HO）が `--dry-run` 契約の正本置き場として妥当
- `tests/extras/ta-67-*.sh` が次の空き番号（`ta-65` は #1101 が使用中・`ta-66` 使用済み）
- `tests/run-tests.sh` は `tests/extras/` に置くだけで自動 source される（#170）
