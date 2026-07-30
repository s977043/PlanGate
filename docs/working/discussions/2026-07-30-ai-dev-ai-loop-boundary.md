# 2026-07-30: ai-dev / ai-loop 境界の再確認 — アーキテクチャノート突合と重心決定

> 出典: ユーザー提供のアーキテクチャノート `plangate-ai-dev-ai-loop-architecture.html`
> （2026-07-30 レビュー実施。ブラウザレビュー + Claude Code handoff 用に生成されたもの）
> status: **方向決定済み 2 件（Human 決定・下記 §5）+ open questions（§8）**。
> 本ファイルの役割: ノートの内容を repo 内へ正本化する**前段の議論土台**。
> ノート内容・現状実測・決定事項・残論点を 1 箇所に集約し、後続 PBI 化
> （#923 Phase 1 / #894 / rollout-policy 整合）の入力にする。正本ではない。

## 0. 実測範囲・前提

- 実測時点: **2026-07-30 22:30 JST 頃**（同日中に状態が動いている。とくに PR #924 / #925 は 21:33 JST 頃に MERGED — 後続 PBI 化の直前に必ず各 issue / PR の最新状態を再取得すること）
- 対象ノート: `~/Downloads/plangate-ai-dev-ai-loop-architecture.html`（本文 283 行相当を全文抽出）
- 突合先（初回実測 = main `b306b12`、PR #924/#925 マージ後の再確認 = main `20e666f`）: `docs/workflows/ai-loop/00_concept.md` /
  `rollout-policy.md` / `lite-criteria.md` / `scripts/ai-loop/plan_package.py` /
  `scripts/ai-loop/delivery.py`（57 tests OK）/ `docs/working/ai-loop-runs/`（49 ファイル = decision record json 28 + 摩擦台帳等 md 21・run-025 まで）/
  `docs/ai/ai-loop/ho-paths.md`（21 パターン）/ issue #870 / #894 / #917 / #920 / #923
- 直前の議論: 2026-07-30 の「ai-loop と ai-dev の関係がおかしい」指摘（本ファイル §6 の非対称 A/B/C）

## 1. ノートの中心原則（verbatim 要約）

> **ai-dev は PR を作る。ai-loop は ai-dev を内包・制御し、PR を MERGE_READY まで
> 収束させ、次の改善につなげる。マージは人間が行う。**

ノートの結論: 「現在の整理は妥当。構造そのものを大きく変えるより、**作業単位・
停止理由・Engineering Layer との対応を補足**するのが適切」。

### 1.1 責務 4 分割（ノート）

| 領域 | 主な責務 | 完了状態 |
|------|---------|---------|
| ai-dev | 実装・修正・テスト・ビルド・PR 作成 | `PR_CREATED` |
| ai-loop Delivery | 実行制御、評価、再試行、停止判定、品質ゲート | `MERGE_READY` |
| ai-loop Evolution | 改善設計、知見再利用、次の課題化、ワークフロー進化 | 次の改善要求または実行計画 |
| Human | 最終レビュー、採用判断、マージ、運用方針決定 | `MERGED` または差し戻し |

### 1.2 実行フロー 6 段階（ノート）

```text
1. Request → 2. ai-dev → 3. PR_CREATED → 4. Delivery Loop → 5. MERGE_READY → 6. Human Merge
```

**注目点**: Delivery Loop は `PR_CREATED` の**後**に置かれ、pre-exec の計画裁定
（C-3'）はフロー図に**登場しない**。「ai-dev は PR 作成後の継続判断を行わない」
と対で、Loop の主戦場を PR 後の収束に置く構図。

### 1.3 Engineering Layer 対応（ノート）

