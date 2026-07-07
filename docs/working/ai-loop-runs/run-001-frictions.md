# Run-001 摩擦記録（L4 Remember / review-feedback-loop 入力）

> 初回実走（2026-07-07）で観測した事実の記録。Optimize（gate/skill/プロンプト更新）は
> 本記録を根拠に別途行う（design-philosophy I-5: 記録なき最適化の禁止）。

## 結果サマリ

- decision: **HUMAN_ESCALATED**（priority 2: boundary=clean だが lite=false）
- W チェック: Model A=approve / Model B=reject（不一致）
- lite=false の根拠: Model B 指摘 #3（「自己資産」第3分類の追加は分類スキーマ拡張 = new design）
  を受け、L1（呼び出し側）が no_new_design を **true→false に自己訂正**して入力した
- decision record: `20260707T021653Z-b209dbe.json`

## 摩擦点（Remember）

| #   | 観測事実                                                                                                                                                                                                                         | 種別                                                      |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| F-1 | Model B が REJECT_CATEGORY を語彙外の日本語「ロジック変更」で返し、L1 が "logic" へ正規化する必要があった。W チェック委託プロンプトに **enum 厳格指定（英語小文字の 14 語彙のみ）** が必要                                       | プロンプト定型の不備                                      |
| F-2 | asset-inventory.md / related-specs.md は「Phase 0 時点固定スナップショット」であり、後代資産を追記すると provenance を毀損する（Model B 指摘 #1）。**「living な資産索引」の置き場が未定義** という設計ギャップが露呈            | タスク設計の欠陥（計画段階で検出できず W チェックが捕捉） |
| F-3 | ho-paths.md L101「docs/ai/ai-loop/ 配下は **Phase 0 限定の例外**」が、恒久のディレクトリ指定か期間限定免除か曖昧。Phase 3 完了後の現在、AI が boundary=clean を自己判定する根拠が弱い（I-1 周辺のグレーゾーン。Model B 指摘 #4） | 正本の曖昧さ                                              |
| F-4 | LoopSpec の deterministic 検証（lint+リンク解決）では「5 件中 3 件しか追記していない部分同期」が PASS する穴（Model B 指摘 #5）。**AC を機械検証可能な形（例: 資産名 5 件の grep 存在確認）で deterministic に落とす**規律が要る | 検証設計の穴                                              |
| F-5 | （正常動作の確認）Model A/B は同一前提に収斂せず真に分岐した（#731 の failure mode「合意が誤りを補強」は発生せず）。非対称 W チェックの独立性が初回実走で実証された                                                              | 成功シグナル                                              |
| F-6 | （正常動作の確認）L1 が自分に不利な証拠（B 指摘）で lite 自己申告を訂正 → arbiter が決定論で escalate。安全側デフォルト（I-4）が end-to-end で機能                                                                               | 成功シグナル                                              |

## Optimize 候補（次サイクル以降・記録に基づく提案）

1. F-1 → ai-loop-cycle スキル / runbook §2-(2) の委託プロンプト定型に reject_category の
   enum 厳格出力を追記（実装先: `.claude/skills/ai-loop-cycle/`・非HO）
2. F-2 → 人間判断（本 run の escalate 事項）: living index の置き場を決める
3. F-3 → ho-paths.md の「Phase 0 限定」文言の明確化 issue を起票（HO 判定の正本につき
   変更自体は慎重に・まず issue）
4. F-4 → loopspec.md の verification.deterministic 節に「AC の機械検証化（grep 等）」の
   推奨を追記（非HO）

---

# Run-002 追記（同ファイルに連続記録）

## 結果サマリ

- decision: **AUTO_APPROVED**（priority 5: severity=low・C/D=approve-approve）— 初の auto-approve + provenance 刻印
- 経路: A=approve / B=reject(documentation・**F-1 の enum 厳格化が機能し語彙準拠**) → severity 分類 →
  Model C/D 観点特化裁定 → 決定論 auto-approve → exec（maker=sonnet）→ deterministic AC 全 PASS
- decision record: `*-run002.json`

## 摩擦点（Remember・次の Optimize 候補）

| # | 観測事実 | 種別 |
|---|---|---|
| F-7 | Model B が計画自身の AC 設計に F-4 同型の穴を検出（no_duplicate_taxonomy が review 観点のみで機械検証不能・コピーによる迂回を AC-4 が検知しない）。**「AC の機械検証化」は再帰的に適用すべき規律**であることが判明 | 検証設計 |
| F-8 | AC-3「記録層**または**契約層」の曖昧さを B が設計判断の残置と指摘 → Model D の裁定（契約層が妥当）で解消された。**配置の選択肢は W チェック前に 1 つへ確定させる**方が安い | 計画粒度 |
| F-9 | （成功）F-1 Optimize が初適用で機能（B の reject_category が enum 準拠）。**記録→Optimize→次サイクルで効果確認**の I-5 ループが 1 巡した | 成功シグナル |
