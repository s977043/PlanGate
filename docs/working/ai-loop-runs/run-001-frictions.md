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

## Run-002 追記（同ファイルに連続記録）

### 結果サマリ（Run-002）

- decision: **AUTO_APPROVED**（priority 5: severity=low・C/D=approve-approve）— 初の auto-approve + provenance 刻印
- 経路: A=approve / B=reject(documentation・**F-1 の enum 厳格化が機能し語彙準拠**) → severity 分類 →
  Model C/D 観点特化裁定 → 決定論 auto-approve → exec（maker=sonnet）→ deterministic AC 全 PASS
- decision record: `*-run002.json`

### 摩擦点（Remember・次の Optimize 候補）

| # | 観測事実 | 種別 |
|---|---|---|
| F-7 | Model B が計画自身の AC 設計に F-4 同型の穴を検出（no_duplicate_taxonomy が review 観点のみで機械検証不能・コピーによる迂回を AC-4 が検知しない）。**「AC の機械検証化」は再帰的に適用すべき規律**であることが判明 | 検証設計 |
| F-8 | AC-3「記録層**または**契約層」の曖昧さを B が設計判断の残置と指摘 → Model D の裁定（契約層が妥当）で解消された。**配置の選択肢は W チェック前に 1 つへ確定させる**方が安い | 計画粒度 |
| F-9 | （成功）F-1 Optimize が初適用で機能（B の reject_category が enum 準拠）。**記録→Optimize→次サイクルで効果確認**の I-5 ループが 1 巡した | 成功シグナル |

| F-10 | decision record（arbiter.py の provenance 出力）に Model B の `reject_category` と C/D 起動理由が記録されず、「なぜ severity=low と分類されたか」が record 単体から追跡できない（C-4 レビュー指摘）。**record の手編集は provenance 改竄になるため行わず**、arbiter.py の provenance schema 拡張（`w_check.reject_category` フィールド追加 + test_arbiter 更新）を Optimize 候補とする | 記録スキーマの不足 |

---

## Run-003 追記（初のコード run・3 ラウンド収束）

### 結果サマリ（Run-003）

- 経過: R1 A✓/B✗(test_shortage) → 4改訂 → R2 **A✗(naming)/B✗(logic) 同一欠陥に独立到達 →
  arbiter BLOCKED 刻印（reject-reject 経路の初発火）** → 改訂5-7 → R3 A✓/B✓ →
  **AUTO_APPROVED（priority 6 合意）** → exec 62/62 PASS
- F-10 達成の実証: run-002 相当入力の smoke で `w_check.reject_category: "documentation"` が刻印

### 摩擦点（Remember）

| #    | 観測事実 | 種別 |
| ---- | -------- | ---- |
| F-11 | 本 run は「裁定エンジンの記録方式を裁定エンジン自身のガバナンスで変更する」自己参照構造（R1/R2 の B が連続指摘）。歯止め（severity マッピング・裁定ロジック不変）で許容したが、**arbiter.py の判断ロジック（decision table 優先順位・SEVERITY_MAP）変更は touches_ho:unconditional 相当の固定ルール化を Human 判断で検討**すべき（構造的ゲート昇格の提案。#739 と同族） | I-1 境界設計 |
| F-12 | 機械検証コマンド自体に欠陥が 2 度混入（R1: BSD sed 非互換で 0 行 / R2: grep パターンが命名規約と不整合で正しい実装を FAIL 判定）。**「検証コマンドは計画時に実機で通し、規約準拠のサンプル入力で PASS/FAIL 両方向を確認する」**を loopspec 検証設計の規律に追加すべき | 検証の検証 |
| F-13 | （成功）W チェックの両極性が実証: 順方向 A も R2 で reject を出し（naming）、B は R3 で I-6 注意（無限 reject 禁止）の下で approve に収束。**3 ラウンド規律 + reject-reject BLOCKED + 合意 AUTO_APPROVED の全経路が 1 run 内で発火** | 成功シグナル |