| Layer | 作業単位 | PlanGate での主な対応先 |
|-------|---------|----------------------|
| Prompt | 単一リクエスト | 各エージェントの指示、入出力契約、制約、出力形式 |
| Context | 判断に必要な状態 | Issue、Plan、履歴、CI、レビュー、Trust Ledger、PlanGate Core |
| Harness | 1 回の実行 | Git、GitHub、テスト、ビルド、CI 取得、ツール実行、結果検証 |
| Loop | 実行全体 | ai-loop Delivery。継続、修正、再試行、停止、成功判定 |
| Graph | 完全なワークフロー | ai-loop Evolution。複数ループ、役割、依存関係、分岐、共有状態の編成 |

原則: **すべての失敗をプロンプトの問題として扱わない。壊れた作業単位とレイヤーを
特定し、そのレイヤーに対して最小の修正を行う**（= issue #923 の「モデルを最初に
責めない」と同一思想）。

### 1.4 終了理由の構造化（ノート）

「停止」と「成功」を分離し、exit reason を 7 値で区別する:

```text
success / max_iterations / budget_exceeded / timeout / blocked / tool_failure / human_required
```

（ノートの Issue テンプレート案では `unknown` を加えた 8 値）

### 1.5 ノートのその他の提案

- ai-loop Delivery は Harness と Loop の**両方を内包**していることを明示するとよい
- ai-loop Evolution は実態として **Graph Engineering に近い**
- Graph は複数エージェントに限らず、状態遷移を持つ単一エージェントでも成立する
- Issue テンプレートへ `Affected Engineering Layer` / `Broken Work Unit` /
  `Failure Symptom` / `Expected Invariant` / `Verification Method` / `Exit Reason` を追加

## 2. 現状との突合（実測）

| ノートの主張 | 現状（main `b306b12` 実測） | 判定 |
|---|---|---|
| ai-dev = `PR_CREATED` まで | `00_concept.md` §2.1-2.2 の 5 責務表と一致 | ✅ 一致 |
| Delivery = `MERGE_READY` まで | 定義一致。実装は判定エンジン `delivery.py`（純判定器・57 tests OK）のみで、**実 PR 収束（Collector / Executor / Reconciler）は #917 未実装**（pbi は PR #925 で **2026-07-30 MERGED**・`20e666f`。次は plan 生成） | ✅ 定義一致 / 実装は #917 |
| ai-loop は ai-dev を「内包・制御」 | `00_concept.md` §1 に同文言。ただし実装の入口は「既存 Plan Package を起点に run 開始」（`plan_package.py`）で、intent 受付は含まれない | ⚠️ 定義と実装が乖離（§6 の C） |
| Delivery Loop は `PR_CREATED` の後 | `00_concept.md` は「intent 受付から MERGE_READY まで一気通貫」+ **C-3 を C-3' に置換**が中核（§2.4・§3.1 の 2026-07-02 設計判断 verbatim） | ❌ **差分**: ノートは C-3' 非言及。§5 の決定で解消方向を確定 |
| Evolution = 改善設計・次の打ち手 | 定義あり（§2.1）・実装ゼロ。#874（Run Evidence）→ #869（Evolution Loop）が担当 | ✅ 定義一致 / 未実装 |
| Exit Reason 7 値 | **存在しない**。現行語彙は裁定 3 値（`AUTO_APPROVED`/`HUMAN_ESCALATED`/`BLOCKED`）+ Delivery 状態 3 値（`PR_CREATED`/`MERGE_READY`/`MERGED`）+ `delivery.py` の `EXITS`（`EXEC_RETURN`/`HUMAN_ESCALATED`）。**#894（Loop Control Contract の decision enum・停止予算・no-progress 判定）の要求と直結** | 🆕 #894 と統合が必要 |
| 5 レイヤー対応表 + 診断 | **存在しない**。#923（Harness/Loop/Graph 責務分離・**Phase 0〜5 の 6 段階**・AC 10 項目）が要求。ノートの表は #923 **Phase 1（Architecture Definition）**の成果物。ただし着手前に **Phase 0（Inventory / Overlap Check = 棚卸し・#911 等との境界確定）**が前提 | 🆕 #923 の入力 |
| Issue テンプレート拡張 | `.github/ISSUE_TEMPLATE/` は 4 ファイル（bug / feature / roadmap-task / config）。レイヤー・Exit Reason 欄なし。**ISSUE_TEMPLATE は EH-3 の HO 9 カテゴリ対象外**（`.github/workflows/*` のみ HO）→ AI 編集可。ただし `docs/ai/issue-governance.md` §2（required sections 正本）の改訂が対になる | 🆕 新規 |
| MERGE_READY ≠ 自動マージ可能 | NO MERGE BY AI（Iron Law）・`MERGED` は Human C-4 のみ、と一致 | ✅ 一致 |

