# TEST CASES: TASK-0046 / Issue #155

## 受入基準 → テストケースマッピング

| AC | TC | 種別 |
|----|----|----|
| AC-1 | TC-1 | grep verification |
| AC-2 | TC-2 | content review |
| AC-3 | TC-3 | evidence existence |
| AC-4 | TC-4 | file existence + section count |
| AC-5 | TC-5 | calculation |

## テストケース

### TC-1: baseline 行の存在

- **検証**: `grep -E '^\| v8\.3' docs/ai/eval-comparison-template.md` が 1 件以上ヒット
- **期待**: ヒットあり

### TC-2: 8 観点の値が埋まっている

- **検証**: baseline 行に 8 列の値（数値または PASS / WARN / FAIL / n/a）が含まれる
- **期待**: 全列に値あり、空セルなし

### TC-3: evidence 存在

- **検証**: `docs/working/TASK-0046/evidence/baseline-data.md` が存在
- **期待**: ファイルあり

### TC-4: procedure ファイル

- **検証**: `docs/ai/eval-baseline-procedure.md` が存在し、`## 手順` セクションを持つ
- **期待**: 両方存在

### TC-5: schema 準拠率 ≥ 95%

- **検証**: handoff 必須 6 要素（## 1.〜## 6.）が 5 PBI 全てで揃っている
- **計算**: PASS 数 / 総 PBI 数 ≥ 0.95
- **期待**: 5 / 5 = 100% ≥ 95%
