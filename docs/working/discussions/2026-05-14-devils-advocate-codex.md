# Devil's Advocate ラウンド: 3 ディスカッション合意の批判的再検証

- 日時: 2026-05-14
- 主題: Steering Loop / 自己進化フレーム / 外部知見統合の 3 合意を、Codex に意図的反対立場で再検証させる
- 参加者: Claude Code（Opus 4.7）/ Codex CLI（devil's advocate mode）
- 前提ログ:
  - `2026-05-14-steering-loop-codex.md`
  - `2026-05-14-self-evolution-codex.md`
  - `2026-05-14-self-evolution-gemini.md`

## Claude のプロンプト（要旨）
3 ディスカッションの合意を批判対象として明示。5 つの問いで Codex に忖度なし反対立場を要求:
- Q1: 観測先行が罠になる 3 シナリオ + 撤退前兆
- Q2: v8.7.0 でやるべき仮想反対 PBI
- Q3: 3 ディスカッションで最も弱い結論 2 件以上
- Q4: 半年ロードマップの過大性、1 milestone のみ選ぶならどれ、切り捨てるべき軸
- Q5: それでも変えるべきでない結論 + 撤回すべき結論

## Codex の回答全文

## Q1. 観測先行が罠になる 3 シナリオ

**推奨/結論: Trace Timeline v1 は「最小観測 + 捨てられる実験」としてなら可。ただし schema 1.1 を広げすぎるなら撤退すべき。**

1. **schema 先行固定の罠**
   観測したい現象が未確定なのに `schema_version: 1.1` を増やすと、後で「本当に必要なイベント粒度」と合わず、互換性維持のために不要フィールドを抱え続ける。

   撤退前兆:
   - 新フィールドの説明が「将来使うかも」になっている
   - 1 つの改善判断に使われる具体例を 3 件出せない
   - 既存 `events.ndjson` の読み手が増えていないのに schema だけ増える

2. **読む負荷だけ増える罠**
   1 人運用では、観測ログは「自動で意思決定に変換される」か「短時間で読める」必要がある。Trace Timeline が詳細すぎると、運用者がログ解釈係になり、PlanGate の省力化に逆行する。

   撤退前兆:
   - 1 run の確認に 5 分以上かかる
   - Timeline を見ても次アクションが 1 行で言えない
   - 「ログはあるが、結局 markdown を読み直している」状態になる

3. **評価軸未整備で死蔵する罠**
   観測は評価・学習の入力だが、評価軸がないと「記録しただけ」になる。半年後に大量の trace があっても、良い run / 悪い run / 再利用すべき判断が分類できなければ資産化しない。

   撤退前兆:
   - Trace Timeline の AC に「どの判断を改善するか」がない
   - promising / failed / noisy などの分類が人手メモ任せ
   - v8.8.0 の自己評価設計が未定のまま trace だけ増える

## Q2. v8.7.0 でやるべき真の優先 PBI

**推奨/結論: 反対案としては、Trace Timeline より先に “Run Outcome Review v1” をやるべき。**

仮想 PBI:

**PBI-HI-009: Run Outcome Review v1**
目的は、各 run の最後に以下を小さく記録すること。

- 目的は達成したか
- 失敗・迷走・手戻りは何か
- 次回再利用すべき判断は何か
- どの skill / gate / artifact が効いたか
- 1 人運用上、負荷が高かった箇所は何か

Trace Timeline より価値がある理由:

- **観測粒度ではなく判断価値から始められる**
  Timeline は「何が起きたか」を増やすが、Outcome Review は「何が良かったか / 悪かったか」を直接残す。

- **Markdown 中心の PlanGate に合う**
  Bash/Python でイベント基盤を広げるより、まず markdown ベースの終了レビューを標準化する方が軽い。

- **自己評価 v8.8.0 への接続が強い**
  LLM-as-a-Judge や multi-judge consensus に行く前に、人間が納得できる評価項目を固定できる。

- **1 人運用で即効性がある**
  読む対象が timeline 全体ではなく、run ごとの短い要約になる。認知負荷が低い。

この反対案を取るなら、v8.7.0 の Trace Timeline は「Outcome Review を作るために最低限必要な event 補助」に格下げすべき。

## Q3. 3 ディスカッションで最も弱い結論

**推奨/結論: 最も弱いのは “OpenTelemetry GenAI semconv 準拠追加” と “Token / Cost attribution の schema 1.1 必須化候補”。次点で “Promising Trace 先行実装”。**