### 2.1 配置制約の実測（後続ドキュメント作成時の前提）

| パス | EH-3（HO 9 カテゴリ） | ai-loop 機械層 / 規範層 |
|------|----------------------|------------------------|
| `docs/ai/*.md`（直下） | **対象外** → 通常フローで AI 編集可 | `ho-paths.md` の HO 表に登録あり → arbiter は touches-HO（ai-loop では escalate） |
| `docs/workflows/ai-loop/**` | 対象外 | **判定基盤 carve-out ②** → ai-loop で回せない（規範層。機械強制は #916 待ち）。通常フロー + Human C-3 で改訂 |
| `.github/ISSUE_TEMPLATE/*.yml` | 対象外 | HO 表に登録なし |
| `.github/workflows/*.yml` | **HO 対象** → Human patch 分離 | — |

## 3. ノートと既存 issue の対応

| ノートの要素 | 対応 issue | 現状 |
|---|---|---|
| 5 レイヤー + 診断 + Issue テンプレート | **#923**（[P1] Harness / Loop / Graph の責務分離とレイヤー診断。**Phase 0〜5**） | pbi 未作成 |
| Exit Reason / 停止と成功の分離 | **#894**（Loop Control Contract: Verifier 階層・停止予算・進捗判定・decision enum） | pbi あり（critical・C-3 論点未解消） |
| Delivery の実 PR 収束 | **#917**（Collector / Executor / Reconciler。EPIC #870 の close blocker） | pbi **main 実在**（PR #925 MERGED `20e666f`）。次 = plan 生成（Mode=critical） |
| Evolution / 実行履歴分析 | **#874**（Run Evidence 契約）→ **#869**（Evolution Loop） | pbi あり（critical） |
| 状態管理・証拠契約・独立レビュー | **#920**（Software Factory 型の統合。既存機構の強化方針と明記） | pbi 未作成・トリアージ未 |

ノートは新奇な提案ではなく、**既存 issue 群が個別に要求してきたものを 1 枚に統合
した見取り図**として機能する。

## 4. 直前議論との接続 — 3 つの非対称（2026-07-30 実測）

ノートが触れていない、同日の実測で確認済みの構造問題:

| # | 非対称 | 実測根拠 |
|---|--------|---------|
| A | **C-3 自動化の投資対効果が逆立ち**: eligible は light 帯（`SIZE_OK_MAX_FILES=2`・変更 1〜2 ファイル）限定だが、light 帯の C-3 は元々「差分確認のみ」。C-3 が重い standard 以上は全部 eligible 外 | `lite-criteria.md` §2 / `mode-classification.md` フェーズ適用マトリクス |
| B | **Plan Package 契約と eligible 条件が相互排他気味**: `plan_package.py` は C-1 + C-2 evidence を必須とするが、mode-classification では C-2 は high 以上のみ「○」。eligible な light 帯は C-2 を通常持たない | `plan_package.py` の定数 `C1_EVIDENCE`/`C2_EVIDENCE`（L31-32）+ **必須化の実体は `check_evidence()`（L100〜。欠落・stale・受理対象外 verdict をすべて error）** / run-001〜025 は Plan Package 束縛前の記録（`gates: {c1: PASS}` のみ。`plan_package.py` 導入 = 2026-07-20 PR #886 は run-025 = 07-12 より後） |
| C | **「内包・一気通貫」の定義 vs 「Plan Package 後段」の実装乖離**: `00_concept.md` §2.4 は「intent 受付から一気通貫」だが、`run TASK-XXXX` の実入口は Plan Package 完成後 | `.claude/commands/ai-loop-workflow.md` / `plan_package.py` |

