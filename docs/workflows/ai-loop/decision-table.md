# decision-table — Arbiter 裁定 Decision table

> 適用ドメイン（Phase 1）: ①plangate 本体 = docs/workflows/ai-loop/ 配下のみ（dogfooding 域・本番フロー WF-00〜07 非適用）
> ②導入先リポジトリ = ho-paths 確定 + LoopSpec scope.allowed_paths 宣言を前提に適用可
> 裁定ロジック設計: `docs/ai/ai-loop/concept.md` §4 / 判定フロー: `docs/workflows/ai-loop/flow-detect.md`

---

## 1. 目的

Arbiter L2 裁定層の判断ロジックを機械的に決定可能な形式で定義する。
入力 4 軸から決定論的に裁定値を導出し、曖昧さを排除する。

---

## 2. 入力軸（4 軸）

| 軸 | 値域 | 説明 |
| ---- | ------ | ------ |
| `boundary` | `touches-HO` / `clean` | HO パス（`docs/ai/ai-loop/ho-paths.md`）への接触有無 |
| `lite` | `true` / `false` | 低リスク要件を満たすか |
| `verdict` | `approve-approve` / `approve-reject` / `reject-reject` / `reject-approve` | W チェック（Model A/B）の合意・不一致結果 |
| `class` | `merge` / `no-merge` | 変更に merge（C-4）を含むか |

### 軸の補足

- `boundary` の判定正本: `docs/ai/ai-loop/ho-paths.md`
- `verdict=approve-reject` は W チェック不一致を意味する（`flow-detect.md §3.1` 参照）
- `class=merge` は Human-owned 固定のため、他の軸にかかわらず human escalate となる
- `verdict=reject-approve` は A が設計妥当性で NG のためブロック（`flow-detect.md §3.1` 参照）

---

## 3. Decision table（優先順位ルール）

複数条件が同時に成立する場合は厳しい裁定を採用:
`blocked > human escalate > auto-approve`

| priority | boundary | lite | class | verdict | → 裁定 |
| ---------- | ---------- | ------ | ------- | --------- | -------- |
| 1 | `touches-HO` | `*` | `*` | `*` | **human escalate（固定）** |
| 2 | `clean` | `false` | `*` | `*` | **human escalate** |
| 3 | `clean` | `true` | `merge` | `*` | **human escalate**（merge=Human-owned 固定） |
| 4 | `clean` | `true` | `no-merge` | `reject-reject` / `reject-approve` | **blocked**（A が設計妥当性で NG） |
| 5 | `clean` | `true` | `no-merge` | `approve-reject` | severity 分類 → C/D 裁定（§4 参照） |
| 6 | `clean` | `true` | `no-merge` | `approve-approve` | **auto-approve** |

`*` はワイルドカード（どの値でも適用）。上から順に評価し、最初に一致した行を採用する。

### 必須ルール

> **boundary=touches-HO の場合、lite / class / verdict にかかわらず必ず human escalate 固定。**
> これは W チェック結果・severity 分類・C/D 裁定のいずれをもスキップする絶対条件。

### priority 0 / 1.5 / 1.7（#809・#780 Slice B 追加・機械実装のみで本表 1〜6 の番号体系は不変）

上記 priority 1〜6 の番号体系（本リポジトリの正本表記）は変更しない。以下の
3 チェックは `scripts/ai-loop/arbiter.py`（#809・#780 Slice B）が実装する
**前置・割込みチェック**であり、実装上は 1〜6 の評価より手前 / 間で評価される:

| priority | 内容 | → 裁定 |
| ---------- | ------ | -------- |
| **0** | ho-paths.md が実行時解決できない、またはパース結果が 0 件（fail-closed）。boundary 判定そのものが実行不能なため、他のどの軸よりも先に評価する | **human escalate（固定・絶対条件）** |
| **1.5** | boundary=clean（priority 1 通過後）だが、`changed_files` が `allowed_paths` のいずれの glob にも一致しない（scope 逸脱） | **human escalate** |
| **1.7** | boundary=clean・scope 逸脱なし（priority 1.5 通過後）だが、`gates.c1 == "PASS"` かつ `gates.breakdown == "pass"`（両方とも厳密一致）を満たさない（plan 品質ゲート未充足） | **human escalate** |

- priority 0 は「boundary が touches-HO か clean か」を判定する前提条件
  （ho-paths 一覧そのもの）が欠落しているケースであり、fail-open
  （判定不能を clean 扱いにする）は絶対に行わない
- priority 1.5 は priority 1（touches-HO）の**後**に評価する。
  `allowed_paths` に HO パスを宣言していても HO escalate は免れない
  （`design-philosophy.md` I-1 不変条件、LoopSpec 既存規定）
