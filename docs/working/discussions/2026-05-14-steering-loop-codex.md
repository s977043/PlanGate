# Steering Loop 強化に関する Claude Code × Codex ディスカッション

- 日時: 2026-05-14
- 主題: PlanGate Steering Loop の強化方針を、既存ロードマップ・Open Issue と統合して策定する
- 参加者: Claude Code（Opus 4.7）/ Codex CLI（default model）
- 関連: `docs/ai/harness-improvement-roadmap.md`, EPIC #193, PBI #196〜#200, #213

---

## 文脈共有（Round 0）

### 既存ロードマップ Phase 構成
| Phase | 名称 | Status | Issue | Milestone |
|------|-----|-------|------|----------|
| 0 | Baseline alignment | ✅ Done | #194 | v8.6.0 |
| 1 | Metrics v1 | ✅ Done | #195 | v8.6.0 |
| 2 | Harness Eval expansion | 🔵 Open | #196 | v8.7.0 |
| 3 | Model Profile v2 | 🔵 Open | #197 | v8.7.0 |
| - | Lightweight Plan Quality Checks | 🔵 Open | #213 | v8.7.0 |
| 4 | Keep Rate | 🔵 Open | #198 | v8.8.0 |
| 5 | Dynamic Context Engine | 🔵 Open | #199 | v8.8.0 |
| 6 | Reporting & Retrospective | 🔵 Open | #200 | v8.9.0 |
| - | Issue Governance | ✅ Done | #201 | v8.6.0 |
| - | Metrics Privacy | ✅ Done | #202 | v8.6.0 |

### Steering Loop 強化 6 Phase 案（前ラウンド Codex 提案）
1. Trace Vocabulary 固定（events v2 schema）
2. Gate Event 化 + `trace timeline`
3. State Machine Manifest（YAML）
4. Hook Enforcement（C-3 / handoff / V-1）
5. Orchestrator Invariants 実装
6. Replay / RCA

### 課題
両者を独立に走らせると **概念の重複（events / metrics / report）と優先順位の競合** が発生する。統合スケジュールが必要。

---

## Round 1 — Claude → Codex: 既存ロードマップとの統合

### Claude のプロンプト（要旨）
既存 6 Phase Roadmap と前ラウンドで Codex が提案した Steering Loop 6 Phase の重複/矛盾、優先順位、Issue 単位への落とし込み、v8.7.0 最小スコープを構造的に答えてほしい。

### Codex の回答全文

結論: **既存 Roadmap は止めない**。Steering Loop は置換ロードマップではなく、既存 #196〜#200 を「制御平面化」するための横断 track として扱うのが筋です。

**Q1. 重複と矛盾**

明確な重複はありますが、致命的な矛盾はありません。

| Steering Loop 案 | 既存 Roadmap との重複 | 判断 |
|---|---|---|
| A. Trace Vocabulary / events v2 | #195 Metrics v1、`schemas/plangate-event.schema.json` | **置換しない**。v1 を source of truth にして、v2 は拡張または派生 vocabulary にする |
| B. Gate Event + trace timeline | #196 Eval expansion、#200 Reporting | #196 に最小統合しやすい |
| C. State Machine Manifest | #199 Dynamic Context Engine、既存 workflow phase | #199 側に寄せるのが自然 |
| D. Hook Enforcement | v8.5 Hook Enforcement、Metrics privacy hook、#213 Plan/Risk/Done Check | 新規大物にせず、#213 と既存 hook の不足分に分解 |
| E. Orchestrator Invariants | #213、#196 release blocker、#199 context manifest | v8.7 では仕様化まで、強制は後続 |
| F. Replay / RCA | #200 Reporting & Retrospective、#196 comparison | #200 の上位価値として扱う |

`events.ndjson schema` については、**v1 の 11 event_type を捨てるべきではありません**。理由は、既に #195 で privacy policy、collector、reporter、validation、by_mode 集計まで接続済みだからです。

前ラウンドの「v2 7 event_type」は、置換 event list ではなく、次のような **event family / trace view** として扱うのが安全です。

| v2 的な抽象 | v1 event 例 |
|---|---|
| task lifecycle | `task_initialized`, `exec_started`, `handoff_completed` |
| artifact generated | `plan_generated` |
| gate decided | `c3_decided`, `v1_completed`, `c4_decided` |
| enforcement event | `hook_violation`, `fix_loop_incremented` |
| review event | `external_review_completed` |
| delivery event | `pr_created` |

つまり、`schema_version: 1.0` の event を保ったまま、`event_family`、`gate_id`、`transition_from/to`、`trace_id` 相当を追加するか、reporter 側で timeline view に正規化するのがよいです。

**Q2. 優先順位の組み換え**

推奨は **(c) 別 track として並走。ただし v8.7 では #196 に最小接続する** です。

(a) 中断は悪手です。#196 は Metrics v1 の直後に置かれた中核 PBI で、ここを止めると v8.6.0 で作った比較基盤の回収が遅れます。

(b) Phase 2.5 / 3.5 挿入は一見きれいですが、既存 milestone の意味を濁します。#196/#197/#213 のスコープが肥大化しやすい。

