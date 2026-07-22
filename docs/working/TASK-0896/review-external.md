# C-2 外部レビュー — TASK-0896（追記専用集約）

> 実施: 2026-07-22 / 2 レーン並列（§7-bis 責務契約準拠）
> レーン A = Codex（設計妥当性: plan/todo/test-cases/pbi-input のみ・実装コード原則非読）
> レーン B = 独立 subagent（コードベース整合: 既存パターン 9 項目の一次ソース全数照合）

## レーン B 総括

plan の「既存コード実態」主張は **9 項目中 9 項目で一次ソース整合**（critical/major = 0）。特に: 非対称の実態は「両者とも空値検査あり・差はキー集合 strict のみ」で plan 記述は正確 / 既存テストは reason 内部文言非 assert（priority 接頭のみ）で「判定結果ベースの不変確認」戦略は成立 / sync 列挙 2 箇所で他の列挙経路なし（install 系は find ベース・CI は glob・全数確認済み）/ import DAG は循環なし。

## 指摘一覧（R-NNN・追記専用）

| R-NNN | レーン | severity | 指摘 | 裁定 | 根拠 |
|-------|--------|----------|------|------|------|
| R-001 | A | major | AC-1 の「REQUIRED_KEYS 系」が共通層集約の対象に含まれていない(Step 1 は 4 定数のみ・TC-1/TC-2 も非対象) | **採用** | 実測: REQUIRED_KEYS 系は c3prime_verify L36-43(record 用 REQUIRED/OPTIONAL/ALLOWED)と arbiter L478(入力ブロック用 PLAN_PACKAGE_REQUIRED_KEYS)で**重複はしていない**が、AC-1 verbatim は「単一モジュール定義」を要求 → c3_contract へ移設し import 参照に統一（additive・挙動不変） |
| R-002 | A | major | review-self.md に c3-prime 契約の `C1-VERDICT:` マーカー + plan hash がなく C-3' presence gate が fail-closed になる | **不採用** | 経路違い。c3-prime evidence マーカーは **ai-loop run（C-3' arbiter 裁定経路）**の機械判定用。本 plan 正式化は human C-3（`bin/plangate approve` → c3.json）経路で、validate の legacy 経路は evidence マーカーを要求しない。前例: TASK-0872 の review-self.md もマーカーなしで human C-3 受理（grep 実測 0 件）。将来本 TASK を ai-loop run に載せる場合はマーカー付与が必要（info として記録） |
| R-003 | A | major | AC-3「I/O なし純関数」を失敗させる検証手段が TC に定義されていない | **採用** | TC-5 を拡張: builtins.open / Path.read_bytes を封じた状態で check_snapshot_trio / canonical_hash を実行して成功する monkeypatch テスト + arbiter が sha256_of_file を参照しない静的検査（TC-10 と統合） |
| R-004 | A | major | 理由リストの順序・文言が契約化も回帰検証もされておらず、先頭要素を外部へ出す設計と「振る舞い不変」が整合しない | **採用** | 論点 3 を拡張: 理由リストの生成順序を検査順（キー集合 → 空値 → 三つ組不一致）で契約固定し test_c3_contract.py で順序 assert。外部可視文言（arbiter reason / c3prime stderr の代表例）を回帰テストで固定 |
| R-005 | B | minor | 残置リストに「reviewers ちょうど 2 者」検査（c3prime L158・#889 R2）が漏れ | **採用** | 論点 2 / Step 3 の残置列挙へ追記。**reviewer 集合の strict/lenient（arbiter=余剰 reviewer 許容 L510 / c3prime=拒否 L158）も snapshot キーと同様の意図的非対称 = 保存対象**と明記 |
| R-006 | B | minor | arbiter 残置のうち source_sha vs target_sha 照合（L523-527）が Step 3 に明記なし・切断面が曖昧 | **採用** | Step 3 Output に残置 1 行追記 |
| R-007 | B | info | canonical hash の行番号表記ゆれ（plan「L146-152」/ 実体 L148-153） | **採用** | Metrics Evidence の行番号修正 |
| R-008 | B | info | arbiter.py 本体に sys.path.insert パターンは存在しない（test 側/c3prime 側のみ） | **採用** | Step 1 に確定方針を明記: arbiter は CLI 直実行時 sys.path[0]=script dir で同 dir import が解決するため **arbiter 自体への sys.path 操作追加は不要**（test 経由は test_arbiter.py L15 の既存 insert で解決） |
| R-009 | B | info | sync 実行を Step 4 まで遅らせる順序は必須（a〜c 途中で sync すると bundled 側 c3_contract 欠落で ta-30 TC-08 FAIL） | **採用** | Step 4 に「コミット a〜c の途中で sync を実行しない（逆転禁止）」を明記 |
| R-010 | B | info（AC 候補返送） | 新設 test_c3_contract.py が CI 自動実行経路に乗らない（test.yml は run-tests.sh のみ・extras に source tree python テスト直実行なし = 既存 4 系と同型の pre-existing 構造） | **採用（最小対応）** | 既存構造と同型のため AC 追加はしないが、bundled 側は ta-30 TC-08 と同型で担保可能 → Step 4 に「ta-30 の bundled 自立実行対象へ test_c3_contract.py を追加検討（1 行）」…ではなく最小確定: **tests/extras/ta-55 へ `python3 scripts/ai-loop/test_c3_contract.py` 実行 1 行を追記**（tests/ は非 HO）。Files to Touch +1（実数 9・Replan 閾値 13 内） |

## 集計

- レーン A: major 4（採用 3 / 不採用 1）・スコープ整合とリスク 3 点セットは「指摘なし」明示
- レーン B: critical/major 0・minor 2・info 4（全採用）・照合 OK 9/9
- **確定反映対象**: R-001 / R-003 / R-004 / R-005 / R-006 / R-007 / R-008 / R-009 / R-010（1 回確定反映・Refs 付きコミット）
- 反映後: 簡易 C-1 再実行 → 人間 C-3（c3.json 発行は確定反映の後 = EH-3 整合順序）

## 監査表（追記専用）

| R-NNN | status | reflected_in (commit) | notes |
|-------|--------|----------------------|-------|
| R-001 | 採用 | (確定反映コミットで記入) | AC-1 verbatim 準拠・REQUIRED_KEYS 系 3 定数を c3_contract へ |
| R-002 | 不採用 | — | 経路違い（human C-3 経路・前例 TASK-0872） |
| R-003 | 採用 | (同上) | TC-5/TC-10 拡張 |
| R-004 | 採用 | (同上) | 理由リスト順序契約 + 代表文言回帰固定 |
| R-005 | 採用 | (同上) | reviewer 集合非対称の保存を明記 |
| R-006 | 採用 | (同上) | source_sha/target_sha 残置明記 |
| R-007 | 採用 | (同上) | 行番号修正 |
| R-008 | 採用 | (同上) | arbiter sys.path 不要の確定 |
| R-009 | 採用 | (同上) | sync 順序逆転禁止 |
| R-010 | 採用 | (同上) | ta-55 に 1 行追記・実数 9 へ更新 |
