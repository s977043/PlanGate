# ai-loop design philosophy — 設計思想正本

> **位置づけ**: ai-loop-workflow の**思想層の正本**。全 ai-loop ドキュメントの最上位に立ち、
> 「なぜこう設計するのか」の根拠と、今後の成長（外部知見の取り込み・仕様の版上げ）の
> 手続きを定義する。個別の機構・手順は本書から参照される各正本が持つ（§7 文書地図）。
> **適用ドメイン**: ai-loop-workflow（docs/ai/ai-loop/ / docs/workflows/ai-loop/）のみ。
> PlanGate 本番フロー（WF-00〜WF-07）には適用しない。
> **検討経緯**: 初版は Fable 起草 + Codex / 独立 adversarial レビュー（Gemini は
> 実行不可のため代替。§11）の 2 系統検討を反映（2026-07-07）。

---

## 1. 中心命題 — 承認の時制の設計

AI 駆動開発の統制は「速度と安全のトレードオフ」として語られがちだが、
ai-loop の見立ては異なる。**本質は「人間の承認をいつ発生させるか＝承認の時制」の設計問題**である。

- **in-the-loop**（PlanGate 本番）: 実行前に人間が承認する。安全だが、
  人間のレビュー容量がリニアにしか伸びず、低リスク変更まで同じ関所を通る。
- **on-the-loop**（ai-loop）: 低リスク帯は流し、**逸脱だけ**を人間に昇格する。
  人間の判断力を「全件の承認作業」から「枠の制定・例外の裁定・事後の監督」へ再配置する。

ai-loop は PlanGate の否定でも代替でもない。**PlanGate が蓄積した統制資産
（失敗履歴・INC 群・HO・provenance・決定論の設計哲学）の上にしか成立しない次世代形**であり、
並走期は PlanGate が本番統制を担い続ける（[`concept.md`](./concept.md) §2・§6）。

> 一行で: **ai-loop とは、承認の時制を「実行前」から「逸脱検知時」へ移すための、
> 境界・裁定・記憶・学習の設計である。**

### 1.1 外部定義との整合 — human-on-the-loop は独自用語ではない

in/on-the-loop は ai-loop の造語ではなく、監視制御・自律システム統制の文献で
確立した用語である。独自定義の漂流を防ぐため、一般定義との対応を明示する。

**一般定義（3 系統）**:

| 出典                                       | 分類                      | 要旨                                                                                                                                                                                                                    |
| ------------------------------------------ | ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Sheridan の監視制御（supervisory control） | —                         | 人間が断続的に指示・継続的に情報を受け取り、計算機側が自律制御ループを閉じる。HOTL の学術的起源                                                                                                                         |
| 米 DoD Directive 3000.09（自律兵器統制）   | in / on / out of the loop | **in**: 人間が個別対象を選択（semi-autonomous）/ **on**: 人間が監視し停止できる（human-supervised）/ **out**: 起動後は人間介入なし（full autonomy）                                                                     |
| EU HLEG「Trustworthy AI 倫理ガイドライン」 | HITL / HOTL / **HIC**     | **HITL**: 全決定サイクルへの介入能力 / **HOTL**: 設計サイクルでの介入 + 運用の監視 / **HIC（human-in-command）**: システム全体の活動監督と「いつ・どう使うか（使わないか）」の決定、人間裁量レベルの設定、override 能力 |

**ai-loop の用法との対応**:

ai-loop の「人間＝枠の制定者・例外の裁定者・事後の監督者」は、一般分類では
**単一の HOTL ではなく 3 モードの複合**である:

