# Handoff — TASK-0088 / #226 段階的導入ガイド
## 1. 要件適合確認
| AC | 判定 |
|----|------|
| AC1 Phase0-3 モード/エージェント/フック明示 | PASS (T1) |
| AC2 各Phase「使わなくてよいもの」 | PASS (T2) |
| AC3 フック有効化推奨順序 | PASS (T3) |
| AC4 エージェント最小セット段階別 | PASS (T4) |
| AC5 plangate.md から到達 | PASS (T5) |
V-1 全 PASS（light のため V-3 スキップ）。
## 2. 既知課題
- settings.json 実配線テンプレ（Phase 別 hooks 設定例）は未同梱（手動配線前提）。
## 3. V2 候補
- Phase 別 `.claude/settings.json` テンプレ生成（apply-claude-settings.sh 連携）。
- `bin/plangate doctor` に「現在の導入 Phase 推定」を追加。
## 4. 妥協点
- 実配線変更を Out of scope とし docs に限定（hook 強制変更は破壊的・別 PBI）。
## 5. 引き継ぎ
#226 を docs/light で実装。staged-adoption-guide.md を新規正本化（Phase 0-3 +
フック推奨順序 + エージェント最小セット + チェックリスト、実 hook/agent 名で
正確化）。plangate.md に参照節追加。次は #227 river-reviewer 外部レビュー IF。
## 6. テスト結果
T1-T5 + E1 全 PASS。c3.json required/plan_hash OK。