- priority 1.7（#780 Slice B）は priority 1.5（scope）の**後**・priority 2（lite）の
  **前**に評価する。`gates`（`{"c1": str, "breakdown": str}`）は任意入力フィールドで、
  欠落・null・非 dict・型不一致・値の表記違い（例: 小文字 `"pass"` 以外の
  `breakdown`、`"PASS"` 以外の `c1`）は**すべて安全側で未充足＝human escalate**
  に倒れる。**本チェックは escalate 条件を追加するだけの安全側変更であり、
  以前 escalate/blocked だった経路を auto-approve にする効果は一切持たない**
  （POLICY_REF を `@v1` → `@v2` へ改版した理由）。`c1` は C-1 セルフレビューの
  結果（`"PASS"` のみ通過）、`breakdown` は breakdown-gate スキルの粒度判定
  結果（`"pass"` のみ通過。`split-suggested` 等は未充足）を渡す想定
  （`.agents/skills/ai-loop-cycle/SKILL.md` Step 0/1 参照）

### 裁定ラベルと provenance 値の対応

| Decision table の裁定ラベル | provenance `decision` 値 |
| --------------------------- | ------------------------- |
| `auto-approve` | `AUTO_APPROVED` |
| `human escalate` | `HUMAN_ESCALATED` |
| `blocked` | `BLOCKED` |

裁定ラベルは本 table 内の意思決定表記、`decision` 値は provenance JSON に刻印する列挙型。

---

## 4. approve-reject（不一致）の裁定詳細

`verdict=approve-reject`（W チェック不一致: A=approve, B=reject）は priority 5 で受ける。
詳細な分岐は `docs/workflows/ai-loop/flow-detect.md` §3.2〜3.3 で定義する。

```text
approve-reject
  ├── severity=critical/major → human escalate 固定
  └── severity=minor/low     → Model C/D 観点特化裁定
        ├── C=approve, D=approve → auto-approve（provenance に C/D 裁定を記録）
        ├── C/D 不一致           → human escalate
        └── C=reject, D=reject  → blocked
```

---

## 5. provenance スキーマ draft

auto-approve 時（priority 6 または C/D 合意）に刻印する最低限の必須フィールド。

> **PoC スコープ**: **provenance 刻印**（正本として確定する記録）は auto-approve
> 時のみ定義する。PoC 実装（`scripts/ai-loop/arbiter.py`）は HUMAN_ESCALATED /
> BLOCKED を含む全裁定で同スキーマの decision record を出力するが、auto-approve
> 以外の record は **audit record（暫定）** であり正本性を持たない。
> HUMAN_ESCALATED / BLOCKED 時の audit trail の正式定義（判断理由・escalate
> 経緯の記録）は Phase 3 以降で行う。

```text
decision:           AUTO_APPROVED / HUMAN_ESCALATED / BLOCKED
issued_by:          arbiter-v0.1（判断エンジン識別子）
policy_ref:         auto-approve-lite-clean@v2（適用 policy 名 + バージョン）
w_check:
  model_a: approve
  model_b: approve
boundary_check:     clean
target_sha:         <変更対象コミット SHA（差し替え検知用）>
lite_check:         true
class_check:        no-merge
scope_check:        in_scope
ho_paths_source:    docs/ai/ai-loop/ho-paths.md（解決された ho-paths のパス。未解決時は null）
ho_pattern_count:   18（解決した HO パターン抽出件数）
timestamp:          <ISO 8601>
```

> **policy_ref バージョン履歴**: `@v0` → `@v1`（#809: allowed_paths 必須化・
> ho-paths 実行時解決の fail-closed 機械化）→ `@v2`（#780 Slice B: `gates`
> 入力による plan 品質ゲート priority 1.7 の追加）。`@v0` 時点の PoC は
> `HO_PATTERNS` ハードコード定数＋allowed_paths 未検証だったため、境界判定
> ロジックが変わった本改版で policy バージョンを進めた。`@v2` は
> auto-approve の新必要条件（`gates.c1 == "PASS"` かつ `gates.breakdown ==
> "pass"`）を追加した改版であり、escalate 条件を追加するだけの安全側変更
> （以前 auto-approve/blocked だった経路が新たに auto-approve になることはない）。

### C/D 裁定時の追加フィールド（severity=minor/low 時のみ）

```text
w_check:
  model_a:   approve
  model_b:   reject
  severity:  low / minor
  model_c:   approve
  model_d:   approve
```

### run メタ（#780 Slice D 後半 追加・additive・任意）

呼び出し側入力の `run`（省略可）をそのまま provenance に刻む。**省略時は `run` キー自体を刻まない**（`run: null` は出力しない）。これにより `metrics.py` は当該 record を legacy（run メタ未計装・集計対象外の正常レコード）に分類し、invalid_run_meta（run メタを主張するが run_id が falsy＝要注意）へ誤計上しない。

