# PBI INPUT PACKAGE — TASK-1059

> 対象 issue: [#1059](https://github.com/s977043/plangate/issues/1059)
> 親 EPIC: [#1035](https://github.com/s977043/plangate/issues/1035)（HOITL → HOTL 移行トラック）の L1 出口条件「帯の是正」
> 関連: [#927](https://github.com/s977043/plangate/issues/927)（非対称 A/B・別論点）/ [#916](https://github.com/s977043/plangate/issues/916)（判定基盤 carve-out の機械強制）/ [#874](https://github.com/s977043/plangate/issues/874)（RunEvidence）
> 本ファイルの実測はすべて **main = `7ab6546`（2026-08-13 時点）** で再取得したもの。行番号は参考値であり契約値としない（アンカーは記号名で持つ）。

## Context / Why

`arbiter.py` において `changed_files` が **「安全検査の対象」と「規模判定の分母」の二役**を負っており、PlanGate の Plan Package を作った時点で `size_ok` の機械検証（priority 1.9）が構造的に落ちる。

### 実装上の事実（実測）

| 消費箇所（記号アンカー） | 役割 | 分類 |
|---|---|---|
| `arbiter.boundary_check()` | HO 接触判定（touches-HO / clean） | **安全検査** |
| `arbiter.check_allowed_paths()` | scope 逸脱判定（priority 1.5） | **安全検査** |
| `arbiter.machine_size_check()` | 規模判定（priority 1.9 の入力） | **規模判定** |
| `arbiter._require_normalized_path_list()`（`validate_input` 内） | パス正規化・traversal 拒否（第一防壁） | 安全検査（入力検証） |
| `arbiter._size_mismatch_reason()` | escalate 理由文字列に `len(changed_files)` を埋める | 表示のみ |
| `delivery.assess()` の `deviated` 算出 | Delivery 状態機械の plan 逸脱判定（`changed_files ⊄ allowed_paths`） | **安全検査（別モジュール）** |
| `collector` の `changed_files` 供給（`fetch_changed_files` / snapshot 組み立て・`changed_files_empty` / `changed_files_unavailable` flag） | 実測供給と fail-open 封じ | 供給側 |

`machine_size_check()` には除外ロジックが無く、渡された配列の件数をそのまま数える（`SIZE_OK_MAX_FILES = 2`）。

### 実測 1: 直近 3 PBI の実データ（本リポジトリ・merged PR のファイル一覧）

`gh pr view <n> --json files` で実測（`arbiter.boundary_check()` は本リポジトリの `ho-paths.md`＝21 パターンで実行）。

| PBI | 実 PR | `changed_files` 件数 | 内訳 | `boundary` | 現行 `size_ok`（機械） | `docs/working/` 除外後の件数 | 除外後 `size_ok` |
|---|---|---|---|---|---|---|---|
| TASK-1036 | #1048（Plan Package） | **7** | すべて `docs/working/` | **clean** | ❌ false | 0 | ✅ true |
| TASK-1044 | #1055（Plan Package） | **9** | すべて `docs/working/` | **clean** | ❌ false | 0 | ✅ true |
| TASK-1045 | #1056（Plan Package） | **8** | すべて `docs/working/` | **clean** | ❌ false | 0 | ✅ true |
| TASK-1036 | 実装 PR **未存在**（issue #1036 は OPEN）。plan の Files to Touch から投影 | 11（投影） | `docs/working/` 8 + `tests/extras/` **3** | **clean** | ❌ false | **3** | ❌ **false** |
| TASK-1045 | 実装 PR 未存在。plan の Files to Touch から投影 | 7（投影） | `docs/working/` 5 + 実コード 2 | **clean** | ❌ false | **2** | ✅ true |

**3 件とも `boundary=clean`**（実測で確認）。すなわち HO carve-out（自己改変防止）を一切緩めずに、規模軸の分母定義だけで帯を実質化できる。

> **issue 本文との差異（重要）**: issue の表は TASK-1036 を「`changed_files` 11 / `tests/extras/` 2 / 実コード変更 2」としているが、**TASK-1036 には実装 PR が存在しない**（issue OPEN・merged は Plan Package の #1048＝7 ファイルのみ）。plan の Files to Touch から投影すると **実コード相当は 3 本**（`ta-26-plugin-sync.sh` / `ta-62-t26-recurse-env-guard.sh` / `tests/extras/README.md`）であり、**`docs/working/` を除外しても `SIZE_OK_MAX_FILES=2` を満たさない**。「除外だけで TASK-1036 が eligible になる」という読みは成立しない。

### 実測 2: ワークフロー自身が下限を規定している

`working-context.md` が定める Plan Package は plan / todo / test-cases / pbi-input / review-self / review-external / INDEX / current-state / decision-log の **9 ファイル**。exec 時に status / handoff / evidence が加わる。`SIZE_OK_MAX_FILES=2` に対し最小構成が既に 9 であり、production run が eligible になる余地が構造的に無い。

### 実測 3: 規約側の状態（issue 本文と食い違う）

- `mode-classification.md`（`.claude/rules/`）には **「分母」「working context」という語が 1 件も存在しない**（grep 実測 0 件）。
- 「working context 成果物は Mode 判定の分母に含めない（例外規定を作らず分母を確定する）」は、**TASK-1044 の C-2 指摘 R-010 / R-015 を受けて TASK-1044 の `plan.md` に書かれた PBI ローカルの決着**であり、`mode-classification.md` 正本には未反映。
- したがって issue の「`mode-classification` では決着した規約が `arbiter.py` に反映されていない」は**正確には「PBI レベルで決着した規約が、`mode-classification.md` 正本にも `arbiter.py` にも反映されていない」**。**AC はこの事実に合わせて設計する必要がある**（後述 AC-5）。

### 実測 4: `changed_files` の供給元（申告制／機械算出の別）

**2 経路あり、経路によって性質が変わる**。

| 経路 | 供給元 | 性質 |
|---|---|---|
| 計画時（exec 前の C-3' 裁定） | `.agents/skills/ai-loop-cycle/SKILL.md` Step 1 —「plan の Files to Touch を使う」 | **申告制**（AI が plan 本文から書き起こす） |
| 再裁定時（実装後・PR 前） | 同 Step 1 —「`git diff --name-only <base>...HEAD` の実差分」/ 実 PR 収束では `collector.fetch_changed_files()` が同等の git 実測を行う | **機械算出**（取得失敗は空で埋めず `changed_files_unavailable` を積む fail-closed） |

`allowed_paths` は `plan_package.extract_allowed_paths()` が **plan.md の `## Files / Components to Touch` 節から `` `…/…` `` 形式のパスを正規表現抽出**する（Collector と `derive_loopspec()` が同一実装を共有）。計画時は `changed_files` と `allowed_paths` が**同一節に由来する**ため、scope 検査（priority 1.5）は計画時にはほぼ自明に通る。

**`docs/working/` は実測で `allowed_paths` に含まれる**:

| PBI | `extract_allowed_paths()` の実測結果 |
|---|---|
| TASK-1045 | 7 件。うち `docs/working/TASK-1045/{plan,todo,test-cases,status,handoff}.md` の **5 件** |
| TASK-1044 | 6 件。うち `docs/working/TASK-1044/*`（**glob 1 件で表現**）+ `docs/working/TASK-0921/handoff.md` |
| TASK-1036 | 8 件。うち `docs/working/TASK-1036/**` / `docs/working/`（glob）。**加えて `.github/workflows/*` / `scripts/hooks/*` / `bin/plangate` を抽出**（後述） |

> **副次観測（本 PBI scope 外・記録のみ）**: `extract_allowed_paths()` は `## Files / Components to Touch` 節を「次の `## ` まで」で切るため、**同節内に散文で書かれた「触らない」宣言のパスも `allowed_paths` に混入する**。TASK-1036 では「Hardening Override 対象パス: 含まない（… `.github/workflows/*` / `scripts/hooks/*` / `bin/plangate` に触らない）」という**禁止列挙が allowed_paths に入っている**。HO 判定（priority 1）は `allowed_paths` より先に評価されるため touches-HO は免れない（`rollout-policy.md` §5 の「`allowed_paths` に HO パスを書いても escalate は免れない」が機械層で担保）が、**非 HO パスの scope 検査は実質的に緩む**。別 issue 候補。
>
> **副次観測 2（同上）**: 計画時の `changed_files` 件数は**記法依存**である。TASK-1044 は `docs/working/TASK-1044/*` を **1 件**として書き、TASK-1045 は 5 件に展開して書いた。同じ Plan Package でも記法次第で規模判定の分母が 1 にも 5 にもなる。除外ロジックを入れても**この記法依存は解消しない**（plan で扱う論点）。

### 実測 5: HO 判定が `docs/working/` をどう扱うか

`ho-paths.md` の HO パス一覧（実測 21 パターン）に **`docs/working/` 配下は含まれない**。`_ho_pattern_to_regex()` は**リポジトリルート起点で `^…$` アンカー**されるため、`docs/working/` 配下のパスは HO パターンに一致しない。実測:

| 入力 `changed_files` | `boundary` |
|---|---|
| `["docs/working/TASK-1059/plan.md", "bin/plangate"]` | **touches-HO**（`bin/plangate` に一致） |
| `["docs/working/TASK-1059/.claude/rules/foo.md", "docs/working/TASK-1059/bin/plangate", "docs/working/TASK-1059/scripts/hooks/x.sh"]` | **clean**（現行実装でも一致しない） |

**これは AC-2 の書き方に直接影響する**（後述）。

---

## What (Scope)

### In scope

1. **規模判定の分母から working context 成果物を除外する**。除外は `machine_size_check()`（priority 1.9 の入力）**のみ**に適用し、`boundary_check()` / `check_allowed_paths()` / `validate_input` のパス検証・`delivery.assess()` の逸脱判定の入力からは**除外しない**。
2. 除外対象パターンの確定（`docs/working/TASK-*/` のみか、`docs/working/` 配下全体か、`PBI-*/` や `_audit/` 等をどう扱うか）を **plan 段階で実測に基づき決める**。
3. **負側テスト**: 除外が安全境界に波及しないことの機械的固定（`test_arbiter.py`）。
4. `docs/workflows/ai-loop/lite-criteria.md` §2「変更規模」への規約明記（分母定義の明文化）。
5. 除外後の `SIZE_OK_MAX_FILES` の妥当性の**再検証と結論の記録**（据え置き / 変更のいずれでも根拠を残す）。
6. `rollout-policy.md` §5 の不変条件が無傷であることの差分確認。

### Out of scope

- **`SIZE_OK_MAX_FILES` の具体値をこの PBI INPUT で決めること**。実測 1 のとおり、除外後の実コード件数は PBI により 2 / 3 と分かれ、evidence 込みの exec run では未計測。**値の決定は plan で実測を出し、C-3 で人間が確定する**（本 PBI では「再検証して根拠を記録する」までを AC 化する）。
- **`SIZE_OK_MAX_FILES` の単純な引き上げのみでの解決**（分母定義を直さないと evidence 追加で再発する）。
- **HO / 判定基盤 carve-out の緩和**。`rollout-policy.md` §5 の不変条件（touches-HO 無条件 escalate / NO MERGE BY AI / lite 4 軸 AC-8 安全側 / `allowed_paths` に HO を書いても escalate 不可）は不動。
- **`.claude/rules/mode-classification.md` の編集**。同ファイルは `ho-paths.md` の `.claude/rules/*.md`＝**HO-rules** に該当し、**AI は編集できない**（HO 常時 block）。正本への規約反映が必要と判断された場合は、**patch 提示までを AI-owned とし、適用は Human-owned** とする（`responsibility-classes.md`）。
- 計画時 `changed_files` の**記法依存**（glob 1 件 vs 展開 5 件）の解消（副次観測 2）。別 issue 候補。
- `extract_allowed_paths()` が「触らない」宣言のパスまで拾う問題（副次観測 1）。別 issue 候補。
- C-2 必須と eligible の相互排他（#927）。
- 判定基盤 carve-out の機械強制（#916）。
- RunEvidence への `changed_files` 保存（#874）。実測: `20260805T013823Z-4448420-run028.json` のトップレベルキーは `boundary_check` / `class_check` / `decision` / `gates` / `ho_paths_source` / `ho_pattern_count` / `issued_by` / `lite_check` / `policy_ref` / `run` / `scope_check` / `target_sha` / `timestamp` / `w_check` の 14 個で、**`changed_files` は record 全体のどこにも存在しない**（issue 本文の記載は実測で裏付けられた）。
- C-3' の standard 以上への適用範囲拡大。
- 過去 run 記録の遡及修正。
- 承認境界の緩和（NO MERGE BY AI / C-4 / HO 適用不可はすべて不変）。
- 申告制 3 軸（新規設計なし / 既存パターン踏襲 / 可逆性）の機械化。

### 想定 touch 範囲（plan で確定する）

| パス | 想定変更 | 備考 |
|---|---|---|
| `scripts/ai-loop/arbiter.py` | `machine_size_check()` の分母定義 | **判定基盤 carve-out ①**（`scripts/ai-loop/**`） |
| `scripts/ai-loop/test_arbiter.py` | 正側 / 負側テスト | 同上 |
| `docs/workflows/ai-loop/lite-criteria.md` | §2「変更規模」への規約明記 | **判定基盤 carve-out ②**（`docs/workflows/ai-loop/**`） |
| `docs/workflows/ai-loop/decision-table.md` | priority 1.9 の記述整合（必要なら） | 同上 |
| `.agents/skills/ai-loop-cycle/SKILL.md` | Step 1 の `size_ok` 申告手順の整合（必要なら） | **判定基盤 carve-out ③** |
| `docs/working/TASK-1059/**` | Plan Package | — |

---

## 受入基準

> issue の AC-1〜AC-6 を出発点に、実測（とくに実測 3 / 実測 5）を反映して過不足を直した。**AC-2 と AC-5 は issue 原文のままでは検証不能または実行不能**なので書き換えている（根拠は各 AC の注記）。

- [ ] **AC-1**: 規模判定（`machine_size_check()` = priority 1.9 の入力）の分母から working context 成果物が除外され、**同じ `changed_files` が `boundary_check()` / `check_allowed_paths()` / `validate_input` のパス検証には除外なしで渡り続ける**ことが、`test_arbiter.py` の**正側・負側両方**のテストで固定される。
- [ ] **AC-2**（issue 原文から書き換え）: **`docs/working/` 配下のパスと HO パスが混在する `changed_files` に対し、`boundary=touches-HO` が維持され priority 1（無条件 escalate）が発火する**ことを負側テストで実証する。
  - 書き換えの根拠: issue 原文「`docs/working/` 配下に HO パス相当を置いても escalate する」は**現行実装でも成立しない**。実測 5 のとおり `docs/working/TASK-1059/.claude/rules/foo.md` 等は `_ho_pattern_to_regex()` のルート起点アンカーにより**変更前から `boundary=clean`** であり、この AC を字義どおり満たすには HO 判定側の意味論変更（本 PBI の Out of scope）が要る。**「除外が安全境界に波及しないことの証明」という AC-2 の意図は、上記の書き換え形で過不足なく検証できる**。
- [ ] **AC-3**: 本リポジトリの直近 3 PBI（TASK-1036 / 1044 / 1045）の**実 PR ファイル一覧**を入力として、除外前後の `size_ok`（機械判定）の変化が evidence として記録される。**実装 PR が存在しない PBI については「plan の Files to Touch からの投影である」と明示する**（TASK-1036 は実装 PR 未存在）。
- [ ] **AC-4**: 除外後の `SIZE_OK_MAX_FILES` の妥当性が、**evidence を含む exec run の実測**（本 PBI 自身の exec run を含めてよい）に基づいて再検証され、**据え置き / 変更いずれの結論でも根拠と実測値が記録される**。値の確定は C-3 の人間判断に委ねる。
- [ ] **AC-5**（issue 原文から書き換え）: **`lite-criteria.md` §2 の分母定義が明文化され、その出典として TASK-1044 R-010 / R-015 の決着（working context 成果物は分母外・例外規定を作らない）が参照される**。あわせて、**`mode-classification.md` 正本には現状この規約が存在しない**という差分を `lite-criteria.md` または handoff に明記し、正本反映が必要な場合は **patch 提示（AI-owned）+ 適用（Human-owned）** の follow-up として残す。
  - 書き換えの根拠: issue 原文「`lite-criteria.md` §2 と `mode-classification.md` の規模軸の分母定義が一致していること」は、**`mode-classification.md` に照合対象の分母定義が存在しない**（実測 3・grep 0 件）ため現状では充足不能。かつ `mode-classification.md` は HO パスであり AI が編集して一致させることもできない。
- [ ] **AC-6**: `docs/workflows/ai-loop/rollout-policy.md` §5 の不変条件が無傷であることが差分確認（`git diff` で当該節に変更が無いこと）で証明される。
- [ ] **AC-7**（追加）: 除外ロジックが **`delivery.py` の plan 逸脱判定（`assess()` の `deviated`）に一切影響しない**ことが、差分確認または `test_delivery.py` の既存テスト全 PASS で示される。
  - 追加の根拠: `changed_files` の消費箇所を全数列挙した結果、`arbiter.py` 以外に `delivery.py` が**安全検査目的で**同フィールドを消費している。issue の AC 群はこの越境をカバーしていない。
- [ ] **AC-8**（追加）: 除外の適用が **priority 1.9 の 1 経路のみ**であり、priority 0 / 1 / 1.5 / 1.6 / 1.65 / 1.7 / 1.95 / 2 以降の判定順序・条件が変更されていないことが、`decision-table.md` との突合で確認される（escalate 経路を auto-approve に変える変更を含まないこと）。

---

## Notes from Refinement

> 判断の正本は [`decision-log.jsonl`](./decision-log.jsonl)。ここは要約。

- **本 PBI は「規模判定の分母定義」だけを直す**。#927（非対称 A/B）の scope を広げず、C-3' の適用範囲を standard 以上へ拡張しない。
- **除外は安全側の逆方向の変更である**という自覚を明示する。#780 Slice C（priority 1.9 の導入）は「escalate 条件を追加するだけの安全側変更」だったのに対し、本 PBI は **一部の escalate 経路を auto-approve 側へ開く**。したがって `POLICY_REF` の改版要否を plan で検討する（`arbiter.py` の `POLICY_REF` は Slice C 導入時に `@v2 → @v3` へ改版された前例がある）。
- **`SIZE_OK_MAX_FILES` の値はこの PBI INPUT で決めない**。除外後でも TASK-1036 投影は 3 ファイルで閾値 2 を超える。「除外すれば帯が実質化する」は**部分的にしか正しくない**ため、値の妥当性は evidence 込み exec run の実測を出したうえで C-3 で人間が確定する。
- **記法依存の残存**（副次観測 2）を既知の残存エクスポージャとして明示する。計画時 `changed_files` は plan の書き方で件数が変わるため、除外を入れても「分母が意味を持つ」保証は plan 記法規約側に依存する。
- **Mode は plan で判定する**。想定は **high-risk 以上**。根拠: 変更対象が `arbiter.py` / `lite-criteria.md` / `rollout-policy.md` 参照であり **`rollout-policy.md` §2 の判定基盤 carve-out ①〜③ に該当**、かつ `mode-classification.md` の例外ルール「承認境界周辺の変更 → 最低でも高」が効きうる（`scripts/hooks/*` そのものではないが、承認境界の判定エンジンである）。**いずれにせよ人間 C-3 必須**で、`lite_eligible=false` / 同期 C-3 固定として扱う。
- **`rollout-policy.md` §2 の carve-out は規範層**である旨が同節に明記されている（`boundary_check` は `ho-paths.md` の HO 表からのみ touches-HO を導出するため、carve-out パスは機械層では `clean` と判定される）。したがって本 PBI の実行者は、**機械層が escalate しなくても規範層で escalate する責務**を負う。ai-loop の C-3' 経路には載せず、通常フロー + Human C-3 で進める。

---

## Estimation Evidence

### Risks

| # | リスク | 影響 | 緩和 |
|---|---|---|---|
| R-1 | 除外ロジックが `boundary_check` / `check_allowed_paths` にも波及し、`docs/working/` 経由で安全検査を迂回する経路が生まれる | **critical**（承認境界の穴） | AC-1 / AC-2 の負側テストで固定。除外は `machine_size_check()` の呼び出し直前でのみ適用し、`Signals` 算出の他の入力には触れない |
| R-2 | 除外パターンが広すぎ（例 `docs/**`）、規模判定が実質無効化される | major | 除外パターンを plan で確定し、パターン自体をテストで固定 |
| R-3 | `docs/working/` 配下に将来 HO 相当の資産が置かれると、除外により規模軸で見えなくなる | major | 実測 5 のとおり現状 HO 表に `docs/working/` は無い。AC-2 で「混在時に touches-HO が維持される」ことを固定し、HO 表への追加は本 PBI では行わない |
| R-4 | 除外後も `SIZE_OK_MAX_FILES=2` で TASK-1036 相当（実コード 3 本）が落ち、「帯の是正」が達成されたと誤認される | major | AC-4 で実測を必須化。handoff に「除外だけでは足りない PBI が実在する」ことを記録 |
| R-5 | `delivery.py` 側の plan 逸脱判定に影響し、実 PR 収束の安全側判定が緩む | major | AC-7 で差分確認 + `test_delivery.py` 全 PASS |
| R-6 | 判定基盤 carve-out 対象の自己改変（ai-loop が自分の判定基準を緩める）と受け取られる | major | 通常フロー + Human C-3 固定。ai-loop C-3' 経路に載せない。`rollout-policy.md` §5 差分ゼロを AC-6 で証明 |
| R-7 | 記法依存（glob vs 展開）により、除外後も分母が申告者の書き方で変わる | minor | 既知の残存として handoff に明記。別 issue 化を提案 |

### Unknowns

| # | 不明点 | 解消方法 | 解消フェーズ |
|---|---|---|---|
| U-1 | 除外パターンの正確な定義（`docs/working/TASK-*/` のみか / `docs/working/**` か / `PBI-*/` `_audit/` `_metrics/` `templates/` をどう扱うか） | 既存 PBI の実 PR ファイル一覧を全数走査して分布を出す | plan |
| U-2 | 除外後の `SIZE_OK_MAX_FILES` の適正値（据え置き 2 か引き上げか） | evidence を含む exec run の実測（本 PBI 自身の run を含む）を集める | plan → **C-3 で人間確定** |
| U-3 | `POLICY_REF` の改版が必要か（escalate → auto-approve 方向の変更であるため） | `arbiter.py` の `POLICY_REF` 運用履歴（`@v2 → @v3`）と照合 | plan |
| U-4 | 除外を **arbiter 側**で行うか、**呼び出し側（SKILL.md Step 1 / collector）** の入力組み立てで行うか | 「安全検査には全件、規模判定には除外後」を 1 つの入力配列で満たすには arbiter 内で分岐する必要がある。呼び出し側で除外すると安全検査からも消える | plan（**arbiter 内が有力**） |
| U-5 | `mode-classification.md` 正本への規約反映を本 PBI の follow-up とするか、別 PBI とするか | HO パスのため AI 適用不可。patch 提示までの粒度を C-3 で確認 | C-3 |
| U-6 | 計画時 `changed_files`（申告制・plan 由来）と再裁定時（git 実測）で、除外の効き方に差が出ないか | 両経路で同じ除外関数を通ることをテストで固定 | plan |

### Assumptions

- `changed_files` を消費する production コードは、実測で **`arbiter.py`（`boundary_check` / `check_allowed_paths` / `machine_size_check` / `validate_input` / 理由文字列）・`collector.py`（供給）・`delivery.py`（plan 逸脱判定）** の 3 モジュールに閉じる（`scripts/ai-loop/*.py` の `changed_files` 全ヒットを読んだうえでの列挙。`run_evidence.py` / `c3prime_verify.py` / `reconciler.py` の production コードには消費が無く、`test_*.py` はテスト入力）。
- `boundary_check()` の HO パターンは `ho-paths.md` から実行時解決される（実測: 本リポジトリで **21 パターン**、source = `docs/ai/ai-loop/ho-paths.md`）。パターン数は運用で増減しうるため**契約値にしない**。
- priority 1.9 は「申告 `size_ok=true` かつ機械判定 false」のときのみ発火する。申告が `false` の場合は `lite_check()` が false になり priority 2 で escalate するため、本 PBI の除外は**申告 `size_ok=true` の run にのみ効く**。
- `rollout-policy.md` §2 の判定基盤 carve-out は**規範層**であり、機械層（`boundary_check`）は carve-out パスを `clean` と判定する（同節に明記）。本 PBI の対象ファイルは carve-out ①〜③ に該当するため、**ai-loop の auto-approve 経路には載せず通常フロー + Human C-3 で進める**。
- 本 PBI は `.claude/settings*.json` を編集しない（self-mod guard）。`approvals/*.json` は Human-owned であり AI が発行しない。
- 行番号は実測時点の main（`7ab6546`）のものであり、先行マージでズレる。plan / test では**記号名アンカー**（関数名・定数名）を使う。
