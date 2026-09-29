# TASK-1392 Current State

> 更新: 2026-09-28

## フェーズ: C-3 待ち
## 進捗: C-2 は R12 で収束（両レーンとも新しい失敗クラスなし）/ C-1 再実行済み（PASS with WARN）/ C-3 未実施

## 直近の完了タスク

- C-2 R12: 両レーン収束。是正漏れ R-095〜R-098 を記述で閉じ、残存脅威モデルを記録（2026-09-28）
- C-2 R1〜R11（R-017〜R-094）と Human 決定の反映（2026-09-25〜28。経緯は INDEX と review-external）

## 現在のタスク

- なし（Human C-3 待ち）

## ブロッカー

- C-3（Human）
- exec は #1391 consumable（todo Preflight の条件: API、binding キーの位置、再束縛の区切り、decision_made の payload、plan:81 の文言など）と #1329 preflight 待ち

## 次のアクション

- Human C-3（判断事項は INDEX の「次のアクション」）

## 計画からの乖離（C-2 の Human 決定による設計変更）

- 永続化モデルを A から B（envelope `kind` + events のみ保存、ほかは導出）へ変更（R-017）
- 冪等性（transaction_id / replay）を first slice から外し、CAS を revision + position に（R-046 / R-049）
- 応答を失ったときの回復は #1395 が stream から導き直す契約（R-060）
- halt marker と pending marker で停止・耐久性不明・Run の消失を永続化（R-071 / R-077）
- 1 回の呼び出しは 1 つの dirfd に束ね、root の同一性を lock 後に照合（R-090 / R-095）
- `load_run` 自身の dir flush は削除（R-089）