| ai-loop での人間の役割                                   | 一般分類での対応                                                                                                                                                                                                                                                      |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 枠の制定者（policy 制定・第0の承認境界・使用範囲の決定） | **HIC（human-in-command）**                                                                                                                                                                                                                                           |
| 例外の裁定者・事後の監督者（監視・停止・override）       | **HOTL**（DoD の human-supervised / EU の HOTL）                                                                                                                                                                                                                      |
| escalate 発火時の個別裁定（人間 C-3 への降格）           | **HITL**（当該案件のみ in-the-loop へ戻る）                                                                                                                                                                                                                           |
| touches-HO / C-4 merge（常時同期ブロック）               | **HITL**（現行 policy。touches-HO は恒久固定。C-4 merge の解禁判定は concept.md Phase 5 の HIC 決定として Human に留保 — 入口基準の正本は [`hotl-merge-entry-criteria.md`](./hotl-merge-entry-criteria.md) / [#733](https://github.com/s977043/plangate/issues/733)） |

この対応から導かれる注意が 2 つある:

1. **「on-the-loop」を一般の HOTL（監視+停止のみ）として弱く読まない。**
   ai-loop の人間は監視者である前に **HIC＝枠の制定者**であり、policy 制定は
   永久に Human-owned（I-1）。一般定義の HOTL 単独よりも人間の権限は強い。
2. **out-of-the-loop（完全自律）は分類上も設計上も採用しない。**
   DoD 分類の out に相当する状態は、ai-loop では non-goal（§9）かつ I-1 により
   到達不能に設計される。

> 要するに: ai-loop の human-on-the-loop とは、「**定常運転時の人間の位置**が
> on である」ことを指す運用上の呼称であり、統制構造の全体は
> **HIC（枠）+ HOTL（監視）+ HITL（例外・境界）のハイブリッド**である。

---

## 2. 第一原理（Invariants）

以下は ai-loop の全設計を貫く不変原理。個別仕様が進化しても、これらに反する変更は
「成長」ではなく「破壊」として棄却する。各原理には**なぜそれが必要か**を必ず付す。

### I-1. 承認境界の不可侵 — 「自分の枠を自分で書き換えない」

学習（Optimize）・次アクション選択（Schedule）・裁定（Evaluate）のいかなる層も、
**承認境界そのもの（policy / HO / C-4 merge）を変更対象にしない**。
policy 制定は永久に Human-owned（第0の承認境界。[`arbiter-policy.md`](./arbiter-policy.md) §6）。

**なぜ**: 学習ループが自分の承認条件を自己承認できる構造は、時間とともに境界を漸進侵食する。
これは AI の悪意を仮定しない場合でも、誤検知抑制の圧力だけで発生する（自己免疫疾患型の劣化）。
境界の変更コストを意図的に高く保つことが、枠内自律の前提条件である。

### I-2. 「No と言える構造」— maker と checker の分離

生成者に自己評価させない。Evaluate は生成と独立した主体・独立した極性
（Model A=順方向「正しく作られているか」/ Model B=adversarial「どう壊れるか」）で行う
（W チェック。[`flow-detect.md`](../../workflows/ai-loop/flow-detect.md) §3）。
この分離は成果物の評価に限らない: **思想・仕様の取り込み判断（§6 intake loop）にも適用する**。

**なぜ**: 自己評価の甘さは、プロンプトの工夫では消えない。生成と同一のコンテキスト・
同一の動機を持つ主体は、自分の仮定を疑えない。独立性と非対称性を**構造**で強制する。

### I-3. 裁定の決定論 — AI の自己申告を信用しない

裁定（L2 / Arbiter）は決定論ロジックで行い、LLM の判断に委ねない。
severity 分類は rule ベース分類器が行い、Model B の自己申告を採用しない
（[`flow-detect.md`](../../workflows/ai-loop/flow-detect.md) §3.2.1）。
auto-approve には provenance を刻印し、「誰が・何を根拠に・何を承認したか」を追跡可能に残す。

**なぜ**: 同じ入力に同じ裁定が返らないシステムは監査できない。冪等性・明示的失敗・
トレーサビリティ・テスト可能性（検証可能性 4 条件）は、事後監督モデルの生命線である。

> **既知の限界（honest 注記）**: 現行 PoC の provenance は「刻印されている」ことを保証するが、
> `issued_by` の**発行元真正性は未検証**（署名等が別途必要。
> [`decision-table.md`](../../workflows/ai-loop/decision-table.md) §5 / PlanGate #420 と同型の
> 未解決課題）。I-3 は「決定論で裁定し記録を残す」原理であり、偽装不可能性まで主張しない。

### I-4. 安全側デフォルト — 判定不能は昇格側に倒す

boundary 判定不能・severity 分類不能・lite 判定の根拠不足は、
すべて **escalate / critical / lite=false 側**に倒す（PlanGate AC-8 安全側原則の継承）。

**なぜ**: on-the-loop は「見逃し」が in-the-loop より高くつく。不確実性の下での既定値を
安全側に固定することで、判定器のバグ・想定外入力が事故ではなく過剰昇格として現れるようにする。

### I-5. 記録なき最適化の禁止（Remember → Optimize の一方向依存）

Optimize（gate / skill / suppression / scheduling policy の更新）は、
Remember（decision record・指摘・反証・効果の保存）に**記録された事実のみ**を根拠とする。
逆に、記録するだけで次回の振る舞いに反映されない Remember も失敗として扱う
（[`adaptive-production-loop.md`](../../workflows/ai-loop/adaptive-production-loop.md) §6）。

**なぜ**: 根拠なきプロンプト・ゲート書き換えは再現不能な劣化を生み、
記録だけの蓄積は「学習している感」だけを生む。両者を分離し一方向依存にすることで、
改善の各ステップが監査可能になる。

### I-6. 停止できないループはループではない

closed loop は 1 サイクルの contract
（[`adaptive-production-loop.md`](../../workflows/ai-loop/adaptive-production-loop.md) §4 を正本とする
Goal / Evaluate / Stop / Memory / Schedule / Boundary の 6 要素）を満たす反復のみを指す。
これを満たさない反復は **scheduled repetition（polling）** と呼び、区別する。
Budget（対応ラウンド上限・escalate 予算）は Stop / Schedule に内包される停止資源である。
「完璧になるまで考え続ける」「全組み合わせを列挙する」型の指示は、
ループ設計以前の**非停止リスク**としてゲートで拒否・再形成する。

停止機構は 2 層ある: **反復の停止**（terminal state への到達）と、
**自律そのものの一時停止**（サーキットブレーカー CB。
[`decision-table.md`](../../workflows/ai-loop/decision-table.md) §6 — 誤って学習した policy や
昇格の洪水を止める）。両方を持たないループは片肺である。

**なぜ**: 非停止は安全性の問題である以前に経済性の問題（推論コスト・トークン・時間）であり、
かつ失敗報告の欠落（止まらないので失敗と認識されない）を生む。

### I-7. 人間の判断力は希少資源 — escalate は予算で管理する

human escalate は無料ではない。escalate 予算（[`arbiter-policy.md`](./arbiter-policy.md) §7）で
管理し、「何でも人間に聞く」への退行（実質 in-the-loop 化）と
「何も聞かない」への暴走（境界侵食）の両方を防ぐ。
critical は予算外（常に昇格）、それ以外は予算を消費する。

**なぜ**: on-the-loop の価値は人間の判断力を例外に集中投資することにある。
escalate が無制限なら人間はまた全件レビューに戻り、ゼロなら I-1〜I-4 が形骸化する。

### I-8. 枠内自律は低リスク帯に限定する — 可逆性の担保

flow に乗せてよいのは `boundary=clean` **かつ** `lite=true` の変更のみ
（[`flow-detect.md`](../../workflows/ai-loop/flow-detect.md) §2 /
[`lite-criteria.md`](../../workflows/ai-loop/lite-criteria.md)）。
lite 判定の必須軸には**可逆性**が含まれる: **不可逆な変更は flow に流さない**。

**なぜ**: on-the-loop の安全装置（サーキットブレーカー・事後 reject・巻き戻し）は、
変更が可逆であることを前提に機能する。不可逆な変更が flow に流れると
「検知しても戻せない」穴が生じ、事後監督モデル全体が成立しなくなる。
低リスク帯限定は暫定の遠慮ではなく、**巻き戻し可能性という構造的前提**である。

### I-9. 承認された宣言は実差分で再検証される — 二段 detect

C-3'（Arbiter）が裁定するのは **plan 宣言**（第 1 段 detect）であり、
実装後の**実差分**は PR 前の宣言↔実差分整合検証 + CI / AI レビュー（第 2 段 detect）で
独立に再検証される（[`00_concept.md`](../../workflows/ai-loop/00_concept.md) §3.3 /
[`execution-runbook.md`](../../workflows/ai-loop/execution-runbook.md) §2-(6)）。
宣言外の変更は exec 差し戻しまたは C-3' 再裁定であり、承認の使い回しを認めない。

**なぜ**: 「plan は承認された」ことと「実装が plan の通りである」ことは別の命題である。
一段目の承認を実差分に自動延長すると、承認と実体の乖離（宣言と違うものが流れる）が
検知不能になる。二段 detect は、承認の効力範囲を宣言に厳密に閉じるための構造である。

---

## 3. 4層エンジニアリングモデル

AI エージェント運用の設計変数を 4 層で整理する（issue #726 より取り込み）。
ai-loop-workflow は**第4層（Loop Engineering）の実装**であり、下位 3 層を前提とする。

| 層                      | 設計対象       | 問い                                                                                                  | ai-loop での対応                                                                                              |
| ----------------------- | -------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 1. Prompt Engineering   | 1 回の呼び出し | 何をどう頼むか（role / instruction / examples / output format / rubric）                              | 各 Model A/B/C/D への委託プロンプト定型（ai-loop-cycle スキル）                                               |
| 2. Context Engineering  | 見せる情報     | 何を見せ、何を見せないか（関連ファイル / 過去の判断 / 却下理由 / stale 除外）                         | decision record・provenance・suppression の選択的持ち込み。詰め込むのではなく**次の判断に効く情報だけを残す** |
| 3. Harness Engineering  | 実行環境       | 何で囲うか（tools / test / retry / subagent / sandbox / reviewer）                                    | arbiter.py・CI・hook 群・サブエージェント分離                                                                 |
| 4. **Loop Engineering** | 外側ループ     | どう回し、どう止め、どう学ぶか（trigger / goal / verification / stopping rule / memory / escalation） | **ai-loop-workflow 本体**（6 ステップサイクル + terminal state + escalate）                                   |

この分離が与える診断力: ループの不調は、まずどの層の問題かを切り分けてから直す。
「プロンプトを盛る」は第 1 層の対処であり、停止しない・記憶が落ちる・自己評価が甘い、
といった問題は第 2〜4 層の設計不良である。層を間違えた対処は効かない。

---

## 4. 静的構造と動的サイクル — L0-L5 × 6 ステップ

ai-loop は 2 つの直交する軸で記述される。混同しない。

- **L0〜L5（静的な層アーキテクチャ）**: 何がどこに存在するか
  （[`concept.md`](./concept.md) §7）。L0 統制契約が全層を拘束し、L2 裁定が心臓。
- **Generate → Evaluate → Remember → Schedule → Optimize → Recurse（動的な 1 サイクル）**:
  時間軸上で何が起きるか
  （[`adaptive-production-loop.md`](../../workflows/ai-loop/adaptive-production-loop.md) §3 の
  6 ステップ表。各ステップの ai-loop 上の対応は同表右列）。

両軸の突き合わせ（どのステップがどの層で実行されるか）は、各正本の該当節を参照して行う。
本書で覚えるべきは写像表ではなく次の一点である:

> **静的構造は「境界がどこにあるか」を答え、動的サイクルは「今どこにいて次に何をするか」を答える。
> 安全性は静的構造（L0）が担保し、生産性は動的サイクルが生む。**

---

## 5. 語彙集（Vocabulary）

思想の劣化は語彙の曖昧化から始まる。以下の用語は本書の定義を正とし、
ai-loop ドキュメント全体で同じ意味に使う。

| 用語                                 | 定義                                                                                                                                                                                                                                                                                                                               | 対義・混同禁止                                                                                          |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| **governed autonomy（枠内自律）**    | 承認境界の内側での AI 自律実行。境界外は常に人間                                                                                                                                                                                                                                                                                   | 完全自律（人間なし）                                                                                    |
| **bounded adaptive production loop** | 低リスク帯に限定され、1 サイクル contract（下記 closed loop）を満たす自己改善ループ                                                                                                                                                                                                                                                | 無制限の自己改善                                                                                        |
| **human-on-the-loop**                | 人間＝枠の制定者・例外の裁定者・事後の監督者。一般分類（EU HLEG / DoD 3000.09）では **HIC + HOTL + HITL（例外・境界）のハイブリッド**であり、定常運転時の位置を指す運用呼称（§1.1）                                                                                                                                                | human-in-the-loop（実行前承認者）／ human-out-of-the-loop ／ 一般 HOTL 単独（監視のみ）としての弱い読み |
| **closed loop**                      | 1 サイクル contract（**Goal / Evaluate / Stop / Memory / Schedule / Boundary** — 正本: [`adaptive-production-loop.md`](../../workflows/ai-loop/adaptive-production-loop.md) §4）を満たす反復。Budget は Stop / Schedule に内包                                                                                                     | scheduled repetition / polling（interval 駆動の再実行）                                                 |
| **escalate**                         | 逸脱を人間へ昇格すること。2 文脈を区別する: **C-3' escalate**（plan 裁定の人間 C-3 への降格。承認境界の撤廃ではない）と **Schedule escalate**（PR 後ループでのラウンド上限超過・critical 指摘等による人間介入要求）                                                                                                                | エラー・失敗（escalate は正常系の一部）                                                                 |
| **W チェック**                       | 順方向（A）と adversarial（B）の 2 モデル非対称二重判定                                                                                                                                                                                                                                                                            | 単一モデルの自己レビュー                                                                                |
| **severity（二軸）**                 | ①W チェック不一致の severity（critical/major/minor/**low** — [`flow-detect.md`](../../workflows/ai-loop/flow-detect.md) §3.2）と ②レビュー指摘の severity（critical/major/minor/**info** — review-principles §3）は**別軸**。混同しない                                                                                            | 単一の severity 軸として扱うこと                                                                        |
| **L2 入力 4 軸**                     | `boundary`（touches-HO / clean）・`lite`（true / false）・`verdict`（W チェック合意結果）・`class`（merge 含む / 含まない）。裁定の全入力（[`concept.md`](./concept.md) §4）                                                                                                                                                       | —                                                                                                       |
| **provenance**                       | auto-approve の根拠刻印。誰が・何を・何を根拠に承認したかの追跡記録（発行元真正性の検証は未実装 — I-3 注記）                                                                                                                                                                                                                       | 単なる実行ログ                                                                                          |
| **terminal state**                   | 裁定の終端 3 値（`AUTO_APPROVED` / `HUMAN_ESCALATED` / `BLOCKED` — [`decision-table.md`](../../workflows/ai-loop/decision-table.md)）。**merge-ready は裁定でなく DoD 状態**（[`00_concept.md`](../../workflows/ai-loop/00_concept.md) §3.3）、**round limit exceeded は HUMAN_ESCALATED への遷移理由**であり独立の state ではない | 中間状態・無限継続                                                                                      |
| **suppression**                      | 機械反証を伴う誤検知抑制の登録                                                                                                                                                                                                                                                                                                     | 根拠なき指摘の無視                                                                                      |
| **Turn/Goal/Time/Proactive（外部語彙）** | Claude Code 系の loop 4 型分類（issue #746）。PlanGate では **型として採用しない**: Turn≒`trigger:manual`・Time≒`trigger:scheduled`・Proactive≒`trigger:scheduled/issue_created` は **trigger の値**であり、Goal は型ではなく **contract の一要素**（adaptive-production-loop §2 の分離を維持） | 4 型を独立の分類軸として輸入すること（trigger/contract 混同の逆流） |
| **touches-HO**                       | HO パス（[`ho-paths.md`](./ho-paths.md)）への接触。全判定をスキップして即 human escalate する絶対条件                                                                                                                                                                                                                              | 高リスク一般（touches-HO は交渉不能の別格）                                                             |

---

## 6. 成長メカニズム — 思想・仕様の版上げ手続き

本書が「成長する基盤」であるための中核。**ai-loop の思想・仕様の成長自体を、
第一原理（特に I-2 maker-checker 分離と I-5 記録なき最適化の禁止）に従わせる。**

### 6.1 外部知見の取り込み（intake loop）

記事・X 投稿・他ツールの設計（例: issue #726〜#729）を取り込む際の固定手順:

1. **issue 化（Remember）**: 出典・中心概念・PlanGate/ai-loop に効きそうな点を issue に記録する。
2. **gap 分析**: 中心概念を既存正本（§7 文書地図の各ファイル）と突合し、
   「既にカバー済み / 既存正本へ追記 / 新規ファイル / 思想と矛盾するため棄却」に仕分ける。
   **この分析を経ない直接実装を禁止する**（正本の断片化・二重定義の防止）。
   - **独立性（I-2 の適用）**: gap 分析・棄却判断は、取り込みを提案した主体と
     **独立した視点**（別モデル・別セッション・adversarial レビューのいずれか）の
     検証を最低 1 系統経る。提案者が自分で「カバー済み」「採用」を確定しない。
   - **記録**: 分析結果（仕分け・独立検証の verdict）を issue コメントに残す。
     残っていない intake は手続き違反として差し戻す。
3. **配置（Optimize）**: 仕分けに従い additive に反映する。新しい用語は §5 語彙集に追加する。
   第一原理（§2）に反する概念は、魅力的でも棄却し、棄却理由を issue に記録する
   （例:「人間なしで自己改善」→ I-1 違反として bounded 版に再形成して採用）。
4. **効果測定**: 反映した概念が実際に判断を変えたかを、**retrospective 実施時**に
   decision record / 運用記録で確認する。直近 2 回の retrospective で参照実績が
   なければ削除候補（§6.3）として起票する。

### 6.2 バージョンアップ（版上げ）の判断基準

| 変更の種類                                   | 手続き                                                                                    |
| -------------------------------------------- | ----------------------------------------------------------------------------------------- |
| 追記・明確化（意味を変えない）               | 通常 PR（additive）。本書の参照整合のみ確認                                               |
| 機構の変更（裁定条件・閾値・terminal state） | 該当正本の版上げ + 本書 §2 との整合確認を PR に明記                                       |
| **第一原理（§2）の変更・削除**               | **Human-owned**。AI は draft 提案まで。人間の明示承認なしに I-1〜I-9 を変更した PR は棄却 |
| 文書構造の再編（ファイル統合・改名）         | §7 文書地図の更新とセットで行う。旧パスからの参照をすべて追従                             |

### 6.3 削除の規律

成長は追加だけではない。効いていない gate・使われない語彙・重複した記述は
**負債**として削除する。ただし削除にも規律を課す:

- **根拠**: 「なぜ入れたか」の記録を確認し、導入理由が消滅したことを示してから消す
  （チェスタトンの柵）。導入記録が見つからない場合も、その旨を記録した上で判断する。
- **責務**: 削除の重みは §6.2 の表に従う — 機構の削除は「機構の変更」、
  語彙・文書の削除は「文書構造の再編」、**第一原理の削除は Human-owned**。
  AI が単独で確定してよいのは削除**候補の起票**までであり、削除の確定は
  当該変更種別の手続き（PR + C-4）を必ず経る。

---

## 7. 文書地図（正本タクソノミ）

各ドキュメントの役割を一意に定める。**同じ問いに 2 つのファイルが答えてはならない。**

| 層       | ファイル                                                                                                                                         | 答える問い                                                         |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| **思想** | 本書（design-philosophy.md）                                                                                                                     | なぜこう設計するのか。成長の手続き                                 |
| **契約** | [`arbiter-policy.md`](./arbiter-policy.md)                                                                                                       | 何が Human-owned か。escalate 予算                                 |
|          | [`ho-paths.md`](./ho-paths.md)                                                                                                                   | touches-HO の機械判定                                              |
|          | [`hotl-merge-entry-criteria.md`](./hotl-merge-entry-criteria.md)                                                                                 | HOTL merge 解禁の入口基準（C-4 merge 解禁判定は Human-owned 不変） |
| **概念** | [`concept.md`](./concept.md)                                                                                                                     | ai-loop とは何か（L0-L5・in/on 対比・Phase 計画）                  |
|          | [`00_concept.md`](../../workflows/ai-loop/00_concept.md)                                                                                         | PlanGate フローとの接続（C-3'・merge-ready 責務）                  |
|          | [`adaptive-production-loop.md`](../../workflows/ai-loop/adaptive-production-loop.md)                                                             | 6 ステップサイクルと 1 サイクル contract（closed loop の正本）     |
| **機構** | [`flow-detect.md`](../../workflows/ai-loop/flow-detect.md)                                                                                       | flow→detect→escalate の判定分岐                                    |
|          | [`decision-table.md`](../../workflows/ai-loop/decision-table.md)                                                                                 | 裁定の決定表・provenance schema・terminal state・CB                |
|          | [`lite-criteria.md`](../../workflows/ai-loop/lite-criteria.md)                                                                                   | lite（低リスク・可逆性）判定基準                                   |
|          | [`loopspec.md`](../../workflows/ai-loop/loopspec.md)                                                                                             | ループ実行境界の宣言構造                                           |
|          | [`loop-safety-gates.md`](../../workflows/ai-loop/loop-safety-gates.md)                                                                           | 非停止プロンプトの事前拒否・再形成                                 |
| **運用** | [`execution-runbook.md`](../../workflows/ai-loop/execution-runbook.md)                                                                           | 1 サイクルの実行手順・Scheduling 判断表                            |
|          | [`review-feedback-loop.md`](../../workflows/ai-loop/review-feedback-loop.md)                                                                     | L4 学習閉ループ（Remember/Optimize の実体）                        |
|          | [`unknown-discovery.md`](../../workflows/ai-loop/unknown-discovery.md)                                                                           | unknowns 4 分類と 3 ゲート                                         |
| **記録** | [`asset-inventory.md`](./asset-inventory.md) / [`related-specs.md`](./related-specs.md) / [`phase3-impact-report.md`](./phase3-impact-report.md) | 資産分類・関連仕様・Phase 判断記録                                 |

### 7.1 既知の構造的課題（次期リファクタリング候補）

現行構造は Phase 0〜2 の増築の結果であり、以下の重複・分裂が既知である。
外部検討（Codex）の結論も踏まえ、**大規模一括再編は行わず段階的に解消する**
（本書が思想の正本として存在することで各ファイルの役割を狭められるため。
一括再編は既存リンク・正本優先順位・C-3'/merge-ready 責務の参照を同時に動かし、
思想正本の追加直後に行う作業としてはリスクが高い）:

- `concept.md`（docs/ai/ai-loop/）と `00_concept.md`（docs/workflows/ai-loop/）の
  「concept」名の重複。前者は「ai-loop とは何か」、後者は「PlanGate との接続」に**役割を限定**した。
  将来の改名（例: 00_concept → plangate-integration）は §6.2「文書構造の再編」手続きで行う。
- **closed loop / 1 サイクル contract の要素列挙**が文書間で揺れていた
  （本書初版・adaptive §4・00_concept §4 で要素数が不一致）。本書 v2 で
  **adaptive-production-loop.md §4 の 6 要素を正本と宣言**し、他文書の列挙は
  同節への参照とみなす。00_concept §4 側の表現整理は次回改訂で追従する。
- 統制系（docs/ai/ai-loop/）と実行系（docs/workflows/ai-loop/）の 2 ディレクトリ分置。
  現状は「契約と機構の分離」として意味を持つため維持するが、
  ファイル数が増えた場合は再評価する。

---

## 8. 取り込み待ち知見のトリアージ（intake loop の初回適用）

§6.1 の手続きを、現在 open の loop 系 issue に適用した結果。実装時はこの仕分けに従う。
（本トリアージ自体の独立検証は本書 PR の C-2 外部レビューが担う）

| issue                       | 中心概念                                                                                              | 仕分け   | 配置先                                                                                                                                                                                           |
| --------------------------- | ----------------------------------------------------------------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| #726 LoopSpec / 4層整理     | 4層モデル → **本書 §3 で採用済み**。LoopSpec（trigger/goal/context/actors/verification の YAML 構造） | 追記     | LoopSpec schema は新規（decision-table.md の provenance schema と整合させる）。stop condition / maker-checker は既存正本でカバー済みにつき参照                                                   |
| #728 loop-safety gates      | 非停止プロンプトの事前拒否（stop condition / feasibility / budget / contradiction detection）         | 追記     | **本書 I-6 が思想的根拠**。機構は flow-detect.md の flow フェーズに事前ゲートとして追記（3 ラウンド上限・escalate 予算は既存）                                                                   |
| #729 Unknown Discovery Gate | unknowns 4 分類・blindspot pass・Deviation Log                                                        | 追記     | plan 前ゲートは PlanGate 側（plan.md の Questions/Unknowns 拡張）と ai-loop 側（C-3' 入力の前提明示）の両建て。Deviation Log は decision record と統合検討。**I-9（宣言↔実差分）の運用面を補完** |
| #746 Claude Code loop 4 型 + Escalation Policy | Turn/Goal/Time/Proactive taxonomy・型昇格手続き・停止条件標準化・Proactive 限定導入 | 大部分カバー済み（§5 に語彙対応を追記。停止条件 9 項目中 7 は LoopSpec/既存正本、禁止 5 項目中 4 は HO/Approval Gate/arbiter-policy §2）。**採用しない**: 4 型の輸入（trigger/contract 混同の逆流）。**追記**: approval-gate 観点 12（UI/UX プロダクト判断）・arbiter-policy §7 に cost cap 非対象注記。**genuine gap → follow-up 起票**: 変更可能範囲（allowed_paths）と cost cap の LoopSpec フィールド・型昇格 policy（制定は Human-owned） | §5 / approval-gate-template / arbiter-policy §7 / follow-up issue |
| #727 CLAUDE.md ガードレール | Think Before Coding / Simplicity First / Surgical Changes / Goal-Driven                               | 部分採用 | 大半は core-contract / behavior-norms（委譲プロトコル）でカバー済み。gap 分析で不足分のみ追記。CLAUDE.md 本体は HO につき apply-script 経由                                                      |

---

## 9. non-goals（本書が扱わないこと）

- PlanGate 本番フロー（WF-00〜WF-07）の変更・置換
- 個別機構の仕様定義（各正本に委譲。本書は「なぜ」だけを持つ）
- 人間承認ゼロの正当化（I-1 により永久に扱わない）
- L5 コンテキスト基盤の先行設計

---

## 10. 関連ドキュメント

- [`concept.md`](./concept.md) — ai-loop コンセプト定義（L0-L5・Phase 計画）
- [`adaptive-production-loop.md`](../../workflows/ai-loop/adaptive-production-loop.md) — 6 ステップサイクル・1 サイクル contract 正本
- [`arbiter-policy.md`](./arbiter-policy.md) — Human-owned 境界・escalate 予算
- [`docs/ai/subagent-delegation/README.md`](../subagent-delegation/README.md) — 委譲プロトコル（Harness 層の隣接正本）
- issue [#726](https://github.com/s977043/plangate/issues/726) / [#727](https://github.com/s977043/plangate/issues/727) / [#728](https://github.com/s977043/plangate/issues/728) / [#729](https://github.com/s977043/plangate/issues/729) — intake 待ち知見

---

## 11. 外部検討の記録（C-2 相当）

本書初版は 2 系統の独立検討を経て v2 に改訂した（I-2 を本書自身に適用した実績）:

- **Codex**（codex-cli / read-only）: I-8（低リスク帯限定）・I-9（宣言↔実差分の二段 detect）の
  原理化、escalate の 2 文脈分離、terminal state の揺れ（round limit exceeded は遷移理由）、
  contract 要素の不一致、リファクタリングは段階的方式を推奨 — **全採用**。
- **独立 adversarial レビュー**（Gemini 実行不可のための代替 — Gemini CLI は
  個人向けティア廃止による認証エラーで `unavailable`。理由と代替観点を記録）:
  closed loop 定義の文書内不整合（critical）、severity 二軸性・L2 入力 4 軸の語彙欠落、
  provenance の過大主張、可逆性の原理格上げ、intake loop の maker-checker 違反、
  削除規律の実行者不在、効果測定の頻度不在 — **全採用**（可逆性は I-8 に統合）。
- **外部定義との照合**（C-4 レビュー指摘「独自定義を作らず一般定義と合わせる」を受けた
  追加検証・2026-07-07）: human-in/on/out-the-loop の一般定義 3 系統
  （Sheridan 監視制御 / 米 DoD Directive 3000.09 / EU HLEG Trustworthy AI の
  HITL・HOTL・HIC 3 分類）を Web 調査で照合。ai-loop の用法は一般 HOTL 単独ではなく
  **HIC + HOTL + HITL のハイブリッド**であることが判明し、§1.1 に対応表と
  誤読防止の注意 2 点を明文化。主な参照:
  [EU HLEG Ethics Guidelines for Trustworthy AI](https://digital-strategy.ec.europa.eu/en/library/ethics-guidelines-trustworthy-ai) /
  [DoD Directive 3000.09](https://www.esd.whs.mil/portals/54/documents/dd/issuances/dodd/300009p.pdf) /
  [CRS: U.S. Policy on Lethal Autonomous Weapon Systems](https://www.congress.gov/crs-product/IF11150)。