(c) が最もよい理由は、Steering Loop は単一機能ではなく **観測、判定、状態遷移、強制、再現性** の横断関心だからです。既存 Roadmap の各 PBIに「Control Plane lens」を追加する形にする。

具体的には:

- v8.7.0: #196 に **trace timeline / gate normalization の最小版** を入れる
- v8.7.0: #213 は **Plan/Risk/Done の quality gate event 化** までに絞る
- v8.8.0: #198 Keep Rate は trace_id / artifact hash を使う
- v8.8.0: #199 Dynamic Context は State Machine Manifest / Context Manifest を吸収
- v8.9.0: #200 Reporting は Replay / RCA に拡張

**Q3. Issue 単位**

新規 PBI は **3〜4 件** が妥当です。A-F をそのまま 6 PBI にすると管理単位が細かすぎ、既存 #196〜#200 と衝突します。

推奨粒度:

1. **Control Plane Trace Timeline v1**
   - 既存 events v1 から、TASK 単位の phase/gate timeline を出す
   - #196 に統合、または #196 の子 Issue
   - v8.7.0 候補

2. **Gate Event Normalization**
   - C-3 / V-1 / C-4 / hook / fix loop を共通 gate model で扱う
   - #213 と強く関連
   - v8.7.0 では docs + schema additive まで

3. **Workflow State Manifest**
   - YAML で phase、allowed transition、required artifact、gate condition を宣言
   - #199 に統合するのが自然
   - v8.8.0 候補

4. **Replay / RCA Report**
   - timeline から「どこで戻ったか」「何が release blocker だったか」を再構成
   - #200 に統合
   - v8.9.0 候補

既存 Issue の統合・閉鎖について:

| Issue | 判断 |
|---|---|
| #196 Eval comparison | **閉じない**。Control Plane Trace Timeline v1 をここに取り込む |
| #197 Model Profile v2 | **閉じない**。Steering Loop とは直交。trace の slice 軸になる |
| #213 Lightweight Plan Quality Checks | **閉じない**。Gate Event Normalization の一部を担う |
| #198 Keep Rate | **閉じない**。trace/artifact hash の利用先 |
| #199 Dynamic Context Engine | **閉じない**。State Machine Manifest の受け皿 |
| #200 Reporting & Retrospective | **閉じない**。Replay/RCA の受け皿 |

新規で独立起票するなら、まずは **1 件だけ**でよいです。

> PBI: Control Plane Trace Timeline v1  
> Scope: existing events.ndjson v1 を壊さず、TASK timeline / gate timeline / transition summary を機械可読 JSON と Markdown で出す

**Q4. v8.7.0 の最小価値**

v8.7.0 で 1 つだけやるなら、**Trace Timeline v1** です。

理由は単純で、既に events.ndjson は動いているため、最小追加で Steering Loop の価値を可視化できます。State Machine Manifest や Replay/RCA は魅力がありますが、先に timeline がないと設計が抽象論になります。

最小スコープはこの程度で十分です。

- `events.ndjson` v1 は変更しない
- `bin/plangate metrics TASK-XXXX --timeline --json`
- `bin/plangate metrics TASK-XXXX --timeline --markdown-section`
- 出力は event 順ではなく、PlanGate phase / gate 順に正規化
- C-3 / V-1 / C-4 / hook_violation / fix_loop を gate としてまとめる
- #196 の comparison に `timeline_summary` を接続する

これにより v8.7.0 で出る価値は:

- 「この TASK はどの gate を通ったか」が機械可読になる
- #196 の eval comparison が単なる点数比較ではなく、**どの制御点で改善/悪化したか**を見られる
- #213 の Plan/Risk/Done Check を event/gate として後から自然に載せられる
- v8.8 の Keep Rate / Dynamic Context への前提ができる

**推奨整理**

v8.7.0 の現行 5 PBI は維持しつつ、優先順だけこう変えるのがよいです。

1. #196 Eval expansion + Trace Timeline v1
2. #213 Lightweight Plan Quality Checks, gate event 化の入口
3. #203 Tool Error Taxonomy, hook/tool failure の分類軸
4. #197 Model Profile v2, trace の比較 slice
5. #204 PlanGateBench Fixtures, #196 完了後に固定

Steering Loop A-F は「新ロードマップ」ではなく、既存 Roadmap の上にかぶせる **Control Plane track** として扱う。v8.7.0 では Trace Timeline だけを入れて、schema v1 を壊さず、後続 #198〜#200 の土台にするのが最も折り合いがよいです。


結論: **既存 Roadmap は止めない**。Steering Loop は置換ロードマップではなく、既存 #196〜#200 を「制御平面化」するための横断 track として扱うのが筋です。

**Q1. 重複と矛盾**

明確な重複はありますが、致命的な矛盾はありません。

