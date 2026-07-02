# decision-table — Arbiter 裁定 Decision table

> 適用ドメイン: ai-loop-workflow（docs/workflows/ai-loop/ 配下）のみ
> 非適用: PlanGate 本番フロー（WF-00〜WF-07）
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
policy_ref:         auto-approve-lite-clean@v0（適用 policy 名 + バージョン）
w_check:
  model_a: approve
  model_b: approve
boundary_check:     clean
target_sha:         <変更対象コミット SHA（差し替え検知用）>
lite_check:         true
class_check:        no-merge
timestamp:          <ISO 8601>
```

### C/D 裁定時の追加フィールド（severity=minor/low 時のみ）

```text
w_check:
  model_a:   approve
  model_b:   reject
  severity:  low / minor
  model_c:   approve
  model_d:   approve
```

### フィールド定義

| フィールド | 必須 | 説明 |
| ----------- | ------ | ------ |
| `decision` | ✅ | 最終裁定値（3 値） |
| `issued_by` | ✅ | 判断エンジンの識別・追跡用（真正性担保には署名等が別途必要） |
| `policy_ref` | ✅ | 適用 policy 名とバージョン（policy 自動失効の追跡用） |
| `w_check` | ✅ | W チェック（A/B）の判定と、C/D 裁定時の詳細 |
| `w_check.model_a` | ✅ | Model A の判定結果 |
| `w_check.model_b` | ✅ | Model B の判定結果 |
| `target_sha` | ✅ | 対象コミット SHA（差し替え検知用。replay 攻撃は検知・別途防止機構が必要） |
| `boundary_check` | ✅ | boundary 判定結果（auto-approve は clean のみ） |
| `lite_check` | ✅ | lite 判定結果（auto-approve は true のみ） |
| `class_check` | ✅ | class 判定結果（auto-approve は no-merge のみ） |
| `timestamp` | ✅ | 刻印日時（ISO 8601） |
| `w_check.severity` | C/D 時のみ | 不一致の severity 分類 |
| `w_check.model_c` | C/D 時のみ | Model C の判定 |
| `w_check.model_d` | C/D 時のみ | Model D の判定 |

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
- [`docs/workflows/ai-loop/00_concept.md`](./00_concept.md) — WF との並立関係
- [`docs/workflows/ai-loop/review-feedback-loop.md`](./review-feedback-loop.md) — CB-1 事後 reject を L4 学習へ還元する閉ループ（§3 で本ドキュメント §6 CB-1 と接続）
