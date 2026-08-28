# C-1 セルフレビュー — TASK-1087 (#1087)

> 実施日: 2026-08-18 / Mode: **high-risk** → 17 項目フル実施
> 対象: `plan.md` / `todo.md` / `test-cases.md`（base `origin/main` = `387ea21`）

## 総合判定: **PASS**（WARN 2 / FAIL 0）

FAIL なし。WARN 2 件はいずれも **plan に明記済みの既知の残存ギャップ**であり、
本 PBI のスコープ外として handoff に上げる方針で整理済み。

---

## Plan チェック（7 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| **C1-PLAN-01** | 受入基準の網羅性 | PASS | AC-1〜12 を定義し、`test-cases.md` の冒頭マッピング表で全 AC に TC を対応付けた。未対応 AC なし |
| **C1-PLAN-02** | Unknowns の処理 | PASS | plan / pbi-input とも「Unknowns: なし」。**全件を実測して分類済み**（46 件 / 7 件）で推測に依存した箇所がない。issue 記載の「2 件」を鵜呑みにせず測り直し、7 件であることと**環境依存**という構造原因まで特定した |
| **C1-PLAN-03** | スコープ制御 | PASS | Out of scope を 5 項目明示（`hybrid-architecture.md` Rule 3/4 / `.codex/skills` untrack #1086 / enforcement 配布 #1144 / HO パスへの**適用** / 他ワーカー担当ファイル）。実装中に発見した `.claude/skills` ⇄ `.agents/skills` parity 欠如も**スコープに取り込まず**別 PBI として記録した |
| **C1-PLAN-04** | テスト戦略 | PASS | Unit（内蔵 selftest）/ Integration（ta-69）/ 回帰（ta-52）/ 変異注入 の 4 層。変異は**レーン全体とレーン内部の 2 系統**を分けて設計（diff-audit Phase 6 item 6 準拠） |
| **C1-PLAN-05** | Work Breakdown の Output | PASS | 「Files / Components to Touch」で 9 ファイル + patch を列挙し、各行に HO 該当有無を明記。触らないファイルも明示 |
| **C1-PLAN-06** | 依存関係 | PASS | todo.md の「⚠️ 依存関係」で T-13←T-12 / T-14,15←T-05〜13 / T-19,20←T-17,18 を明示。Human 側は **H-01 → H-02**（C-3 未承認の patch を適用しない）を明記 |
| **C1-PLAN-07** | 動作検証の自動化 | PASS | 全 TC が `sh tests/extras/ta-69-distribution-checks.sh` と 2 本の `--selftest` で自動実行可能。手動は evidence 記載 3 件（TC-E1/E2/E3）のみ |

---

## ToDo チェック（5 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| **C1-TODO-01** | タスク粒度 | PASS | T-01〜T-24。各タスクが 1 ファイル〜1 関心事に収まっている |
| **C1-TODO-02** | depends_on の設定 | PASS | 「⚠️ 依存関係」節に集約。順序違反が起きうる箇所（sync は正本編集の後 / 変異は TC の後）を特定済み |
| **C1-TODO-03** | チェックポイント | PASS | 🚩 を 9 箇所（T-03 / T-07 / T-10 / T-14 / T-15 / T-19 / T-20 / T-21 / T-23 / T-24）に設定。判定の分岐点と不可逆操作の直前に置いた |
| **C1-TODO-04** | Iron Law 遵守 | PASS | `.github/workflows/*` は **patch 提示のみ**（H-02 = Human-owned）。`c3.json` を発行しないことを T-24 に明記。`bin/plangate` / `scripts/hooks/*.sh` に触れない |
| **C1-TODO-05** | 完了条件 | PASS | rollback を high-risk の全実装タスクに記載。検証/読取のみのタスクは `rollback: 不要` と明記 |

---

