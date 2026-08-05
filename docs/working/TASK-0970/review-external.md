# C-2 EXTERNAL REVIEW — TASK-0970

> 入力: [`plan.md`](./plan.md) / [`todo.md`](./todo.md) / [`test-cases.md`](./test-cases.md) / [`pbi-input.md`](./pbi-input.md)
> 責務契約: [`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md) §7-bis（2 レーン）
> 差分管理: [`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md)「C-2 指摘の差分管理」（追記専用集約 → 1 回確定反映 → 簡易 C-1 → c3 発行）
> 実測基点: `origin/main` = `4448420`（本レビューの実測はすべてこの commit で取得。
> 対象 2 ファイルが本ブランチと `origin/main` で同一であることを `git diff --stat` = 空で確認済み）

## 判定サマリ

| 区分 | 反映前（本レビュー時点） | 反映後（R-001〜R-003 確定反映後の見込み） |
|------|------------------------|------------------------------------------|
| critical | 0 | 0 |
| **major** | **1**（R-001） | **0** |
| minor | 2（R-002 / R-003） | 0 |
| info | 3（R-004 / R-005 / R-006） | 3（記録のみ・acknowledged） |

**反映前の verdict**: `request-changes`（major 1 件により lite ゲートの
`critical/major=0` 要求を満たさず、ai-loop へ進入できない）。

**反映後の verdict**: `approve`（R-001〜R-003 を 1 回確定反映した plan に対して）。

```text
C2-VERDICT: approve plan=sha256:a32d837fbd4208bce7c556e27f22f0cb6ea3ab3a88c9d28a7b8d25a3f259b1a1
```

> 上記マーカーの `plan_hash` は **確定反映後の `plan.md`** に対する値である
> （反映前の plan に対する verdict は上表のとおり `request-changes`）。
> `plan_hash` が変わったため C-1 の受理マーカーは stale になっており、
> 簡易 C-1 の再実行が別途必要（本ファイル作成者は `review-self.md` を変更しない）。

## 指摘一覧（R-NNN・追記専用）

### R-001【major】`changed_files` の carve-out を plan が自作しており、機械ガードを申告制へ差し戻す

- **レーン**: 設計妥当性 / コードベース整合（両レーンで検出）
- **観点**: 保守性・拡張性（承認境界の機械検証性）

**事実（実測）**:

- 反映前 plan の `## Files / Components to Touch` は 3 行目に `docs/working/TASK-0970/**` を持ち、
  直後の本文で「allowed_paths には含めるが `changed_files` の実装差分計上からは除く」と
  **plan 自身が carve-out 規則を定義**していた。lite 4 軸表は「申告と `changed_files` 実数が一致する」と主張していた。
- `.claude/skills/ai-loop-cycle/SKILL.md:41` は「**計画時**（exec 前の C-3' 裁定）: plan の Files to Touch を使う」と規定する。
- `plugin/plangate/skills/ai-loop-cycle/scripts/plan_package.py:170-186`（`extract_allowed_paths()`）は
  `## Files / Components to Touch` 節のバッククォート付きパスを機械抽出する。反映前 plan での実測は **3 件**。
- 「`docs/working` を `changed_files` から除いてよい」という規定は
  `rollout-policy.md` / `lite-criteria.md` / `decision-table.md` / `execution-runbook.md` / `SKILL.md` の
  いずれにも**存在しない**（全文検索 0 件）。
- 先例: 同一 2 ファイルを触った `docs/working/TASK-0877/plan.md:88-95` の Files to Touch に
  `docs/working/**` 行は**無い**（3 行はすべて実装ファイル）。

**Impact**:

`decision-table.md:68` の priority 1.9 は「申告 `size_ok == true` だが `changed_files` の実ファイル数が
`SIZE_OK_MAX_FILES`（2）を超える」を human escalate とする。3 件を渡せば priority 1.9 で escalate、
2 件へ絞れば通過する。すなわち 2 件へ絞る操作は、#780 slice C が「申告制 `size_ok` の虚偽宣言を
検出するため」に導入した**唯一の機械ガードへ、申告者自身がフィルタした集合を渡す**ことに等しく、
機械検証が実質的に申告制へ差し戻る。`rollout-policy.md:110`「lite 4 軸の AC-8 安全側
（判定不能→false・**虚偽宣言禁止**）」に抵触する。

**補足（レビュアー実測）**: 「`docs/working/TASK-0970/**` を allowed_paths に載せないと status.md が
書けない」という制約は**実装上存在しない**。`scripts/ai-loop/check_exec_boundary.py` の冒頭契約が示すとおり、
同検査器は実行系トークンの AST 検査であって `allowed_paths` によるファイル書込み制御ではない。

**Fix（採用）**: plan の Files to Touch から 3 行目を削除し、自作 carve-out 規則を撤去する。
作業コンテキストの扱いは「本 run では allowed_paths に載せない（実装上の制約が無いことを実測で確認済み）」と明記する。

### R-002【minor】baseline「537 passed / 0 failed」が宣言した基点で再現しない

- **レーン**: 設計妥当性
- **観点**: 保守性（判定基準の再現性）

**事実**: 反映前 plan / test-cases / pbi-input は baseline を `537 passed / 0 failed`（基点 `a952872`）と
絶対値で宣言していたが、同 commit の**通常 checkout** で clean env + `</dev/null` 実行の実測は
**539 passed / 0 failed** だった。同 commit の pristine detached worktree では **538**
（差分は `TC-17 .claude/settings.json: no diff vs main` が worktree では `[SKIP] TC-17 not a git repo` に
なるため。全行 diff で 1 行のみの差であることを確認済み）。

**Impact**: TC-B の期待値「538 passed」は実測 baseline 539 より小さく、かつ pristine worktree の値と
偶然一致する。修正後に 540 を観測して RT-4 を誤発火させる／538 を観測して「TC 追加が効いていない」ことを
見逃す、という双方向の誤判定経路が残る。

**Fix**: plan / test-cases / pbi-input の baseline 絶対値を「A-1 で再実測した値（`baseline` / `baseline+1`）」の
記号表現へ置換し、実数は `evidence/test-runs/` の A-1 ログを正とする
（issue #970 の AC-4 原文「exec 開始時に現 main で再実測した値」と一致させる）。
あわせて基点 `a952872` を現 `origin/main` = `4448420` へ更新する
（対象 2 ファイルは両 commit で同一のため、plan の行番号実測値は不変）。

### R-003【minor】削除対象行の直上コメントが修正後に実装と正反対になる

- **レーン**: コードベース整合
- **観点**: 保守性（残骸・再発ベクタ）

**事実**: `scripts/sync-plugin-plangate.sh:195-196` は
「集計にはコピーループと同一の `[ -L ]` 除外を入れる（R-351 / 論点 D'-2。集計定義と実削除条件の非対称は
『N 件と数えて M 件消す』guard 無効化を招く）」と書かれている。本 PBI が L206 を削除すると、
このコメントは (a) 実装を誤記述し (b) 根拠文（非対称は guard 無効化を招く）と結論（だから `-L` を入れる）が
逆立ちする。

**Impact**: **#970 の再発ベクタそのもの**。将来の保守者・AI が「コメントどおりに `-L` を戻す」ことで
集計 ⊊ 削除の窓が再び開く（#914 で `-L` が入った経緯自体が「plan に書かれたとおり実装した」ことである）。

**Fix**: A-5 の Output に「同 hunk の L195-196 コメントを『削除ループと同一条件で集計する
（`-L` 除外は入れない）』へ書き換える」を追加。Constraints の「1 行の削除に限定」を
「集計ループ 1 行の削除 + 直上コメントの追従（同一ファイル・同一 hunk）」に緩める
（ファイル数は 2 のままで RT-1 に影響しない）。

