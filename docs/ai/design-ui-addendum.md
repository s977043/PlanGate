# Design/UI Addendum 仕様（F3 / TASK-0074）

> 起源: field feedback #236。UI/デザインタスクで追加指示の往復をゼロにする
> ための、pbi-input 条件付き追記セクションと真実源分岐の正本仕様。

## 1. 目的

UI/デザイン変更が主目的の PBI で「踏襲元曖昧 / 配置・レスポンシブ未言語化 /
視覚受入基準・回帰ガード欠如」による追加指示往復を、起票時の構造化で消す。

## 2. UI タスク判定トリガ（C-3 D-1 確定）

- **基本: 人手宣言** — pbi-input の `is_ui_task: true/false`
- **補助: 自動ヒント** — 変更想定が UI 層中心（`*/components/**`,
  `*.css`, `*.tsx` の見た目変更, `*/styles/**` 等）の場合、plan/レビュー時に
  「UI タスクの可能性。Design/UI Addendum を確認」と**警告（強制しない）**
- 自動のみに依存しない（誤判定でゲート回避/過剰要求の双方を生むため）

> **スコープ注記（V-3 major 反映）**: 本 PBI（F3 / TASK-0074）は
> **テンプレ + spec の整備まで**。自動ヒント警告の*実装*（変更ファイル傾向
> 検出 → plan/レビュー時 or `plangate` 検査での警告出力）は**後続 TASK**
> とする。それまで「ゲート回避防止」は人手宣言 + レビュー時の本 spec 参照に
> 依存する（強制ではなくソフト誘導。#236 の一律必須化回避方針と一貫）。
> 後続 AC 候補: 「UI 層中心変更で is_ui_task:false の場合に警告を出す検査の
> 実装」。

## 3. 真実源（source of truth）分岐

```text
UIタスク と判定（is_ui_task: true）
        │
        ▼
  Figma / デザインカンプ あり？
   ├─ あり ─▶ Figma ノード URL/フレーム必須。期待値は Figma を正
   │           （pixel/token は Figma 由来）。証跡=実装スクショ vs Figma
   ├─ なし ─▶ 踏襲元既存実装（X / not Y）必須。期待値は既存パターンを正
   │           証跡=before/after スクショ（PC/SP）
   └─ どちらも無 ─▶ `[参照なし]` を明示選択
               （曖昧なまま進めない・ゲート回避もさせない）
        │
        ▼
  どの分岐でも: 視覚的受入基準 / 視覚的回帰ガード は必須
```

優先順（両方ある場合）: **Figma > 既存パターン**。

## 4. 必須フィールド（pbi-input Design/UI Addendum）

1. 踏襲元の明示（X / not Y・理由）★最優先・単独でも効果大
2. 真実源（Figma 参照 or 既存パターン or `[参照なし]`）
3. 配置仕様（前後要素・余白/間隔・トークン名）
4. レスポンシブ・マトリクス（PC/SP・状態別）
5. 視覚的受入基準（検証可能な形）
6. 視覚的回帰ガード（変えてはいけない既存表示）
7. 視覚証跡（Figma 対比 or before/after・ビューポート別）

## 5. 非 UI タスクの扱い

`is_ui_task: false` または UI 無関係の場合、Addendum セクションは**削除可**
（テンプレに「非UIは削除可」と明記）。一律必須化しない＝認知負荷を増やさず
Figma なし案件のゲート回避も防ぐ。

## 6. design.md との整合

solution-architect が design.md を書く際、UI タスクなら「視覚設計」
セクション（[`docs/working/templates/design.md`](../working/templates/design.md)）
に Addendum の必須フィールド全体（1〜7）を反映する。pbi-input（要求）→ design.md（設計）→
受入（証跡）で視覚要件が一貫する。

## 7. 関連

- 起源 issue: #236
- テンプレ: `bin/plangate` init 生成 pbi-input / `docs/working/templates/design.md`
- 思想: F2「曖昧なまま進めない・ゲート回避もさせない」と一貫