## 5. Human 決定（2026-07-30）

### 決定 1: 重心を Delivery へ移す

> C-3' は「**eligible run 限定の入口最適化**」に位置づけを格下げして**維持**し、
> ai-loop の本体価値を **PR 後の収束（Delivery）+ 改善（Evolution）** と再定義する。
> ノートの構図（Delivery Loop = PR 作成後）どおり。実装済みの arbiter・
> c3-prime-contract・25 run の実績は捨てない。eligible 枯渇問題（§4 の A/B）は
> 「解く」のではなく**優先度を下げる**（本体価値が C-3' に依存しなくなるため）。

この決定が各問題に与える影響:

| 対象 | 影響 |
|------|------|
| 非対称 A / B | 優先度低下（C-3' は限定的な入口最適化なので、適用帯が狭くても本体価値を毀損しない）。是正 issue は起票するが P2 相当 |
| 非対称 C | **解消方向**: 「内包・一気通貫」の記述を「Delivery は `PR_CREATED` 以降の収束に責務を持つ。入口（Plan〜C-3'）は eligible run 限定の最適化」へ改訂する |
| #917 | **最優先の実装対象**（重心そのもの）。EPIC #870 close blocker と整合。ただし issue 本文の「#894(a) 確定後の着手が効率的」+ AC-6（#894 接続）による**緩い順序依存**あり — plan で扱いを確定（TASK-0917 pbi の U-5 と同一論点） |
| #894 | Exit Reason 統合の受け皿として重要度が上がる |
| `00_concept.md` §2.4・§3 | 改訂が必要（carve-out ② → 通常フロー + Human C-3。§3.1 の 2026-07-02 設計判断 verbatim は「歴史的判断 + 本決定による位置づけ変更」として両方残す） |
| `rollout-policy.md` | 「C-3' 適用範囲の拡大」方向の改訂圧力が下がる。現行 Phase 1 のまま維持で可 |

### 決定 2: 進め方は「まず docs 化して議論の土台に」

正規 PBI 化（#923 Phase 1 等）の前に、本ファイルを議論の土台として整備する。
PBI 化・正本改訂はこの議論の収束後。

## 6. 正本改訂の候補マップ（PBI 化の入力）

| # | ドキュメント | 内容 | 対応 issue | 制約 |
|---|---|---|---|---|
| D1 | `docs/ai/agent-engineering-layers.md`（新規正本） | 5 レイヤー定義 + PlanGate 対応表 + 診断プロトコル + Exit Reason（#894 接続宣言） | #923 **Phase 0（棚卸し）+ Phase 1（文書化）** | `docs/ai/` 直下 = ai-loop では touches-HO（通常フローで作成）。※本表の「Phase」は #923 の実行計画の段階を指す。`rollout-policy.md` の「Phase 1（導入先適用）」とは**別概念**（多義性注意） |
| D2 | `00_concept.md` §2.4/§3 改訂 | 決定 1 の反映（Delivery 重心・C-3' 位置づけ・実行フロー 6 段階）+ D1 参照 | #870 / #923 | **carve-out ②** → Human C-3 必須 |
| D3 | Issue テンプレート拡張 + `issue-governance.md` 改訂 | `Affected Layer` / `Exit Reason` 等の追加 | #923 | ISSUE_TEMPLATE は HO 外。governance 正本と対で改訂 |
| D4 | rollout-policy / plan_package 整合の是正 issue 起票 | 非対称 A / B の記録と是正方針（例: Plan Package 契約の mode 可変化） | 新規 issue（P2 目安） | — |

