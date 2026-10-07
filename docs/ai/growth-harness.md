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

| 段 | 名前 | 入力 | 出力 | 担当（責務 4 分類） | 起動条件 / 停止条件 |
| --- | --- | --- | --- | --- | --- |
| **L1** | 観測 | run の結果・摩擦・手戻り | improvement-seeds エントリ（単一形式） | AI-owned（下書き）+ Human-owned（`confirmed_by`） | 起動: WF-06 retro の opt-in run、または WF-05 handoff 発行時の下書き（§6 の 1）。停止: 人間が confirm しない下書きは追記しない |
| **L2** | 蓄積・整理 | `docs/working/improvement-seeds.md` | `docs/working/improvement-digest.md`（定期更新） | AI-owned（生成）+ Human-owned（digest PR の C-4） | 起動: WF-05 完了時、または seeds が前回 digest から **N = 5 件以上**増えたとき（**初期値・要調整**）。停止: 前回 digest 以降の seeds 増分が 0 件なら生成しない |
| **L3** | 還流 | 最新 digest | plan 生成・派遣プロンプトへの参照入力 / TC 昇格候補 / 却下済み仮説 | AI-owned（参照・候補生成）。HO 側の配線は Human-owned | 起動: plan 生成時・派遣プロンプト作成時。停止: digest が `superseded` とした知見は渡さない |
| **L4** | 採用判定 | 昇格候補 + 実行履歴 | 採用 / 不採用の記録（不採用は digest の却下欄へ） | CI-owned（Ratchet 検証）+ Human-owned（採用 PR の C-4） | 起動: 昇格候補が出たとき（PR #1495 マージ後）。停止: 検証待ちが **M = 3 run** 続いたら不採用で閉じる（**初期値・要調整**） |

### L1 観測: 記録形式を 1 つに寄せる

- 現在、学びの蓄積先は **2 系統**ある。WF-06 retro が書く `docs/working/improvement-seeds.md`
  （[`retro-phase.md`](./retro-phase.md) §2 の 5 項目 + `confirmed_by`）と、
  `AGENT_LEARNINGS.md`（独自形式「事実 / 再利用条件 / 根拠」、`AGENT_LEARNINGS.md` §記録フォーマット）。
- 方針: **新規の記録は seeds の 5 項目 + `confirmed_by` 形式に寄せる**。
  本ループは `AGENT_LEARNINGS.md` を書き換えない。`AGENT_LEARNINGS.md` 自身の更新規約
  （同ファイル §記録ルール 5）は変更しない。
  両者の対応は digest 側（L2）で参照関係として持つ（digest の各知見に出典として
  seeds の見出し / `AGENT_LEARNINGS.md` の見出しを併記する）。
- [`retro-phase.md`](./retro-phase.md) 提案 B（seeds への任意項目「プロセス教訓」）とは競合しない。
  提案 B が採用されても本書の対応表に 1 行足すだけで済む。
- 項目の対応（digest で参照関係を持つときの読み替え）:

| `AGENT_LEARNINGS.md` | improvement-seeds |
| --- | --- |
| 見出し | `## <date> — <task_id>` の見出し |
| 事実 | 失敗・手戻り / ツール・プロセス上の摩擦点 |
| 再利用条件 | 次回再利用すべき判断 |
| 根拠 | 効いた skill / gate / artifact（出典の PR・commit を併記） |
| （無し） | 目的達成可否 / `confirmed_by` は空欄とし、digest では「未 confirm」と表示する |

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
- **同型の失敗が 2 回出たら TC 昇格候補**にする。**昇格基準の正本は本書**。
  同型判定のみ `docs/ai/seeds-hygiene.md:37` の「同一の技術的原因」判定を参照する。
- L4 で不採用になった候補は digest の**却下欄**に残し、L3 で
  dispatch-template 要素 4 の「**却下済み仮説**」として派遣先へ渡す。
  これで L4 の結果が次の run の入力に戻り、ループが閉じる。
- digest は参照入力であり、承認境界を緩和する根拠にしない（seeds-hygiene §還流と同じ）。

### L4 採用判定: 予防効果を検証できたものだけ採用

- 昇格候補（TC / skill 追記 / docs 追記）は、ai-loop V2 Ratchet で
  **「この変更があれば当該失敗を検出・予防できた」ことを検証**してから採用する。
- 予防主張と検証の束縛（expected prevention claims）は PR #1495（未マージ）が担う。
  それまでは L4 は**未成立**として扱い、昇格候補は「検証待ち」で保留する。
- **検証できないものは採用しない**。不採用でも候補と理由は digest の却下欄に残す（L3 へ戻る）。
- 検証待ちが M run（§1 表、初期値 3）続いた候補は不採用で閉じる。

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
| roadmap §18 が完了状態と食い違う | 冒頭 Status は「すべて Done（EPIC #193 CLOSED）」だが §18 は「最初は PBI-HI-001: Metrics v1 から始める」と未着手前提のまま | `docs/ai/harness-improvement-roadmap.md:3` / §18（`:657`） |

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
| 1 | **L1 入力量の確保**: high-risk 以上は retro opt-in を推奨、WF-05 handoff の既知課題から seeds 下書きを作る（confirm は人間） | L1 | 非 HO（推奨の記述のみ。mode 連動の既定化は retro-phase 提案 A で HO） |
| 2 | hygiene の定期実行（生成 skill 化 + digest #002 生成、`superseded`・却下欄の導入、`AGENT_LEARNINGS.md` ↔ seeds の参照関係を digest に持たせる） | L1/L2 | 非 HO |
| 3 | docs と実装の不一致是正: `scripts/reporting.py` が seeds を読む（06_retro / working-context の記述に実装を合わせる） | L2 | 非 HO |
| 4 | L0 への digest 配線（#1157 §6.2 + 本書 HO patch 案） | L3 | **HO**（Human 適用） |
| 5 | dispatch-template 要素 4 に digest 参照（却下済み仮説を含む）を追加、2 回同型で TC 昇格候補を出す | L3 | 非 HO |
| 6 | PR #1495 マージ後、昇格候補を Ratchet で検証する接続 | L4 | 触るパス見込み: `scripts/ai-loop-v2/*.py`・`docs/ai/ai-loop-v2/`（非 HO）。CI 配線で `.github/workflows/*.yml` に及ぶなら HO。**確定するまで安全側で HO 扱い** |
| 7 | roadmap §18 を完了状態に同期 | 付随 | 非 HO |
