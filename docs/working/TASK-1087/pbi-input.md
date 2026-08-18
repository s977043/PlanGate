# PBI INPUT PACKAGE — TASK-1087 (#1087)

## Context / Why

PlanGate を **plugin として配布する**方向へ進めるにあたり、
[#1144](https://github.com/s977043/PlanGate/issues/1144)（enforcement 層が 3 経路すべてで 0 件配布）
が中核課題として存在する。しかし **それを直す前に検知器を立てないと、
直したつもりが退行しても誰も気づかない**。

本リポジトリでは直近に同型が 2 件起きている:

| INC | 内容 |
|-----|------|
| **#1109** | 検査が `openai.yaml` 欠落を silently skip し、CI は `--warn-only` なので **既存 8 violations ごと常に緑**だった |
| **#1138** | #1118 の是正を PR #1122 が **再導入して退行**させた |

配布物検査は 3 本ある（`claude plugin validate` /
`scripts/check-skill-name-collisions.py` / `scripts/check-stale-skill-refs.py`）が、
**CI に 1 本も配線されておらず、うち 2 本は rc=1 のまま放置**されている。
rc=1 のまま配線すれば CI が即赤になるため、**まず rc=1 の中身を確定させ、
偽陽性なら検査側を実態に合わせる**必要がある。

### 2026-08-18 再実測（issue 記載の 2026-08-13 値を測り直した結果）

| 対象 | issue 記載 | 実測 | 差 |
|------|-----------|------|-----|
| `check-skill-name-collisions.py` | rc=1 / 46 件 | **rc=1 / 46 件** | 一致 |
| `check-stale-skill-refs.py` | rc=1 / **2 件** | **rc=1 / 7 件** | **不一致（5 件多い）** |
| `.github/workflows/` 内の 3 本への言及 | 0 件 | **0 件**（grep rc=1） | 一致 |

**stale は 2 件ではなく 7 件**。増分 5 件はすべて `.claude/settings.json` への参照で、
**このファイルは `.gitignore:14` で ignore されており、リポジトリには存在しない**
（各利用者がローカル生成する）。つまり **検査結果が実行環境に依存する**
（settings.json を持つ開発機と CI で rc が変わる）。issue 起票時は
settings.json が存在する環境で測られたと推定される。

### `check-skill-name-collisions.py` の既存配線（正確な射程 / 2026-08-18 実測）

`check-skill-name-collisions.py` は **`scripts/doctor_check.py` に配線済み**だが、
**`bin/plangate doctor --json` の経路からしか到達しない**。正確には:

| 事実 | 根拠（実測） |
|------|------------|
| `scripts/doctor_check.py` が本スクリプトをサブプロセス実行する | `grep -rn "check-skill-name-collisions" --include='*.py' .` → `scripts/doctor_check.py` に 3 ヒット（`check_skill_collisions()` 定義 / `script = REPO / "scripts" / ...` / not-found skip） |
| `bin/plangate` 自体には `collision` の文字列が無い | `grep -n "collision" bin/plangate` → 0 件。**`bin/plangate` は `doctor_check.py` へ総称的に委譲するだけ**（`grep -n "doctor_check" bin/plangate` → `--json` 分岐で `python3 "$py" --scope "$doctor_scope"`） |
| `--json` 経路では実際に検査が走る | `bin/plangate doctor --json` の `checks[]` に `skill/command/agent name collisions (#721)` が **level=warn** で存在 |
| **プレーンな `bin/plangate doctor` では走らない** | `bin/plangate doctor \| grep -ci collision` → **0** |
| 是正前は warn で 46 件を出し続けていた | `origin/main` 版のスクリプトを実行 → `rc=1` / `合計 46 件の name 多重定義を検出`。`doctor_check.py` は `ok = not (rc == 1)` としているため `ok=false` / `level=warn` |

つまり「CI 未配線」は正しいが、**doctor（`--json` 経路）には warn として配線済み**であり、
**「緑ではないが赤にもならない」**状態にあった。`level=warn` は doctor の失敗数に
計上されないため、46 件は誰も止めない。#1109 と同型のクラスである。

> **注意**: `bin/plangate` を grep しても `collision` は出ない（総称委譲のため）。
> 配線の有無は **`scripts/doctor_check.py` 側**、または
> `bin/plangate doctor --json` の実出力で確認すること。

## What (Scope)

### In scope

1. **46 件 / 7 件の全件分類**（正常 / 真の違反）を evidence として残す
2. `check-skill-name-collisions.py` の判定を実態に合わせる
   — repo-local ⇄ plugin export のミラーを「正常」と扱う。**ただし全部無視にしない**
3. `check-stale-skill-refs.py` の判定を実態に合わせる
   — 引用・記法説明・ignore 対象パスを参照と誤判定しない。**ただし真の stale は検出し続ける**
4. 変異注入で **検出力が残っていることを実証**する
5. **CI 配線 patch の提示**（`.github/workflows/*` は Hardening Override 対象。**AI は適用しない**）

### Out of scope

- `.claude/rules/hybrid-architecture.md` Rule 3 / Rule 4 の変更
  （**HO かつ正本**。検査を実態に合わせるのであって、規範を変えるのではない）
- `.codex/skills` の untrack（**#1086**）
- enforcement 層の配布そのもの（**#1144**）
- `bin/plangate` / `scripts/hooks/*.sh` / `.github/workflows/*` への **適用**（すべて HO）
- `scripts/check-approval-token-write.sh` / `tests/extras/ta-25-*`（別ワーカー作業中）

## 受入基準

| AC | 内容 |
|----|------|
| **AC-1** | 46 件の name 多重定義を 1 件ずつ「正常なミラー / 真の衝突」に分類し、evidence に全件記載する |
| **AC-2** | 7 件の stale 参照を 1 件ずつ「引用・記法説明・ignore 対象 / 真の stale 参照」に分類し、evidence に全件記載する |
| **AC-3** | `python3 scripts/check-skill-name-collisions.py` → **rc=0** |
| **AC-4** | `python3 scripts/check-stale-skill-refs.py` → **rc=0** |
| **AC-5** | **真の衝突**を注入すると collisions が rc=1 を返す（除外条件が広すぎないことの実証） |
| **AC-6** | **真の stale 参照**を注入すると stale が rc=1 を返す |
| **AC-7** | 各除外条件について「**その除外で見逃すクラス**」を明記する |
| **AC-8** | `--warn-only` 的な握り潰しを新設しない（#1109 の教訓） |
| **AC-9** | 絶対件数（46 / 7）を契約値にしない。集合の性質で書く |
| **AC-10** | CI 配線 patch が `git apply --check` rc=0 で、**未適用**である |
| **AC-11** | 変異注入で「レーン全体を落とす変異」と「レーン内部の分類を誤らせる変異」の両方を立て、kill を実証する（空振りは正直に記録） |
| **AC-12** | 既存の doctor 統合契約（rc=0/1/その他 の 3 値）を壊さない |

## Notes from Refinement

- **`plugin/plangate/` は `.claude/` から `scripts/sync-plugin-plangate.sh` が生成する
  export**（手書きではない）。さらに `sync-plugin-plangate.yml` の `drift-check` job が
  `.claude/**` / `plugin/plangate/**` を触る **PR で必ず走り、差分があれば exit 1** する。
  → ミラー対の内容 drift は **既存 CI が hard fail で担保済み**であり、
  collisions 側でミラーを除外しても **担保の空白は生じない**（重要な設計根拠）。
- 元 issue #692 の動機は **interactive-ocean**（consumer repo）で
  `self-review` が repo-local / growth-core / plangate の **3 重定義**だったケース。
  producer repo である本リポジトリの repo-local ⇄ 自 plugin export は**別クラス**。
- `.claude/skills/` と `scripts/*.py`（`scripts/hooks/*.sh` を除く）は
  **Hardening Override 対象外**（`mode-classification.md` の注記に明記）。

## Estimation Evidence

### Risks

| # | リスク | 対応 |
|---|-------|------|
| R1 | 検査を弱める方向の変更のため、**見逃しクラスを作る** | 除外ごとに見逃しクラスを明記し、他層での担保有無を併記（AC-7） |
| R2 | ミラー除外が広すぎて **真の衝突まで通す** | 除外条件を「厳密に 2 定義 / 一方が repo-local / 他方が plugin / root 内相対パス一致」の合接に限定し、変異で実証（AC-5/AC-11） |
| R3 | `ta-52` の TC-03 が現行仕様（ミラー = 衝突）を前提にしており **破れる** | ta-52 TC-03 を「真の衝突」構成に作り替える。ミラー = 非衝突の TC を追加 |
| R4 | gitignore 除外に `git` 依存が入る | git 不在時は「何も除外しない」= 現行挙動へ縮退（安全側） |

### Unknowns

- なし（全件を実測で分類済み）

### Assumptions

- `plugin/` 直下は本リポジトリ自身の export 置き場であり、
  第三者 plugin を vendor する場所ではない（現状 `plugin/plangate` のみ）
