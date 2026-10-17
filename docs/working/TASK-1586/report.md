# TASK-1586 保守候補とEvidence — read-only調査

> Status: **candidate / unapproved**, as of 2026-10-18 JST
> Fixed main: `1d624d95e597c711ec7f659868d4e1bf49d87d7a`
> Historical observation: `5fcdb2e3`
> This is **not** a `RunEvidence` or verified `HarnessImprovementCandidate`; no execution permission is conveyed.

## Candidate一覧と判断

| ID | 事実 / Source | Unknown / Risk | Owner / 対応と検証・Rollback |
| --- | --- | --- | --- |
| CI-01: Testが約7分 | [Test run 39028937133](https://github.com/s977043/PlanGate/actions/runs/39028937133)は2026-10-17 UTC 11:30:11–11:37:12、elapsed421秒・success。以前のmain `5fcdb2e3` の[run 38872144619](https://github.com/s977043/PlanGate/actions/runs/38872144619)は429秒・success | Issueの旧値210run・合計2155分は1runあたり10.26分。個別wall時間と集計分母・課金対象が一致するか**UNKNOWN**。ジョブのskipで速くしても改善とは認めない | **Human / HO**（`.github/workflows/*.yml`）。過去集計の抽出定義・対象run IDs・課金Runner分数を再照合。提案後も同等テスト範囲・exit code・p50/p90・料金を比較。変更時はHuman承認・revert可能なpatch |
| SKILL-01: `intent-classifier` | `.agents/skills/intent-classifier/SKILL.md` = `.codex/skills/.../SKILL.md` = `plugin/plangate/skills/.../SKILL.md` （Git blob `3b87c86bffda710331159b659d5372b3afce83db`）。`.claude/skills/.../SKILL.md` は `84d23ea62c980db7ac0cca008e84ca2093fdd60c` | Claude版には、CLIは導入先に配布されず「実施できないことを明示して止める」といった新しい明示説明が不足。Intent分類自体の違反実測は**なし** | **Maintainerの設計判断 / C-3**。差分全文のレビュー後に正本の意味論を保った最小文面修正を別PRへ。CLI未配布・no-silent-skipの負例を検証。問題ならHuman判断でrevert |
| SKILL-02: `plangate-setup` | `.agents/skills/plangate-setup/SKILL.md` = Codex版 = Plugin版（blob `ff20aa82530465aec5c477752270554442c38fb6`）。Claude版のみ `c4cfc8748c53a115f869d196a8abae886b9932af` | Claude版でdownstream CLI対応範囲と`doctor --fix`のfail-closed境界の説明が短い。実際の事故・契約逸脱は**未観測** | **Maintainerの設計判断 / C-3**。CLI `status/validate/approve/doctor`等の個別確認、downstream修復不可の負例、配布元への影響を別PRで検証。意図的なClaude固有表現を無断削除しない |
| NEG-01: Browser E2E | [#1556](https://github.com/s977043/PlanGate/issues/1556)は2026-10-17 Closed、修正PR #1569後に対象job 10/10 success（PR1/main9） | 10件で恒久無故障は証明できない | **Historical / 除外**。同じ失敗の新runなしに修正PRを作らない。再発ならOwnerが新証跡で判断 |
| NEG-02: Ratchet | [run 38330052668](https://github.com/s977043/PlanGate/actions/runs/38330052668) は2026-10-13の`TemporaryDirectory` cleanup `ENOTEMPTY(pack)`。[#1578](https://github.com/s977043/PlanGate/issues/1578)は2026-10-15 Closed。現mainの`test_ratchet.py` は`gc.auto=0`/`maintenance.auto=false` | このrunを**修正後再発**とみなすのは誤り。修正後の継続的失敗率は未測定 | **Historical / 除外**。新runの観測があれば切り分け直す |
| HO-01: `CLAUDE.md`説明・配線乖離 | [#1586](https://github.com/s977043/PlanGate/issues/1586) の旧SHA観測に2912文字の行・Hook配線記述の不一致 | 現mainでの行数と実Hook配線は**未再検証** | **Human HO**。現在の物理配線を先に実測。Human-only apply/rollbackが承認されるまで変更しない |

## Skillsコピー比較の方法と限界

1. GitHubから固定mainの各 `SKILL.md` を個別取得し、Git blob SHAを比較した。対象は `intent-classifier` と `plangate-setup` の各4経路、計8ファイル。
2. `scripts/sync-plugin-plangate.sh` の `SKILLS_DIR="$REPO_ROOT/.agents/skills"` と、Skill冒頭の「正本」「Claude/Codexは別配布先」を照合した。
3. **結果**: 2/2でClaude版だけ異なる。比較した8ファイル以外の構成・reference・frontmatter検証・Runtime実行は行っていない。**Blob不一致そのものは危険動作を証明しない**。
4. `.claude/skills/**` はLegacyの`docs/ai/ai-loop/ho-paths.md`で明示されたパスに一致しないが、これを自動変更の許可とみなさない。C-3と現在のOwner/ガバナンスが優先。

## 採否と最小の次ステップ

1. **まずSKILL-01/02を優先してHumanへ提出**。失われた規範が実際の利用場面に影響するか、静的diffだけでなく負例を確認。最初から全コピーを上書きしない。
2. CI-01は監査を継続。旧`2155分`を削減可能時間と断言しない。workflowファイルはHOなのでHuman以外変更しない。
3. NEG-01/02は新証拠がない限り実装キューに入れない。
4. いずれも**承認済みplan / 変更対象 / Verification / Rollback / Human-owned C-4** がそろったときだけ別変更へ進む。

## Stop conditions

権限の曖昧さ、正本差異の未解消、実データの欠測、テストskipによる見かけ上の高速化、認証情報の混入、未承認の自動HO適用、独立レビューの不在があれば保留する。このレポート自体はIssueの全AC達成を主張しない。
