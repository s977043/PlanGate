# Governed Autonomy 構想 — PlanGate × RiverReview による in→on 変態

> **Status**: 構想ディスカッション（2026-06-11）。実装なし・正本化なし。
> **置き場所**: 中立ローカル（plangate / river-review いずれのリポジトリにも未配置）。
> **テーマ**: PlanGate を基礎とした AI 駆動開発を、human-in-the-loop から
> human-on-the-loop へ「変態（metamorphosis）」させる。C-3 / C-4 のレビューを
> RiverReview の判断実行に委ね、承認境界は溶かさず自動範囲だけ広げる。

---

## 0. このドキュメントの位置づけ

- 本日（2026-06-11）は**構想の固定化のみ**。コード・hook・正本（`.claude/rules`,
  `docs/ai`）には一切触れない。
- 将来正本化する場合の配置方針は §8 に記す（HO 境界を尊重し、いきなり rules に書かない）。
- 比喩（幼虫 / 蛹 / 蝶）は思考の補助線。蛹で何が**溶け・残り・新生**するかで設計を整理する。

---

## 1. 背景 — in→on 変態と cortex 対照

### 1.1 出発点

PlanGate がこれまで強化したのは「単一 PBI を安全に通す」**垂直方向の統制**
（C-3 承認 / 承認境界 / hook 強制 / 責務4分類 / settings drift 防止）。ここはほぼ飽和。
「より先」は方向が変わり、**学習する WF（A）× 自律オーケストレーション（B）**
＝「自動の範囲が広がる」方向へ進む。

### 1.2 参照: AirCloset cortex（Zenn 3 記事）

- **human-in-the-loop ではなく human-on-the-loop**（人間は個別判定に混ざらず上から監督）。
- **学習の出力が「次の plan 品質」でなく「次の gate」**：失敗した瞬間に lint/型 gate を
  自動追加し、同型再発を機械的に弾く。
- **Product Graph / cpg**：コード・docs・DB・インフラを 1 グラフ統合、AI が Runbook で辿る。
- 品質ゲートの物理強制（eslint-disable 禁止・カバレッジ 90% 強制）。

### 1.3 設計思想の対比：PlanGate=「門」、cortex=「輪」

| 観点 | PlanGate（現在地） | cortex（参照） |
|---|---|---|
| 統制の重心 | plan 前段の入口（承認・境界・hook） | 全工程の閉ループ |
| 自律レベル | in-the-loop（ゲートで人間が混ざる） | on-the-loop（上から監督） |
| 継続改善 | retrospective 集計止まり | ガイドライン育成＋gate 自動追加 |
| コンテキスト | docs/working ファイル群 | Product Graph / cpg |
| 安全装置 | 承認境界・self-mod guard・EH（最厳格） | lint 逃げ道封鎖（品質寄り） |

**結論**: 両者は強みが直交。PlanGate の外骨格（承認境界）を保ったまま、cortex 的な
「輪」と「学習の gate 化」を取り込む＝**Governed Autonomy**。

---

## 2. 変態の本質 — 承認の「時制」が変わる

in→on の差は自動化率でなく **承認の時制**。

| | in-the-loop（幼虫） | on-the-loop（蝶） |
|---|---|---|
| 承認の時制 | 実行前（pre-act gate） | 逸脱検知時（on-exception） |
| 人間の認知負荷 | 件数にリニア比例（速度の天井） | 例外件数のみ（疎） |
| ゲートの役割 | 関所（通すか決める） | トリップワイヤ（逸脱を検知） |
| 信頼の対象 | 個別判断 | ガードレールそのもの |
| 失敗モード | 人間がボトルネック | サイレント逸脱（検知漏れ） |

### 蛹で起きる三層

- **溶ける器官**: 実行前ゲートとしての C-3（実行前 y/n の物理位置）。機能は残るが位置が
  「実行前」→「逸脱時」へ再結晶。
- **溶けない外骨格**: 承認境界・provenance（#420）・責務4分類・self-mod guard。
  自律の翼が大きいほど価値が上がる。
- **新生する器官**: 免疫系（学習→gate 自動生成、子失敗→自動修正起票）。

### 第1原則との両立（核心）

AI運用4原則 第1「実行前 y/n」は**廃止ではなく適用レイヤーの上昇**で両立：
> 個別アクション単位の y/n（幼虫）→ **方針・承認境界・例外昇格点の y/n（蝶）**。
> 人間は「各実行を承認」をやめ、「**自律の檻の形と、檻を出る条件**」を承認する。
> 檻の中は AI 自律、檻に触れたら自動停止＋人間昇格。

