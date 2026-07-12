# TASK-0809 Test Cases

> AC 対応: #809 受入基準 1（fail-closed）・2（allowed_paths）・3（POLICY_REF）・5（.codex 整合）

| TC | 前提 | 入力 | 期待 | 種別 |
|----|------|------|------|------|
| TC-1 | CWD=repo root（ho-paths.md 実在） | 従来入力 + allowed_paths | 既存 64 テスト相当の裁定が不変（ho-paths.md 自身→touches-HO 含む） | 回帰 |
| TC-2 | ho-paths 全候補が不在（tmp dir で実行） | 任意の changed_files | 全件 HUMAN_ESCALATED・reason に "fail-closed" と探索パス | unit |
| TC-3 | ho-paths は在るが「HO パス一覧」表が空/パース 0 件 | 任意 | TC-2 と同じ（0 件 = 未確定扱い） | unit |
| TC-4 | allowed_paths=["docs/**"] | changed_files=["docs/a.md"] | 従来どおり裁定続行 | unit |
| TC-5 | allowed_paths=["docs/**"] | changed_files=["src/x.py"] | HUMAN_ESCALATED（scope_violation・違反パス明示） | unit |
| TC-6 | allowed_paths キー欠落 | 従来入力 | exit 1 入力エラー（必須フィールド） | unit |
| TC-7 | allowed_paths=["CLAUDE.md"]（HO を宣言） | changed_files=["CLAUDE.md"] | HUMAN_ESCALATED（touches-HO が優先。I-1: allowed_paths は HO 免除にならない） | unit |
| TC-8 | — | — | POLICY_REF == "auto-approve-lite-clean@v1" を pin | unit |
| TC-9 | bundled 展開先（plugin scripts/ + references/） | ta-30 相当 | test_arbiter が自立 PASS（references/ho-paths.md を解決） | integration |
| TC-10 | drift: 解決された全パターンが ho-paths.md 本文に存在 | — | PASS（parse 方式変更に追従した drift 検査） | unit |
| TC-11 | `--ho-paths` 明示指定（カスタムパス） | カスタム表のパターン | カスタム境界で touches-HO 判定（導入先シミュレーション） | unit |

エッジ: glob は既存 _ho_pattern_to_regex のセグメント意味論を allowed_paths にも再利用（`*` は "/" をまたがない・`**` は再帰）。