| Steering Loop 案 | 既存 Roadmap との重複 | 判断 |
|---|---|---|
| A. Trace Vocabulary / events v2 | #195 Metrics v1、`schemas/plangate-event.schema.json` | **置換しない**。v1 を source of truth にして、v2 は拡張または派生 vocabulary にする |
| B. Gate Event + trace timeline | #196 Eval expansion、#200 Reporting | #196 に最小統合しやすい |
| C. State Machine Manifest | #199 Dynamic Context Engine、既存 workflow phase | #199 側に寄せるのが自然 |
| D. Hook Enforcement | v8.5 Hook Enforcement、Metrics privacy hook、#213 Plan/Risk/Done Check | 新規大物にせず、#213 と既存 hook の不足分に分解 |
| E. Orchestrator Invariants | #213、#196 release blocker、#199 context manifest | v8.7 では仕様化まで、強制は後続 |
| F. Replay / RCA | #200 Reporting & Retrospective、#196 comparison | #200 の上位価値として扱う |

`events.ndjson schema` については、**v1 の 11 event_type を捨てるべきではありません**。理由は、既に #195 で privacy policy、collector、reporter、validation、by_mode 集計まで接続済みだからです。

前ラウンドの「v2 7 event_type」は、置換 event list ではなく、次のような **event family / trace view** として扱うのが安全です。

| v2 的な抽象 | v1 event 例 |
|---|---|
| task lifecycle | `task_initialized`, `exec_started`, `handoff_completed` |
| artifact generated | `plan_generated` |
| gate decided | `c3_decided`, `v1_completed`, `c4_decided` |
| enforcement event | `hook_violation`, `fix_loop_incremented` |
| review event | `external_review_completed` |
| delivery event | `pr_created` |

つまり、`schema_version: 1.0` の event を保ったまま、`event_family`、`gate_id`、`transition_from/to`、`trace_id` 相当を追加するか、reporter 側で timeline view に正規化するのがよいです。

**Q2. 優先順位の組み換え**

推奨は **(c) 別 track として並走。ただし v8.7 では #196 に最小接続する** です。

(a) 中断は悪手です。#196 は Metrics v1 の直後に置かれた中核 PBI で、ここを止めると v8.6.0 で作った比較基盤の回収が遅れます。

(b) Phase 2.5 / 3.5 挿入は一見きれいですが、既存 milestone の意味を濁します。#196/#197/#213 のスコープが肥大化しやすい。

(c) が最もよい理由は、Steering Loop は単一機能ではなく **観測、判定、状態遷移、強制、再現性** の横断関心だからです。既存 Roadmap の各 PBIに「Control Plane lens」を追加する形にする。

具体的には:

- v8.7.0: #196 に **trace timeline / gate normalization の最小版** を入れる
- v8.7.0: #213 は **Plan/Risk/Done の quality gate event 化** までに絞る
- v8.8.0: #198 Keep Rate は trace_id / artifact hash を使う
- v8.8.0: #199 Dynamic Context は State Machine Manifest / Context Manifest を吸収
- v8.9.0: #200 Reporting は Replay / RCA に拡張

**Q3. Issue 単位**

新規 PBI は **3〜4 件** が妥当です。A-F をそのまま 6 PBI にすると管理単位が細かすぎ、既存 #196〜#200 と衝突します。

推奨粒度:

1. **Control Plane Trace Timeline v1**
   - 既存 events v1 から、TASK 単位の phase/gate timeline を出す
   - #196 に統合、または #196 の子 Issue
   - v8.7.0 候補

2. **Gate Event Normalization**
   - C-3 / V-1 / C-4 / hook / fix loop を共通 gate model で扱う
   - #213 と強く関連
   - v8.7.0 では docs + schema additive まで

3. **Workflow State Manifest**
   - YAML で phase、allowed transition、required artifact、gate condition を宣言
   - #199 に統合するのが自然
   - v8.8.0 候補

4. **Replay / RCA Report**
   - timeline から「どこで戻ったか」「何が release blocker だったか」を再構成
   - #200 に統合
   - v8.9.0 候補

既存 Issue の統合・閉鎖について:

| Issue | 判断 |
|---|---|
| #196 Eval comparison | **閉じない**。Control Plane Trace Timeline v1 をここに取り込む |
| #197 Model Profile v2 | **閉じない**。Steering Loop とは直交。trace の slice 軸になる |
| #213 Lightweight Plan Quality Checks | **閉じない**。Gate Event Normalization の一部を担う |
| #198 Keep Rate | **閉じない**。trace/artifact hash の利用先 |
| #199 Dynamic Context Engine | **閉じない**。State Machine Manifest の受け皿 |
| #200 Reporting & Retrospective | **閉じない**。Replay/RCA の受け皿 |

新規で独立起票するなら、まずは **1 件だけ**でよいです。

> PBI: Control Plane Trace Timeline v1  
> Scope: existing events.ndjson v1 を壊さず、TASK timeline / gate timeline / transition summary を機械可読 JSON と Markdown で出す

**Q4. v8.7.0 の最小価値**

v8.7.0 で 1 つだけやるなら、**Trace Timeline v1** です。

理由は単純で、既に events.ndjson は動いているため、最小追加で Steering Loop の価値を可視化できます。State Machine Manifest や Replay/RCA は魅力がありますが、先に timeline がないと設計が抽象論になります。

最小スコープはこの程度で十分です。

