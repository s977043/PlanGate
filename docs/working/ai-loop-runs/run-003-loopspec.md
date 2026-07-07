# ai-loop Run-003 — LoopSpec + 計画（F-10 Optimize: provenance schema 拡張）

> **本 run の性質**: 摩擦記録（F-10・C-4 レビュー指摘由来）から生まれた Optimize を
> ai-loop 自身のサイクルで実装する — Remember→Optimize の I-5 ループの実装編。
> **初のコード（非 docs）run**。
> Run-002 摩擦の Optimize を反映: **F-7**（AC はテストスイートで範囲厳密に機械検証）/
> **F-8**（配置の選択肢なし — フィールドは `w_check.reject_category` に一意確定）。

## LoopSpec

```yaml
loop:
  name: run-003-provenance-reject-category
  trigger:
    type: manual
    detail: "F-10（decision record に reject_category 欠落・#738 C-4 レビュー指摘由来）の Optimize 実装"
  goal:
    description: "arbiter.py の provenance 出力 w_check に reject_category を追加し（model_b=reject 時のみ値・それ以外 null）、record 単体で severity 分類根拠を追跡可能にする"
    exit_criteria_ref: "00_concept.md §3.3 + 本書 AC 1-5（全て機械検証）"
  context:
    include:
      - run_frictions # F-10 の内容と「手編集は改竄」の判断
      - design_docs # decision-table.md §5 provenance schema
      - diff
    exclude:
      - stale_tool_outputs
  actors:
    maker: implementation_agent(sonnet)
    checker: w-check(model_a=sonnet-forward, model_b=sonnet-adversarial)
  verification:
    deterministic:
      - "python3 scripts/ai-loop/test_arbiter.py → 全 PASS（既存 59 + 新規）"
      - "新規テスト: model_b=reject 時に provenance.w_check.reject_category が入力値と一致"
      - "新規テスト: model_b=approve 時に reject_category が null（または省略でなく null 明示）"
      - "後方互換: 既存 59 テストが変更なしで PASS（既存フィールドの削除・改名ゼロ）"
      - "python3 scripts/ai-loop/arbiter.py --input <run-002 と同等入力> の出力に reject_category が含まれる（手動 smoke）"
    review:
      - requirements_fit
      - backward_compat # 既存 record 消費側（docs 参照・監査）を壊さない
  stopping_rule:
    terminal_state_ref: "decision-table.md（AUTO_APPROVED / HUMAN_ESCALATED / BLOCKED）"
    round_limit_ref: "execution-runbook.md §2-(7) Scheduling 判断表（上限3）"
  memory:
    write:
      - decision_record
      - run_frictions
    ref: "execution-runbook.md §2-(4)（L4 学習側: review-feedback-loop.md）"
  escalation:
    touches_ho: unconditional
    budget_ref: "arbiter-policy.md §7"
```

## 計画

- **Goal**: 上記のとおり。**decision-table.md §5（provenance schema の正本 doc）にも
  同フィールドを additive 追記**し、コードと正本 doc の宣言↔実態を一致させる（I-9）。
- **Non-goals**: 既存 decision record（過去 run の JSON）の遡及修正（改竄禁止）。
  provenance の発行元署名（#733 条件1 の領域・別 PBI）。severity マッピング自体の変更。
- **AC（機械検証 — F-7 反映）**:
  1. `w_check.reject_category` が model_b=reject 時に入力値で出力される（新規テスト）
  2. model_b=approve 時は null（新規テスト）
  3. 既存 59 テストが無修正で PASS（後方互換）
  4. decision-table.md §5 に同フィールドが additive 追記されている（grep を §5 範囲に限定:
     `sed -n '/§5\|## 5/,/## 6/p'` で切り出してから grep — F-7 の範囲厳密化）
  5. run-002 相当入力での smoke 実行で新フィールドを目視確認
- **Files（Expected Diff・一意確定 — F-8 反映）**:
  `scripts/ai-loop/arbiter.py` / `scripts/ai-loop/test_arbiter.py` /
  `docs/workflows/ai-loop/decision-table.md`（§5 のみ）の 3 ファイル
- **lite 4 軸**: size_ok=true（3 files）/ no_new_design=true（既存 schema への additive
  フィールド 1 件・既存テスト構造踏襲・配置は一意確定済み）/ follows_pattern=true /
  reversible=true（additive・revert 容易。過去 record は触らない）
- **boundary**: clean（scripts/ai-loop/ は ho-paths.md の HO 一覧に非該当 —
  bin/plangate・scripts/hooks/ と異なる。decision-table.md は docs/workflows/ai-loop/ 配下）
- **class**: no-merge

---

