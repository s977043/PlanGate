# Growth Harness（エージェント自律成長ループ）設計正本

> 本書は、エージェントが run を重ねるごとに**同型の失敗を減らしていく**ための
> ハーネス設計である。新しい蓄積先・新しい承認経路は作らない。既存の
> [`retro-phase.md`](./retro-phase.md)（WF-06 / improvement-seeds）・
> [`seeds-hygiene.md`](./seeds-hygiene.md)（統合フェーズ / digest）・
> [`subagent-delegation/dispatch-template.md`](./subagent-delegation/dispatch-template.md)・
> ai-loop V2 Ratchet を、途切れている箇所でつなぐ配線設計に限定する。
> Status: **設計のみ**（実装・HO 適用は後続 PBI）。測定基準: `origin/main` = `7fad3e71`（2026-10-07）。

## 0. 結論（先に）

| 項目 | 結論 |
| --- | --- |
| 構造 | **L1 観測 → L2 蓄積・整理 → L3 還流 → L4 採用判定** の 4 段ループ |
| AI が自律でやること | **候補生成**と、**非 HO 層**（`.claude/skills/` / `docs/ai/` / `AGENT_LEARNINGS.md` / seeds・digest）への反映提案のみ |
| AI がやらないこと | C-3 / C-4 / merge の判断、HO 対象パスの編集。HO 対象は [`ho-apply-script`](../../.claude/skills/ho-apply-script/SKILL.md) の型で patch / script を提示し **Human が適用** |
| 採用の基準 | L4 で**予防効果を検証できたものだけ**採用。検証できないものは採用しない（記録には残す） |
| 現状 | ループは**各段の間で途切れている**（§2）。後続 PBI は L2 → L3 の順に着手（§6） |

## 1. 4 段ループ

| 段 | 名前 | 入力 | 出力 | 担当（責務 4 分類） |
| --- | --- | --- | --- | --- |
| **L1** | 観測 | run の結果・摩擦・手戻り | improvement-seeds エントリ（単一形式） | AI-owned（下書き）+ Human-owned（`confirmed_by`） |
| **L2** | 蓄積・整理 | `docs/working/improvement-seeds.md` | `docs/working/improvement-digest.md`（定期更新） | AI-owned（生成）+ Human-owned（digest PR の C-4） |
| **L3** | 還流 | 最新 digest | plan 生成・派遣プロンプトへの参照入力 / TC 昇格候補 | AI-owned（参照・候補生成）。HO 側の配線は Human-owned |
| **L4** | 採用判定 | 昇格候補 + 実行履歴 | 採用 / 不採用の記録 | CI-owned（Ratchet 検証）+ Human-owned（採用 PR の C-4） |

### L1 観測: 記録形式を 1 つに寄せる

- 現在、学びの蓄積先は **2 系統**ある。WF-06 retro が書く `docs/working/improvement-seeds.md`
  （[`retro-phase.md`](./retro-phase.md) §2 の 5 項目 + `confirmed_by`）と、
  `AGENT_LEARNINGS.md`（独自形式「事実 / 再利用条件 / 根拠」、`AGENT_LEARNINGS.md` §記録フォーマット）。
- 方針: **新規の記録は seeds の 5 項目 + `confirmed_by` 形式に寄せる**。
  `AGENT_LEARNINGS.md` の既存エントリは**削除も書き換えもしない**。
  両者の対応は digest 側（L2）で参照関係として持つ（digest の各知見に出典として
  seeds の見出し / `AGENT_LEARNINGS.md` の見出しを併記する）。
- `AGENT_LEARNINGS.md` は「Codex がそのまま使える検証済み知見」の**閲覧面**として残し、
  一次記録は seeds とする。二重記録をしない。

### L2 蓄積・整理: hygiene を定期実行する

- [`seeds-hygiene.md`](./seeds-hygiene.md) の処理（重複統合 / 矛盾検出 / 陳腐化判定）を
  **定期実行**して digest を更新する。現状は手動 1 回きり（§2）。
- 生成は AI、採用は digest PR の C-4（Human）。seeds 本体は不変（append-only）。
- 陳腐化した知見の無効化は #1157 設計の `superseded` マーク（派生層のみ）に従う。

### L3 還流: digest を読ませる

- 読み手は 2 つ: **plan 生成**（フェーズ B の Work Breakdown / Risks の参考入力。
  [`seeds-hygiene.md`](./seeds-hygiene.md) §還流）と、**派遣プロンプト**
  （[`dispatch-template.md`](./subagent-delegation/dispatch-template.md) 要素 4
  「既知の事実・確定済み結論・却下済み仮説」の材料）。
- **同型の失敗が 2 回出たら TC 昇格候補**にする。同型判定は seeds-hygiene の
  「同一の技術的原因」判定を流用する（2 回以上の記録で「恒常運用へ昇格すべき候補」）。
- digest は参照入力であり、承認境界を緩和する根拠にしない（seeds-hygiene §還流と同じ）。

### L4 採用判定: 予防効果を検証できたものだけ採用

- 昇格候補（TC / skill 追記 / docs 追記）は、ai-loop V2 Ratchet で
  **「この変更があれば当該失敗を検出・予防できた」ことを検証**してから採用する。
- 予防主張と検証の束縛（expected prevention claims）は PR #1495（未マージ）が担う。
  それまでは L4 は**未成立**として扱い、昇格候補は「検証待ち」で保留する。