- `events.ndjson` v1 は変更しない
- `bin/plangate metrics TASK-XXXX --timeline --json`
- `bin/plangate metrics TASK-XXXX --timeline --markdown-section`
- 出力は event 順ではなく、PlanGate phase / gate 順に正規化
- C-3 / V-1 / C-4 / hook_violation / fix_loop を gate としてまとめる
- #196 の comparison に `timeline_summary` を接続する

これにより v8.7.0 で出る価値は:

- 「この TASK はどの gate を通ったか」が機械可読になる
- #196 の eval comparison が単なる点数比較ではなく、**どの制御点で改善/悪化したか**を見られる
- #213 の Plan/Risk/Done Check を event/gate として後から自然に載せられる
- v8.8 の Keep Rate / Dynamic Context への前提ができる

**推奨整理**

v8.7.0 の現行 5 PBI は維持しつつ、優先順だけこう変えるのがよいです。

1. #196 Eval expansion + Trace Timeline v1
2. #213 Lightweight Plan Quality Checks, gate event 化の入口
3. #203 Tool Error Taxonomy, hook/tool failure の分類軸
4. #197 Model Profile v2, trace の比較 slice
5. #204 PlanGateBench Fixtures, #196 完了後に固定

Steering Loop A-F は「新ロードマップ」ではなく、既存 Roadmap の上にかぶせる **Control Plane track** として扱う。v8.7.0 では Trace Timeline だけを入れて、schema v1 を壊さず、後続 #198〜#200 の土台にするのが最も折り合いがよいです。



---

## Round 2 — Claude → Codex: 反論と深掘り

### Claude のプロンプト（要旨）
3 点の懸念を提示:
1. Trace Timeline v1 を #196 に取り込むと #196 のスコープが肥大化する
2. events.ndjson v1 を「壊さない」前提で trace_id 等を追加する方法（metadata 押込 vs schema bump）
3. Gate Event Normalization を #213 に統合するのは責務違反

加えて 2 点の踏み込み質問:
- Q5: Trace Timeline v1 の Definition of Done を 5〜7 項目で
- Q6: v8.7.0 で押し出して良い PBI 候補

### Codex の回答全文

**懸念 1: #196 への取り込み**

推奨: Claude 案に同意。Trace Timeline v1 は独立 PBI に切り出すべきです。

理由は、#196 は「評価比較の信頼性」を扱う PBI で、Trace Timeline v1 は「観測データの正規化基盤」です。#196 に入れると、PR の成功条件が `eval 判定が正しいか` と `trace モデルが正しいか` に分裂します。

整理案:

- 新規 PBI: `Trace Timeline v1`
- v8.7.0 milestone に追加
- #196 は Trace Timeline v1 の出力を consume する
- #196 の parser 拡張は「既存 session log / events から eval に必要な入力を読む」までに限定
- timeline の phase/gate normalization は #196 外へ出す

つまり依存関係は `Trace Timeline v1 -> #196` が自然です。

**懸念 2: events.ndjson v1 の additive 拡張**

推奨: `schema_version: 1.1` に bump し、optional top-level fields を追加するのが現実解です。

`metadata` に押し込む案は避けるべきです。理由は、trace 系の中核フィールドが free-form 領域に入ると、reporter / eval / privacy validator の全てが `metadata` の暗黙契約に依存し始めるからです。

推奨 schema 方針:

```json
{
  "schema_version": "1.1",
  "event_id": "...",
  "timestamp": "...",
  "event_type": "...",
  "phase": "WF-03",
  "gate_id": "C-3",
  "trace_id": "...",
  "parent_event_id": "...",
  "artifact_refs": [],
  "policy_refs": [],
  "metadata": {}
}
```

ポイント:

- `schema_version: 1.0` は読み取り互換として維持
- `schema_version: 1.1` で optional top-level fields を追加
- `additionalProperties: false` は維持
- privacy validator は top-level 新フィールドも allowlist 対象に含める
- `metadata` は event 固有の補足情報に限定する
- `trace_id` / `parent_event_id` / `artifact_refs` / `policy_refs` は reporter が直接読める位置に置く

これなら EH-8 の privacy 強制を弱めず、後方互換も保てます。

**懸念 3: #213 との統合**

推奨: これも Claude 案に同意。Gate Event Normalization は #213 に入れず、独立 PBI にするべきです。

#213 は Plan / Risk / Done の「品質チェック Skill」です。一方 Gate Event Normalization は C-3 / V-1 / C-4 などの「workflow 制御イベントモデル」です。責務が違います。

分離案:

- #213: 人間/AI が作る plan の品質を軽量に検査する
- Gate Event Normalization: workflow gate の状態遷移と判定結果を共通 event model に落とす
- Trace Timeline v1: normalized gate events と phase events を時系列/論理順に再構成する

関係としてはこうです。

```text
#213 Plan Quality Checks
  -> gate decision の入力になることはある

Gate Event Normalization
  -> gate decision を共通 event として記録する

Trace Timeline v1
  -> phase/gate event を reader-friendly / eval-friendly に並べる
```

#213 に gate normalization を詰めると、Skill の話と runtime workflow の話が混ざります。独立 PBI が妥当です。

