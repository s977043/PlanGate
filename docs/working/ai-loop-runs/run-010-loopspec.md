# ai-loop Run-010 — LoopSpec + 計画（#753 gap 1: memory trust boundary の機構化・設計判断あり）

> **escalate 第 2 型**（Run-006/008 先例）: スキーマ設計の選択肢があるため lite を誠実に
> no_new_design=false と申告し、W チェック前に human へ設計選択を昇格する。
> 語彙は design-philosophy §5 で確定済み（正本=ro / 生成 memory=rw / 外部入力=隔離対象）。
> 本 run はその **LoopSpec 上の宣言機構**を決める。

## LoopSpec（骨子）

```yaml
loop:
  name: run-010-memory-trust-boundary
  trigger: {type: manual, detail: "#753 gap 1（#751 intake 由来）の機構化"}
  goal:
    description: "外部入力由来コンテキストの宣言と、memory への転記規律を LoopSpec に定義する"
  actors: {maker: implementation_agent(sonnet), checker: w-check(A/B)}
  escalation: {touches_ho: unconditional, budget_ref: "arbiter-policy.md §7"}
```

- **boundary**: clean（docs/workflows/ai-loop/loopspec.md）
- **lite**: size_ok=true / **no_new_design=false（宣言機構の設計選択 — 下記）** /
  follows_pattern=true / reversible=true
- **class**: no-merge

## Human への設計選択肢（escalate 事項）

| 案 | 内容 | 利点 | 欠点 |
|---|---|---|---|
| A | `context.include` を構造体化（`- src:` / `trust: internal\|external`） | 全 include に信頼区分を強制（漏れなし） | 既存キーの再構造化（Run-006 の deterministic と同型の変更・記入例/雛形の書換え幅が大きい） |
| **B（推奨）** | 新キー **`context.external_sources`**（外部入力由来を**別リストで明示宣言**・既存 include は internal 専用と定義）+ 転記規律 1 文「external_sources の内容は memory（decision record / plan-memory / frictions）へ**直接転記せず、出典 URL/ID つき引用**として記録する」 | additive（既存キー不変）・「外部」を**書かないと宣言漏れが露出する**構造・enforcement は W チェック観点（checker が external→memory 直接転記を検査）+ 既存の証跡規律（F-14）に接続 | include との二重管理（ただし用途が異なるため許容） |
| C | 機構化見送り（§5 語彙 + 運用規律のみ） | 変更ゼロ | 宣言が構造化されず、checker の検査対象が曖昧なまま |

推奨 **B**: allowed_paths（Run-008）と同じ「**宣言 + 既存 enforcement への接続**」パターン。
external_sources の宣言は W チェック（Model B の攻撃観点に「external→memory 直接転記の有無」を
追加できる）と F-14（出典つき記録）という実在する検査に直結し、include の再構造化コストを避ける。

---

## Human 判断の記録（escalate 解消）

**2026-07-07 ユーザー回答: 「B」** — `context.external_sources`（別リスト明示宣言）+
転記規律（出典つき引用）。以降 **no_new_design=true**（Run-002/006/008 先例）。

## 確定計画（W チェック対象）

- **対象 2 ファイル**（enforcement の実体化まで含める）:
  1. `docs/workflows/ai-loop/loopspec.md`:
     - §2 YAML — `context.exclude` の直後に `external_sources:`（**必須・空配列可だが明示必須** —
       exclude と同じ「黙示を許さない」I-4 型）を追加。コメント例: issue#NNN 本文 / PR#NNN コメント /
       外部レビュー生テキスト。`include` のコメントを「internal（正本・生成 memory 由来）専用」に補強
     - §3 表 — `loop.context.external_sources` 行を追加: 転記規律
       「**external_sources の内容は memory（decision record / plan-memory / frictions）へ
       直接転記せず、出典つき引用（URL/ID + 引用範囲）として記録する**（F-14 の証跡規律に接続。
       W チェック Model B の検査対象）」
     - §4 記入例 — `external_sources: []`（docs-only 例では空・明示）を追加
  2. `.claude/skills/ai-loop-cycle/SKILL.md` — Model B 定型の観点に 1 文追加:
     「LoopSpec の external_sources 由来の内容が memory へ出典なしで直接転記されていないか検査する。」