### R-004【info】carve-out 非該当は正しいが、変更対象は判定基盤の配布経路を持つファイル

- **レーン**: コードベース整合
- **観点**: 拡張性（自己改変防止境界）

`scripts/sync-plugin-plangate.sh` は `rollout-policy.md:56` が
「上記 ①〜③ の配布コピー（`plugin/plangate/skills/ai-loop-cycle/**` 等）は `sync-plugin-plangate.sh` が
生成する派生成果物であり、正本を carve-out することで実質的に保護される」と述べている当の同期エンジンであり、
同一ファイル L358-402 に carve-out 対象の配布コピーを守る経路2 guard を持つ。
本変更は経路1 のみ・fail-closed 方向のみなので escalate 要件には当たらないが、
**W チェック 2 体への申し送りとして carve-out 節に 1 行注記する**（plan への反映対象）。

### R-005【info】src 側の残存非対称は fail-closed 側（Non-goal 化は安全）

- **レーン**: コードベース整合
- **観点**: セキュリティ（fail-open の有無）

src に symlink `.md` がある場合、base 集計（L200）からは除外される一方、削除ループの stale 判定
（`[ ! -f "$_src_refs/$_rb" ]`）は symlink を解決するため同名 dst を stale にしない。
結果として base が過小になり `stale > base` が成立しやすくなる＝**fail-closed 側**。
本 PBI の修正が新たな fail-open を作らないことを確認した（**記録のみ・plan 変更なし**）。

### R-006【info】todo の A-9 / A-10 は working-context の todo 規約と形式上ずれる

- **レーン**: 設計妥当性
- **観点**: 可読性（規約整合）

`working-context.md` の todo 規約は「L-0〜V-4・PR 作成は workflow-conductor が自動制御するため含めない」と
するが、todo には A-9（V-1）/ A-10（PR 作成）がある。ai-loop 経路では conductor が駆動しないため実害はなく、
`execution-runbook.md` の (5b) grader + (6) 強化セルフレビューが standard mode の V-3 相当を代替する
（**記録のみ・plan 変更なし**）。

## 監査表（追記専用・squash/rebase 耐性）

| R-NNN | severity | status | reflected_in | notes |
|-------|----------|--------|--------------|-------|
| R-001 | major | reflected | 本コミット（`Refs: R-001`） | plan Files to Touch 3 行目削除 + 自作 carve-out 規則撤去。`extract_allowed_paths()` 再実行で 2 件を実測確認 |
| R-002 | minor | reflected | 本コミット（`Refs: R-002`） | plan / test-cases / pbi-input の baseline を記号化 + 基点を `4448420` へ更新 |
| R-003 | minor | reflected | 本コミット（`Refs: R-003`） | plan Constraints 緩和 + Files to Touch 変更欄 + todo A-5 Output にコメント追従を追加 |
| R-004 | info | reflected | 本コミット（`Refs: R-004`） | carve-out 節へ 1 行注記（W チェック 2 体への申し送り） |
| R-005 | info | acknowledged | —（記録のみ） | fail-closed 側のため Non-goal 維持が安全。plan 変更なし |
| R-006 | info | acknowledged | —（記録のみ） | ai-loop 経路では実害なし。plan 変更なし |

## 後続手順（working-context「C-2 指摘の差分管理」の固定順序）

1. 本ファイルへ R-NNN 集約（完了）
2. plan / todo / test-cases（+ pbi-input の baseline 記述）へ **1 回確定反映**（完了・`Refs: R-NNN`）
3. **簡易 C-1 の再実行**（未実施 / 別担当）— 反映により `plan_hash` が変化し、
   `review-self.md` の `C1-VERDICT: PASS plan=sha256:...` が stale になっているため
4. 人間（または C-3' 裁定）による承認発行
5. exec
