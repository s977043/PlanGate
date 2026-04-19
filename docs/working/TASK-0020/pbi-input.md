# PBI INPUT PACKAGE: plugin 導入手順と migration note を整備する

> 作成日: 2026-04-19
> PBI: [TASK-0016-D] plugin 導入手順と migration note を整備する
> チケットURL: https://github.com/s977043/plangate/issues/20
> 親チケット: https://github.com/s977043/plangate/issues/16

---

## Context / Why

Issue #16（plugin 化）の最終ステップとして、既存 `plangate` リポジトリ利用者が plugin への移行を判断できるよう、導入手順と差分を明文化する。

実装（#17, #18, #19）が完了しても、ドキュメントが無ければ利用者は plugin の存在・使い方・移行判断基準を把握できない。本 issue は利用者向けの **導線ドキュメント** を整備することで、plugin 化の成果を実際の採用に繋げる。

---

## What（Scope）

### In scope

- **リポジトリ Root `README.md` 更新**:
  - plugin 導入セクションを新規追加
  - 新旧導入方法の差分を表形式で明記
    - 従来: `.claude/` 直置き（リポジトリ clone 必須）
    - plugin: `plangate` plugin として他リポジトリに導入可能
  - plugin 同梱範囲（7 skills + 8 agents + 3 rules）の記載
  - plugin 未同梱 agents の理由と入手方法
  - Codex CLI が対象外である旨の明記
- **`docs/plangate-plugin-migration.md` 新規作成**:
  - plugin 化の背景・目的
  - デュアル運用の前提と今後の方向性
  - 現時点の同梱範囲（詳細リスト）
  - 対象外の理由（プロジェクト固有 agents 等）
  - 将来計画（marketplace 公開、完全移行の想定時期）
  - 既存利用者向け移行手順（段階的移行）
- **plugin 内 `README.md` 本文追加**（TASK-0017 で配置したプレースホルダーを置換）:
  - plugin のインストール方法
  - 基本的な使い方（`/ai-dev-workflow` 呼び出し例等）
  - 同梱 skills / agents / rules の一覧
  - トラブルシュート（既知の制約）

### Out of scope

- marketplace 登録申請
- plugin の本格的なマーケティング
- 英語版ドキュメント
- 動画・スクリーンショット等の視覚資料
- Codex CLI 向けドキュメント（対象外と明記するのみ）
- 既存 `.claude/` ドキュメントの全面改訂（plugin 側の追記に留める）

---

## 受入基準

- [ ] リポジトリ Root `README.md` に plugin 導入セクションが追加されている
- [ ] `README.md` に新旧導入方法の差分が表形式で記載されている
- [ ] `README.md` で Codex CLI が対象外であることが明記されている
- [ ] `docs/plangate-plugin-migration.md` が新規作成されている
- [ ] migration note に背景・同梱範囲・対象外の理由・将来計画が記載されている
- [ ] plugin 内 `README.md` の本文が完成している（プレースホルダー解消）
- [ ] plugin 内 `README.md` にインストール手順と使用例が含まれている
- [ ] ドキュメント間の相互参照リンクが正しい
- [ ] 新旧の導入差分を一目で把握できる表現である

---

## Notes from Refinement

### 決定事項（親 TASK-0016 より継承）

- plugin 名: `plangate`
- 配布境界: B. 中核（7 skills + 8 agents + 3 rules）
- 互換方針: A. デュアル運用
- Codex CLI: 対象外

### 参考: 新旧導入方法の差分テンプレート

```markdown
| 項目 | 従来（.claude/ 直置き） | plugin（本チケット以降） |
|------|----------------------|-----------------------|
| 導入方法 | リポジトリを clone | Claude Code に plugin 追加 |
| 導入単位 | 1 リポジトリ全体 | plugin パッケージ |
| 同梱範囲 | 全 skills / 全 agents | 中核 7 skills + 8 agents |
| カスタム agents | repo 側で編集 | plugin 導入リポジトリ側で拡張 |
| アップデート | git pull | plugin アップデート |
| 対象 | plangate 本体開発 | 他プロジェクトで PlanGate 運用 |
```

### ドキュメント間の関係

```text
README.md（Root）
  └─> 簡潔な導入ガイド + migration note へのリンク

docs/plangate-plugin-migration.md
  └─> 詳細な背景・同梱範囲・移行手順

plugin/plangate/README.md
  └─> plugin 単体の使い方（インストール・呼び出し例）
```

### 想定モード判定

**light**（低）を想定。

- 変更ファイル数: 3（README.md, migration note, plugin README.md）
- 変更種別: ドキュメント追加・更新
- リスク: 低（既存コード挙動に影響しない）

---

## Estimation Evidence

### Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| 同梱範囲の記述が実装（#17-#19）と乖離する | Medium | #17-#19 完了後に着手、実装結果を参照しながら執筆 |
| 既存利用者向け移行手順が不明確で混乱を招く | Medium | デュアル運用前提を明記、「急いで移行する必要はない」旨を記載 |
| 将来計画（marketplace 公開時期）の記述が過度にコミットメント化 | Low | 「想定」「検討中」等の曖昧表現で余地を残す |
| Codex CLI 対象外の記述が誤解を生む | Low | 「現時点では対象外、将来検討の可能性あり」と明記 |

### Unknowns

- marketplace 公開の具体的な時期・条件
- 他プロジェクトでの plugin 採用フィードバック（導入後に収集）
- plugin の install コマンド正式 syntax

### Assumptions

- Sub #17, #18, #19 が完了している（同梱範囲が確定）
- README.md の既存構成は維持しつつ、セクション追加のみで完結
- migration note はエンドユーザー（他プロジェクト開発者）と既存 plangate 利用者の両方を対象

---

## 依存

- **前提**: Sub #17（TASK-0017）、Sub #18（TASK-0018）、Sub #19（TASK-0019）全て完了
- **後続**: なし（本 issue で親 #16 が Close 可能になる）

---

## 次フェーズへの申し送り

- B: plan 生成（#17-#19 完了後に着手）
- plan では既存 README 構成調査タスクを先頭に含める
- C-1 セルフレビュー（light モードで Plan 7項目のみで可）
- C-3 ゲート後に exec
- 本 issue 完了時点で **親 #16 を Close** する