**Q5: Trace Timeline v1 の DoD**

推奨 DoD は次の 7 項目です。

1. `timeline` の入力 source が明確である  
   最低対象は `events.ndjson`。必要なら session log は補助入力に限定し、正本は `events.ndjson` とする。

2. gate event の定義が固定されている  
   v1 では `c3_decided`, `v1_completed`, `c4_decided` を gate event とする。`hook_violation`, `fix_loop_incremented`, `tool_error`, `policy_violation` は gate ではなく observation event として扱う。

3. phase order の正本が決まっている  
   v1 は WF-01〜WF-05 の linear order を標準とする。mode 別 manifest がある場合は override 可能にするが、v8.7.0 の release 判定では linear order を正本にする。

4. timeline normalization rule が機械判定できる  
   出力順は `phase_order -> gate_order -> timestamp -> event_id`。timestamp だけに依存しない。

5. gate と observation の紐づけ規則がある  
   `parent_event_id` があればそれを優先。なければ同一 `trace_id` / 同一 phase / 近接 timestamp の順で fallback する。ただし fallback は `inferred: true` を付ける。

6. reporter output が安定している  
   同じ input から同じ timeline JSON / Markdown が生成される。並び順、missing field 表示、unknown event の扱いが snapshot test で固定されている。

7. privacy / schema validation を通過する  
   Trace Timeline v1 の出力に secret / raw prompt / local-only path の漏洩がないことを EH-8 相当の検査で確認する。unknown top-level field を許容して通す設計にはしない。

この DoD を満たせば、v8.7.0 で「trace を評価や review に使える最小基盤」としてリリース可能です。

**Q6: v8.7.0 で押し出す候補**

推奨: まず #197、次点で #213 を v8.8.0 に押し出す候補にします。

#197 Model Profile v2 を押し出してよい理由:

- Trace Timeline v1 は #196 / #204 / 将来の gate enforcement の基盤になる
- Model Profile v2 は重要だが、trace 基盤がない状態では効果測定や比較の説明力が弱い
- v8.7.0 の主題を harness observability / eval reliability に寄せるなら、profile 拡張より timeline が先

#213 Plan Quality Checks を次点にする理由:

- #213 は品質改善として価値があるが、workflow runtime の可観測性とは独立している
- Gate Event Normalization / Trace Timeline v1 と混ぜると責務が曖昧になる
- v8.8.0 で `timeline を見ながら plan quality check の効果を測る` 形にした方が筋がよい

逆に、#196 / #204 は残したいです。#196 は eval comparison の中核で、#204 は fixtures として #196 / timeline の検証材料になります。#203 Tool Error Taxonomy も observation event の分類精度に効くため、Trace Timeline v1 と相性がよいです。
**懸念 1: #196 への取り込み**

推奨: Claude 案に同意。Trace Timeline v1 は独立 PBI に切り出すべきです。

理由は、#196 は「評価比較の信頼性」を扱う PBI で、Trace Timeline v1 は「観測データの正規化基盤」です。#196 に入れると、PR の成功条件が `eval 判定が正しいか` と `trace モデルが正しいか` に分裂します。

整理案:

- 新規 PBI: `Trace Timeline v1`
- v8.7.0 milestone に追加
- #196 は Trace Timeline v1 の出力を consume する
- #196 の parser 拡張は「既存 session log / events から eval に必要な入力を読む」までに限定
- timeline の phase/gate normalization は #196 外へ出す

つまり依存関係は `Trace Timeline v1 -> #196` が自然です。

**懸念 2: events.ndjson v1 の additive 拡張**

推奨: `schema_version: 1.1` に bump し、optional top-level fields を追加するのが現実解です。

`metadata` に押し込む案は避けるべきです。理由は、trace 系の中核フィールドが free-form 領域に入ると、reporter / eval / privacy validator の全てが `metadata` の暗黙契約に依存し始めるからです。

推奨 schema 方針:

```json
{
  "schema_version": "1.1",
  "event_id": "...",
  "timestamp": "...",
  "event_type": "...",
  "phase": "WF-03",
  "gate_id": "C-3",
  "trace_id": "...",
  "parent_event_id": "...",
  "artifact_refs": [],
  "policy_refs": [],
  "metadata": {}
}
```

ポイント:

- `schema_version: 1.0` は読み取り互換として維持
- `schema_version: 1.1` で optional top-level fields を追加
- `additionalProperties: false` は維持
- privacy validator は top-level 新フィールドも allowlist 対象に含める
- `metadata` は event 固有の補足情報に限定する
- `trace_id` / `parent_event_id` / `artifact_refs` / `policy_refs` は reporter が直接読める位置に置く

これなら EH-8 の privacy 強制を弱めず、後方互換も保てます。

**懸念 3: #213 との統合**

推奨: これも Claude 案に同意。Gate Event Normalization は #213 に入れず、独立 PBI にするべきです。

#213 は Plan / Risk / Done の「品質チェック Skill」です。一方 Gate Event Normalization は C-3 / V-1 / C-4 などの「workflow 制御イベントモデル」です。責務が違います。

分離案:

