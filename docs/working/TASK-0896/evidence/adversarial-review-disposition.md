# 敵対レビュー disposition — TASK-0896（AC-8）

> 実施: 2026-07-22 / 2 レーン並列（Codex + 独立 behavior-diff 実測）/ 対象 = feat/task-0896-c3-contract 4 コミット
> 結果: **critical / major 0**。両レーンとも「受理/拒否の強度低下・偽造受理・import fail-open なし」を実測で確認

## レーン実測サマリ

- **独立レーン（behavior diff）**: 新旧実装を同一敵対入力で駆動 — plan_package_check 37/37 tuple 全一致 / c3prime_verify 37/37 exit code 全一致 / producer 出力 byte 同一（sha256 一致）/ bundled 自立 4 系全 OK / cmp 10 ファイル byte 一致 / run-tests 412 passed
- **Codex レーン**: strict/lenient 両経路の偽造（余剰 reviewer・非 dict snapshot・未知キー・空値・None==None）全 reject / import 欠落は未捕捉 ImportError で停止（fail-open でない）/ SnapshotTrioTests 等 13+11 件実行成功

## 指摘と裁定

| AF | レーン | severity | 指摘 | 裁定 |
|----|--------|----------|------|------|
| AF-1 | 両レーン一致 | minor | 複合異常時の先頭 stderr 理由が変化（旧: per-reviewer で verdict 異常が先 / 新: 全 reviewer trio 検査後に verdict — 例: model_a.verdict 不正 + model_b.source_sha 改竄で新実装は trio 不一致を先に報告）。exit code / 判定結果は全一致 | **採用（記録対応）**: 機械消費者 0 件を rg 全数確認済み（bin/plangate は stderr 転送のみ・test は exit code のみ assert）。R-004 順序契約（キー集合→空値→trio）の設計帰結であり実装は変えない。PR body に「診断優先順の変化（判定結果不変）」を明記 + handoff 既知課題 KI-1。理由コード enum 化（V2）時に受理器レベルでも順序固定 |
| AF-2 | 独立 | minor | arbiter の `import c3_contract` は sys.path 挿入なし — `spec_from_file_location` 等の埋め込み import で ModuleNotFoundError（現実の importer は全て path 挿入済みで無害を実測） | **不採用**: R-008（C-2 確定）で「arbiter に sys.path 操作を追加しない」を設計確定済み。handoff 既知課題 KI-2 に経路制約として記録 |
| AF-3 | 独立 | info | c3_contract 部分配布時、c3prime_verify は traceback exit 1（fail-closed）だが legacy record も exit 10 でなく 1 になる | **採用（記録対応）**: handoff 運用注記。sync 対列挙 + ta-30 で構造的に防止済み |
| AF-4 | 独立 | info | `derived_loopspec_hash` が任意値でも受理 — 新旧同一の既存挙動（本 PR の差分でない） | **不採用（スコープ外）**: handoff V2 候補に記録（契約側の値検証は #874 系で検討） |

**AC-7 確認**: 偽造 record 群 reject 不変（37 パターン exit code 一致 + test_c3prime_verify 12 不変）
