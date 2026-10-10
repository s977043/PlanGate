# TASK-1550 — Test Cases (design only)

> Status: **Not run**. These are planned acceptance tests, not a claim that behavior is implemented. Test runner/fixture location is chosen only after the active PR creation path is verified and C-3 approved.

## AC → TC mapping

| AC | Tests |
| --- | --- |
| AC-01 route evidence | TC-01, TC-02 |
| AC-02 three-part projection | TC-03, TC-04 |
| AC-03 docs/behavior/code/custom/negative | TC-03, TC-04, TC-05, TC-06, TC-07 |
| AC-04 issue links and approval boundaries | TC-06, TC-08 |
| AC-05 distribution parity | TC-09 |
| AC-06 observational adoption | TC-10 |
| AC-07 rollback/detection | TC-05, TC-08 |

## Planned cases

### TC-01 — Active route evidence (positive)
- Input: 直近の実PR 1件について利用Agent/CLI/workflowとbody producerを追跡。
- Expected: caller → body producer → API/CLI、main ref、実PR参照、権限分類が1対1で追跡できる。
- Negative: file存在のみなら稼働証拠としては**採用しない**。

### TC-02 — Unverified/legacy route (negative)
- Input: `scripts/apply-task-0124-patches.sh`等、body構築記述はあるが稼働証拠を持たない経路。
- Expected: `unknown/legacy`とラベル付けし、存在だけで優先対象にはしない。

### TC-03 — Pure documentation change (positive)
- Input: 挙動やルールの適用が変わらないdocs-only PR。
- Expected: Kill-switch = PR revert等、Detection = `N/A (no runtime behavior change)`、Observation = `N/A (no post-merge runtime change)`を理由付きで許容する。

### TC-04 — Agent-behavior documentation (negative control)
- Input: `CLAUDE.md` / `AGENTS.md` / Rule / Agent定義を変更するPR。
- Expected: Detection signalを安易にN/Aにしない。HO対象ならC-3とHuman applyが必要、文面の追加で権限は増えない。

### TC-05 — Code change with signal and rollback
- Input: 実行挙動を変える変更。
- Expected: 3要素、観測窓、発生時に元へ戻せる操作、観測できるCI/挙動シグナルを説明できる。
- Negative: TODOが残っていれば完了と主張しない。

### TC-06 — Custom body/closing keyword (compatibility)
- Input: `Closes #123` / `Refs: #456`を持つ独自PR本文。
- Expected: 本文・リンク語・レビュー履歴を壊さず最小情報を追加できる。自動approve/mergeは実行しない。

### TC-07 — No second source of truth
- Input: 共通PRテンプレートと選定された自動PR生成経路。
- Expected: 意味が一致し、定義全文を別の場所に重複複製しない。テンプレート変更時のrecheck先が明示されている。

### TC-08 — Authorization and denial (negative)
- Input: C-3未承認 / HO Human apply未了 / C-4未承認の各状態。
- Expected: execution/HO write/mergeをそれぞれ拒否。PR本文の改善を権限変更に使わない。

### TC-09 — Claude/Codex/plugin parity
- Input: 変更後のソース・生成物・配布物。
- Expected: 対象経路のみ意図した更新。手動ミラー複製なし。機械的sync/parity検査で差分を説明できる。

### TC-10 — Real post-adoption verification
- Input: Human merge後、対象経路から実際に作成されたPR。
- Expected: 3要素が記述され、その内容が形式だけでなく当該変更に適しているとレビューできる。導入前referenceとの比較は条件を明記。事例未取得なら`NOT VERIFIED`。