- #213: 人間/AI が作る plan の品質を軽量に検査する
- Gate Event Normalization: workflow gate の状態遷移と判定結果を共通 event model に落とす
- Trace Timeline v1: normalized gate events と phase events を時系列/論理順に再構成する

関係としてはこうです。

```text
#213 Plan Quality Checks
  -> gate decision の入力になることはある

Gate Event Normalization
  -> gate decision を共通 event として記録する

Trace Timeline v1
  -> phase/gate event を reader-friendly / eval-friendly に並べる
```

#213 に gate normalization を詰めると、Skill の話と runtime workflow の話が混ざります。独立 PBI が妥当です。

**Q5: Trace Timeline v1 の DoD**

推奨 DoD は次の 7 項目です。

1. `timeline` の入力 source が明確である  
   最低対象は `events.ndjson`。必要なら session log は補助入力に限定し、正本は `events.ndjson` とする。

2. gate event の定義が固定されている  
   v1 では `c3_decided`, `v1_completed`, `c4_decided` を gate event とする。`hook_violation`, `fix_loop_incremented`, `tool_error`, `policy_violation` は gate ではなく observation event として扱う。

3. phase order の正本が決まっている  
   v1 は WF-01〜WF-05 の linear order を標準とする。mode 別 manifest がある場合は override 可能にするが、v8.7.0 の release 判定では linear order を正本にする。

4. timeline normalization rule が機械判定できる  
   出力順は `phase_order -> gate_order -> timestamp -> event_id`。timestamp だけに依存しない。

5. gate と observation の紐づけ規則がある  
   `parent_event_id` があればそれを優先。なければ同一 `trace_id` / 同一 phase / 近接 timestamp の順で fallback する。ただし fallback は `inferred: true` を付ける。

6. reporter output が安定している  
   同じ input から同じ timeline JSON / Markdown が生成される。並び順、missing field 表示、unknown event の扱いが snapshot test で固定されている。

7. privacy / schema validation を通過する  
   Trace Timeline v1 の出力に secret / raw prompt / local-only path の漏洩がないことを EH-8 相当の検査で確認する。unknown top-level field を許容して通す設計にはしない。

この DoD を満たせば、v8.7.0 で「trace を評価や review に使える最小基盤」としてリリース可能です。

**Q6: v8.7.0 で押し出す候補**

推奨: まず #197、次点で #213 を v8.8.0 に押し出す候補にします。

#197 Model Profile v2 を押し出してよい理由:

- Trace Timeline v1 は #196 / #204 / 将来の gate enforcement の基盤になる
- Model Profile v2 は重要だが、trace 基盤がない状態では効果測定や比較の説明力が弱い
- v8.7.0 の主題を harness observability / eval reliability に寄せるなら、profile 拡張より timeline が先

#213 Plan Quality Checks を次点にする理由:

- #213 は品質改善として価値があるが、workflow runtime の可観測性とは独立している
- Gate Event Normalization / Trace Timeline v1 と混ぜると責務が曖昧になる
- v8.8.0 で `timeline を見ながら plan quality check の効果を測る` 形にした方が筋がよい

逆に、#196 / #204 は残したいです。#196 は eval comparison の中核で、#204 は fixtures として #196 / timeline の検証材料になります。#203 Tool Error Taxonomy も observation event の分類精度に効くため、Trace Timeline v1 と相性がよいです。

---

## Round 3 — Claude → Codex: 実装着手プランの確定レビュー

### Claude のプロンプト（要旨）
Round 1-2 の合意事項を提示した上で、以下を依頼:
- Q7: Trace Timeline v1 の Issue 本文ドラフト（issue-governance.md 準拠の完成品）
- Q8: Gate Event Normalization の Issue サマリ（200 字 Goal + In Scope 5 bullet + 完了条件 3 項目）
- Q9: 実装着手順序と並行性、schema 1.1 担当 PBI の判断
- Q10: roadmap 文書の更新箇所（section 番号案込み）

### Codex の回答全文

**Q7. Trace Timeline v1 Issue 本文ドラフト**

Title:
`PBI-HI-009: Trace Timeline v1`

