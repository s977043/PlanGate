# stop-rollback — Stop 条件と巻き戻し（EPIC #822 項目4）

> 親: [#822](https://github.com/s977043/plangate/issues/822) EPIC（HITL→HOTL変革）項目4「stop条件と巻き戻し」
> 適用ドメイン（Phase 1）: ①plangate 本体 = docs/workflows/ai-loop/ 配下のみ（dogfooding 域・本番フロー WF-00〜07 非適用）
> ②導入先リポジトリ = ho-paths 確定 + LoopSpec scope.allowed_paths 宣言を前提に適用可
> 本書の成立ち: 設計案A（手順書ベース）・設計案B（チェックリスト＋機械検証スクリプト案ベース）の
> 2 ドラフトに対し独立の敵対的検証（各 major 4 件 / critical 2〜3 件を含む）を行い、
> **すべての critical / major 指摘を解消したうえで両案の長所を統合した最終版**。
> ドキュメント設計のみ・実装コードは一切含まない（本書からコードを生成するのは別 PBI）。

---

## 0. 位置づけ・非ゴール

- 本書は以下の既存正本の**再定義ではない**。値・機構の変更が必要な場合は各正本の版上げ手続きに従う
  （[`loop-safety-gates.md`](loop-safety-gates.md) §6 と同じ扱い）:
  - [`decision-table.md`](decision-table.md) §3（priority 0〜6）/ §6（CB-1〜3）
  - [`arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) §7（escalate 予算）
  - [`00_concept.md`](00_concept.md)（対応ラウンド上限 3）
  - [`loop-safety-gates.md`](loop-safety-gates.md)（Gate 1〜5）
- **merge=Human-owned 固定**（[`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md)）は
  一切変更しない。本書のいかなる記述も merge の自動化・省略・条件緩和を意味しない（§6 で再確認する）。
- **事後 revert 自動化 + post-merge 監視**（[`hotl-merge-entry-criteria.md`](../../ai/ai-loop/hotl-merge-entry-criteria.md)
  条件2）は引き続き ❌ 未設計のまま。本書は「revert PR の下書き作成支援」までを扱い、revert の
  **自動 merge** は提案しない（条件2の充足を主張しない）。
- 過大な自動化を提案しない: 検出（機械化可能な部分）と実行判断（人間が握る部分）を常に分離する。
- 本書は [`orchestrator-mode.md`](../../../.claude/rules/orchestrator-mode.md) の AS-1〜5（親子 PBI 分解ゲート）
  とはスコープが異なる。orchestrator-mode.md は「PBI 分解の確定・子 PBI exec 開始・親完了宣言」を対象にし、
  本書は「ai-loop の exec 前ゲート（C-3' 裁定）のスキップが事後に覆された場合の停止・巻き戻し」を対象にする。
  両者は独立に適用され、矛盾しない（AS-3 の「親完了宣言は Human-owned または事前定義 policy」という例外条項は
  概念的に on-the-loop の policy モデルと近接するが、本書の対象である CB-1（個別 decision record 単位の
  事後 reject）とは適用階層が異なるため、本書は AS-1〜5 を継承・翻訳しない）。

---

## 1. 目的

ai-loop（on-the-loop 運用）における「反復・自律をいつ止めるか」（stop 条件）と、
「AUTO_APPROVED として exec 前ゲートをスキップされた変更を、人間が事後に reject した場合、
何を・どこまで機械的に・どこから人間が巻き戻すか」（rollback 手順）を、既存正本を横断して
1 か所に集約する。既存正本は機構ごとに分散しており（decision-table.md §6 の CB 定義、
arbiter-policy.md §7 の escalate 予算、working-context.md AC-9 の in-the-loop 前提の巻き戻し等）、
「実際に事後 reject が起きたときに何をすればよいか」を辿るドキュメントが存在しなかった。
本書はこのギャップを埋める。

---

## 2. 既存 stop 条件 対応表

### 2.1 Layer 1 — 反復の停止（個別裁定の terminal state）

[`design-philosophy.md`](../../ai/ai-loop/design-philosophy.md) I-6「停止できないループはループではない」の
2 層構造のうち、**個別の裁定・issue 評価が terminal state（`AUTO_APPROVED` / `HUMAN_ESCALATED` / `BLOCKED`）
に到達する層**。

| 機構名 | ファイル:行 | トリガー | 発動後の挙動 |
| --- | --- | --- | --- |
| L0 入力検証 | `scripts/ai-loop/arbiter.py:504`（`InputError`）/ `:549`（`validate_input`） | JSON 不正・不正パス・型不一致 | `InputError` → exit code 1 |
| priority 0（ho-paths 未解決 fail-closed） | `scripts/ai-loop/arbiter.py:833-845` / `decision-table.md:55-66` | ho-paths.md が実行時解決できない、またはパース結果が 0 件 | `HUMAN_ESCALATED`（`boundary=unresolved`・絶対条件） |
| priority 1（touches-HO） | `scripts/ai-loop/arbiter.py:884-885` / `decision-table.md:41` | `changed_files` が HO パターンに一致 | `HUMAN_ESCALATED` 固定（Human-owned） |
| priority 1.5（scope 逸脱） | `scripts/ai-loop/arbiter.py:886-887` / `decision-table.md:64` | `allowed_paths` のいずれの glob にも不一致 | `HUMAN_ESCALATED`（`scope_check=scope_violation`） |
| priority 1.7（plan-quality gate） | `scripts/ai-loop/arbiter.py:865-872,888-889` / `decision-table.md:65` | `gates.c1=="PASS"` かつ `gates.breakdown=="pass"` を満たさない | `HUMAN_ESCALATED` |
| priority 1.9（size 機械検証） | `scripts/ai-loop/arbiter.py:874-881,890-891` / `decision-table.md:66` | 申告 `lite.size_ok=true` と実ファイル数（`SIZE_OK_MAX_FILES=2`）不一致 | `HUMAN_ESCALATED` |
| priority 2（lite 判定 NG） | `scripts/ai-loop/arbiter.py:892-893` / `decision-table.md:42` | lite 4 軸のいずれか false/欠落 | `HUMAN_ESCALATED` |
| priority 3（class=merge 固定） | `scripts/ai-loop/arbiter.py:894-895` / `decision-table.md:43` | `class=merge` | `HUMAN_ESCALATED`（merge=Human-owned 固定・緩和なし） |
| priority 4（reject-reject / reject-approve） | `scripts/ai-loop/arbiter.py:896-897` / `decision-table.md:44` | W check 不一致（A が設計妥当性で NG）または双方 reject | `BLOCKED` |
| priority 5（severity 分類・C/D 裁定） | `scripts/ai-loop/arbiter.py:909-965` / `decision-table.md:45` | `verdict=approve-reject`。severity=critical/major は即 escalate、minor/low は Model C/D 裁定 | severity 次第で `HUMAN_ESCALATED` または C/D 裁定結果（`AUTO_APPROVED`/`HUMAN_ESCALATED`/`BLOCKED`） |
| priority 6（approve-approve 合意） | `scripts/ai-loop/arbiter.py:898-899` / `decision-table.md:46` | W check 双方 approve | `AUTO_APPROVED` |
| discovery A-1（HO リスク語検出） | `scripts/ai-loop/discovery.py:267-276` | issue の title/body が HO パス/語を含む | `candidate=False`（`reason="ho-risk"`） |
| discovery A-2（大規模語検出） | `scripts/ai-loop/discovery.py:278-286` | title/body に大規模語（アーキ・横断・移行 等） | `candidate=False`（`reason="not-lite"`） |
| discovery A-3/A-4（未解決依存検出） | `scripts/ai-loop/discovery.py:288-298` | body に未解決依存の示唆（blocked・depends on # 等） | `candidate=False`（`reason="dependency"`） |
| discovery opt-in ラベル前提 | `scripts/ai-loop/discovery.py:256-263` | opt-in ラベル欠落 | `candidate=False`（`reason="no-optin-label"`） |
| discovery 候補ゼロ終端 | `scripts/ai-loop/discovery.py:320-364`（`run_discovery` 集計。候補ゼロでも特別分岐なく通常どおり集計）/ `:487`（`main` の無条件 `return 0`） | 全 issue が除外 | exit 0・候補なしと明示（正常終了） |
| **loop-safety Gate 1〜5** | `loop-safety-gates.md:117-165` | 「完璧になるまで」型等の非停止プロンプト | ⚠️ **仕様のみ**（flow 進入前ゲート・コード実装なし）。flow 不進入・再形成提案 |
| **対応ラウンド上限（3）** | `00_concept.md:51,167-171` | 指摘対応ループの対応ラウンドが 3 を超過 | ⚠️ **仕様のみ・コード強制なし**（`HUMAN_ESCALATED` の想定） |

### 2.2 Layer 2 — 自律そのものの一時停止（サーキットブレーカー）

| 機構名 | ファイル:行 | トリガー | 発動後の挙動 |
| --- | --- | --- | --- |
| **escalate 予算（§7）** | `arbiter-policy.md:121-131` | human 昇格件数がスライディング時間窓内で予算上限超過 | ⚠️ **仕様のみ・上限値 TBD・コード強制なし**（CB-3 と連動想定） |
| **CB-1（事後 reject・即時停止）** | `decision-table.md:254-264` | `AUTO_APPROVED` 済みの変更を人間が事後 reject | ⚠️ **仕様のみ・コード実装ゼロ**。`policy_suspended=true` 宣言・巻き戻し・review queue 昇格（§3 で本書が手順を具体化） |
| **CB-2（連続 incident による policy 自動失効）** | `decision-table.md:266-278` | 同一 policy で N 回（既定 3）連続 reject | ⚠️ **仕様のみ・コード実装ゼロ**。`policy_expired=true`・全件 escalate |
| **CB-3（escalate 予算超過・全停止）** | `decision-table.md:280-290` | 全 policy 合算の escalate 件数が時間窓内で予算超過 | ⚠️ **仕様のみ・コード実装ゼロ**。`circuit_open=true` |

### 2.3 読み方（実測に基づく注意点）

- `round_index` は `scripts/ai-loop/metrics.py:112-119`（`_has_valid_round_index`）・
  `:122-136`（`_group_by_run`）・`:190-241`（first_pass 集計）で使われるが、いずれも
  **集計専用**である。「3 を超えたら拒否する」という比較ロジックは `arbiter.py` のどこにも
  存在しない（`grep -n "round_index" scripts/ai-loop/arbiter.py` の全 4 件はいずれも入力検証の
  型チェックであり、閾値比較は含まない。実測確認済み）。
- 同様に、escalate 予算の具体的上限値は TBD のまま、CB-1〜3 のフラグ
  （`policy_suspended` / `policy_expired` / `circuit_open`）を読み書きするコードは
  `scripts/ai-loop/` 配下に一切存在しない（実測確認済み）。
- **本書が新規に手順化するのは §2.2 の Layer 2（CB-1 中心）の「仕様はあるが実装がない部分」を
  人間の運用手順として補完することであり、Layer 1（priority 0〜6・discovery A-1〜A-4）を
  変更・再定義することではない。** Layer 1 はすでに機械実装済みで、本書の対象外。

---

## 3. AUTO_APPROVED 後の事後 reject 巻き戻し手順（AC-9 → ai-loop 翻訳）

### 3.0 前提の違い（working-context.md AC-9 との対応）

[`working-context.md`](../../../.claude/rules/working-context.md)「C-3 条件付き降格」§AC-9 は、
**in-the-loop（C-3 の一時的非同期降格）が reject された場合**の後始末を 5 ステップで定義する:

> 1. exec が作った実装ブランチを破棄（または revert）
> 2. 生成済み PR を close
> 3. 当該 run の成果物（status/handoff 等）を invalidation マーク
> 4. `decision-log.jsonl` と監査ログに reject＋巻き戻しを記録
> 5. 既に出た派生成果物（後続が参照したもの）を「無効」と明示し追従是正

ai-loop（on-the-loop）はこの前提を共有しない。翻訳表:

| 観点 | working-context.md AC-9 | ai-loop（本書の対象） |
| --- | --- | --- |
| 対象モデル | in-the-loop・C-3 の**一時的非同期降格**が reject された場合の後始末 | on-the-loop・priority 6（W check 合意）または C/D 裁定合意による**exec 前ゲートのスキップ**（C-3' 相当）が事後 reject された場合 |
| 単位 | 1 PBI = 1 ブランチ/PR | 1 `target_sha`（コミット）単位の decision record。record 自体は PR/ブランチを持たない |
| merge の扱い | AC-9 step2「PR close」を含む | `class=merge` は priority 3 で常時 `HUMAN_ESCALATED` 固定（変更なし）。`AUTO_APPROVED` 自体は merge を許可しない |
| 監査ログの置き場 | `docs/working/<child-context>/decision-log.jsonl` | `docs/working/ai-loop-runs/*.json`（record）+ `run-NNN-loopspec.md`。同型の一元ログは現状**存在しない**（§3.7 で新設提案） |
| in-the-loop 前提の根拠 | — | [`asset-inventory.md`](../../ai/ai-loop/asset-inventory.md):40「C-3 承認ロジックは実行前承認が前提。ai-loop では C-3 を C-3'（AI 裁定ゲート）に置換する（再設計対象）」 |

### 3.1 merge 済みケースの扱い（帰結・critical 指摘 R-3/F7 の統合解）

`class=merge` は構造的に常に priority 3 で `HUMAN_ESCALATED` になるため、**`AUTO_APPROVED` された
変更自体が merge を含むことはない**。したがって「`AUTO_APPROVED` された変更を人間が事後 reject する」は
必ず「exec 前承認をスキップされた実装（コード変更そのもの）が間違っていた」ケースを指す。

ただし、その AUTO_APPROVED な実装を含む PR が、**その後に別途通常の C-4（人間レビュー）を経て
merge されている**ことはありうる。この場合の扱いを以下のとおり明確化する（敵対的検証で
以下 2 点が矛盾したまま残っていたための統合）:

- **CB-1 という stop 機構自体（policy 即時停止の宣言・review queue への昇格・監査ログ記録）は、
  merge 済み / 未 merge にかかわらず無条件に発火する。** これは「この先同じ policy で誤判定が
  繰り返されるのを止める」ためのものであり、対象コミットが物理的に取り消せるか否かとは無関係である。
  merge 済みだからといって CB-1 の適用対象から外れる（＝policy 停止・review queue 昇格を省略してよい）
  ということはない。
- **merge 済み / 未 merge で変わるのは、Step 1/2（下記）の「巻き戻しアクションの種類」だけ**である:
  - 未 merge: ブランチ破棄・PR close
  - merge 済み: revert PR の下書き作成（この revert PR 自体の **merge は通常の C-4** を経る。
    AC-9 固有・CB-1 固有の特別な merge 経路は設けない。responsibility-classes.md の
    merge=Human-owned 固定をそのまま適用するだけであり、新しい仕組みは不要）

### 3.2 着手前提: 巻き戻し実行前に必須の人間発行アーティファクト（major 指摘 R-4 反映）

Step 1（ブランチ破棄・revert という破壊的操作）に着手する前提として、以下のいずれかの
**AI が自作できない、人間が発行したアーティファクト**の存在を必須とする:

- 対象 PR への GitHub `Request changes` レビュー（GitHub 側が発行者を保証する）
- または `reject-ack.json`（`decision` / `signed_by` / `timestamp` を持つ、`c3.json` と同型の
  人間発行ファイル。[`maintenance.json` 発行元ギャップ](../../../.claude/rules/responsibility-classes.md)
  と同種の問題を防ぐため、AI の会話内解釈だけを根拠に破壊的操作を実行しない）

後述 §3.7 の `rollback-log.jsonl` の `acknowledged_by` フィールドは、**この人間発行アーティファクトからの
転記でなければならない**。AI が会話内容から独自に生成した文字列であってはならない。

> **なぜ必要か**: `rollback-log.jsonl` の `acknowledged_by` を AI が自分の理解で書ける構造のままだと、
> 「AI が『reject された』と誤解（あるいは誘導）した場合に、ブランチ破棄・PR close という破壊的操作が
> 実質的に AI の自己申告だけを根拠に走ってしまう」という構造的弱点になる。CB-1（自律暴走の安全弁）
> 自体が根拠薄弱なトリガーで作動しうることは、EPIC #822（HOTL＝人間監督の実効性）の趣旨に反する。

### 3.3 Step 0（AC-9 にはない追加前置ステップ）: 対象特定と意味論確認

- **入力**: reject 対象の record ファイル（`docs/working/ai-loop-runs/*.json`）または `run_id`
- **実行内容**: `git show <target_sha>` で対象コミットの実在を確認する

#### 3.3.1 target_sha が解決不能な場合（critical 指摘 R-2 反映）

`git show`／`git cat-file -e` が `fatal: bad object` 等で失敗するケース（force-push・squash-merge・
reflog 期限切れ後の `git gc` により対象コミットが祖先関係からも到達不能になったケース）を
明示的に扱う。本リポジトリは squash-merge を常用しており、reject 判断のタイミングによっては
対象コミットが既に squash 先コミットに吸収され消失している可能性が現実的にある。

- 対象コミットが解決不能な場合は、即座に `event:"TARGET_UNRESOLVABLE"` を
  `rollback-log.jsonl`（§3.7）に記録し、**Step 1（ブランチ破棄/revert のコード上の操作）は
  スキップして人間 escalate のみで完了**とする（rollback が「できない」ことを隠さず記録する
  fail-closed 経路）。
- この経路でも Step 3（invalidation マーク）・Step 4（`policy_suspended` 宣言・監査ログ記録）は
  実行する（§3.1 の統合解のとおり、CB-1 の停止機構自体は対象喪失と無関係に発火する）。
  対象コミット喪失自体は別途インシデントとして扱うべき事象であり、本書の巻き戻し手順の
  「失敗」ではなく「想定内の限界」として記録する。

#### 3.3.2 target_sha の多義性・多対一問題（critical 指摘 F3 反映）

`target_sha` の計画時 base / 実装後 commit の両義性（`decision-table.md` §5「`target_sha` の
計画時 vs 実装後の意味論」、issue #782 P3・未解消）により、**計画時 base の意味で刻まれた
`target_sha` は、同じ `origin/main` HEAD から分岐した複数タスクに共有されうる**（多対一）。
この場合、reject 対象の record 単体からは「どの実装ブランチ/PR を巻き戻すべきか」を機械的にも
人間的にも一意特定できない。

- **PF-3b（新設）**: Step 0 で対象コミットの reachability を確認した後、
  **全 record 横断で同一 `target_sha` を参照する他 record が存在しないか**を確認する
  （`grep -r '"target_sha": "<値>"' docs/working/ai-loop-runs/*.json` 相当）。
  複数ヒットした場合は「一意特定不能」として Step 1 に進まず、`task_id` / `timestamp` /
  `run-NNN-loopspec.md` の自由記述で人間が手動突合するまで停止する。

#### 3.3.3 ファイル名 SHA と record 中身の不一致（CL-6 の裁定方針・major 指摘 F5 反映）

実測でファイル名の SHA と record 中身の `target_sha` が食い違う事例が確認されている
（`20260707T112728Z-97e1ed8-run016-r1.json` はファイル名 `97e1ed8` だが中身の `target_sha` は
`10d903c`。`20260707T122856Z-1ba9b8e-run018-r1.json` はファイル名 `1ba9b8e` だが中身は
`cc45651`。いずれも実ファイルで再確認済み）。

- **裁定方針（統一）**: **JSON 中身の `target_sha` を機械的な一次候補（provisional candidate）とする**。
  ただしこれは「機械が確定させてよい」という意味ではなく、`run-NNN-loopspec.md` の自由記述との
  突合を経て、**最終的な対象特定は必ず人間が確認する**。ファイル名だけで対象を特定してはならない。
  （これは「機械が一次候補すら出さない」よりも実務上有用だが、機械の一次候補を「正」として
  そのまま実行に進めることは決してしない ― 人間確認というゲートは省略不可）

#### 3.3.4 git reachability 検証の shallow clone / TOCTOU 対策（major 指摘 F4 反映）

- `git cat-file -e <sha>` はローカル repo の物理状態にのみ依存するため、CI runner で一般的な
  `--depth=1` の shallow clone では、リモートに実在するコミットでも偽陰性（unreachable 判定）に
  なりうる。reachability 確認の前に `git rev-parse --is-shallow-repository` を確認し、
  shallow なら `git fetch --unshallow` してから再検証する。
- 確認（Step 0）から実行（Step 1）までの間に別プロセスが force-push / `git gc` を行うレース
  （TOCTOU）に備え、**Step 1 直前に reachability を再検証**する。安全側（unknown → escalate）に
  倒れるため事故には直結しないが、「本来復元可能なのに無駄に escalate する」誤検知コストを
  下げるための運用上の注意として明記する。

- **機械化可否**: **半自動**（実在確認・複数候補検出・ファイル名不一致検出は機械化可能。
  意味論の確定・複数候補時の最終選定・ファイル名不一致時のどちらが正かの最終確認は人間確認必須）

### 3.4 Step 1（AC-9 step1 相当）: 実装ブランチの破棄または revert

- **前提**: §3.2 の人間発行アーティファクトが存在し、§3.3 の対象特定が完了していること
  （`TARGET_UNRESOLVABLE` の場合はこの Step をスキップする）
- **ai-loop 文脈**: `target_sha`（Step 0 で確定済み）が指すコミットに対応するローカル/リモート
  ブランチを破棄する、または未来のコミットが上に乗っている場合は `git revert` する
- **merge 適合性の確認**: この操作は「ブランチの破棄」または「revert コミットの作成」であり、
  それ自体は merge 判断ではないため responsibility-classes.md には抵触しない
- **機械化可否**: **機械的に実行可能**（通常の git 操作。ただしリモートへの force-push 等
  破壊的操作は [`working-context.md`](../../../.claude/rules/working-context.md)「Bash 連結コマンド時の
  error guard」の三点照合に従う）

### 3.5 Step 2（AC-9 step2 相当）: 生成済み PR の close（該当する場合のみ）

- **ai-loop 文脈**: 対象 PR が**未 merge**なら close する。**既に merge 済み**（＝別途正規の C-4 を
  経ている）なら close の対象ではなく、revert PR の下書き作成に切り替える（§3.1 の帰結どおり、
  この revert PR の merge は通常の C-4 を経る。特別扱いしない）
- **確認対象 PR の曖昧さ解消（major 指摘 F8 反映）**: 「対象 PR」は元 PR か revert PR かで
  確認事項が異なるため、Post-flight（§3.7 補足）では以下の 2 項目に分割する:
  - (a) revert PR を起票した場合、そのレビュー・merge の状態
  - (b) 元 PR が未 merge 時点で close された場合は、その close 状態
- **機械化可否**: PR close / revert PR 下書き作成のコマンド実行自体は機械化可能だが、
  「reject 判断 → close 実行」を無承認で連鎖させると事実上の自己完結になりうるため、
  §3.2 の人間発行アーティファクトを経てから AI が実行する。revert PR の**merge 実行は
  常に Human-owned**（新規/既存を問わず変更なし）

### 3.6 Step 3（AC-9 step3 相当）: 当該 run の成果物の invalidation マーク

- **ai-loop 文脈**: 対象は `docs/working/ai-loop-runs/*.json`（record）と `run-NNN-loopspec.md`。
  これらは append-only の監査証跡であるため、**既存 record を書き換えず**、新規ファイルへの
  追記で invalidation を表現する
- **機械化可否の位置づけ（major 指摘 F9 反映）**: この操作は append-only の記録作業であり、
  [`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) の Human-owned
  （self-mod guard 対象 settings の適用・merge・権限操作）には該当しない。同正本の AI-owned 列
  （「実装・テスト・検証・PR 準備・manual patch / script 生成」）に相当する記録作業であり、
  **AI が実行してよい**（§3.2 の人間発行アーティファクトが既に存在することを前提に、
  その事実を記録するだけの操作であるため）

### 3.7 Step 4（AC-9 step4 相当）: 監査ログへの記録

- **提案スキーマ**: 新設 `docs/working/ai-loop-runs/rollback-log.jsonl`（既存の
  `docs/working/_audit/skip-decision-log.jsonl` と同型の append-only パターンを踏襲）

  ```jsonc
  {
    "ts": "<ISO8601>",
    "event": "POST_HOC_REJECT | TARGET_UNRESOLVABLE | DEPENDENT_RUN_DETECTED | DEPENDENT_RUN_INVALIDATED",
    "run_id": "run-XXX|null",
    "round_index": "N|null",
    "target_sha": "<確定済みSHA、または特定不能時は候補一覧>",
    "policy_ref": "<対象 record の policy_ref をそのまま転記（CB-2 の同一 policy 連続 reject 判定に必須）>",
    "original_decision": "AUTO_APPROVED",
    "rollback_action": "branch_discarded | reverted | pr_closed | revert_pr_drafted | none_target_unresolvable",
    "human_ack_ref": "<§3.2 の人間発行アーティファクトへの参照（PR review URL または reject-ack.json パス）>",
    "acknowledged_by": "<human。§3.2 のアーティファクトからの転記のみ。AI 独自生成は不可>",
    "acknowledged_at": "<ISO8601|null>"
  }
  ```

  > `round_index` は既存 25 record（Run-001〜021）に存在しないため `run_id` と同じく nullable
  > とする（minor 指摘 R-5 反映。`round_index:"N|null"` 表記に統一し、実装時のバリデーションが
  > 誤って必須 int 型と扱う引き金を防ぐ）。
  >
  > `policy_ref` フィールドを追加した理由（major 指摘 R-1 反映）: CB-2「同一 policy で N 回連続
  > reject」を人間が運用上追跡するには、rollback-log 単体から「どの record が同一 policy の
  > 何回目の reject か」を判別できる必要がある。`arbiter.py:689`（`build_provenance()` 内
  > `"policy_ref": POLICY_REF`）が既に各 record に `policy_ref` を刻んでいるため、reject 対象
  > record から転記するだけで済む（追加コスト極小）。

- **CB-1 の停止機構自体（`policy_suspended=true` の宣言・review queue への昇格）は、
  §3.1 のとおり merge 済み / 未 merge にかかわらず無条件で本ログへ記録する。**
- **ただし `policy_suspended` フラグを次回 arbiter 呼び出し時に実際に読んで拒否する実装は
  存在しない**（§2 参照）。本書は記録までに留め、「記録された事実を人間または次回呼び出し側が
  確認して当該 policy の使用を手動で控える」という**運用でのカバー**を明記する（実装提案はしない）。
- **機械化可否**: **機械的に実行可能**（ログ追記のみ。記録内容は §3.2 で確認済みの人間 reject
  判断という「事実」の転記であり、AC-9 step4 と同じ思想。実効的な自動停止は別スコープ）。
- **CB-2 / CB-3 との関係（major 指摘 R-1 反映・§2.2 で既出のギャップの再確認）**:
  本 Step は CB-1 の記録手順を具体化するが、CB-2（連続 N 回 reject での policy 自動失効）・
  CB-3（escalate 予算超過での全停止）を実装するものではない。`rollback-log.jsonl` に
  `policy_ref` を刻むことで、CB-2 判定に必要な「同一 policy の reject 回数」を**人間が手動で
  数えられる材料**を用意するに留まる（機械的な自動失効の実装は別 PBI・§5 参照）。

### 3.8 Step 5（AC-9 step5 相当・最難関）: 派生成果物の追従是正

- **ai-loop 文脈**: 後続 run が reject 対象の `target_sha` を祖先に持つコミットを前提に実行
  されていないかを `git merge-base --is-ancestor <reject対象sha> <後続runのtarget_sha>` で
  機械チェックできる（git オブジェクトが到達可能な間のみ）
- **既知の限界（過大な自動化をしない理由）**:
  - provenance record には `changed_files` が刻まれない（`arbiter.py:622-716` の
    `build_provenance()` にこのキーは存在しない。実測確認済み）。そのため「ファイル単位の依存」
    までは機械検出できず、**コミット祖先関係の検出に留まる**
  - `run_id`/`round_index` を欠く旧 25 record（Run-001〜021）は run 横断の紐付けが機械的に
    できず、連鎖検出の対象外になりうる（Step 0 と同じ制約）
  - 7 桁短縮 SHA の衝突可能性はゼロではない（現状は問題ないが保証がない）
- **機械化可否**: **半自動**（祖先関係の検出は機械化可能。しかし「検出された依存 run を実際に
  無効とみなすか」の最終判断は**必ず人間が行う**。全自動での連鎖無効化はしない。検出結果を
  `rollback-log.jsonl` に `event:"DEPENDENT_RUN_DETECTED"` として提示し、人間の確認後に
  `event:"DEPENDENT_RUN_INVALIDATED"` を追記する 2 段階とする）

---

## 4. 巻き戻し手順の機械実行可能性

### 4.1 Step 別 総括表

| ステップ | 内容 | 機械化可否 | 残る人手作業 |
| --- | --- | --- | --- |
| 前提（§3.2） | 人間発行アーティファクトの存在確認 | 存在確認は機械的に可能 | アーティファクトの**発行そのもの**（Request changes レビュー or `reject-ack.json` 署名）は人間固定 |
| Step 0（§3.3） | 対象特定（target_sha 実在確認・多義性検出・不一致検出） | 半自動 | 意味論確定（計画時/実装後）・複数候補時の最終選定・ファイル名不一致時の裁定 |
| Step 1（§3.4） | ブランチ破棄/revert | **機械的に実行可能** | なし（破壊的操作は三点照合を経る。前提として §3.2 のアーティファクトが必須） |
| Step 2（§3.5） | PR close / revert PR 下書き | **機械的に実行可能**（実行は §3.2 のアーティファクト確認後） | revert PR の **merge 判断**（常に Human-owned） |
| Step 3（§3.6） | run 成果物の invalidation マーク | **機械的に実行可能**（append-only 記録・AI-owned） | なし |
| Step 4（§3.7） | 監査ログ記録（`policy_suspended` 宣言・review queue 昇格を含む） | **機械的に実行可能**（append-only 記録） | policy 再承認の**実施そのもの**（Human-owned・第0の承認境界） |
| Step 5（§3.8） | 派生成果物の連鎖是正 | 半自動（祖先関係検出まで） | 検出結果を無効とみなす最終判断 |
| CB-1 の実効化（次回呼び出し時の `policy_suspended` 参照） | 実行回避の自動強制 | **未実装（本書はコード化しない）** | 全て（人間が手動で使用を控える運用。§3.7 参照） |
| CB-2/CB-3・round 上限・escalate 予算 | 実行回数・昇格件数の強制打ち切り | **未実装（本書はコード化しない）** | 全て（仕様のみ。§2.2 参照） |

### 4.2 操作カテゴリ別マトリクス（検証 read-only vs 実行 write/destructive）

| 操作カテゴリ | 検証（read-only） | 実行（write/destructive） | 本書での扱い |
| --- | --- | --- | --- |
| record 整合性チェック（target_sha reachability・多義性・ファイル名不一致・round_index 一意性） | 提案（スクリプト化可能） | — | 検証スクリプトの**提案**まで。実装は別 PBI |
| target_sha / PR 特定 | 部分提案（人間確認込み） | — | 抽出結果の自動適用（close/revert）はしない |
| ブランチ破棄・PR close・revert 実行 | — | 常に §3.2 の人間発行アーティファクト必須 | 自動化提案なし（responsibility-classes.md 準拠） |
| invalidation マーク・監査ログ記録 | — | **AI 実行可**（append-only・§3.6/§3.7 参照） | 記録作業として AI-owned に位置づけ |
| CB-1〜3 の状態管理（`policy_suspended`/`policy_expired`/`circuit_open`） | 未実装 | 未実装 | 本書のスコープ外・将来 PBI |
| merge 後の revert 自動化 | — | `hotl-merge-entry-criteria.md` 条件2 が ❌ 未設計 | 本書では一切提案しない（条件2の充足は別プロセス） |
| 派生成果物の参照是正（祖先関係の検出） | 提案（`git merge-base --is-ancestor`） | — | 検出結果の提示までで、無効化判断は人間 |

**既存 precedent との整合**: `discovery.py` の `--emit-next-command`（コマンド文字列を生成するが
実行しない）パターンに倣い、本書で言及する全ての「検証スクリプト案」は**判定結果の出力・候補
コマンド文字列の生成までを行い、実行は行わない**という既存原則を踏襲する。これにより過大な
自動化を構造的に回避する。

### 4.3 既存資産の再利用可否（major 指摘 F11 の訂正反映）

派生成果物の参照是正（Step 5 / §3.8）における「他 record が当該 `target_sha` を参照していないか」
の検索について、`.claude/skills/ref-integrity-scan/SKILL.md` を実際に確認したところ、
**同スキルの対象はファイルパス参照専用**（「スキル/ルール/フック/設定/ドキュメントの削除・移動・
改名時の被参照スキャン」）であり、SKILL.md 冒頭「When NOT to use」に「コード内の import/require
参照」は明示的にスコープ外と記載されている。**コミット SHA を対象とした dependency 検索は
ref-integrity-scan の対象外**であり、そのまま適用しても Step 5 の検証は行えない。

- 誤った再利用可否判断は「チェックしたつもりで実は何もチェックできていない」状態を生むため、
  本書では ref-integrity-scan を Step 5 の実装候補として**推奨しない**よう訂正する。
- SHA ベースの dependency 検索が必要になった場合は、別途（同型だが新規の）軽量スクリプトが
  必要になる。本書はこの新規実装を提案しない（§5 参照。将来 PBI のスコープ）。

---

## 5. 敵対的検証で発見された限界事項（明示的に残すギャップ）

以下は本書が**意図的に解消しない**、または**解消できない**限界である。EPIC #822 の後続 PBI
候補として個別に切り出すことを推奨する。

| # | 限界事項 | 本書での扱い | 出典 |
| --- | --- | --- | --- |
| 1 | force-push / squash-merge / `git gc` により `target_sha` が指すコミットが物理的に到達不能になるケース | §3.3.1 の `TARGET_UNRESOLVABLE` fail-closed 経路で「巻き戻し不能」を記録するに留め、コード上の revert 操作は行わない。復旧手段自体は本書のスコープ外 | R-2 |
| 2 | `target_sha`（計画時 base 説）が同一 HEAD から分岐した複数タスクに共有される多対一問題 | §3.3.2 の PF-3b で複数候補検出まで機械化。最終選定は人間固定 | F3 |
| 3 | CB-1〜3 の状態（`policy_suspended`/`policy_expired`/`circuit_open`）を次回 arbiter 呼び出し時に実際に読んで拒否する実装が存在しない | §3.7 で記録までに留め、運用でのカバー（人間が手動で使用を控える）を明記。実装は別 PBI | R-1 §2.2 |
| 4 | round 上限（3）・escalate 予算（TBD 値）の機械的強制が存在しない | §2.3 で実測（`metrics.py` は集計専用）を明記。実装は別 PBI | F1 |
| 5 | `issued_by`（AUTO_APPROVED の発行元）の真正性が未検証（署名・HMAC 等が別途必要） | `design-philosophy.md` I-3 の既知の限界としてそのまま継承。§3.2 の human_ack はあくまで「事後 reject の意思決定」の真正性を担保するものであり、`AUTO_APPROVED` 発行自体の真正性検証（[`hotl-merge-entry-criteria.md`](../../ai/ai-loop/hotl-merge-entry-criteria.md) 条件1）は別スコープ | R-4 派生 |
| 6 | provenance に `changed_files` が刻まれないため、Step 5 の連鎖是正はファイル単位ではなくコミット祖先関係の検出に留まる | §3.8 に明記。追加する場合は decision-table.md §5 の additive 拡張として別途提案 | 設計案A §4 継承 |
| 7 | `run_id`/`round_index` を欠く旧 25 record（Run-001〜021）は run 横断の紐付けが機械的にできない | Step 0/Step 5 で明記。timestamp の前後関係と `run-NNN-loopspec.md` の自由記述に頼る | 設計案A §2.2 継承 |
| 8 | git reachability 検証は shallow clone で偽陰性になりうる／TOCTOU レースが起こりうる | §3.3.4 で `--is-shallow-repository` 確認・`--unshallow` フォールバック・実行直前の再検証を明記。残余リスクは「無駄な escalate」という誤検知コストに留まり事故には直結しない | F4 |
| 9 | 7 桁短縮 SHA の衝突可能性はゼロではない | §3.8 に明記。現状は問題ないが保証はない | 設計案A §2.2 継承 |
| 10 | ref-integrity-scan は SHA ベースの dependency 検索に対応しない | §4.3 で訂正。新規スクリプトは別 PBI | F11 |

---

## 6. 「完全自動巻き戻し」は行わない旨の明記

本書のいかなる記述も、以下を主張・提案しない:

- **merge の自動化・省略・条件緩和**（[`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md)
  の merge=Human-owned 固定は不変。revert PR の merge も常に通常の C-4 を経る）
- **AI が単独で「reject された」と判断してブランチ破棄・PR close 等の破壊的操作を実行すること**
  （§3.2 の人間発行アーティファクトが常に前提）
- **CB-1〜3 の状態を次回呼び出し時に自動参照して auto-approve を止めること**（未実装。運用でのカバーに留める）
- **round 上限・escalate 予算の機械的強制**（未実装。仕様のみ）
- **merge 後の revert の自動 merge**（[`hotl-merge-entry-criteria.md`](../../ai/ai-loop/hotl-merge-entry-criteria.md)
  条件2 は引き続き ❌ 未設計。revert PR の下書き作成支援までであり、その merge 実行は Human-owned）
- **派生成果物の連鎖是正の全自動無効化**（検出は機械化、無効とみなす最終判断は常に人間）

**AI が実行してよいのは、§3.2 の人間発行アーティファクトの存在を前提とした「事務的な実行」
（ブランチ破棄・PR close・revert PR 下書き・append-only 記録）までであり、「reject するかどうか」
「巻き戻し対象をどれとみなすか」「policy を再承認するか」「revert PR を merge するか」の
**意思決定そのものは常に Human-owned**である。**

---

## 7. 既存正本との整合確認

| 本書の記述 | 整合確認先 | 結果 |
| --- | --- | --- |
| merge=Human-owned 固定は一切変更しない | `responsibility-classes.md` | 矛盾なし |
| CB-1 は merge 済み/未 merge にかかわらず無条件発火し、変わるのは巻き戻しアクションの種類のみ | `decision-table.md` §6 CB-1 | 矛盾なし（CB-1 のトリガー文言自体が merge 済み/未 merge を区別していないことと整合） |
| 事後 revert 自動化・post-merge 監視は提案しない | `hotl-merge-entry-criteria.md` 条件2 | 矛盾なし（❌ 未設計状態を維持） |
| 判定不能・データ欠落は unknown → human escalate に倒す | `design-philosophy.md` I-4 | 矛盾なし（安全側デフォルトの継承） |
| CB-1〜3 を実装しない（記録までに留める） | `decision-table.md` §6 | 矛盾なし（仕様は不変。実効性ギャップの指摘のみ） |
| invalidation マーク・監査ログ記録は AI-owned | `responsibility-classes.md`（AI-owned 列: 実装・テスト・検証・manual patch 生成） | 矛盾なし（self-mod guard 対象 settings の適用・merge・権限操作には該当しない append-only 記録） |
| 破壊的操作は人間発行アーティファクトを前提とする | `.claude/skills` 慣行（maintenance.json 等の人間承認トークン代理作成禁止と同型） | 矛盾なし |
| working-context.md AC-9 の 5 ステップを継承・翻訳 | `working-context.md` | 矛盾なし（in-the-loop 文脈から on-the-loop 文脈への読み替えとして明示） |
| orchestrator-mode.md AS-1〜5 とはスコープが異なる | `orchestrator-mode.md` | 矛盾なし（§0 で明示） |
| reversal_rate（同一 run 内の収束率）と事後 reject（run 外の別レビューによる取り消し）は別概念 | `design-hotl-metrics.md`（項目3） | 矛盾なし（混同していない） |
| ref-integrity-scan は SHA 参照検索には非対応 | `.claude/skills/ref-integrity-scan/SKILL.md` | 訂正済み（§4.3） |

---

## 8. 関連ドキュメント

- [`docs/workflows/ai-loop/decision-table.md`](decision-table.md) §3 priority 0〜6 / §5 provenance / §6 サーキットブレーカー
- [`docs/workflows/ai-loop/loop-safety-gates.md`](loop-safety-gates.md) Gate 1〜5・§6 既存正本との不整合防止一覧
- [`docs/workflows/ai-loop/00_concept.md`](00_concept.md) 収束ルール（対応ラウンド上限3）
- [`docs/workflows/ai-loop/adaptive-production-loop.md`](adaptive-production-loop.md) terminal state 表
- [`docs/workflows/ai-loop/flow-detect.md`](flow-detect.md) class=merge/no-merge 判定
- [`docs/workflows/ai-loop/lite-criteria.md`](lite-criteria.md) §2 可逆性要件
- [`docs/ai/ai-loop/design-philosophy.md`](../../ai/ai-loop/design-philosophy.md) I-1（承認境界の不可侵）/ I-3（裁定の決定論・既知の限界）/ I-4（安全側デフォルト）/ I-6（停止できないループはループではない）
- [`docs/ai/ai-loop/arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) §6 第0の承認境界 / §7 escalate 予算 / §8 安全装置
- [`docs/ai/ai-loop/hotl-merge-entry-criteria.md`](../../ai/ai-loop/hotl-merge-entry-criteria.md) 条件2（事後 revert 自動化・未設計）
- [`docs/ai/ai-loop/asset-inventory.md`](../../ai/ai-loop/asset-inventory.md) — working-context.md C-3 ロジックの not-uses 分類（AC-9 が in-the-loop 前提であることの根拠）
- [`docs/working/TASK-0822/design-hotl-metrics.md`](../../working/TASK-0822/design-hotl-metrics.md) — reversal_rate との概念区別（EPIC #822 項目3。本 PR 時点で未マージのためリンク先は暫定的に不在。項目3 のマージ後に解決する）
- [`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md) AC-9（巻き戻し5ステップの原型）
- [`.claude/rules/responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) merge=Human-owned 固定・責務4分類
- [`.claude/rules/orchestrator-mode.md`](../../../.claude/rules/orchestrator-mode.md) AS-1〜5（本書とスコープが異なることの確認のみ）
- [`.claude/skills/ref-integrity-scan/SKILL.md`](../../../.claude/skills/ref-integrity-scan/SKILL.md) — 適用範囲がファイルパス参照専用であることの確認
- 既存 record 実測: `docs/working/ai-loop-runs/`（25件）、監査ログ書式参考: `docs/working/_audit/skip-decision-log.jsonl`
- 本書の前段ドラフト: `docs/working/TASK-0822/design-hotl-stop-rollback.md`（設計案A）/
  `docs/working/TASK-0822/design-stop-rollback-b.md`（設計案B）— いずれも敵対的検証済み、
  本書がその統合最終版