## TestCases チェック（5 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| **C1-TC-01** | 受入基準との紐付き | PASS | 冒頭に AC → TC マッピング表。AC-1〜12 すべてに TC が対応 |
| **C1-TC-02** | Edge case 網羅 | PASS | frontmatter 無し / README.md 除外 / 複数 plugin / kind 違いの同名（`codex-mvp-split` が command と skill に存在）/ git 不在（TC-S9）/ gitignore パターン近傍の typo（TC-S8） |
| **C1-TC-03** | 自動化可否 | PASS | 手動は TC-E1/E2/E3（evidence 記載の確認）のみ。残りは全て自動 |
| **C1-TC-04** | 負側 TC の本番経路 | PASS | ta-69 は全 TC を**引数なしの既定経路**で起動。サンドボックスは `REPO_ROOT` ごと切替（ta-52 と同方式）。**M4 / M3 の変異が本番ツリー TC（TC-S1）を落とした**ことで、負側の検出力が本番経路にあることを実測裏付け |
| **C1-TC-05** | 件数 assert の不在 | PASS | `46` / `7` の等値比較なし。rc と `grep` による集合の性質で契約 |

---

## 指摘事項

### WARN-1: skill レーンのミラー内容 drift が未担保のまま残る

ミラー除外により、`.claude/skills/X` ⇄ `plugin/plangate/skills/X` の内容差は
collisions で見なくなる。agent / command は `drift-check` job が `exit 1` で担保するが、
**skill だけは plugin の正本が `.agents/skills/` であり、
`.claude/skills` ⇄ `.agents/skills` の parity 検査が存在しない**。

- **本 PBI が担保を奪ったわけではない**: 変更前の collisions も description しか見ておらず、
  本文 drift は元から見ていなかった。46 件常時 rc=1 が**偶然そこに居ただけ**
- 実測で確認された 3 件の description 差分はすべてこの未担保レーンにある
- plan.md「M-1b」および `docs/ai/skill-collision-detection.md` に明記し、
  **別 PBI（#1144 / #1086 と同じ配布レーン整理の領域）**として handoff に上げる

→ **スコープに取り込まない判断**。本 PBI は「検知器を実態に合わせる」ことが目的で、
新しい検査の新設は別の設計判断を要する。

### WARN-2: `claude plugin validate --strict` は現時点で配線できない

実測（2026-08-18）:

| コマンド | rc |
|---------|-----|
| `claude plugin validate plugin/plangate` | **0**（7 warnings） |
| `claude plugin validate --strict plugin/plangate` | **1** |

7 warnings の内訳は `agents/README.md` / `commands/README.md`（validator が
README を定義ファイルとして扱うことによるもの）と、**frontmatter を持たない
5 つの command**（`working-context` / `ai-loop-workflow` / `ai-dev-workflow` /
`codex-mvp-split` / `plangate-setup`）。

後者は**配布物の実害**である（command が description なしで配布される。
collisions の全件分類でこの 5 件の description が空だったことと一致）。
しかし正本は `.claude/commands/*.md` = **Hardening Override 対象**であり
**AI は修正できない**。

→ CI 配線 patch は **non-strict を hard gate として配線**し、
`--strict` は「7 warnings 解消後」の follow-up として明記した。
**non-strict では 7 warnings を検出しない**ことを patch のコメントと
handoff に残す（黙って緑にしない）。

---

## Iron Law / 承認境界の確認

| 確認項目 | 結果 |
|---------|------|
| `.github/workflows/*` を編集していないか | ✅ 未編集。patch 生成はスクラッチパッド上のコピーで行い、`git status .github/` は clean |
| `bin/plangate` / `scripts/hooks/*.sh` / `schemas/*.schema.json` に触れていないか | ✅ 未変更 |
| `.claude/rules/*.md` / `CLAUDE.md` / `AGENTS.md` に触れていないか | ✅ 未変更 |
| `.claude/commands/*.md` / `.claude/agents/*.md` に触れていないか | ✅ 未変更 |
| `c3.json` を発行していないか | ✅ 未発行（high-risk = 人間 C-3 必須） |
| 他ワーカー担当ファイルに触れていないか | ✅ `scripts/check-approval-token-write.sh` / `tests/extras/ta-25-*` 未変更 |
| `--warn-only` 相当の握り潰しを新設していないか | ✅ 新設なし。除外分は INFO として印字し、M3b 変異でその契約を守っている |

## exec 可否

**C-1 PASS。** ただし Mode = `high-risk` のため
`lite_eligible=false` / autonomous APPROVE 不可 / **C-3 は人間必須**。
本ワーカーは `c3.json` を発行しない。