memory の伏線2つがこれを支える: ①「計画承認後は自律実行」②「自己設置の再承認 Gate は
自己解釈で解除しない」。第4原則（解釈変更禁止）にも反しない（文言でなくループの粒度が変態）。

---

## 3. RiverReview 現状確認（2026-06-11 実態調査）

RiverReview（s977043/river-review, v1.12.0）は**構想がほぼ実装済みの OSS**だった。

| RiverReview の核 | 実体 | 変態での役割 |
|---|---|---|
| Skills define judgment | レビュー基準を versioned / repo-owned skill 化（upstream/midstream/downstream） | チーム判断のコード化＝改善の単位 |
| Gates execute judgment | plan ゲート / exec ゲート（verify ゲート #802 計画中） | C-2/V-3 既対応、C-3/C-4 へ拡張可 |
| Riverbed remembers | suppression memory / fixture 回帰 / 決定論スコアリング / feedback classification | **「学習の gate 化」が実装済み** |
| 思想 | **人間レビューを AI で置換しない。判断基準を skill 化し人間は高リスク判断に集中**（Human Judgment Focus） | on-the-loop の定義そのもの |

**既存接続**: PlanGate は `docs/ai/external-reviewer-interface.md`（#227 / TASK-0089）で
RiverReview を C-2/V-3 の第一参照実装として配線済み（C-2→upstream, V-3→midstream）。

**依存ギャップ（羽化前に要確認の栄養）**:

- river CLI は **npm 未公開**（#800）。現状はプラグイン or GitHub Actions 経路のみ。
- **verify ゲート（#802）は計画中**。C-4「PR 完成後の検証」は RiverReview 側未実装。

---

## 4. C-1〜C-4 × RiverReview マッピング

**重要な分離**: RiverReview が担うのは「**判断の実行（verdict 生成）**」。
「**承認トークンの発行**」は別レイヤー（承認境界）。混ぜると境界が溶ける。