## Round 2 改訂（W チェック Round 1: A=approve / B=reject(test_shortage) を受けた計画修正）

> Round 1 の本文は監査記録として不変。本節が Round 2 の確定計画（W チェックは本節込みで再実施）。
> B の指摘 4 点を全採用:

### 改訂 1 — AC-4 のコマンドを portable 化（B 観点 2: BSD sed で 0 行を実機実証）

旧: `sed -n '/§5\|## 5/,/## 6/p'`（BSD sed で alternation 非対応・サイレントに空）
新: **`awk '/^## 5\./,/^## 6\./' docs/workflows/ai-loop/decision-table.md`**（BSD/GNU 両対応・
本 host で 58 行を返すことを実証済み）。さらに「コード例に文字列があるだけ」を弾くため、
**フィールド定義表の行として** `grep '| \`reject_category\`'` を範囲内で要求する。

### 改訂 2 — 表現規約を既存の omit 方式に統一（B 観点 1/3: omit vs null の規約不統一）

旧: model_b=approve 時は「null 明示」
新: **既存の severity / model_c / model_d と同じ「該当時のみ key を出力（それ以外は省略）」**
（`if reject_category is not None` — arbiter.py L308 の既存パターン踏襲）。
新規約を導入しないことで no_new_design=true の根拠を回復し、#733 将来 HMAC 署名の
キャノニカライズにも規約ブレを持ち込まない。AC-2 を「model_b=approve 時は key 不在」に変更。

### 改訂 3 — 一貫性テストを AC に追加（B 観点 4: テスト過小）

新 AC-6: **arbitrate() を end-to-end で通した record に対し、
`w_check.severity == classify_severity(w_check.reject_category)` が成り立つ**ことを検証する
テストを追加（build_provenance 直呼びでは検知できない「severity と category の食い違い
リグレッション」を record レベルで捕捉 — F-10 の本来目的への充足）。

### 改訂 4 — boundary 判定への構造的注記（B 観点 5: I-1 消去法判定の懸念）

boundary=clean（ho-paths 一覧非該当）は維持するが、以下を明記する:
**本 run は「裁定エンジンの記録方式を裁定エンジン自身のガバナンスで変更する」自己参照構造を持つ。
歯止め: severity マッピング・裁定ロジック（decision table 優先順位）は Non-goals として不変。
裁定ロジック自体の変更を今後同経路で通してよいかは、#739（ho-paths 曖昧性）/ #733 の
Human 判断領域として摩擦記録（F-11）に残す。**

### Round 2 の確定 AC（機械検証）

1. `w_check.reject_category` が model_b=reject 時に入力値で出力される（新規テスト）
2. model_b=approve 時は **key 不在**（omit・新規テスト）
3. 既存 59 テストが無修正で PASS
4. `awk '/^## 5\./,/^## 6\./'` 切り出し範囲に `| \`reject_category\`` のフィールド定義行が存在
5. run-002 相当入力での smoke 実行で新フィールドを確認
6. arbitrate() e2e で `severity == classify_severity(reject_category)`（一貫性テスト）

---

## Round 3 改訂（最終ラウンド。R2: A=reject(naming) / B=reject(logic) — 同一欠陥に独立到達）

> R2 の reject-reject 合意は arbiter で BLOCKED として刻印済み（`*-run003-r2.json`）。
> 両者が独立に実機再現した欠陥は 1 点に収束: **AC-4 の grep パターンが §5 の既存命名規約
> （`w_check.` プレフィックス付き）と不整合で、規約準拠の正しい実装を FAIL 判定する**。

### 改訂 5 — AC-4 の grep パターンを規約準拠に修正

新 AC-4: `awk '/^## 5\./,/^## 6\./' docs/workflows/ai-loop/decision-table.md | grep -F '`w_check.reject_category`'`
が 1 行以上を返す（既存表の `w_check.severity` / `w_check.model_c` と同じプレフィックス付き表記）。

### 改訂 6 — AC-6 の性質を明記（B R2 観点 3）

AC-6 の一貫性テストは **配線検証**（reject_category が record まで正しく伝播し severity と
整合すること）であり、**SEVERITY_MAP 自体の妥当性検証ではない**（マッピング変更は Non-goals。
マッピングの誤りはテストと実装が classify_severity を共有するため本テストでは共倒れ PASS する）。

### 改訂 7 — F-11 に構造的ゲート提案を含める（B R2 観点 4）

「注記して通す」の前例化を防ぐため、F-11 の摩擦記録に **「arbiter.py の判断ロジック
（decision table 優先順位・SEVERITY_MAP）変更は touches_ho:unconditional 相当の固定ルール化を
Human 判断で検討」** という構造的ゲート昇格の提案を含める（本 run では advisory・採否は人間）。