推奨順序: **D4 起票（記録だけ先に）→ #923 Phase 0〜1 として D1+D3 を PBI 化 → D2 は
D1 確定後**（D2 が参照する先を先に作る）。#917（Delivery 実装）はこれらと独立に進行可
（ただし #917 issue 本文は「#894(a) 契約〔enum / reason code〕確定後の着手が効率的」
としており、AC-6 は #894 接続を要求する — 完全独立ではなく緩い順序依存がある）。

## 7. ノート由来の実装指示・テンプレート案（転記）

ノートには Claude Code へそのまま渡せる実行指示と Issue テンプレート案が含まれる。
PBI 化の際の素材として要点のみ転記する:

- 実施内容: 現状実装との差分一覧 → 不足責務・曖昧な境界・重複実装の特定 →
  破壊的変更を避けた段階的計画 → Issue を小さく分割（各 Issue に
  `Affected Engineering Layer` / `Broken Work Unit` / `Failure Symptom` /
  `Expected Invariant` / `Verification Method` を明記）
- 原則: 完了済みの実装を重複して作り直さない / `MERGE_READY` までを自動化範囲とし
  マージは人間に残す / 失敗時に最初からプロンプトを修正しない

## 8. Open questions（議論すべき残点）

1. **Exit Reason 7 値と既存語彙の統合設計**: 裁定 3 値・Delivery 状態 3 値・
   `delivery.py` の `EXITS` と、どう階層化するか（#894 の C-3 論点「terminal 3 値 /
   8 値の関係」と同一の議論。二重定義を避け #894 側で確定させるべきか）
2. **Evolution = Graph の再ラベリングの是非**: `00_concept.md` の 5 責務表を
   レイヤー語彙で書き換えるか、対応表（D1）からの参照に留めるか
3. **#920（Software Factory）との整理**: 状態管理・証拠契約の要求が #923 /
   #894 と重なる。EPIC #870 配下に入れるか、独立トラックか（トリアージ未実施）
4. **C-3' の格下げを rollout-policy にどう書くか**: 「Phase 1 のまま維持」で
   済ませるか、「入口最適化」への位置づけ変更を §1 に明記するか
5. **非対称 B の実利判断**: light 帯で C-2 を要求し続けるか（現状の
   `plan_package.py` 契約のまま）、mode 可変にするか — D4 issue の中心論点。
   なお中間解として `mode-classification.md` の **Lite ゲート（`lite_eligible`）**
   = 「C-2 を複数観点から **1 本**（critical/major=0 要求・観点固定）へ軽量化」が
   既に存在する。ゼロ化か 1 本化かの比較も D4 に含める
6. **収束判定の基準**: 誰が・どの条件で「議論が収束した」とみなし PBI 化を開始
   するか（例: §8 の各論点に Human の方向決定が付いた時点 / 一定期間フィードバック
   が無ければ現行案で確定）。これを決めないと本ファイルが「土台」のまま滞留する

## 9. 参照

- ノート原本: `~/Downloads/plangate-ai-dev-ai-loop-architecture.html`（repo 外・3MB HTML）
- 正本: [`00_concept.md`](../../workflows/ai-loop/00_concept.md) /
  [`rollout-policy.md`](../../workflows/ai-loop/rollout-policy.md) /
  [`lite-criteria.md`](../../workflows/ai-loop/lite-criteria.md) /
  [`delivery-state-machine.md`](../../workflows/ai-loop/delivery-state-machine.md)
- issue: [#870](https://github.com/s977043/plangate/issues/870) /
  [#894](https://github.com/s977043/plangate/issues/894) /
  [#917](https://github.com/s977043/plangate/issues/917) /
  [#920](https://github.com/s977043/plangate/issues/920) /
  [#923](https://github.com/s977043/plangate/issues/923)
- 関連 pbi（いずれも 2026-07-30 MERGED で main 実在）: `docs/working/TASK-0917/pbi-input.md`（PR #925・`20e666f`）/
  `docs/working/TASK-0916/pbi-input.md`（PR #924・`d98a701`）
