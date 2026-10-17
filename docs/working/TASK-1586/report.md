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

## Actions 1,000件の再集計（2026-10-18 / read-only）

[Issue #1586](https://github.com/s977043/PlanGate/issues/1586) の旧報告`Test 210 run / 合計約2,155分`について、**210件は再現・時間合計は未再現**と判明した。今回の結果を優先し、同じ期間の料金削減と誤解しない。

| Metric | Actual observation | Limitation |
| --- | --- | --- |
| Collection | `GET /actions/runs?per_page=100&page=1..10`、全branch・全workflowの最新1,000run | スナップショット・ページ移動による変動を許容し、run IDを検証する |
| Window | 2026-10-08 03:02:28Z ～ 2026-10-17 17:46:14Z | 取得された最古・最新の`created_at` |
| Test count | **210 unique run IDs** | `name == "Test"`、旧件数と一致 |
| Status | **success 138 / cancelled 66 / failure 6** | Cancelledをfailure/成功に読み替えない |
| Total elapsed | **71,853秒 = 1,197.55分** | 各runの`updated_at - run_started_at`合計。billable時間とは異なる |
| Success elapsed | **約1,016.88分** | successの138runのみ。単一Runの成功時間でもない |
| Original `2,155分` | **今回の同一run集合・elapsed定義では再現しない** | 差957.45分。課金Runner時間、別集計の混入、計算手順の再検証が必要 |

再現手順：GitHub Actions runs APIのページ1〜10を全件取得 → `name == "Test"`でフィルタ → run IDを一意化・`conclusion`集計 → `max(0, updated_at - run_started_at)` を秒で合計（`2026-10-18`閲覧時）。代表4件の`/actions/runs/{id}/timing`で`run_duration_ms`も検証。報告された`billable.UBUNTU.total_ms=0`を全件の費用ゼロとは解釈しない。

**Owner decision:** Runner課金履歴・jobの実稼働秒・workflow elapsedを別々に定義し、同等検証範囲を維持する変更仮説が承認されるまで`.github/workflows/**`を変更しない。改善前後の費用差は`UNKNOWN`。

## Skillsコピー比較の方法と限界

1. GitHubから固定mainの各 `SKILL.md` を個別取得し、Git blob SHAを比較した。対象は `intent-classifier` と `plangate-setup` の各4経路、計8ファイル。
2. `scripts/sync-plugin-plangate.sh` の `SKILLS_DIR="$REPO_ROOT/.agents/skills"` と、Skill冒頭の「正本」「Claude/Codexは別配布先」を照合した。
3. **結果**: 2/2でClaude版だけ異なる。比較した8ファイル以外の構成・reference・frontmatter検証・Runtime実行は行っていない。**Blob不一致そのものは危険動作を証明しない**。
4. `.claude/skills/**` はLegacyの`docs/ai/ai-loop/ho-paths.md`で明示されたパスに一致しないが、これを自動変更の許可とみなさない。C-3と現在のOwner/ガバナンスが優先。

## Skill差分の精密レビュー（正本差分がただちに実害を意味するわけではない）

GitHub blob不一致を、両バージョンの行単位LCSで照合した。**Claude版にも一部の停止・fail-closed記述は既に存在する**ため、「安全説明が全部欠落している」とは判断しない。

| Skill | 正本だけにある重要な説明 | Claude側にも残る説明 | 反証 / 未確認 |
| --- | --- | --- | --- |
| `intent-classifier` | `.agents` の78〜84行に、配布するのはskills/rules/agents/commandsの読み物層のみ、CLI・enforcementは配布対象外、CLIがなければ明示停止・silent skip禁止とする7行の説明 | Claude版71〜73行にproject root解決とdownstream `doctor --fix`のrc=2/no-write、以降にCLIがPATHにない場合のdegrade説明 | CLI利用不可を明示する他箇所が存在するか、consumerによる誤った完了報告があるかは未検証 |
| `plangate-setup` | `.agents` の41〜67行に、#1497で明示検証済みのdownstream操作（status/validate/approve/read-only doctor、および限定render）、script-relative helper非保証、CLI未配布の注意を詳述 | Claude版41〜48行にCLIの必要性と `doctor --fix`/dry-runのrc=2/no-write、CLIがない場合の手動確認を記載 | 細かい適用範囲の欠落が行動・テスト失敗につながるかは未確認 |

### 修正前の検証計画（未実行、Human C-3レビュー用）

1. **Canonicalとconsumerの契約確認**: `scripts/sync-plugin-plangate.sh` の配布正本が `.agents/skills` であることを固定mainで確認。Claude固有の差分は意図的かOwnerが判断し、無条件にファイル全体を上書きしない。
2. **CLI非配布の負例**: downstreamに`plangate` CLIが無いfixtureで、実行できないことを明示し、未実施の`approve`/`render`/`doctor`をPASSと報告しないことを判定する。
3. **`doctor --fix` の負例**: downstreamで修復不可の場合は `rc=2 / no-write` を維持。read-only `doctor`の可用性とwrite可能性を別判定。
4. **下流コマンドの範囲**: #1497で確認した明示コマンドに限ることを示し、`exec`やscript-relative helperをCLI root resolverだけで対応済みと推測しない。
5. **更新後のdrift確認**: source/Claude/Codex/Pluginの実際の配布経路・同期コマンドのdry-run、既存Skill lintとCIを現行headで評価する。機械生成先を正本と取り違えない。

この計画は変更許可やテストPASSではない。テストの実行者・環境・exit code・実測結果がまだないため、判断は **DIFF_CONFIRMED / BEHAVIOR_UNKNOWN / NEEDS_APPROVAL** とする。

## 採否と最小の次ステップ

1. **まずSKILL-01/02を優先してHumanへ提出**。失われた規範が実際の利用場面に影響するか、静的diffだけでなく負例を確認。最初から全コピーを上書きしない。
2. CI-01は監査を継続。旧`2155分`を削減可能時間と断言しない。workflowファイルはHOなのでHuman以外変更しない。
3. NEG-01/02は新証拠がない限り実装キューに入れない。
4. いずれも**承認済みplan / 変更対象 / Verification / Rollback / Human-owned C-4** がそろったときだけ別変更へ進む。

## Stop conditions

権限の曖昧さ、正本差異の未解消、実データの欠測、テストskipによる見かけ上の高速化、認証情報の混入、未承認の自動HO適用、独立レビューの不在があれば保留する。このレポート自体はIssueの全AC達成を主張しない。
