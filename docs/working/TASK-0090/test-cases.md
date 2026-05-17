# テストケース — TASK-0090 / #224
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | "1. Plugin 安定性宣言" にコンポーネント別表(Stable/Beta) + versioning-policy §3 参照 | 構造突合 |
| T2 | AC2 | "2. バージョン同期メカニズム（release archive 方式）" に pin/update/検証 + curl tar.gz 手順 | 構造突合 |
| T3 | AC3 | "3. カスタマイズ API" に overlay precedence + 上書き可否境界表 + 記録 | 構造突合 |
| T4 | AC4 | "4. 手動コピー版からの移行" に Step 1-4(install/差分/重複削除/カスタマイズ) | 構造突合 |
| T5 | AC5 | migration doc から plugin-stability-and-sync 逆参照あり / 新 doc が versioning-stability-policy を前方参照（§3.1 逆リンクは #225/#263 マージ後の後続・既知課題）| 構造突合 |
| T6 | AC6 | hooks は C-3 承認があっても overlay 不可（settings 適用プロセス）/ C-3 例外は rules のみ、と分離明記 | 構造突合 |
## Edge
- E1: submodule/npm 不採用の理由が明記（release archive 確定）
- E2: plugin 側直接編集禁止（更新で消える）が明記