```text
run:
  run_id:        run-022（run 単位の連番識別子。非空 string 必須）
  round_index:   1（初回呼び出し=1、再試行ごとに +1。**1 起点**。int 必須・bool 不可。metrics は round_index==1 を初回 sentinel として first_pass を判定するため 0 起点は不可）
  task_id:       TASK-XXXX（対象 PBI 識別子。string 必須）
  repair_action: reject 指摘に基づき修正（再試行時のみ・任意・string）
```

`run` は `scripts/ai-loop/metrics.py`（#812）が run 単位の集計（first-pass rate 等）に
用いる消費契約。gate 挙動（POLICY_REF）は変えない純粋な additive provenance 拡張であり、
本追加による policy バージョン改版は行わない（run 追加自体は据え置き。現行ベースラインは
`@v2` — #780 Slice B の `gates` 必須化によるもので、run 起因の改版ではない）。

### 入力: gates（#780 Slice B 追加・additive・任意）

呼び出し側入力の `gates`（省略可）は priority 1.7（plan 品質ゲート）の判定
にのみ使う入力軸であり、`run` と異なり **provenance には echo されない**
（判定結果は decision / reason にのみ反映される。PoC スコープでは gates 自体の
生値を record に刻む必要性が薄いため見送り — 将来 Phase で必要になれば
additive に追加検討）。

```text
gates:
  c1:        PASS（C-1 セルフレビューの結果。"PASS" 以外はすべて未充足扱い）
  breakdown: pass（breakdown-gate スキルの粒度判定結果。"pass" 以外はすべて未充足扱い）
```

`gates` 省略・null・非 dict・キー欠落・値の表記違いは**すべて安全側で
plan_quality_ok=false**（priority 1.7 で human escalate）に倒れる。

### フィールド定義

| フィールド | 必須 | 説明 |
| ----------- | ------ | ------ |
| `decision` | ✅ | 最終裁定値（3 値） |
| `issued_by` | ✅ | 判断エンジンの識別・追跡用（真正性担保には署名等が別途必要） |
| `policy_ref` | ✅ | 適用 policy 名とバージョン（policy 自動失効の追跡用） |
| `w_check` | ✅ | W チェック（A/B）の判定と、C/D 裁定時の詳細 |
| `w_check.model_a` | ✅ | Model A の判定結果 |
| `w_check.model_b` | ✅ | Model B の判定結果 |
| `target_sha` | ✅ | 対象コミット SHA（差し替え検知用。replay 攻撃は検知・別途防止機構が必要。計画時/実装後の意味論は下記参照） |
| `boundary_check` | ✅ | boundary 判定結果（auto-approve は clean のみ。ho-paths 未解決 fail-closed 時は `unresolved`） |
| `lite_check` | ✅ | lite 判定結果（auto-approve は true のみ） |
| `class_check` | ✅ | class 判定結果（auto-approve は no-merge のみ） |
| `scope_check` | ✅（#809 追加） | allowed_paths 判定結果。`in_scope`（priority 1.5 の scope 検査を実際に通過）/ `scope_violation`（逸脱検出）/ `unresolved`（ho-paths 未解決 fail-closed）/ `not_evaluated`（touches-HO 等 scope 検査より前で確定し未評価。既定値。`in_scope` と誤読させないため #809 敵対的レビュー minor 反映で導入）。auto-approve は `in_scope` のみ |
| `ho_paths_source` | ✅（#809 追加） | 解決された ho-paths.md のパス（未解決 fail-closed 時は `null`）。全裁定経路で刻む |
| `ho_pattern_count` | ✅（#809 追加） | 解決した HO パターン抽出件数（int。未解決時は 0）。「`boundary=clean` だが `ho_pattern_count=1`」のような過少網羅を監査で検知するための可視化フィールド（fail-closed 閾値そのものは 0 のまま — 導入先ごとに妥当な最小 HO クラス数が異なるため件数閾値化はしない） |
| `timestamp` | ✅ | 刻印日時（ISO 8601） |
| `w_check.severity` | C/D 時のみ | 不一致の severity 分類 |
| `w_check.model_c` | C/D 時のみ | Model C の判定 |
| `w_check.model_d` | C/D 時のみ | Model D の判定 |
| `w_check.reject_category` | model_b=reject 時のみ（omit 方式） | reject 理由カテゴリ（severity 分類の入力元。model_b=approve 時はキー自体を省略） |
| `run` | 任意（#780 追加・additive） | 呼び出し側入力の run メタをそのまま刻む。**省略時はキー自体を刻まない**（`null` も出力しない → metrics で legacy 分類）。`scripts/ai-loop/metrics.py`（#812）の run 単位集計（first-pass rate 等）の入力契約 |
| `run.run_id` | run 提供時のみ | 非空 string（run 単位の連番識別子。空文字・空白のみは入力エラー） |
| `run.round_index` | run 提供時のみ | int（bool 不可・必須）。**1 起点**（初回呼び出し=1、再試行ごとに +1）。`metrics.py` は round_index==1 を初回ラウンドの sentinel として first_pass を判定するため、0 起点にすると成功 run が恒久的に first_pass 分子から漏れる |
| `run.task_id` | run 提供時のみ | string（対象 PBI 識別子） |
| `run.repair_action` | run 提供時のみ・任意 | string（再試行時の修正内容の要約。初回 round には無いことが多い） |
| `gates` | 任意（#780 follow-up 追加・additive） | 呼び出し側入力の gates（priority 1.7 の plan-quality 判定に使う `{c1, breakdown}` 相当）を**生値のまま**刻む（dict でも非 dict でも判定せず記録のみ）。**省略時はキー自体を刻まない**（`null` も出力しない・`run` と同じ規約）。plan-quality gate で escalate した理由を provenance から監査・集計可能にする（Trust Ledger 強化）。判定ロジック（`plan_quality_check`）・`POLICY_REF` は変えない純粋な additive 拡張 |