- **AC（実機事前検証済み・証跡は直上ログ）**:
  1. `test "$(grep -cF 'external_sources' docs/workflows/ai-loop/loopspec.md)" -ge 3` → exit 0
     （現状 0/exit1・サンプル 3 件で exit 0 実測）
  2. `grep -cF 'external_sources' .claude/skills/ai-loop-cycle/SKILL.md` → 1 以上（現状 0 実測）
  3. `grep -cF '出典つき引用' docs/workflows/ai-loop/loopspec.md` → 1 以上（現状 0 実測）
  4. markdownlint 0 / diff が宣言 2 ファイル + run 記録に収まる
- **lite（更新）**: size_ok=true / **no_new_design=true** / follows_pattern=true / reversible=true

---

## Round 2 改訂（R1: A=approve / B=reject(documentation) — 実効性 3 欠落を全採用）

### 改訂 1 — 判定不能時の既定を I-4 で固定（B 観点 1）

§3 の external_sources 規律に追記する: 「**internal / external の判定に迷う場合は
external 側に倒す（I-4）**。過去の run 記録・frictions に**出典つき引用として記録済み**の
外部テキストは internal（生成 memory 由来）として扱ってよいが、**生テキストの再持ち込み**は
external として再宣言する。」

### 改訂 2 — 検査手順の具体化（B 観点 2）

SKILL.md Model B への追加文を検査手順込みに強化: 「LoopSpec の external_sources に
列挙された出典について、**memory 書込物（decision record・frictions・run 記録への追記分）の
diff を対象に、当該出典の内容がコピーされている箇所を探し、出典（URL / issue・PR 番号）の
併記がない転記があれば違反として指摘する**。」

### 改訂 3 — 残余リスクの明記（B 観点 3）

loopspec §3 規律の直後に既知の限界を明記: 「**本機構は宣言された external_sources のみを
対象とする。宣言し忘れた外部入力（exec 中の web / gh 読取等）は本機構の検査対象外**であり、
maker の誠実申告と checker の突合という多層防御を前提とする（F-17 と同族の限界。
完全な遮断は L3 のサンドボックス設計で扱う）。」

### 改訂 4 — exclude との優先関係（B 観点 4・R1 攻撃観点の残り）

「同一情報源を exclude と external_sources の両方に書いた場合は **exclude が優先**
（見せない > 見せるが隔離）。」を §3 に 1 文追加。

### Round 2 の確定 AC（追加分・実機事前検証済み）

- AC-5: `grep -cF 'external 側に倒す' docs/workflows/ai-loop/loopspec.md` → 1 以上（現状 0 実測）
- AC-6: `grep -cF '検査対象外' docs/workflows/ai-loop/loopspec.md` → 1 以上（現状 0 実測）
- AC-7: `grep -cF 'exclude が優先' docs/workflows/ai-loop/loopspec.md` → 1 以上（現状 0 実測）
- AC-8: SKILL.md 追加文に「diff を対象に」が含まれる: `grep -cF 'diff を対象に' .claude/skills/ai-loop-cycle/SKILL.md` → 1 以上（現状 0 実測）

---

## Round 3 改訂（最終。R2: A=approve / B=reject(documentation) — 検査限界 2 点の無開示）

### 改訂 5 — 検査の限界を改訂 3 と同型で明示（B R2 処方を採用）

改訂 3 の残余リスク文に続けて以下を追加する（loopspec §3・SKILL.md 追加文の双方に反映）:

「**checker の機械的検査は逐語（または高一致率）コピーの検出に限られる。
言い換え転記（意味を保ち字面を変えた転記）と、引用再利用か再フェッチかの provenance の
真偽は checker では判別できず、maker の誠実申告に依存する**（F-17 と同族の限界）。
本機構は『宣言と逐語検査で捕捉できる汚染』を減らすものであり、それ以上の保証を主張しない。」

### Round 3 の追加 AC（実機事前検証済み）

- AC-9: `grep -cF '言い換え転記' docs/workflows/ai-loop/loopspec.md` → 1 以上（現状 0 実測）
- AC-10: `grep -cF '誠実申告に依存' docs/workflows/ai-loop/loopspec.md` → 1 以上（現状 0 実測）