```markdown
## Goal

PlanGate の `events.ndjson` を時系列の trace timeline として読めるようにし、Gate / phase / observation の流れを v8.7.0 の Control Plane track の最初の可視化単位として確立する。

## Why

- Metrics v1 (#195) は event を保存できるが、現状は「実行の流れ」を追う timeline として読むには情報が不足している。
- Gate event / observation / phase の対応が曖昧なままだと、後続の Eval expansion (#196) や Retrospective (#200) が感覚的な分析に戻る。
- Steering Loop A-F は新ロードマップではなく Control Plane track として既存 roadmap に重ねるため、最初に trace の最小語彙と表示単位を固定する必要がある。

## What (In Scope)

- `events.ndjson` を Trace Timeline v1 の唯一の input source として定義する。
- `schemas/plangate-event.schema.json` を `schema_version: 1.1` へ additive に拡張する。
- optional top-level fields として `trace_id` / `parent_event_id` / `artifact_refs` / `policy_refs` / `gate_id` / `phase` を追加する。
- 既存の `additionalProperties: false` と privacy policy (#202) の制約を維持する。
- Gate event として扱う event type / field 条件を最小定義する。
- WF-01〜WF-05 / C-3 / V-1 / C-4 / handoff の phase order を timeline 表示規則として定義する。
- gate observation と trace event を結びつける最小ルールを定義する。
- 既存 reporter が schema 1.1 event を読んでも壊れないことを検証する。

## What (Out of Scope)

- schema v2 への置換、既存 event type の削除、既存 Metrics v1 event vocabulary の再設計。
- interactive UI / dashboard / browser visualization の実装。
- Keep Rate v1 (#198) の算出ロジック。
- Dynamic Context Engine v1 (#199) との自動連携。
- Reporting & Retrospective (#200) の最終レポートテンプレート実装。

## Acceptance Criteria

- [ ] `events.ndjson` が Trace Timeline v1 の input source であることが docs に明記され、他の暗黙入力に依存しない。
- [ ] `schemas/plangate-event.schema.json` が `schema_version: 1.1` を受け入れ、追加 field は optional top-level fields として定義されている。
- [ ] Gate event の判定条件が、event type / `gate_id` / `phase` / status のどれを使うかまで機械的に確認できる粒度で定義されている。
- [ ] Phase order が WF-01〜WF-05 / C-3 / V-1 / C-4 / handoff の順序として文書化され、欠損・順序不明時の扱いが定義されている。
- [ ] gate observation と trace event の紐付けルールが `trace_id` / `parent_event_id` / `artifact_refs` / `policy_refs` の範囲で定義されている。
- [ ] 既存 `scripts/metrics_reporter.py` または同等の reporter が schema 1.1 event を読み込んでも regression しないことが検証されている。
- [ ] Metrics privacy policy (#202) に反する field、file path、prompt、stack trace、secret-like value が schema / sample / reporter output に混入しないことが検証されている。

## Dependencies

- Parent EPIC: #193 — Harness Improvement Roadmap の child PBI として扱う。
- #195 — Metrics v1 の `events.ndjson` / `schemas/plangate-event.schema.json` / reporter を前提にする。
- #202 — Metrics Privacy Policy の forbidden data / public data policy を維持する。
- #196 — Eval expansion が timeline signal を利用できるよう、出力語彙を衝突させない。
- #213 — Lightweight Plan Quality Checks の gate observation と接続できるよう、observation 参照の最小ルールを合わせる。

## Estimation Evidence

### Risks

- schema 1.1 の optional field が増えすぎると、Metrics v1 の単純さと `additionalProperties: false` の運用しやすさを損なう。
- Gate event normalization と責務が重なるため、どちらの PBI が field 定義を所有するか曖昧になる可能性がある。
- sample event に file path / prompt / stack trace 相当の情報を入れると privacy policy (#202) に違反する。

### Unknowns

- 既存の `run-event.schema.json` を維持するか、非推奨にするか、Trace Timeline v1 の参照対象外にするか。
- Gate observation の既存 artifact 名・保存場所が v8.7.0 でどこまで固定されているか。
- timeline reporter を既存 `metrics_reporter.py` に統合するか、別コマンドに分けるか。

### Assumptions

- Trace Timeline v1 は additive change のみで実装し、既存 Metrics v1 event は壊さない。
- `schema_version: 1.0` の既存 event は reporter 側で後方互換として読める状態を維持する。
- v8.7.0 では可視化の完成度より、trace 語彙・schema・privacy validation の固定を優先する。

## Mode

standard

根拠: schema / reporter / docs / privacy validation に跨るが、破壊的 migration や runtime gate 強制の変更は含めない。既存 Metrics v1 への additive extension であり、high-risk / critical ではない。

## Milestone

v8.7.0

## Labels

- enhancement
- area:metrics
- area:schema
- priority:P0
- mode:standard

## Parent EPIC / Roadmap

- Parent EPIC: #193
- Roadmap doc: `docs/ai/harness-improvement-roadmap.md`
- Related docs: `docs/ai/metrics.md`, `docs/ai/metrics-privacy.md`
```

**Q8. Gate Event Normalization Issue サマリ**

Goal:
Gate / hook / workflow event の表現揺れを v8.7.0 内で最小正規化し、Trace Timeline v1 と Eval expansion が同じ gate signal を読める状態にする。既存 event vocabulary は壊さず、`gate_id` / `phase` / status の正規化ルールを追加する。

In Scope:
- Gate event と非 Gate event の判定ルール定義
- `gate_id` の命名規則定義
- `phase` の許容値と WF / Gate 対応表の定義
- hook result / C-3 / V-1 / C-4 / handoff event の status 正規化
- sample event と privacy-safe fixture の追加

v8.7.0 完了条件:
- schema 1.1 の gate 関連 field が Trace Timeline v1 と一致している
- 代表 Gate event が同じ normalization rule で reporter / eval から読める
- 既存 Metrics v1 event の後方互換が維持されている

**Q9. 実装着手順序と並行性**

推奨は「分離 Issue なし」で、`schema 1.1` は **Trace Timeline v1 が担当**。理由は、schema 1.1 の主目的が timeline を成立させる optional field 追加だからです。