### `target_sha` の計画時 vs 実装後の意味論（issue #782 P3）

- **計画時裁定（exec 前 C-3'）**: `target_sha` = 裁定対象計画が前提とする
  base commit（分岐元。通常は `origin/main` の HEAD）。「この基準点に対する
  計画」を固定する意味であり、実装コミットの代用ではない。計画時の
  差し替え検知は base 粒度に留まる（plan 粒度ではない）点に注意
- **再裁定・実装後**: `target_sha` = 裁定対象の実装 commit
- **値の制約**: null / 空は不可（`validate_input` の既存挙動は不変。
  コード変更は本項のスコープ外）

---

## 6. サーキットブレーカー

on-the-loop 固有の「自律暴走」防止機構。

### CB-1: 事後 reject（即時停止）

```text
トリガー : auto-approve 済みの変更を人間が事後 reject した
動作     :
  1. 当該 policy を即時一時停止（policy_suspended=true）
  2. 可能な範囲で巻き戻し実行（不可逆操作を除く）
  3. human review キューへ昇格（CB-1 フラグ付き）
  4. 人間が原因分析・policy 再承認するまで同一 policy の auto-approve を停止
復旧     : 人間が policy を再承認して policy_suspended=false に更新する
```

### CB-2: 連続 incident による policy 自動失効

```text
トリガー : 同一 policy で N 回連続の事後 reject（N はデフォルト 3、パラメータ化予定。
             同一バージョンの再承認ではカウントは累積し、新バージョン発行でのみリセット）
動作     :
  1. 当該 policy を自動失効（policy_expired=true）
  2. 失効ログを provenance に記録
  3. 以降、当該 policy を使った auto-approve を全面停止
  4. 全件 human escalate モードへフォールバック
復旧     : 人間が policy を再設計・再承認して新バージョンを発行する
目的     : 「自分の枠を自分で書き換えない」原則の維持（arbiter-policy.md §6 参照）
```

### CB-3: escalate 予算超過（全停止）

```text
トリガー : 全 policy 合算のグローバルな human escalate 件数が、
             スライディング時間窓内で予算上限 N 件を超過
動作     :
  1. 全 auto-approve を一時停止（circuit_open=true）
  2. サーキットブレーカー発火を CI / Workflow-owned に通知
  3. 人間がサーキットブレーカー状態を確認・リセットするまで停止継続
目的     : 異常検知による人間監督の強制
```

---

## 7. 関連ドキュメント

- [`docs/ai/ai-loop/arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) — W チェック・escalate 予算・第0の承認境界
- [`docs/ai/ai-loop/ho-paths.md`](../../ai/ai-loop/ho-paths.md) — boundary=touches-HO 判定の正本
- [`docs/workflows/ai-loop/flow-detect.md`](./flow-detect.md) — flow→detect→escalate の動作フロー（§3.2〜3.3: approve-reject の詳細）
- [`docs/workflows/ai-loop/lite-criteria.md`](./lite-criteria.md) — `lite` 軸の判定基準（可逆性要件含む）
- [`docs/workflows/ai-loop/00_concept.md`](./00_concept.md) — WF との並立関係
- [`docs/workflows/ai-loop/review-feedback-loop.md`](./review-feedback-loop.md) — CB-1 事後 reject を L4 学習へ還元する閉ループ（§3 で本ドキュメント §6 CB-1 と接続）
