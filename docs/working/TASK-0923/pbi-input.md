# PBI INPUT PACKAGE — TASK-0923

> Issue: [#923](https://github.com/s977043/plangate/issues/923)（enhancement / **priority:P1** / ai-loop / architecture / area:workflow）
> スコープ: issue の実行計画 **Phase 0（Inventory / Overlap Check）+ Phase 1（Architecture Definition）のみ**。Phase 2〜5（Contracts / ai-loop Integration / Observability / Validation）は後続 PBI
> 由来: 境界議論 doc（[`2026-07-30-ai-dev-ai-loop-boundary.md`](../discussions/2026-07-30-ai-dev-ai-loop-boundary.md)）の **D1**（`agent-engineering-layers.md` 新設）。同 doc の Human 決定 2 件（重心 Delivery / docs 化先行）の収束を受けて PBI 化（2026-07-31 Human 確認済み）
> 作成: 2026-07-31（main `02a7185` で実測）
> レビュー: 敵対レビュー（R-201〜R-206 = セッション内採番・成果物は PR 本文に要約）+ River Review（RV-F1〜F4）を全件反映済み

## Context / Why

AI Agent の設計では **Harness（実行環境）/ Loop（証拠に基づく検証・改善・停止）/ Graph（制御経路）** の 3 つが混同されやすく、失敗時に原因レイヤーを特定できず**モデル性能へ誤帰属**しやすい（issue #923 背景）。

PlanGate / ai-loop には既に Plan-first・C-1〜C-4・Conductor/Worker/Verifier/Gate・`MERGE_READY`・Trust Ledger 等、3 レイヤーに相当する機能が存在するが、**各機能の所属責務・障害の発生レイヤー・停止条件・Graph 状態の表現が横断的に整理されていない**。

外部アーキテクチャノート（境界議論 doc §1.3 に転記済み）は 5 レイヤー対応表（Prompt / Context / Harness / Loop / Graph）と診断原則「**すべての失敗をプロンプトの問題として扱わない。壊れた作業単位とレイヤーを特定し、そのレイヤーに最小の修正を行う**」を提示しており、これが本 PBI の Phase 1 成果物の直接素材になる。

### 実測（main `02a7185`）

- レイヤー定義・責務カタログは**リポジトリに存在しない**。用語集は **`docs/ai/` 配下には無い**が、**`docs/pages/reference/glossary.md`（80 行・略号中心のクイックリファレンス・ABCD↔WF 対応の正本）が repo に実在**する（R-201 で当初の「存在しない」を是正）。issue の Phase 1 も「用語集を**更新**する」（新設ではない動詞）
- 境界議論 doc は main 実在（PR #926）で、Human 決定 1「**重心を Delivery へ**（C-3' は eligible run 限定の入口最適化）」が記録済み — レイヤー対応表の「Loop = ai-loop Delivery」記述はこの決定と整合させる
- 関連 issue の現状: #911（Work Item Graph — pbi 未作成・issue 本文が「詳細実装は #911 を正とする」と分界済み）/ #894（Loop Control Contract — pbi あり・**Exit Reason enum の正本候補**）/ #874（RunEvidence — pbi あり・failure layer の保存先）/ **#869（Harness Evolution / Retrospective 駆動の改善サイクル — pbi あり）/ #908（Trajectory Eval — pbi あり）**（RV-F3 で同定追記）/ #920（Software Factory — P2・Phase 0 で境界確認が必要と本 pbi 起草者がトリアージコメント済み）
- issue Phase 0 の「Trust Ledger 関連 Issue との境界確定」は、**該当 issue #780 が CLOSED のため対応 issue が無い** — Trust Ledger はコンポーネント棚卸し（In scope 1）で扱う（RV-F3）

## What（Scope）

### In scope（issue Phase 0 + Phase 1 の verbatim を基点に具体化）

#### Phase 0: Inventory / Overlap Check

1. 主要コンポーネントと関連 issue の**棚卸し表**を作成。対象は issue 実装案 A の「最低限の対象」10 項目を**全包含**する: Plan artifact / **Context Contract** / C-1〜C-4・C-3' / Conductor・Worker・Verifier・Gate / **LoopControl** / RunEvidence / Work Item Graph / `MERGE_READY` / Trust Ledger / **Harness Evolution**（+ 実装済みの arbiter / delivery。太字 3 件は当初列挙から欠落していたもの — R-202）
2. 各責務を Harness / Loop / Graph へ**仮分類**し、重複・責務衝突・未定義領域を一覧化
3. **#911 / #894 / #874 / #869 / #908 / #920 との境界を確定**（「重複する実装は新設せず、各正本へ仕様追記する」— issue 明記の原則に従う）

#### Phase 1: Architecture Definition

1. **3 レイヤーの正式定義を `docs/ai/agent-engineering-layers.md`（新規正本）へ追加**（5 レイヤー対応表〔Prompt / Context を含む〕+ 診断原則を含む。境界議論 doc §1.3 の表が素材）
2. **Layer Responsibility Catalog** を作成（既存コンポーネント → primary layer の対応表）
3. **`primary layer` / `secondary layer` / `non-responsibility` の記述規約**を定義
4. **Agent Engineering 用語集の整備**（実現方式は **U-1 の 3 択**〔既存 `docs/pages/reference/glossary.md` への追記 / layers 正本へ内包 / 独立ファイル〕を plan で確定 — RV-F1）

### Out of scope（issue の非目標 + Phase 2 以降）

- 新しい Graph 実行エンジンの導入 / 既存 ai-loop・Work Item Graph の作り直し / 全処理の Graph 化 / モデル性能評価の置換 / LangGraph 等への依存（issue 非目標 verbatim）
- **Phase 2 以降のすべて**: Failure Layer Classification / Stop Contract / Workflow State Snapshot の schema 定義（Phase 2）・ai-loop 統合（Phase 3）・Observability / Trust Ledger（Phase 4）・fixture / テスト（Phase 5）
- **Exit Reason enum の正本定義**: 境界議論 doc の open question 1 の帰結として、**enum の正本は #894（Loop Control Contract）側**とし、本 PBI は対応表からの**参照に留める**（二重定義しない。Phase 0 の境界確定で #894 側へ申し送る）
- Issue テンプレート拡張（`Affected Engineering Layer` / `Exit Reason` 欄）: 境界議論 doc の D3。本 PBI に含めるかは plan で判断（含める場合も `issue-governance.md` の改訂とセットで最小に）

## 受入基準

> issue #923 の受入条件 10 項目のうち、**Phase 0〜1 で充足可能なもの**に絞って按分（残りは Phase 2 以降の後続 PBI が担う）。plan で最終確定する。

- **AC-1**: Harness / Loop / Graph の**責務と境界が文書化**されている（`docs/ai/agent-engineering-layers.md` 新設。issue 受入条件 1 の充足）
- **AC-2**: 主要コンポーネントが **Layer Responsibility Catalog へ分類**されている（同 2。棚卸し表 + primary/secondary/non-responsibility 規約に基づく）
- **AC-3**: **#911 / RunEvidence（#874）/ LoopControl（#894）等と責務が重複していない**ことが境界表で示される（同 7。「Work Item Graph 詳細は #911 が正」「Exit Reason enum は #894 が正」等の分界宣言を含む）。**検証方法（R-204 / RV-F2 で時系列を是正）**: 境界表の自己申告で終わらせず、**V-3 外部レビュー（high-risk で必須・実装後）が境界表を対象 issue 本文とクロスチェック**する（C-2 は plan ゲートで境界表がまだ存在しないため主体にできない。plan に境界表**ドラフト**を含めて C-2 で先行確認する二段構成は plan の裁量）
- **AC-4**: 診断原則（「モデルを最初に責めず、失敗レイヤーを診断する」）と **3 レイヤー診断の実施手順（人間向けチェックリスト）**が文書化されている（同 8「モデル昇格前に 3 レイヤー診断を実行できる」の**文書レベル**での充足。機械化は Phase 3 以降）
- **AC-5**: 既存フローの**後方互換性が維持**される（同 10。本 PBI は文書追加のみで挙動変更ゼロ = `sh tests/run-tests.sh` が baseline を維持）
- **AC-6**: 重複が判明した領域について、**新設ではなく各正本への仕様追記 or 申し送り**として記録される（出典は受入条件 10 項目ではなく issue「既存Issueとの関係」節 + 完了の定義 6 — R-205）。**検証方法（R-204）**: 申し送りは**対象 issue へのコメント投稿を必須**とする（#920 への 2026-07-31 トリアージコメントが先例。境界表のみでは自己申告に留まるため）。→ これにより U-4 は「**コメント必須**」で解消

## Notes from Refinement

### 配置制約（実測・境界議論 doc §2.1 と同一）

| 対象 | EH-3（編集時常時 block） | ho-paths（ai-loop 実行時） |
|------|------------------------|---------------------------|
| `docs/ai/agent-engineering-layers.md`（新設） | **対象外** → 通常フロー（ai-dev）で AI 作成可 | `docs/ai/*.md`（トップレベル）= **HO-contract** → ai-loop で回すと touches-HO。**本 PBI は通常フローで実施する** |

### 素材（すべて main 実在）

- 境界議論 doc §1.3 の 5 レイヤー対応表 + §1.4 Exit Reason 7 値 + §1.5 提案（「Delivery は Harness と Loop の両方を内包」「Evolution は Graph に近い」「Graph は単一エージェントでも成立」）
- 同 §5 Human 決定 1（重心 Delivery）— Loop 行の記述はこれと整合させる
- issue #923 の「レイヤー定義」節（Harness / Loop / Graph の 3 定義）と「実装案」節

### Mode 見込み: high-risk（R-203 で standard から是正・plan で確定）

- 定量: 変更ファイル数 **3〜4**（新規正本 1 + 用語集 + 棚卸し表 + 関連正本への参照追記。上端採用で standard 帯 3-5）。**受入基準 6 → high 帯（6-10）**
- `mode-classification.md` の判定ロジック「1. 定量基準の各軸で判定（**最大値を採用**）」により定量 = **high**。「3. 定量と定性の高い方」により**最終 = high-risk 以上が確定**（当初 standard と書いたのは判定ロジックの不遵守 — 自ら「high 帯」と記載した軸を最終判定へ反映していなかった）
- 帰結: **C-2 外部レビュー必須（○）・V-2 も必須**（standard なら両方スキップだった）。`lite_eligible=false`・Human C-3
- 定性は文書追加のみ・挙動変更ゼロ・HO 9 カテゴリ非該当（実測）だが、判定ロジック上 定性で下げることはできない

## Estimation Evidence

### Risks

| Risk | 影響 | 一次緩和 |
|------|------|---------|
| 3 レイヤー定義が既存正本と用語衝突する。**具体的な衝突源を実測済み（R-206）**: `00_concept.md` L56 の 5 責務表は列見出しが**まさに「レイヤー」**/ 同 L270 の「Loop」（Delivery Loop / Evolution Loop）/ §4.2「**6 層自己改善ループ**」— 本 PBI の「Loop」は既存正本内で **3 種類の異なる意味**の「Loop / 層」と混線する | 正本間ドリフト（#913 型）の新規発生 | Phase 0 の棚卸しで既存正本の用語を全数照合し、**再定義せず参照**する。「Loop（Engineering Layer）」と「Delivery/Evolution Loop（run の進行構造）」の呼び分け規約を layers 正本に明記する |
| #894 の Exit Reason enum とレイヤー診断の停止語彙が二重定義になる | 語彙分裂 | Out of scope で「enum 正本は #894」と分界済み。対応表は参照のみ |
| #920（Software Factory）と State/Evidence の概念が重複 | 二重整理 | Phase 0 で境界確認し、重複は #920 側へ申し送り（#920 のトリアージコメントで予告済み） |
| Catalog の分類が「正解のない議論」化して収束しない | PBI が終わらない | primary layer は**単一値**（迷ったら secondary へ）+ 「分類は診断の出発点であり真理表ではない」と規約に明記 |
| 決定 1（重心 Delivery）と矛盾する記述の混入 | 境界議論 doc との不整合 | Loop = Delivery 中心 / C-3' = 入口最適化 の言い回しを議論 doc から転写しレビューで照合 |

### Unknowns

- **U-1**: 用語集の実現方式 3 択（plan で確定）: (a) **既存 `docs/pages/reference/glossary.md` への追記**（issue の「更新する」と整合。ただし同ファイルは略号中心で概念定義とは性質が異なる）/ (b) layers 正本へ内包 / (c) 独立ファイル新設
- **U-2**: 棚卸し表の置き場（`docs/working/TASK-0923/` の作業成果か、正本の付録か）
- **U-3**: Issue テンプレート拡張（D3）を本 PBI に含めるか後続にするか（含める場合 `issue-governance.md` の改訂とセット）
- ~~U-4~~ **解消済み（R-204）**: 境界確定は**対象 issue へのコメント投稿を必須**とする（AC-6 の検証方法として固定。#920 への先例あり）

### Assumptions

- 境界議論 doc の Human 決定 1・2 が有効であること（2026-07-31 に収束確認済み）
- #911 / #894 / #874 / #869 / #908 / #920 の各 issue 本文・pbi-input が境界確定の入力として現状のまま参照可能であること
- `sh tests/run-tests.sh` の baseline が維持されること（本 PBI は文書のみで影響しない想定）