1. **OpenTelemetry GenAI semconv 準拠**
   弱い理由は、PlanGate の現実が汎用 observability platform ではなく、1 人運用の Markdown/Bash/Python ワークフローだから。標準準拠は将来の接続性には効くが、現時点の主要課題が「運用判断の質」なら優先度は低い。

   問題は「業界主流だから正しい」という論法に寄りやすいこと。PlanGate が今必要としているのは標準語彙より、run 後に何を学ぶかの最小分類。

2. **Token / Cost attribution の schema 1.1 必須化候補**
   これはかなり怪しい。コスト管理が主目的なら有効だが、自己進化の中心が「評価 → 学習 → ガバナンス」なら、token/cost は補助指標にすぎない。

   必須化すると、すべてのイベント生成者に計測責務が乗る。実装・欠損処理・後方互換・外部 CLI 差分の負荷が増える。1 人運用では、価値より維持費が勝つ可能性が高い。

3. **Promising Trace の v8.7.0 先行実装**
   「良い trace を残す」発想は正しいが、promising の判定基準が未定ならタグが主観ラベルになる。タグだけ先に作ると、後で評価軸とズレた負債になる。

   先にやるなら `promising` ではなく、より素朴な `review_required` / `reusable_decision` / `manual_followup` くらいがよい。

## Q4. 半年ロードマップの過大性

**推奨/結論: 半年で v8.7.0 観測、v8.8.0 自己評価、v8.9.0 学習を全部やるのは過大。1 人運用なら “自己評価の最小核” に絞るべき。**

正直な見積もり:

- **v8.7.0 観測**
  最小なら 2-3 週。  
  Trace Timeline、schema 1.1、既存イベント移行、docs、検証まで入れると 4-6 週。

- **v8.8.0 自己評価**
  最小なら 3-5 週。  
  評価軸、judge prompt、AC、false positive 対策、review artifact、運用ルールまで入れると 6-8 週。

- **v8.9.0 学習**
  最小でも 4-6 週。  
  memory / learnings / skill 更新 / governance / rollback / stale knowledge 対策まで含めると 8-12 週。

半年で 1 milestone しか選べないなら:

**v8.8.0 相当の “自己評価 v1” を選ぶべき。**

理由は、観測も学習も評価なしでは方向が定まらないから。評価軸があれば、観測は「評価に必要なものだけ」に削れる。学習も「合格した判断だけを再利用する」に制限できる。

意図的に切り捨てるべき軸:

- **OpenTelemetry 準拠**
  今は切る。外部連携が現実要件になるまで不要。

- **Token / Cost attribution の必須化**
  任意メタデータでよい。必須にしない。

- **multi-judge consensus**
  v8.8.0 の AC にしない。まず single judge + human-readable rationale で十分。

- **自動学習 / 自動 skill 更新**
  切る。1 人運用では誤学習の回復コストが高い。学習は最初は人間承認つきの markdown 記録でよい。

- **15 軸すべてのロードマップ化**
  切る。地図としては有用だが、実装計画に直結させると過大化する。

## Q5. それでも変えるべきでない結論

**推奨/結論: 変えるべきでない結論は 3 つ。撤回すべき結論もある。**

変えるべきでない結論:

1. **Steering Loop は自己進化の中心ではなく、観測・再現基盤である**
   これは正しい。自己進化の中心は「何を良いと評価するか」と「何を次回に残すか」。Steering Loop はその材料を安定して取るための基盤にすぎない。

2. **新ロードマップではなく既存 roadmap に Control Plane track として重ねる**
   これも維持すべき。別ロードマップ化すると、PlanGate の運用面が分裂する。既存 milestone に重ねる方が、1 人運用では管理負荷が低い。

3. **#197 Model Profile v2 を v8.8.0 以降に押し出す**
   妥当。今 Model Profile を拡張しても、評価軸が弱ければ「モデル差分をどう判断するか」が決まらない。先に評価の最小核を作るべき。

自信を持って撤回・弱体化すべき結論:

- **Token / Cost attribution を schema 1.1 必須化候補にする**
  撤回。任意フィールド候補に落とすべき。

- **OpenTelemetry GenAI semconv 準拠を v8.7.0 近傍の実装論点にする**
  撤回。docs の参考情報に留めるべき。

- **Promising Trace を v8.7.0 で先行実装する**
  弱体化。先に `Run Outcome Review v1` か、少なくとも `reusable_decision` のような具体ラベルに変えるべき。