- **検証できないものは採用しない**。不採用でも候補と理由は digest に残す。

## 不変条件

1. C-3 / C-4 / HO / merge の Human 承認を**弱めない**。本ループのどの出力も承認の代替にならない。
2. AI の自律範囲は**候補生成と非 HO 層への反映**のみ。
3. HO 対象（[`mode-classification.md`](../../.claude/rules/mode-classification.md) の 12 カテゴリ）への
   変更は ho-apply-script の型で提示し、Human が適用する。
4. seeds は append-only。統合・無効化は派生層（digest）でのみ行う。

## 2. 現状の途切れ（実測根拠）

| 途切れ | 実測 | 根拠 |
| --- | --- | --- |
| reporting は seeds を読まない | `scripts/reporting.py` に `seed` の出現 0 件（大小区別なし）。`:313` は「次の harness improvement PBI 候補」の**見出し文字列**のみ | `scripts/reporting.py:313` |
| …が、docs は入力源と書く | 06_retro は受け取り先を「#200 期間集計 CLI（improvement-seeds.md を入力源に吸い上げ）」、working-context は「#200 期間集計の入力源」と記述 | `docs/workflows/06_retro.md:47` / `.claude/rules/working-context.md:240` |
| seeds の読み出し経路が未適用 | L0 への digest 配線は設計書のみ（「設計書のみ（実装・適用は含まない）」）。working-context の L0 行は `INDEX.md → current-state.md` のまま | `docs/working/_reports/1157-seeds-read-path-patch.md:4` / §6.2、`.claude/rules/working-context.md:116` |
| digest は 1 回きり | digest は #754 / PR #761 で生成されたサンプル #001 のみ、以後更新 0 回。生成 skill / CLI も無い | `docs/working/_reports/1157-seeds-read-path-patch.md` §1.1–1.2 |
| retro は既定 OFF | WF-06 は opt-in 既定 OFF。未 opt-in の run では seeds が書かれない | `docs/ai/retro-phase.md:6` |
| L4 の検証部品が未マージ | Ratchet 本体（`scripts/ai-loop-v2/ratchet.py`、#1488 / #1491）は main にあるが、予防主張の束縛は PR #1495（OPEN）で main に不在 | `scripts/ai-loop-v2/ratchet.py`、PR #1495 |
| roadmap §18 が完了状態と食い違う | 冒頭 Status は「すべて Done（EPIC #193 CLOSED）」だが §18 は「最初は PBI-HI-001: Metrics v1 から始める」と未着手前提のまま | `docs/ai/harness-improvement-roadmap.md:3` / `:655` |

## 3. 既存資産との関係（重複させない）

| 既存 | 本書での扱い |
| --- | --- |
| [`retro-phase.md`](./retro-phase.md) | L1 の記録形式の正本。変更しない |
| [`seeds-hygiene.md`](./seeds-hygiene.md) | L2 の処理正本。本書は「定期実行」と「L3 への接続」だけを足す |
| `docs/working/_reports/1157-seeds-read-path-patch.md` | L3 の L0 配線の正本設計。本書の HO patch 案はこれを前提に差分だけを足す |
| `AGENT_LEARNINGS.md` | 既存エントリは保持。新規の一次記録は seeds へ |
| ai-loop V2 Ratchet | L4 の検証器。本書は呼び出し条件だけを定める |

## 4. HO 側の変更案

`.claude/rules/working-context.md` への差分案は
[`docs/working/_reports/growth-harness-ho-patch.md`](../working/_reports/growth-harness-ho-patch.md)。
**AI は適用しない**。

## 5. 残存脅威モデル

本ループは多層防御の 1 層であり、完全性を主張しない。保証の主体は C-3 / C-4 の Human レビューと
CI、HO の Human 適用である。

| 守るもの | 守らないもの |
| --- | --- |
| 同型の失敗が記録・統合されず再発する経路（L1〜L3 の配線） | 初出の失敗（1 回目は防げない） |
| 検証されない知見が規範として固定されること（L4 で不採用） | digest の誤った知見を人間が C-4 で見逃した場合 |
| AI が自分の学びを根拠に承認境界を緩めること（不変条件 1〜3） | retro を opt-in しない run の学び（L1 に入らない） |
| seeds 原文の改ざん（append-only・派生層でのみ無効化） | Ratchet が表現できない失敗クラス（実 API 形状・タイミング等） |

## 6. 後続 PBI 候補（L2 → L3 の順）

| 順 | 候補 | 層 | HO |
| --- | --- | --- | --- |
| 1 | hygiene の定期実行（生成 skill 化 + digest #002 生成、`superseded` 導入） | L2 | 非 HO |
| 2 | `AGENT_LEARNINGS.md` ↔ seeds の参照関係を digest に持たせる | L1/L2 | 非 HO |
| 3 | `scripts/reporting.py` が seeds を読む（docs の記述と実装を一致させる） | L2 | 非 HO |
| 4 | L0 への digest 配線（#1157 §6.2 + 本書 HO patch 案） | L3 | **HO**（Human 適用） |
| 5 | dispatch-template 要素 4 に digest 参照を追加、2 回同型で TC 昇格候補を出す | L3 | 非 HO |
| 6 | PR #1495 マージ後、昇格候補を Ratchet で検証する接続 | L4 | 要確認 |
| 7 | roadmap §18 を完了状態に同期 | 付随 | 非 HO |
