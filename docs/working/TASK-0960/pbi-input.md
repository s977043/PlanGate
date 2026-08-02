# PBI INPUT PACKAGE — TASK-0960

> Issue: [#960](https://github.com/s977043/plangate/issues/960)（bug / **priority:P2** / governance / area:docs）— 現タイトル: 「fix(docs): C-1 の項目数が「17」表記のまま実体 25 — 現場が 15/17/20/25 の 4 通りで回避している」
> スコープ: **live な定義箇所のみ**を対象とし、`docs/working/` 配下の**過去の成果物（履歴）は変更しない**（issue In scope 冒頭を正とする）
> 作成: 2026-08-02（**main `a4afacb` で実測**。裏取り結果は下表）
> 関連: [#936](https://github.com/s977043/plangate/issues/936)（本文が「17項目」表記 — OPEN。本 issue 解決後に表記追従が要る・相互にスコープ外）/ [#956](https://github.com/s977043/plangate/issues/956)（`.codex/skills/` の commit 済み drift 2 件 — **OPEN**。③ 派生再生成の巻き込みリスクとして現存）/ 後発追加の出典: #544 / #578 / #579 / #581 / 検出契機: #956 の調査の副産物（2026-08-02）

## Context / Why

C-1 セルフレビューの項目数が **「17 項目」と宣言されているが、テンプレート実体は 25 項目**。宣言内訳（`Plan 7 + ToDo 5 + TestCases 3 + 結合 2`）のうち Plan / ToDo / 合計が実態と一致していない（TestCases 3・結合 2 は一致 — issue 自身の対比表と整合）。「17」は歴史的なコア番号帯（`C1-PLAN-01`〜`C1-B1B2-17`）の**通称**で、#544 / #578 / #579 / #581 で追加された項目が数に反映されていない。

| | 宣言 | 実体（実測） |
| --- | --- | --- |
| Plan | 7 | **9** |
| ToDo | 5 | **6** |
| TestCases | 3 | 3 |
| 結合 / B1B2 | 2 | 2 |
| **core 小計** | **17** | **20** |
| 後発追加（SUP/SEC/SCOPE/UI） | — | **5** |
| **合計** | **17** | **25** |

**起票の最大の理由 = 現場が場当たり的に回避しており、回避の仕方が食い違っている**。実行者ごとに違う数字で運用されている（**15 / 17 / 20 / 25 の 4 通りが並存**。C-1 は plan ゲートの中核であり「何項目やれば C-1 完了か」が実行者依存になっている）:

| 出典 | 主張している項目数 |
| --- | --- |
| `docs/working/discussions/2026-06-12-544-loop-safety-controls.md:46` | 「Plan 7 + ToDo 5 + TestCases 3 = **15 項目**。『17項目』は v3 改善コメント由来の**通称**」 |
| `docs/working/TASK-0121/review-self.md:21` | 「依頼文は『17項目』としているが、明示された内訳は **15 項目**であるため、本レビューは明示 ID に従って評価する」 |
| `docs/working/TASK-0917/review-self.md:16` | 「core **17** 項目 + テンプレート追加 **8** 項目 = **25** 項目」 |
| `docs/working/TASK-0914/review-self.md:13` | 「**17** 項目フル（テンプレート現行版の全 **25** チェック）」 |

### 裏取り結果（作成時点 main = `a4afacb`・2026-08-02）

| # | issue の主張 | 実測（コマンド / 参照） | 結果 | 判定 |
|---|------|------|------|------|
| 1 | テンプレート実体は 25 項目（PLAN 9 / TODO 6 / TEST 3 / B1B2 2 = core 20、SUP 2 / SEC 1 / SCOPE 1 / UI 1 = 後発 5） | `grep -c '^### C1-' docs/working/templates/review-self.md` → **25**。内訳再集計 `grep -o '^### C1-[A-Z0-9]*' … \| sort \| uniq -c` → PLAN **9** / TODO **6** / TEST **3** / B1B2 **2**（core 計 **20**）+ SUP **2** / SEC **1** / SCOPE **1** / UI **1**（後発計 **5**） | issue の実測表と**完全一致**。補足: `C1-UI-01` は見出しに「#579・**is_ui_task 時のみ**」と明記された**条件付き項目**（「25」単純表記の設計論点 — R-6 / U-1） | 一致 |
| 2 | live な「17項目」言及 = **34 ファイル**（`grep -rln "17 *項目\|17項目" --include="*.md" .` から `docs/working/` 除外） | 同条件を再実行（本環境の `grep -r` は `./` プレフィックスなし出力のため `sed 's\|^\./\|\|'` で正規化後に `grep -v '^docs/working/'`）→ **34** | **総数 34 は一致**。ただし層別の実測（パス パターンによる機械分類）は ① **5** / ② **16** / ③ **11** / ④ **2** ＝ 34 で、issue の層別合計 35（③=12）と **1 件分の帰属差**がある。③「12」が誤りとは断定できず**層別定義に依存**（例: issue 作者が `docs/changelog.md` を CHANGELOG の sync 派生として ③ にも数えたなら合計が合う — In scope ② 行の注参照）。exec 時は件数をハードコードせず現 main 基点の再走査 + 層別帰属の確定で機械確定する（TASK-0954 と同じ規律） | 総数一致（層別は帰属差 1 — 定義確定は plan） |
| 3 | ① HO 対象（AI 編集不可）は 5 ファイル | 34 件を Hardening Override 9 カテゴリ（`scripts/hooks/check-plan-hash.sh` の `_override` case 文が正本）と突合 → 該当は `.claude/rules/working-context.md` / `.claude/rules/mode-classification.md` / `.claude/commands/ai-dev-workflow.md` / `.claude/commands/README.md` / `.claude/agents/workflow-conductor.md` の **5 件のみ**。`.claude/skills/acceptance-review/SKILL.md` は case 対象**外**（R-003/R-006 の注記どおり） | issue ① と**完全一致**。EH-3 は HO パスを maintenance 窓内でも**常時 block** → AI は**差分提案（patch）まで・適用は Human-owned**（前例実在を確認: `docs/working/TASK-0871/approvals/ho-apply-approval.md` / `docs/working/TASK-0872/patches/*.patch`） | 一致 |
| 4 | （補助）現場回避 4 引用が記載行に実在する | `sed -n '46p' / '21p' / '16p' / '13p'` で 4 ファイルを実測 → 4 件とも記載どおりの文言で実在（15 / 15 / 「core 17+8=25」 / 「17項目フル＝全 25」） | 引用は stale 化していない（作成時点 main で行番号・文言とも確認済み） | 一致 |
| 5 | （補助）mode 別適用が実体と不整合（light = Plan 7 項目のみ、実体 PLAN 9） | `grep -n 'Plan 7項目' .claude/rules/mode-classification.md` → L153「△（Plan 7項目のみ）」/ L170「Plan 7項目（C1-PLAN-01〜07）のみ」が現存 | 「決めるべきこと 2」の前提を live 確認。なお当該ファイル自体が **HO 対象**のため、mode 別適用の再定義（AC-2）も **HO patch 経由**になる | 一致 |
| 6 | （補助）③ は「正本修正 + sync で自動追従（手編集しない）」 | sync 経路の実測: `.codex/skills/` = `scripts/install-plangate-skills-to-codex.sh`、`plugin/plangate/**` = `scripts/sync-plugin-plangate.sh` が存在。一方 **`.claude/skills/` を再生成する sync スクリプトは `scripts/` に見当たらない**（`.claude/skills` を参照するのは実測 5 ファイル全数で、**書き換え系は rename 用 2 本のみ**。ほかに読み取り専用 checker 2 本〔`check-skill-name-collisions.py` / `check-stale-skill-refs.py`〕とメッセージ文言 1 件〔`scripts/ai-dev-workflow` L96〕が字句参照するが再生成はしない。TASK-0954 U-3 でも「正本と非同一の別系統」と実測） | ③ 内 `.claude/skills/acceptance-review/SKILL.md` の「sync 経由・手編集ゼロ」（AC-4）の**経路が未確立の可能性** → U-2 として plan で確定 | 要計画（ギャップ検出） |

## What（Scope）

### In scope（issue の層別を正として転記）

`docs/working/` 配下の**過去の成果物（履歴）は変更しない**。live な定義箇所のみを対象とする。live な言及 = **34 ファイル**（裏取り #2。層別実測は ① 5 / ② 16 / ③ 11 / ④ 2）:

| 層 | 件数（issue → 実測） | 扱い |
| --- | --- | --- |
| **① HO 対象（AI 編集不可）** | 5 → **5** | `.claude/rules/{working-context,mode-classification}.md` / `.claude/commands/{ai-dev-workflow,README}.md` / `.claude/agents/workflow-conductor.md` → **差分提案まで AI-owned・適用は Human-owned** |
| **② 正本（AI 編集可）** | 16 → **16** | `.agents/skills/{plan-review-gate,acceptance-review,README}` / `docs/ai-driven-development.md` / `docs/plangate.md` / `docs/workflows/README.md` / `docs/pages/reference/glossary.md` 等。**注**: ② に含まれる `docs/changelog.md` は `scripts/sync-release-docs.sh` による**自動同期ファイル**（ヘッダに「手動編集しない」明記）かつ「17項目」hit は**過去リリース記録行（L430 付近）のみ** → 字義どおりの ② 統一は生成ファイル手編集 or 履歴書き換えになるため、**④ 相当の不変更 or CHANGELOG 経由 sync のどちらで扱うかを plan で確定**（U-6 に含める） |
| **③ 同期派生** | 12 → **11**（差 1 は帰属定義依存 — 裏取り #2） | `plugin/plangate/**` / `.codex/skills/**` / `.claude/skills/**` → **正本修正 + sync で自動追従**（手編集しない。ただし `.claude/skills/` の sync 経路は U-2） |
| **④ 履歴（不変更）** | 2 → **2** | `CHANGELOG.md` / `examples/eval-fixtures/**` |

### 決めるべきこと（issue 記載・実装前に確定が必要 → 本 PBI では未確定＝plan 決定事項に送る）

1. **正となる数をどれにするか**。選択肢（issue verbatim）:
   - (a) テンプレート実体に合わせて **25** に統一する
   - (b) **core 20 + 追加 5** の二層表記にする（mode 別適用と接続しやすい）
   - (c) テンプレート側を削って 17 に戻す（**非推奨** — 後発追加は #544/#578/#579/#581 で意図的に入ったもの）
2. **mode 別適用との接続**。`mode-classification.md` は「light = Plan 7 項目のみ」としているが、実体は PLAN が 9 項目。**light の適用範囲も同時に定義し直す必要がある**（裏取り #5: 対象は HO パスのため再定義は HO patch 経由）
3. **数を本文に直書きするのをやめるか**。「テンプレートの項目数を正とする」と書けば再発しないが、mode 別マトリクスは具体数が要る

### Out of scope（issue verbatim）

- `docs/working/` 配下の過去成果物の書き換え（履歴として保全）
- C-1 の項目そのものの追加・削除（本 issue は**数と表記の整合のみ**）
- #936（test-cases.md の生成量制御）— 別問題。ただし #936 本文も「C-1 セルフレビュー17項目」と書いており、本 issue 解決後に表記追従が要る

### Non-goals（issue verbatim）

- C-1 の項目追加・削除
- `review-self.md` テンプレートの構造変更
- 過去の review-self.md の遡及修正

## 受入基準

> issue #960 の **AC 7 項目**を 1:1 で保持し、検証方法を付与。plan で最終確定する。

- **AC-1**: 正となる項目数の方針（決めるべきこと 1）が決定され、根拠が記録されている。検証: plan / decision-log.jsonl に選択肢 (a)/(b)/(c) の比較と採用理由が残っている
- **AC-2**: mode 別適用範囲（決めるべきこと 2）が実体と整合するよう再定義されている。検証: `mode-classification.md`（HO 対象 → patch 提示 + Human 適用）の C-1 行が実体の項目 ID 帯と突合可能な表記になっている
- **AC-3**: ② 正本 16 ファイルの表記が方針どおりに統一されている。検証: 裏取り #2 と同条件の再走査で、旧表記（「17項目」等）の live 残存が方針で許容した箇所以外 0 件
- **AC-4**: ③ 同期派生 12 ファイル（実測 11 — 裏取り #2）が **sync スクリプト経由で**追従している（手編集ゼロ）。検証: 同期スクリプト再実行後の `git status` が clean。`.claude/skills/` の sync 経路未確立の場合の扱いは U-2 の決定に従い（**issue AC-4 からの条件付き逸脱**）、逸脱時は handoff に根拠を明示
- **AC-5**: ① HO 対象 5 ファイルの差分が Human 適用可能な形で提示されている（前例: TASK-0871 `approvals/ho-apply-approval.md` / TASK-0872 `patches/` — 実在確認済み）。検証: sandbox / clean worktree での**実適用テスト**（TASK-0872 の `ho-apply-approval.md` 方式。`--check` 単独は検証と見なさない）+ 適用手順の提示
- **AC-6**: `docs/working/` 配下が変更されていないこと（`git diff --name-only` で確認）。読み: **既存ファイルの変更ゼロ**。本 TASK 自身の working context（`docs/working/TASK-0960/` 新規追加）と HO patch 提示物は working-context ルール（handoff 必須）上、当然に許容 — この読み替えは plan で明記する
- **AC-7**: 数の再発防止策（本文直書きをやめる / 機械検査を入れる 等）が決定され記録されている。検証: 決定内容が plan / decision-log に記録され、機械検査を選ぶ場合はその検査が本 PBI の変更に対して PASS する

## Notes from Refinement

### Mode 判定案（plan で確定）

- 定量: live 対象 34 ファイル中、実 PR で変更するのは ② 16 + ③ 11（sync 再生成）= **27 前後**（+ HO patch 提示物）→ 変更ファイル数 16+ で**定量は critical 帯**。AC 7 個 → high 帯
- 定性: 変更種別は**表記是正（doc 寄り・機械的置換中心）**で、新規設計は「正とする数」の決定（U-1）と再発防止機構（U-4）に限られる
- ただし **HO パス接触**（① 5 ファイル + AC-2 の `mode-classification.md` 再定義）→ mode-classification 例外ルール「承認境界周辺の変更 → 最低でも高」が優先し、**最低 high-risk + `lite_eligible=false` 強制 + 同期 C-3 固定**。doc-light は HO 対象 `.md` を含むため**無効**
- 安全側の初期値: **high-risk**（②正本 → ③sync → ①HO patch のスライス分割時）。ただし **② 単独でも実測 16 ファイル＝定量基準の critical 帯（16+）**のため、high-risk 初期値が成立するのは **② を 16 未満のスライスに分割することが前提**。分割しない場合は **critical**。一括なら **critical 受容**（V-2/V-3/V-4 フル + 同期 C-3）。分割単位は U-5 として plan で確定

### HO 分担の前提（本 PBI の構造的制約）

① 5 ファイルは EH-3 が**常時 block**（maintenance 窓内でも。裏取り #3）のため、AI は patch / 適用手順 / 検証コマンドの提示まで。適用は Human-owned。②③ の先行マージと ① の Human 適用の間に**一時的な表記不整合期間**が生じるため、適用順序（HO 先行 / 同時 / 事後）を plan で設計する（U-5）

### 再発防止の設計論点（AC-7 / 決めるべきこと 3）

数字ハードコードはテンプレート項目の追加が続く限り再び陳腐化する。「テンプレート実体を正とする」参照化は再発を防ぐが、mode 別マトリクス（light の適用範囲等）は具体の項目 ID 帯が要る。折衷（参照化 + ID 帯表記）や機械検査（宣言数とテンプレート実体の突合 CI）を含め plan で確定する

## Estimation Evidence

### Risks

| Risk | 影響 | 一次緩和 |
|------|------|---------|
| 修正中・マージ待ちの間に並行 PR / 新 PBI が「17項目」表記を再生産する | 統一直後に live 残存が復活し AC-3 が崩れる | exec 直前とPR 作成直前に裏取り #2 の再走査で全数を再確定。再発防止（AC-7）を表記統一と同じ PR に同梱 |
| ③ sync 再生成が #956 の commit 済み drift（**OPEN**・`.codex/skills/` 2 件）等の無関係差分を巻き込む | 無関係差分が PR に混入し C-4 レビューを汚染（TASK-0954 で実測された同型リスク） | #956 の先行解消 or 当該ファイルの stage 除外 + handoff 明示を plan に組み込む |
| `.claude/skills/` の sync 経路が未確立（裏取り #6） | AC-4「手編集ゼロ」が満たせない | U-2 を plan の設計判断とし、経路確立（スクリプト拡張）か、1 ファイル限定の手編集許容 + 根拠記録かを決めて AC-4 の検証文に反映 |
| HO patch 5 件の Human 適用が遅延・不履行 | ①（HO）と ②③ の間で表記不整合が長期化し、4 通り回避が「5 通り目」を生む | 適用順序の設計（U-5）+ handoff で未適用を BLOCKED として明示（blocker/owner/unblock_condition） |
| 「25」単純統一を選んだ場合、条件付き項目 `C1-UI-01`（is_ui_task 時のみ）が常時適用と誤読される | 実行者が非 UI タスクで 25 項目を強行 or 24 で完了扱いにする齟齬が再発 | 正とする数の決定（U-1）時に条件付き項目の注記方法まで含めて確定 |
| mode 別適用の再定義（AC-2）が light 運用の実質変更になる | 既存 light 運用 PBI の C-1 コストが変わる（表記是正の枠を超える） | 「実体と整合する最小の再定義」に限定し、適用範囲の拡張・縮小の判断は根拠を decision-log に記録 |

### Unknowns

- **U-1**: 正となる数の選択 — (a) 25 統一 / (b) core 20 + 追加 5 の二層 / (c) 17 に戻す（issue 上非推奨）。issue は**未確定**（決めるべきこと 1）→ plan の最初の決定事項。条件付き項目 `C1-UI-01` の扱いを含む
- **U-2**: `.claude/skills/acceptance-review/SKILL.md` の同期経路 — `scripts/` に `.claude/skills/` 再生成スクリプトが見当たらない（裏取り #6）。sync 対象化 / 手編集許容 + 記録 のどちらかを確定
- **U-3**: mode 別適用の新定義の具体 — light「Plan 7 項目のみ」を実体（PLAN 9、うち 08/09 は #544 由来の AEE 項目）とどう整合させるか（7 のまま ID 明示 / 9 に拡張 / コア 7 + AEE 別掲 等）
- **U-4**: 再発防止の機構選択 — 本文直書き廃止（参照化）/ 機械検査（宣言数 vs `grep -c '^### C1-'` 突合の CI・hook）/ 併用
- **U-5**: スライス分割と適用順序 — ②③① の PR 分割単位、HO patch の Human 適用タイミング、#956 との順序
- **U-6**: AC-3 の「統一」判定に使う再走査条件の確定 — 「17項目」以外の旧表記（「15 項目」「Plan 7 + ToDo 5 + TestCases 3」等の内訳表記）をどこまで走査対象に含めるか。および `docs/changelog.md` の扱い — **自動同期・履歴ミラー**（`sync-release-docs.sh` 生成・hit は過去リリース記録行 L430 のみ — In scope ② 行の注）のため、**④ 相当の不変更とするか、CHANGELOG 経由 sync で扱うか**を確定

### Assumptions

- issue の対象・層別が現 main（`a4afacb`）で有効であること（総数 34 は実測一致。層別は ③ に帰属差 1 があり — 層別定義依存、exec 時再走査 + 帰属確定で機械確定する — 裏取り #2）
- C-1 項目そのものの追加・削除は行わない（Non-goals。`review-self.md` テンプレートの構造も不変更）
- `docs/working/` は AC-6 の読みどおり**既存不変更・本 TASK 新規のみ**
- HO ① 5 ファイルは AI 直接編集不可（EH-3 常時 block が物理強制 — 裏取り #3）であり、patch 提示 + Human 適用の分担が成立すること（前例 TASK-0871 / TASK-0872 実在）
- #936 への表記追従は本 PBI 完了後の別対応（本 PBI では関連記録のみ）
