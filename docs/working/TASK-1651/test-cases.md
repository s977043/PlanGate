# TASK-1651 Test Cases

## 受入基準 → テストケース

| AC | TC |
|----|----|
| AC-1（macOS / Linux 両方で `project_root` 以外の絶対パスを検出） | TC-01, TC-04, TC-05, TC-06 |
| AC-2（陽性対照） | M-1, M-2, M-3 |
| AC-3（docstring と TC-7 見出しの契約一致） | TC-07 |

## テストケース一覧

| ID | 種別 | 前提 | 入力 | 期待出力 | 期待値の出所 |
|----|------|------|------|---------|------------|
| TC-01 | Integration | macOS、変更後 | `sh tests/extras/ta-10-doctor-fix.sh` | `[PASS] doctor-fix TC-7` を出力。変更前は同条件で `[FAIL] doctor-fix TC-7`（変更前後で結果が変わる） | issue #1651 再現手順 |
| TC-02 | Integration | 変更後 | 同上 | TC-7 の既存条件（scope == hooks、hook-wiring 項目の name/ok/level、default と `--scope v8.6.0` のバイト一致、leak 文字列 3 種なし）を維持 | 既存 TC-7 |
| TC-03 | Unit（TC-7b） | 変更後 | 合成 JSON `{"project_root":"/x/r","checks":[{"project_root":"/x/r"}]}` | 検出（ネストした同名キーは除外されない、D-2） | plan D-2 |
| TC-04 | Unit（TC-7b）**Linux 型** | 変更後、OS 不問 | 合成 JSON `{"project_root":"/home/runner/work/p","checks":[{"detail":"/home/runner/work/p/x"}]}` | 検出（`isabs`）。旧検査（`"/Users/"` 固定）では非検出であることを T-2 で記録 | plan D-1 |
| TC-05 | Unit（TC-7b）**macOS 型** | 変更後、OS 不問 | 合成 JSON `{"project_root":"/Users/u/p","checks":[{"detail":"missing: /Users/u/p/x"}]}` | 検出（D-3 の REPO 値部分一致。`isabs` は偽） | plan D-3 |
| TC-06 | Unit（TC-7b）陰性 | 変更後 | 合成 JSON `{"project_root":"/Users/u/p","project_root_source":"script-root","checks":[{"detail":"missing: .claude/settings.json"}]}` | 通過（許可キーのみ絶対パス） | plan D-2 / doctor_check.py 実装 |
| TC-07 | Doc 照合 | 変更後 | `doctor_check.py` `__doc__` の Privacy 文と TC-7 見出しコメント | 両方が「絶対パスはトップレベル `project_root` の 1 キーのみ」を述べる。"no paths beyond what is already public" / 「絶対パス値は JSON に含まれない」の旧文言が残らない | plan D-4 |

## 変異注入計画（陽性対照・commit しない）

| ID | 変異 | 期待 | 検出力を示す OS |
|----|------|------|----------------|
| M-1 | `doctor_check.py` `main()` に `result["leak_probe"] = str(REPO)` を追加 | TC-7 FAIL | macOS / Linux 両方（REPO は両 OS で絶対パス。CI ubuntu でも同変異で FAIL することを確認） |
| M-2 | `run_hooks_checks()` の check の `detail` を `f"missing: {REPO}/.claude/settings.json"` に変更 | TC-7 FAIL（D-3 の部分一致で検出） | 両方 |
| M-3 | 検査器の除外条件を「キー名が `project_root` で始まる / どの深さでも」に緩める | TC-03 FAIL | 両方（合成入力のため OS 不問） |

## エッジケース

- `project_root` が欠落または空文字 → 検査器は FAIL（D-3 の前提が崩れるため）
- `project_root_source` が絶対パス → 検出（D-2。除外しない）
- `doctor --json` が非 JSON を出す（stderr 混入）→ 既存どおり `json.load` 例外で FAIL
- 相対パス（`docs/working/...`）・URL 風文字列 → 誤検出しない（TC-06 の detail で代表）

## Convention Evidence

該当なし（期待値はすべて issue 再現手順・既存 TC・plan 決定事項が出所）。