最終推奨は明確です。  
v8.7.0 は Trace Timeline 本体ではなく、**Run Outcome Review v1 + 最小イベント補助** に寄せるべきです。schema 1.1 は additive でも慎重にし、必須フィールド追加は避ける。半年計画は「観測 → 自己評価 → 学習」ではなく、**自己評価の最小核を先に作り、観測と学習をその従属物にする** 方が PlanGate の現実制約に合っています。
## Q1. 観測先行が罠になる 3 シナリオ

**推奨/結論: Trace Timeline v1 は「最小観測 + 捨てられる実験」としてなら可。ただし schema 1.1 を広げすぎるなら撤退すべき。**

1. **schema 先行固定の罠**
   観測したい現象が未確定なのに `schema_version: 1.1` を増やすと、後で「本当に必要なイベント粒度」と合わず、互換性維持のために不要フィールドを抱え続ける。

   撤退前兆:
   - 新フィールドの説明が「将来使うかも」になっている
   - 1 つの改善判断に使われる具体例を 3 件出せない
   - 既存 `events.ndjson` の読み手が増えていないのに schema だけ増える

2. **読む負荷だけ増える罠**
   1 人運用では、観測ログは「自動で意思決定に変換される」か「短時間で読める」必要がある。Trace Timeline が詳細すぎると、運用者がログ解釈係になり、PlanGate の省力化に逆行する。

   撤退前兆:
   - 1 run の確認に 5 分以上かかる
   - Timeline を見ても次アクションが 1 行で言えない
   - 「ログはあるが、結局 markdown を読み直している」状態になる

3. **評価軸未整備で死蔵する罠**
   観測は評価・学習の入力だが、評価軸がないと「記録しただけ」になる。半年後に大量の trace があっても、良い run / 悪い run / 再利用すべき判断が分類できなければ資産化しない。

   撤退前兆:
   - Trace Timeline の AC に「どの判断を改善するか」がない
   - promising / failed / noisy などの分類が人手メモ任せ
   - v8.8.0 の自己評価設計が未定のまま trace だけ増える

## Q2. v8.7.0 でやるべき真の優先 PBI

**推奨/結論: 反対案としては、Trace Timeline より先に “Run Outcome Review v1” をやるべき。**

仮想 PBI:

**PBI-HI-009: Run Outcome Review v1**
目的は、各 run の最後に以下を小さく記録すること。

- 目的は達成したか
- 失敗・迷走・手戻りは何か
- 次回再利用すべき判断は何か
- どの skill / gate / artifact が効いたか
- 1 人運用上、負荷が高かった箇所は何か

Trace Timeline より価値がある理由:

- **観測粒度ではなく判断価値から始められる**
  Timeline は「何が起きたか」を増やすが、Outcome Review は「何が良かったか / 悪かったか」を直接残す。

- **Markdown 中心の PlanGate に合う**
  Bash/Python でイベント基盤を広げるより、まず markdown ベースの終了レビューを標準化する方が軽い。

- **自己評価 v8.8.0 への接続が強い**
  LLM-as-a-Judge や multi-judge consensus に行く前に、人間が納得できる評価項目を固定できる。

- **1 人運用で即効性がある**
  読む対象が timeline 全体ではなく、run ごとの短い要約になる。認知負荷が低い。

この反対案を取るなら、v8.7.0 の Trace Timeline は「Outcome Review を作るために最低限必要な event 補助」に格下げすべき。

## Q3. 3 ディスカッションで最も弱い結論

**推奨/結論: 最も弱いのは “OpenTelemetry GenAI semconv 準拠追加” と “Token / Cost attribution の schema 1.1 必須化候補”。次点で “Promising Trace 先行実装”。**

1. **OpenTelemetry GenAI semconv 準拠**
   弱い理由は、PlanGate の現実が汎用 observability platform ではなく、1 人運用の Markdown/Bash/Python ワークフローだから。標準準拠は将来の接続性には効くが、現時点の主要課題が「運用判断の質」なら優先度は低い。

   問題は「業界主流だから正しい」という論法に寄りやすいこと。PlanGate が今必要としているのは標準語彙より、run 後に何を学ぶかの最小分類。

2. **Token / Cost attribution の schema 1.1 必須化候補**
   これはかなり怪しい。コスト管理が主目的なら有効だが、自己進化の中心が「評価 → 学習 → ガバナンス」なら、token/cost は補助指標にすぎない。

   必須化すると、すべてのイベント生成者に計測責務が乗る。実装・欠損処理・後方互換・外部 CLI 差分の負荷が増える。1 人運用では、価値より維持費が勝つ可能性が高い。