| | C-1 | C-2 | C-3 | C-4 |
|---|---|---|---|---|
| 現在 | セルフ | 複数視点 AI | 人間（plan 承認） | 人間（PR 承認） |
| 変態後の**判断実行** | RiverReview core | RiverReview upstream（実装済） | **RiverReview deep-model（2 モデル W チェック）** | **RiverReview midstream/verify(#802)** |
| 変態後の**承認発行** | — | — | 二分（§5） | 二分（§5） |

---

## 5. 承認二分ルール（設計の中核）

設計原則: **決定論・明示的失敗・トレース可能**（responsibility-classes の検証可能性要件に準拠）。
RiverReview verdict は入力、出力は4値（auto-approve / human 昇格 / 同期ブロック / 拒否）。

### 5.1 判定の入力（4 軸だけ・新概念を増やさない）

| 軸 | ソース | 値 |
|---|---|---|
| `boundary` | mode-classification HO 9 カテゴリ判定 | touches-HO / clean |
| `lite` | mode-classification `lite_eligible` | true / false |
| `verdict` | RiverReview スコアリング | critical/major 件数 |
| `class` | responsibility-classes | merge 含む / 含まない |

### 5.2 W チェック（2 モデル）— 承認トリアージの第一信号

RiverReview の W チェック（二重レビュー）を承認トリアージの核に据える。
**2 モデルが割れた所だけ人間が見る**＝Human Judgment Focus の最も純粋な実装。

| モデル A | モデル B | → 承認判定 |
|---|---|---|
| approve | approve | 合意 → auto-approve 候補（boundary clean 時） |
| approve | reject | **不一致 → human 昇格**（最も価値ある信号） |
| reject | reject | 合意 → ブロック |

**2 モデルの役割は非対称にする**（同型見落としを構造的に削減 / 死因3 予防）:

- モデル A＝順方向: plan-conformance / 設計妥当性（「正しく作られているか」）
- モデル B＝逆方向（adversarial）: 「どう壊れるか / どこをすり抜けたか」

### 5.3 C-3（plan 承認）二分マトリクス

実装前なので巻き戻しが安く、閾値は C-4 より緩めにできる。

| boundary | lite | verdict | → 判定 | 承認発行者 |
|---|---|---|---|---|
| clean | true | crit=0 ∧ maj=0（2 モデル合意） | **auto-approve** | AI（provenance 刻印） |
| clean | true | 2 モデル不一致 or maj≥1 | **human 昇格** | 人間（該当指摘のみ提示） |
| clean | false | crit=0 ∧ maj=0 | **human 昇格（軽）** | 人間（差分確認のみ） |
| clean | false | crit≥1 | **同期ブロック** | 人間（全 plan レビュー） |
| **touches-HO** | （無視） | （無視） | **同期ブロック固定** | 人間（AC-10 強制） |

- touches-HO は `lite_eligible` と auto-approve を**常に無効化**
  （mode-classification AC-10 / HO 常時 block と完全一致）。
- working-context「C-3 条件付き降格」の同期/非同期に、最低リスク帯だけ
  「**非同期かつ AI 承認**」段を追加する形。承認境界の撤廃ではない。

### 5.4 C-4（PR/merge 承認）二分 — 最も硬い

**分離**: C-4 auto-approve は「merge を AI が押す」ではない。`approve 判定`と
`merge 実行`は別レイヤー。responsibility-classes で **merge = Human-owned 固定**、
memory「sockpuppet マージ禁止 / 正規フロー必須」。

3 レイヤーに分解:

```text
レイヤーA: review verdict 生成   → RiverReview midstream/verify(#802)   … AI 可
レイヤーB: approve 判定発行      → 二分ルール（下表）                  … 条件付き AI 可
レイヤーC: merge 実行           → policy-gated auto-merge or 人間      … 二分
```

| boundary | lite | verdict | → B: approve | → C: merge |
|---|---|---|---|---|
| clean | true | crit=0∧maj=0（2 モデル合意） | **AI auto-approve** | **policy-gated auto-merge**※ |
| clean | false | crit=0∧maj=0 | AI approve（暫定） | **人間 merge** |
| clean | any | 不一致 or maj≥1 | **human 昇格** | 人間 merge |
| touches-HO / merge-policy 変更 | — | — | **同期ブロック** | **人間 merge 固定** |

※ policy-gated auto-merge は responsibility-classes の
`HumanOrPolicyFinalApprovalPassed`（事前定義 policy）を merge に適用＝
orchestrator-mode AS-3 と同じ構造。「人間 or 事前 policy」の **policy 側**を C-4 に
拡張するので新たな抜け穴を作らない。「人間レビュー必須をなくす」は**この最低
リスク帯でのみ**成立。

### 5.5 要石

二分の境界線は **`boundary`（HO 判定）が唯一の硬い壁**。それを越えなければ
verdict 質（crit/maj）× lite × 2 モデル合意度で機械的に分かれる。HO に触れた瞬間に
全部 human に戻る——この一点を死守すれば承認境界を溶かさず自動範囲だけ広げられる。

---

## 6. provenance / サーキットブレーカー

### 6.1 provenance 刻印（死因2「監督の幻想」対策・必須）

auto-approve / policy-merge 時は**承認の実在を証跡で担保**（EH-3 / #420 思想の拡張）。

```jsonc
// approvals/c3.json または c4.json に追記
{
  "decision": "AUTONOMOUS_APPROVED",
  "issued_by": "river-review@1.12.0",          // 誰が判断したか
  "policy_ref": "auto-approve-lite-clean@v1",   // どの事前 policy で
  "verdict_digest": "sha256:...",               // RiverReview 出力のハッシュ
  "w_check": { "model_a": "approve", "model_b": "approve" },
  "target_sha": "abc123",                        // 対象 commit（差し替え検知）
  "boundary_check": "clean",                     // HO 判定結果
  "lite_eligible": true,
  "circuit_breaker_armed": true
}
```

### 6.2 サーキットブレーカー（死因6「不可逆性」対策）

auto-approve を**いつでも in-the-loop に緊急差し戻す**機構
（working-context AC-9 reject 巻き戻しを on→in 方向へ転用）。

| トリガー | 動作 |
|---|---|
| auto-approve 後に人間が事後 reject | AC-9 巻き戻し（実装ブランチ破棄 / PR close / 成果物 invalidation） |
| 同一 policy で N 回連続 incident | その policy の auto-approve を**自動失効**→ human 昇格へ降格 |
| RiverReview verdict と実障害の乖離検知 | 該当 skill を suppression でなく**再学習キュー**へ |

### 6.3 human 昇格の「予算」（死因4 alert fatigue 対策）

on-the-loop の人間は有限。昇格無制限は形骸化を招く。1 スプリントで人間が見る昇格を
N 件に上限化し、超過分は重大度で自動トリアージ（critical のみ昇格、major は
riverbed memory に滞留させ次の skill 昇格候補へ）。

---

## 7. policy 制定 ＝ 第0の承認境界（論点 a）

`auto-approve-lite-clean@v1` のような policy 自体が**新しいメタ承認境界**。
これを HO パス相当として扱い、**policy の制定・改版だけは必ず人間（永久
in-the-loop）**＝「自分の翼の形を自分で書き換えない」を成文化（死因3 自己免疫の予防）。

- policy は versioned（`@v1`）。改版は HO 同様 Standard・同期 C-3 を強制。
- policy 制定主体: 人間（または将来、複数人間レビューの合議）。AI は policy の
  **draft 提案まで**、発行は不可（責務4分類「AI は自分の実行許可を発行しない」と一貫）。

### 人間承認ゼロへの道筋（保留・道だけ敷く）

最終的な人間ゼロは **policy maturity** で測る:

- policy が「N 回連続で人間判断と一致」した実績（eval baseline 接続）で段階的に信頼委譲。
- 今は**保留**。md には「将来この指標で解禁判定する」枠だけ残す。解禁判定そのものも
  人間が行う（メタ承認境界）。

---

## 8. 正本配置方針（論点 b）

verdict 実行（RiverReview）と承認発行（PlanGate）の責務境界を**どこに正本化するか**。

| 案 | 内容 | 評価 |
|---|---|---|
| 案1: external-reviewer-interface.md 拡張 | 既存 C-2/V-3 IF に C-3/C-4 の「verdict 実行」を追記 | verdict 側は自然。承認発行が別軸で混ざる懸念 |
| 案2: 新正本を立てる | `docs/ai/governed-autonomy.md`（仮）に承認二分・W チェック・policy を集約 | 承認境界に関わり HO 相当。**新正本制定は人間 C-3 必須** |
| 案3（推奨）: 二分して書く | verdict 実行＝external-reviewer-interface.md 拡張 / 承認二分・policy＝responsibility-classes と working-context の拡張節 | 既存正本の責務分界に**素直に乗る**。重複定義回避 |

**推奨は案3**: 「judgment 実行」は RiverReview IF、「承認発行」は責務4分類 /
working-context という既存の責務線に沿わせる。新概念正本を増やさない。

---

## 9. 変態の3法則 / 6 死因（チェックリスト）

### 変態の3法則

1. **自律範囲は広げる。だが自律を統治するメタ層（policy・gate 生成）は永久に
   in-the-loop**（自己免疫の予防）。
2. **監督にも provenance を課す**（監督の幻想の排除）。
3. **羽化と同時にサーキットブレーカーを作る**（不可逆性への保険）。

### 6 死因と抗体

| # | 死因 | PlanGate の抗体 | 不足 |
|---|---|---|---|
| 1 | サイレント逸脱（検知漏れ） | hook 12 種・EH 群 | 物理配線 6/12（検知器が半身） |
| 2 | 監督の幻想 | C-4 / handoff | 「見た証跡」が無い → §6.1 で対処 |
| 3 | 免疫系の自己免疫疾患 | severity 階層 | gate/policy 生成の承認境界 → §7 で対処 |
| 4 | 例外昇格の洪水 | mode 分類 | トリアージ層 → §6.3 で対処 |
| 5 | 承認境界の漸進侵食 | HO 常時 block / self-mod guard / #420 | provenance の穴（#420 未解決） |
| 6 | 羽化の不可逆性 | （巻き戻し AC-9） | on→in 差し戻し経路 → §6.2 で対処 |

---

## 10. 残論点・次アクション

### 残論点

- **R1**: 2 モデルの具体（同一モデル温度違い / 別モデル / 別 skill セット）。コストと
  多様性のトレードオフ。
- **R2**: policy maturity の定量指標（eval baseline との接続方法）。
- **R3**: river CLI npm 公開（#800）/ verify ゲート（#802）の前後関係と C-4 自動化の
  クリティカルパス。
- **R4**: human 昇格「予算」N の初期値と超過時のトリアージ閾値。
- **R5**: hook 物理配線 6/12 → 12/12 が on-the-loop の前提条件（死因1）。羽化の最低
  栄養として先行すべきか。

### 次アクション候補（実装はしない・次セッション以降）

1. 本 md をレビューし、案3（正本二分）で正本化の PBI 化を検討。
2. 最小羽化 PoC の対象を doc-light に絞る（最低リスク帯で W チェック→auto-approve を試行）。
3. RiverReview 側 #800 / #802 の状況を踏まえ C-4 自動化のロードマップ化。
4. policy スキーマ（`@vN`・boundary・lite・閾値）の draft（人間発行前提）。

---

## 付録: 関連参照

- PlanGate: `.claude/rules/{responsibility-classes,working-context,mode-classification,
  review-principles,orchestrator-mode,hybrid-architecture}.md`,
  `docs/ai/external-reviewer-interface.md`
- RiverReview: README / DOCUMENTATION / riverbed memory ガイド / W チェックガイド /
  #800（npm publish）/ #802（verify ゲート）
- cortex: Zenn @aircloset 3 記事（91824e55b7fc9c / d416342f46f16b / f6c990989e60d4）

---

## 11. 補遺：L0 の再評価と「別プロジェクト」という結論

> §10 までを受けた発展。**ブレスト（未確定）**。

### 11.1 制御の極性が反転する

```text
PlanGate         : "block until approved"（実行前に止める gate machine）
新システム        : "flow → detect → escalate on exception"
```

`bin/plangate exec`（APPROVED な c3.json が無ければ実行しない）は in-the-loop の心臓。
on-the-loop はこれを逆向きに再設計する＝継承でなく再設計。

### 11.2 L0 こそ大きく異なる（一枚岩でない）

当初「L0 だけは継承」は楽観的すぎた。L0 は中立な統制基盤でなく「人間が実行ループの
中にいる」前提に最適化された契約。前提が変われば契約も変わる。

L0 をさらに2層に割る:

```text
L0-契約（具体定義）  ← 書き換わる：責務分類 / 第1原則文言 / HO挙動 / mode判定
L0-メタ（設計哲学）  ← survive：「境界・provenance・決定論で自律を統制する」思想だけ
```

### 11.3 責務分類は「4→再設計」

| | PlanGate | 新システム |
|---|---|---|
| AI-owned | 実装・テスト・PR準備 | ＋自律実行・auto-approve 発行 |
| Human-owned | settings・merge・C-3/C-4 承認 | **policy 制定・例外裁定・事後監督** |
| CI-owned | drift 検出 | ＋逸脱検知・ブレーカー発火 |
| Workflow-owned | DoD・タスクロック | ＋学習ループ・昇格予算管理 |
| **Policy-owned**（新） | — | 事前定義された自律許可の裁定 |
| **Sensor-owned**（新?） | — | 逸脱検知の責務 |

Human-owned の中身が「実行前承認」から「メタ統治」へ総入れ替え、空席に Policy-owned。

### 11.4 結論：別プロジェクトとして始める

- 再利用率は契約まで含めると1割未満。survive は L0-メタ（設計哲学）だけ。
- 同一リポジトリ移行は in/on 契約の同居＝Shadow Config の親玉で自滅。
- → **新規実装で建て、PlanGate は freeze（参照実装・生きた教師）。別リポジトリ・別名**。
- PlanGate の最大の遺産は失敗履歴（INC群・HO由来・#420）＝新システムの threat model
  初期値。再利用すべきは機構でなく学習の記憶。

### 11.5 始め方の罠と対策

| 罠 | 対策 |
|---|---|
| グリーンフィールドの記憶喪失 | 最初に書くのはコードでなく PlanGate threat model の移植 |
| 谷（valley of death） | 成功を「全機能カバー」で測らず 1 領域の存在証明をゴールに |
| 外部依存のクリティカルパス | RiverReview 成熟（#800/#802）を前提条件として明示・分離 |
| スコープの誘惑 | 順序固定: L0-メタ抽出 → L2 心臓 → 1 領域 PoC |

---

## 12. 命名決定：別プロジェクト「Arbiter」

- 蛹→蝶の変態比喩は PlanGate を母体とする相対名のため不採用（独立プロジェクトに不適）。
- 仕組みの自立した本質「走らせたまま枠内に保ち逸脱だけ昇格する」＝**裁定**から命名。
- **決定: Arbiter**（裁定者）。心臓＝L2 裁定層を直指す。PlanGate を前提としない自立概念。
- 独立まとめ: `2026-06-11-arbiter-vision.md`。