順序は以下が妥当です。

1. Trace Timeline v1 で schema 1.1 の field set と privacy boundary を固定
2. Gate Event Normalization で `gate_id` / `phase` / status の語彙を同じ schema 上に正規化
3. Trace Timeline v1 側で reporter 後方互換と timeline sample を最終検証

完全並行は避けた方がよいです。並行起票は OK ですが、実装は Trace Timeline v1 の schema PR を先行させ、Gate Event Normalization はその branch / PR の schema 方針を前提に着手する形が安全です。

`Schema 1.1 Migration` をさらに分離するのは、現時点では過分です。分離すると v8.7.0 の PBI が増え、Control Plane track の初手が schema 作業だけに見えます。Trace Timeline v1 の AC 内に schema 1.1 を含める方が、目的と成果物が対応します。

**Q10. ロードマップ文書の更新箇所**

最小構成なら、`docs/ai/harness-improvement-roadmap.md` は以下の追加で足ります。

- `## 5. ロードマップ概要` の直後に新章追加
  - 新 section: `## 6. Control Plane track`
  - 既存 `## 6` 以降は 1 つずつ繰り下げ

書く内容:
- Control Plane track は新ロードマップではなく、既存 Phase 2〜6 に重ねる横断 track である
- v8.7.0 の対象は `Trace Timeline v1` と `Gate Event Normalization`
- `events.ndjson` は `schema_version: 1.1` へ additive bump し、`additionalProperties:false` と privacy policy は維持する
- `#197 Model Profile v2` は v8.8.0 へ移動候補であること
- Phase A-F との対応表は最小でよい

section 案:

```markdown
## 6. Control Plane track

### 6.1 位置づけ
Control Plane track は Steering Loop A-F を既存 Harness Improvement Roadmap に重ねる横断 track であり、新しい独立ロードマップではない。

### 6.2 v8.7.0 scope
- Trace Timeline v1
- Gate Event Normalization
- Harness Eval expansion (#196)
- Lightweight Plan Quality Checks (#213)

### 6.3 Event schema policy
`events.ndjson` は `schema_version: 1.1` へ additive に拡張する。既存 event type は削除せず、`additionalProperties:false` と Metrics Privacy Policy (#202) を維持する。

### 6.4 Deferred scope
Model Profile v2 (#197) は v8.8.0 へ移動候補。Keep Rate (#198), Dynamic Context (#199), Reporting & Retrospective (#200) は v8.8.0 以降で Control Plane signal を利用する。
```

この構成なら、既存 Phase 章を大きく書き換えずに、v8.7.0 の実装着手判断だけを明文化できます。

---

## 決定事項サマリ（Claude 統合）

### 戦略
- Steering Loop A-F は **新ロードマップではなく既存 Roadmap に重ねる Control Plane track** として扱う
- 既存 #196〜#200, #213 は閉じず、Control Plane lens を後付けする

### v8.7.0 新規起票（2 件）
1. **Trace Timeline v1**（新規 PBI、schema 1.1 拡張を内包、`mode: standard`, `priority: P0`）
2. **Gate Event Normalization**（新規 PBI、schema 1.1 上で gate_id / phase / status を正規化）

### v8.7.0 milestone 調整
- 維持: #196 / #213 / #203 / #204
- 移動候補: **#197 Model Profile v2 → v8.8.0**（理由: trace 基盤なしでは効果測定の説明力が弱い）

### events.ndjson schema 方針
- `schema_version: 1.1` に additive bump
- 追加 optional top-level fields: `trace_id` / `parent_event_id` / `artifact_refs` / `policy_refs` / `gate_id` / `phase`
- `additionalProperties: false` と Metrics Privacy Policy (#202) は維持
- 既存 1.0 event は後方互換で読める

### 実装順序
1. Trace Timeline v1 で schema 1.1 を先行確定
2. Gate Event Normalization は同 schema 上で語彙正規化
3. Trace Timeline v1 側で reporter 後方互換と sample 検証で完走

### ロードマップ文書更新
- `docs/ai/harness-improvement-roadmap.md` に `## 6. Control Plane track` 新章追加（既存 §6 以降を繰り下げ）
- 4 サブセクション: 位置づけ / v8.7.0 scope / Event schema policy / Deferred scope

## 次アクション

- [ ] `docs/ai/harness-improvement-roadmap.md` に Control Plane track 章追加
- [ ] Trace Timeline v1 (PBI-HI-009 相当) を gh issue create で起票
- [ ] Gate Event Normalization (PBI-HI-010 相当) を起票
- [ ] #197 Model Profile v2 の milestone を v8.7.0 → v8.8.0 へ変更
- [ ] EPIC #193 に新規 2 PBI を sub-issue として紐付け

## 参考: TAKT との差別化メッセージ

- TAKT = **orchestration engine**（YAML で agent 楽団 routing）
- PlanGate = **governed development loop**（Gate contract / artifacts / human approval / handoff の品質制御）
- 目指す姿: durable execution engine ではなく **「後から責任ある説明ができる deterministic control plane」**