3. **Promising Trace の v8.7.0 先行実装**
   「良い trace を残す」発想は正しいが、promising の判定基準が未定ならタグが主観ラベルになる。タグだけ先に作ると、後で評価軸とズレた負債になる。

   先にやるなら `promising` ではなく、より素朴な `review_required` / `reusable_decision` / `manual_followup` くらいがよい。

## Q4. 半年ロードマップの過大性

**推奨/結論: 半年で v8.7.0 観測、v8.8.0 自己評価、v8.9.0 学習を全部やるのは過大。1 人運用なら “自己評価の最小核” に絞るべき。**

正直な見積もり:

- **v8.7.0 観測**
  最小なら 2-3 週。  
  Trace Timeline、schema 1.1、既存イベント移行、docs、検証まで入れると 4-6 週。

- **v8.8.0 自己評価**
  最小なら 3-5 週。  
  評価軸、judge prompt、AC、false positive 対策、review artifact、運用ルールまで入れると 6-8 週。

- **v8.9.0 学習**
  最小でも 4-6 週。  
  memory / learnings / skill 更新 / governance / rollback / stale knowledge 対策まで含めると 8-12 週。

半年で 1 milestone しか選べないなら:

**v8.8.0 相当の “自己評価 v1” を選ぶべき。**

理由は、観測も学習も評価なしでは方向が定まらないから。評価軸があれば、観測は「評価に必要なものだけ」に削れる。学習も「合格した判断だけを再利用する」に制限できる。

意図的に切り捨てるべき軸:

- **OpenTelemetry 準拠**
  今は切る。外部連携が現実要件になるまで不要。

- **Token / Cost attribution の必須化**
  任意メタデータでよい。必須にしない。

- **multi-judge consensus**
  v8.8.0 の AC にしない。まず single judge + human-readable rationale で十分。

- **自動学習 / 自動 skill 更新**
  切る。1 人運用では誤学習の回復コストが高い。学習は最初は人間承認つきの markdown 記録でよい。

- **15 軸すべてのロードマップ化**
  切る。地図としては有用だが、実装計画に直結させると過大化する。

## Q5. それでも変えるべきでない結論

**推奨/結論: 変えるべきでない結論は 3 つ。撤回すべき結論もある。**

変えるべきでない結論:

1. **Steering Loop は自己進化の中心ではなく、観測・再現基盤である**
   これは正しい。自己進化の中心は「何を良いと評価するか」と「何を次回に残すか」。Steering Loop はその材料を安定して取るための基盤にすぎない。

2. **新ロードマップではなく既存 roadmap に Control Plane track として重ねる**
   これも維持すべき。別ロードマップ化すると、PlanGate の運用面が分裂する。既存 milestone に重ねる方が、1 人運用では管理負荷が低い。

3. **#197 Model Profile v2 を v8.8.0 以降に押し出す**
   妥当。今 Model Profile を拡張しても、評価軸が弱ければ「モデル差分をどう判断するか」が決まらない。先に評価の最小核を作るべき。

自信を持って撤回・弱体化すべき結論:

- **Token / Cost attribution を schema 1.1 必須化候補にする**
  撤回。任意フィールド候補に落とすべき。

- **OpenTelemetry GenAI semconv 準拠を v8.7.0 近傍の実装論点にする**
  撤回。docs の参考情報に留めるべき。

- **Promising Trace を v8.7.0 で先行実装する**
  弱体化。先に `Run Outcome Review v1` か、少なくとも `reusable_decision` のような具体ラベルに変えるべき。

最終推奨は明確です。  
v8.7.0 は Trace Timeline 本体ではなく、**Run Outcome Review v1 + 最小イベント補助** に寄せるべきです。schema 1.1 は additive でも慎重にし、必須フィールド追加は避ける。半年計画は「観測 → 自己評価 → 学習」ではなく、**自己評価の最小核を先に作り、観測と学習をその従属物にする** 方が PlanGate の現実制約に合っています。

---

## 決定事項の修正（Claude 統合）

### Codex 反対立場で **撤回・弱体化** された結論

| 項目 | 元の判断 | 修正後 |
|-----|--------|-------|
| Token / Cost attribution の schema 1.1 必須化 | Gemini 推奨で「入れるべき」 | **撤回** — 任意メタデータに落とす |
| OpenTelemetry GenAI semconv 準拠 | Gemini 推奨で v8.7.0 検討 | **撤回** — docs 参考情報のみ |
| Promising Trace の v8.7.0 先行実装 | Gemini 推奨で実装 | **弱体化** — より素朴な `reusable_decision` 等のラベルに |
| Trace Timeline v1 を v8.7.0 主軸 | Round 1-3 合意 | **要再検討** — Run Outcome Review v1 に振替候補あり |
| multi-judge consensus を v8.8.0 AC | Gemini 推奨 | **撤回** — single judge + human rationale で十分 |
| 自動学習 / 自動 skill 更新 | 暗黙の前提 | **明示的に切る** — 1 人運用では誤学習回復コストが高い |

