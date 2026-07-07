# ai-loop Run-006 — LoopSpec + 計画（F-18: deterministic 欄の構造化・設計判断あり）

> **本 run は lite 自己判定を誠実に no_new_design=false とする**: deterministic の
> スキーマ変更（文字列リスト → 構造体）には複数の設計選択肢があり、Run-001 の教訓
> （スキーマ拡張 = new design）に照らし I-4 安全側に倒す。よって flow 段階で
> **human escalate が正しい挙動**であり、W チェックは実施せず設計選択肢を人間へ提示する。

## LoopSpec（骨子）

```yaml
loop:
  name: run-006-deterministic-schema
  trigger: {type: manual, detail: "F-18（#745 C-4 Gemini 指摘由来）の Optimize"}
  goal:
    description: "loopspec.md の verification.deterministic を『純粋コマンド + 期待値』の分離形式へ改定"
  actors: {maker: implementation_agent(sonnet), checker: w-check(A/B)}
  escalation: {touches_ho: unconditional, budget_ref: "arbiter-policy.md §7"}
```

- **boundary**: clean（docs/workflows/ai-loop/）
- **lite**: size_ok=true / **no_new_design=false（スキーマ設計の選択肢あり — 下記）** /
  follows_pattern=true / reversible=true
- **class**: no-merge

## Human への設計選択肢（escalate 事項）

| 案 | 形式 | 利点 | 欠点 |
|---|---|---|---|
| **A（推奨）** | 構造体: `- cmd: <純粋シェルコマンド>` / `expect_exit: <int・既定0>` / `note: <任意・人間可読>` | 機械実行可能（L3 自動実行への布石）・期待値が明示・注記の混入を構造で排除 | 既存 run 記録と形式が異なる（時点記録ゆえ移行不要） |
| B | 文字列リスト維持 + 規約「コマンドのみ・注記は別欄 notes に」 | 変更最小 | 規約頼み（Run-005 と同型の混入が再発しうる） |
| C | 並行リスト（commands / expects） | 単純 | 対応関係がインデックス頼みで壊れやすい |

推奨 **A**: F-18 の趣旨（そのままシェル実行可能）を構造で保証し、Run-004/005 で確立した
「AC 固定句・実機事前検証・証跡」の規律とも `note` 欄で両立する。

---

## Human 判断の記録（escalate 解消）

**2026-07-07 ユーザー回答: 「A」** — 構造体形式（`cmd` / `expect_exit` / `note`）を採用。
設計判断は human 承認済みとなったため、以降の実装は **no_new_design=true**（Run-002 の
先例: 方向性の human 決定後、run は実装のみを担う）。

## 確定計画（W チェック対象）

- **対象**: `docs/workflows/ai-loop/loopspec.md` 1 ファイルのみ
  1. §2 YAML の `deterministic` を構造体定義に置換:
     `- cmd: string`（純粋シェルコマンド・そのまま実行可能・注記や期待値を混ぜない）/
     `expect_exit: int`（任意・既定 0）/ `note: string`（任意・人間可読、実行に使わない）
  2. §3 フィールド定義表の `loop.verification.deterministic` 行を構造体仕様に更新し、
     `cmd` / `expect_exit` / `note` の 3 行を追加（既存表記規約 `loop.verification.deterministic[].cmd` 形式）
  3. §4 記入例の deterministic を新形式へ書き換え（例自体は living なテンプレート例であり
     run の時点記録ではない — 原則 11 の対象外）
  4. F-12/F-14 規律文（実機事前検証・証跡）は `cmd` に対して適用される旨を 1 文で接続
- **AC（実機事前検証済み・証跡は上記実行ログ）**:
  1. `grep -cF 'expect_exit' docs/workflows/ai-loop/loopspec.md` → **2 以上**（スキーマ+記入例。現状 0/exit1 実測・サンプル 1 実測）
  2. `grep -cF -- '- cmd:' docs/workflows/ai-loop/loopspec.md` → **2 以上**（現状 0/exit1 実測・サンプル 1 実測）
  3. markdownlint（repo 設定）→ 0 error
  4. `git diff --name-only origin/main` が loopspec.md + run 記録に収まる
- **lite（更新）**: size_ok=true / **no_new_design=true（human 承認済み設計の実装）** /
  follows_pattern=true / reversible=true
