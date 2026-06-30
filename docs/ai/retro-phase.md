# opt-in 終端 Retro フェーズ 正本仕様（F4 / TASK-0075）

> [`docs/workflows/06_retro.md`](../workflows/06_retro.md) の opt-in 起動条件と
> improvement-seeds スキーマの正本。起源 #235。

## 1. opt-in 起動正本（既定 OFF / 承認境界固定）

**正本の opt-in source は 1 つ: C-3 承認済み pbi-input の `retro_enabled: true`**
（未記載＝false）。これ以外では WF-06 は発火しない。

- **承認境界の固定（V-3 MJ-2 反映）**: `retro_enabled` は **C-3 承認済み
  pbi-input に存在する場合のみ**有効。plan_hash / EH-3 が C-3 後の改変を
  検出するため、AI が plan 生成中・後続編集で自己付与する経路は成立しない
  （人間が C-3 でレビューした artifact が唯一の opt-in 根拠）。
- **明示コマンド `/ai-dev-workflow TASK-XXXX retro` は将来 CLI（未実装）**
  （V-3 MJ-1 反映: 現行 `scripts/ai-dev-workflow` に `retro` 経路が無いため
  正本起動方式から除外。CLI 実装は後続 PBI。実装時に人間 opt-in の第2経路
  として追加する）。

env は不使用（自己付与リスク回避 / TASK-0071 教訓）。フラグが立たない限り
WF-06 は発火しない＝既存 run 挙動は完全に不変（純追加・後方互換）。

## 2. improvement-seeds.md スキーマ（append-only / C-3 D-2 最小）

配置: `docs/working/improvement-seeds.md`（リポジトリ単位で累積、run またぎ）。
1 run 1 エントリを **追記のみ**（既存エントリの編集・削除をしない）。

```text
## <date ISO8601> — <task_id>
- 目的達成可否: <text>
- 失敗・手戻り: <text>
- 次回再利用すべき判断: <text>
- 効いた skill / gate / artifact: <text>
- ツール・プロセス上の摩擦点: <text>
- confirmed_by: <human>
```

スコアリング・優劣判定は含めない（#231 LLM-judge の責務）。

## 3. 責務分離（重複防止）

| 関連 | 関係 | 本 PBI の扱い |
|------|------|--------------|
| #228 Outcome Review テンプレ | 5 項目テンプレの正本 | **参照のみ**（再定義しない） |
| #231 Dogfooding Eval judge | 機械評価・スコアリング | 本 phase はスコアリングしない |
| #200 Reporting & Retrospective | 期間集計・改善 PBI 抽出 | 本 phase は **入力（seeds）を生む前段**。集計本体は #200 |

## 4. 承認境界（PlanGate 原則維持）

自動なのは**ドラフト生成のみ**。`improvement-seeds.md` への確定追記は
**人間の confirm（1 行）でのみ**実行。skip 選択時は追記せず run 正常終了。
人間判断点を固定する PlanGate 原則を撤廃しない。

> 運用助言（Gemini minor・V2 候補）: seeds 肥大時は #200 側で archive/rotate。
> skip 時に理由 1 行を任意で残すと #200 統計精度が上がる（要件外・任意）。

## 5. 単発セッション捕捉の改善仕様（#505 ギャップ4 / Specification）

> Status: Specification（設計判断 #228 に関わるため実装は段階 PBI / plan → C-3）。
> 出自: PR #501-504 セッションの振り返り。

### 課題

opt-in 既定 OFF + `retro_enabled` の正本 source が「C-3 承認済み pbi-input」のみで
あるため、**pbi-input を持たない単発セッション**（緊急 hotfix・1 人運用の日中改修・
本セッションのような issue 駆動の連続 PR）では WF-06 が発動せず、プロセス教訓が
improvement-seeds に蓄積されない。

### 改善提案（実装は段階 PBI）

| 提案 | 内容 | 影響パス | 区分 |
|------|------|---------|------|
| A. mode 連動 opt-in | standard 以上モードで `retro_enabled` 既定 true（light / ultra-light は false 維持） | `mode-classification.md` | HO（apply） |
| B. スキーマ拡張 | improvement-seeds 5 項目に **任意項目「プロセス教訓」**（git 操作・HO 対応・自己検出など）を追加 | 本書 §2 | 非HO |
| C. 単発セッション手動 retro | pbi-input 無しでも人間が明示 confirm すれば retro を許可（承認境界 = 人間 confirm は維持） | 本書 §1 | 非HO |

### 不変条件（緩和しないもの）

- **人間 confirm でのみ improvement-seeds に追記**（A/B/C いずれも撤廃しない）
- **スコアリングは含めない**（#231 judge の責務）
- opt-in 緩和は「発動しやすさ」の調整であり、**承認境界（人間判断点固定）は不変**

### 提案 B のスキーマ（追記イメージ・任意項目）

```text
- プロセス教訓（任意）: <git 操作 / HO 対応 / 誤検出と自己修正など、次回の予防に値する手順上の学び>
```

## 6. 関連

- workflow: [`docs/workflows/06_retro.md`](../workflows/06_retro.md)
- 起源 issue: #235（関連 #228 / #200 / #231）
- 思想: F2/F3 と同じく「ゲート回避させない／人間判断点を固定」