### 変えるべきでない 3 結論（robustness check 通過）

1. **Steering Loop は自己進化の中心ではなく観測・再現基盤** — Codex 自身も最強に確信
2. **新ロードマップではなく既存に Control Plane track として重ねる** — 運用面分裂回避
3. **#197 Model Profile v2 を v8.8.0 以降に押し出し** — 評価軸が弱いままモデル差分判断は不可能

### 最大の発見: 仮想反対 PBI「Run Outcome Review v1」
Trace Timeline v1 より **先にやるべき** 候補として浮上:

- 各 run 完了時に Markdown で記録する評価項目を標準化
- 目的達成度 / 失敗・迷走 / 再利用すべき判断 / 効いた skill/gate/artifact / 認知負荷
- **Bash/Python ではなく Markdown ベースで完結** → 1 人運用に合う
- v8.8.0 dogfooding eval への接続が直接的

これは **Claude×Codex×Gemini の 3 ディスカッションの中で最も実装が軽く、価値が早く出る** 案。Trace Timeline v1 はその下位（Outcome Review を支える最小 event 補助）に格下げ可能。

### 半年ロードマップの再評価

Codex の正直見積もり:
- v8.7.0 観測: 最小 2-3 週、フル 4-6 週
- v8.8.0 自己評価: 最小 3-5 週、フル 6-8 週
- v8.9.0 学習: 最小 4-6 週、フル 8-12 週

→ **1 人運用で半年フル 3 milestone は非現実的**

**1 milestone しかこなせない場合の Codex 推奨**: 自己評価 v1（v8.8.0 相当）を選ぶ。評価軸があれば観測も学習も従属物として自然に削れる。

### 意図的に切り捨てるべき軸（明示）
- OpenTelemetry 準拠
- Token / Cost attribution 必須化
- multi-judge consensus AC 化
- 自動学習 / 自動 skill 更新
- 15 軸すべてのロードマップ化（地図は残すが実装計画化しない）

## 統合後の最終戦略（Claude 判断）

### Option A: Codex 反対案を全面採用（保守的）
- v8.7.0 主軸を **Run Outcome Review v1**（Markdown ベース）に変更
- Trace Timeline v1 は最小 event 補助に格下げ
- Gate Event Normalization は v8.8.0 以降に延期
- v8.8.0 = 自己評価 v1（single judge + human rationale）
- v8.9.0 は明示的に「計画しない」とする

### Option B: 部分採用（バランス型）
- v8.7.0 で Trace Timeline v1 + Run Outcome Review v1 を **両方** 起票、後者を主、前者を従
- schema 1.1 拡張は **3 fields のみ**（gate_id / phase / parent_event_id）に絞る
- Token/Cost / OTel 準拠 は撤回
- v8.8.0 = 自己評価 v1
- v8.9.0 は決め打ちせず v8.8.0 完了後判断

### Option C: 元計画維持（楽観的）
- 3 ディスカッションの当初合意通り進める
- Codex の批判は roadmap.md の「Risks」セクションに記載のみ

**Claude 推奨: Option B**
理由: Run Outcome Review v1 の軽量性は確かに魅力だが、Steering Loop の観測基盤がゼロでは v8.8.0 自己評価の入力が markdown だけになり再現性が弱い。両方の最小版を v8.7.0 で立ち上げる方が、認知負荷を抑えつつ複利が効く。

## 次アクション（修正版）

- [ ] **新規仮想 PBI「Run Outcome Review v1」** の検討（既存 Trace Timeline v1 と並列起票するか、後者の AC に取り込むか）
- [ ] schema 1.1 拡張フィールドを 6 → 3 に削減（gate_id / phase / parent_event_id のみ、`trace_id` / `artifact_refs` / `policy_refs` は v8.8.0 以降）
- [ ] roadmap.md に「**意図的に切り捨てる軸**」セクションを追加（OTel / token必須化 / multi-judge AC / 自動学習）
- [ ] v8.9.0 milestone を「計画しない（v8.8.0 完了後判断）」に変更検討
- [ ] 「self-evolution 15 軸」は地図として残すが、実装計画と切り離す宣言を明示

