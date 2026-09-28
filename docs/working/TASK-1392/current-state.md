# TASK-1392 Current State

> 更新: 2026-09-28

## フェーズ: C-2
## 進捗: plan はモデル B・冪等性なし・CAS = revision + position / C-2 R1〜R5 実施済み（未収束）/ C-1 再実行済み / C-3 未到達

## 直近の完了タスク

- C-2 R9 の指摘 R-077〜R-083 と Human 決定（replace 前に pending marker を書く）を反映（2026-09-28）
- C-2 R8 の指摘 R-071〜R-076 と Human 決定（#1392 に halt marker を追加）を反映（2026-09-28）
- C-2 R7 の指摘 R-065〜R-070（#1395 の回復契約のエラー分類・RunNotFound・flush 失敗・lock の待ち上限）を反映（2026-09-28）
- C-2 R6 の指摘 R-060〜R-064 と Human 決定（回復規則を捨て #1395 が stream から導き直す / load は耐久性確定後に返す）を反映（2026-09-28）
- C-2 R5 の指摘 R-054〜R-059 を反映（2026-09-28。R-054 の回復規則は R-060 で撤回）
- C-2 R4: 冪等性を first slice から外し、CAS を revision + position に（2026-09-25）

## 現在のタスク

- なし（C-2 R10 待ち）

## ブロッカー

- exec は #1391 consumable（todo Preflight の条件。再束縛の区切り・bound_context・plan:81 の文言など）と #1329 preflight 待ち

## 次のアクション

- C-2 R10 → 新クラスが出なくなったら Human C-3

## 計画からの乖離

- 永続化モデルを A から B（envelope `kind` + events のみ保存）へ変更（R-017）
- 冪等性（transaction_id / replay）を first slice から外し、再送の二重確定は revision + position の CAS で防ぐ（R-046 / R-049）
- 応答を失ったときの回復は #1392 の規則ではなく、#1395 が stream から次の action を導き直す契約にする（R-060。R-054 を置き換え）
- `load_run` は lock を取り dir fsync の後に返す（R-061）
