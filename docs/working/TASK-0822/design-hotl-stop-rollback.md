# TASK-0822 項目4: stop条件と巻き戻し 設計（案A）

> 親: #822 EPIC（HITL→HOTL変革）。既存 [`decision-table.md`](../../workflows/ai-loop/decision-table.md) §6
> サーキットブレーカー・[`working-context.md`](../../../.claude/rules/working-context.md) AC-9・
> [`hotl-merge-entry-criteria.md`](../../ai/ai-loop/hotl-merge-entry-criteria.md) 条件2 を踏まえた
> **ドキュメント設計のみ**（実装コードは書かない）。

## 結論

1. **stop条件はほぼ全て「仕様済み or 実装済み」だが、両方揃っているのは arbiter.py / discovery.py の裁定ロジックのみ**。
   round上限（3）・escalate予算・CB-1〜3 は decision-table.md / arbiter-policy.md / 00_concept.md に
   **仕様として明記済みだがコード実装ゼロ**（§1 参照）。本書はこのギャップを埋める実装は提案しない
   （EPIC #822 の別項目候補として切り出しを推奨・§4）。
2. **working-context.md AC-9 の5ステップはそのまま転用できない**が、思想（可逆性優先・append-only記録・
   段階的巻き戻し）は継承可能。ai-loop 文脈への翻訳表を §2 に示す。
3. **`class=merge` は priority 3 で常時 human escalate 固定のまま**（responsibility-classes.md
   merge=Human-owned固定と完全一致・本書はこれを一切緩和しない）。したがって
   「AUTO_APPROVED された変更の事後reject」は必ず「exec前承認（C-3'相当）をスキップされた実装が
   間違っていた」ケースであり、「人間が merge 承認した後にそれを覆す」ケースではない。後者は
   通常の C-4 運用（revert PR を新規に立てて通常の C-4 を踏む）の範囲内でありAC-9固有の巻き戻しは不要。
4. 巻き戻し手順の**機械化可否は工程ごとに異なる**（§3 総括表）。対象特定（target_sha の意味論）と
   派生成果物の連鎖是正（Step 5）は**人間確認が必須**で残り、記録・ログ化は機械化可能。

---

## 0. 位置づけ・非ゴール

- 本書は [`decision-table.md`](../../workflows/ai-loop/decision-table.md) §6（CB-1〜3）・
  [`arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) §7（escalate 予算）・
  [`00_concept.md`](../../workflows/ai-loop/00_concept.md)（round上限3）の**再定義ではない**。
  値・機構の変更が必要な場合は各正本の版上げ手続きに従う（loop-safety-gates.md §6 と同じ扱い）。
- **merge=Human-owned固定**（[`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md)）
  は一切変更しない。本書のいかなる記述も merge の自動化・省略・条件緩和を意味しない。
- **事後revert自動化 + post-merge監視**（[`hotl-merge-entry-criteria.md`](../../ai/ai-loop/hotl-merge-entry-criteria.md)
  条件2）は引き続き ❌ 未設計のまま。本書は「revert PR の下書き作成支援」までは扱うが、
  revert の**自動 merge** は提案しない（条件2の充足を主張しない）。
- 過大な自動化を提案しない: 検出（機械化）と実行判断（人間）を常に分離する。

---

## 1. 既存stop条件 対応表（棚卸し）

| 層/フェーズ | 機構名 | 実装状態 | トリガー（要約） | 発動後（要約） | 正本 |
| --- | --- | --- | --- | --- | --- |
| L0 入力検証 | `validate_input` 他 | ✅ 実装済み | JSON不正・不正パス・型不一致 | `InputError` → exit 1 | `arbiter.py` |
| priority 0 | ho-paths 未解決 fail-closed | ✅ 実装済み | ho-paths.md 解決不能/0件 | `HUMAN_ESCALATED`（fail-closed絶対） | `arbiter.py` / `decision-table.md` |
| priority 1 | touches-HO（絶対条件） | ✅ 実装済み | changed_files が HO パターン一致 | `HUMAN_ESCALATED` 固定 | 同上 |
| priority 1.5 | scope逸脱（allowed_paths） | ✅ 実装済み | allowed_paths 非一致 | `HUMAN_ESCALATED` | 同上 |
| priority 1.7 | plan-quality gate | ✅ 実装済み | `gates.c1`/`gates.breakdown` 未充足 | `HUMAN_ESCALATED` | 同上 |
| priority 1.9 | size機械検証 | ✅ 実装済み | 申告 size_ok=true と実測ファイル数不一致 | `HUMAN_ESCALATED` | 同上 |
| priority 2 | lite判定NG | ✅ 実装済み | lite 4軸のいずれか false/欠落 | `HUMAN_ESCALATED` | 同上 |
| priority 3 | class=merge固定 | ✅ 実装済み | class=merge | `HUMAN_ESCALATED`（Human-owned固定） | 同上 |
| priority 4 | reject-reject/reject-approve | ✅ 実装済み | W check不一致（A設計妥当性NG） | `BLOCKED` | 同上 |
| priority 5a | severity=critical/major | ✅ 実装済み | 不一致理由の安全側既定含む分類 | `HUMAN_ESCALATED` | 同上 |
| priority 5b | model_c/d欠落 | ✅ 実装済み | C/D裁定に必要な入力欠落 | `HUMAN_ESCALATED`（安全側） | 同上 |
| priority 6 | approve-approve合意 | ✅ 実装済み | W check双方approve | `AUTO_APPROVED` | 同上 |
| discovery A1〜A4 | opt-inラベル/HOリスク語/大規模語/未解決依存 | ✅ 実装済み | §該当語検出 | `candidate=False` | `discovery.py` |
| discovery B | candidateゼロ終端 | ✅ 実装済み（正常終了） | 全issue除外 | exit 0・候補なしと明示 | 同上 |
| discovery C | 入力エラー fail-fast | ✅ 実装済み | issues.json不正 | exit 1 | 同上 |
| loop-safety Gate 1-5 | 非停止プロンプト事前ゲート | ⚠️ 仕様のみ（運用ゲート） | 「完璧になるまで」等の非停止指示 | flow不進入・再形成提案 | `loop-safety-gates.md` |
| **対応ラウンド上限（3）** | 指摘対応ループの打ち切り | ⚠️ **仕様のみ・コード強制なし** | 対応ラウンドが3超過 | `HUMAN_ESCALATED`（仕様上） | `00_concept.md` / `adaptive-production-loop.md` |
| **escalate予算（§7）** | human昇格件数の上限 | ⚠️ **仕様のみ・上限値TBD・コード強制なし** | 昇格件数が予算超過 | サーキットブレーカー（仕様上） | `arbiter-policy.md` §7 |
| **CB-1 事後reject** | 即時停止+巻き戻し | ⚠️ **仕様のみ・コード実装ゼロ** | AUTO_APPROVED済みを人間が事後reject | policy_suspended・巻き戻し・review queue昇格（仕様上） | `decision-table.md` §6 |
| **CB-2 policy自動失効** | 連続N回reject | ⚠️ **仕様のみ・コード実装ゼロ** | 同一policyでN回（既定3）連続reject | policy_expired・全件escalate（仕様上） | 同上 |
| **CB-3 escalate予算超過** | 全停止 | ⚠️ **仕様のみ・コード実装ゼロ** | 時間窓内の予算超過 | circuit_open（仕様上） | 同上 |
| 事後revert自動化 | merge後の自動revert+監視 | ❌ 未設計 | — | — | `hotl-merge-entry-criteria.md` 条件2 |

**読み方**: `round_index` は現状 `metrics.py` の**集計専用**（first-pass rate 等）であり、実行を打ち切る
比較ロジック（3超過で拒否する分岐）はコード上どこにも存在しない（`arbiter.py` grep 済み・確認済み）。
同様に escalate 予算の具体的上限値も TBD のまま、CB-1〜3 のフラグ（`policy_suspended`/`policy_expired`/
`circuit_open`）を読み書きするコードも存在しない。**このセッションで実装した priority 0〜1.9 の
機械チェックと、CB-1〜3・round上限・escalate予算という「仕様はあるが未実装」の集合は明確に別カテゴリ**
であり、EPIC #822 の健全性主張（`design-hotl-boundary.md`）はこの区別を保つ必要がある。

---

## 2. AUTO_APPROVED 事後reject時の巻き戻し手順（AC-9 → ai-loop 翻訳）

### 2.1 前提の違い（まず明確にすること）

| 観点 | working-context.md AC-9 | ai-loop（本書の対象） |
| --- | --- | --- |
| 対象モデル | in-the-loop・C-3 の**一時的非同期降格**が reject された場合の後始末 | on-the-loop・priority 6（W check合意）または C/D裁定合意による **exec前ゲートのスキップ**（C-3'相当）が事後rejectされた場合 |
| 単位 | 1 PBI = 1 ブランチ/PR | 1 `target_sha`（コミット）単位の decision record。record 自体は PR/ブランチを持たない |
| merge の扱い | AC-9 step2「PR close」を含む | **class=merge は priority 3 で常時 human escalate 固定**（変更なし）。AUTO_APPROVED 自体は merge を許可しない。実際に merge 済みなら、それは別途通常の C-4 を経ている |
| 監査ログの置き場 | `docs/working/<child-context>/decision-log.jsonl` | `docs/working/ai-loop-runs/*.json`（record）+ `run-NNN-loopspec.md`。同型の一元ログは現状**存在しない**（§2.3 で新設提案） |

**帰結**: 「AUTO_APPROVED された変更を人間が事後reject する」は必ず「exec前承認をスキップされた実装が
間違っていた」ケースを指す。すでに merge 済みの変更を覆したい場合は、それは AC-9 の話ではなく
**通常の revert PR + 通常の C-4** で扱う（新しい仕組みは不要。responsibility-classes.md の merge固定を
そのまま適用するだけ）。

### 2.2 ステップ翻訳（Step 0 は ai-loop 固有の追加前置ステップ）

#### Step 0（追加・AC-9にはない）: 対象特定と意味論確認

- **入力**: reject対象の record ファイル（`docs/working/ai-loop-runs/*.json`）または `run_id`
- **実行内容**: `git show <target_sha>` で対象コミットの実在を確認する
- **既知の制約（fail-closedで扱うべき理由）**:
  - `target_sha` が「計画時 base commit」か「実装後 commit」かは record 単体では判別できない
    （issue #782 P3、未解消のまま）
  - **実測でファイル名の SHA と record 中身の `target_sha` が食い違う事例が2件確認済み**
    （`run016-r1.json` はファイル名 `97e1ed8` だが中身は `10d903c`、`run018-r1.json` も同様）。
    **ファイル名だけで対象を特定してはならない**。必ず JSON 中身の `target_sha` を正とし、
    対応する `run-NNN-loopspec.md` の記述と突合してから**人間が最終確認**する
  - `run_id` / `round_index` は #815（Slice D）以降に追加された任意フィールドであり、
    **Run-001〜021（2026-07-02〜07-08 実施分）の既存25recordには一切存在しない**。
    これらのレコードでは Step 0〜Step 5 の run単位の紐付けを機械的に行えず、
    `timestamp` の前後関係と `run-NNN-loopspec.md` の自由記述に頼らざるを得ない
- **機械化可否**: **半自動**（実在確認は機械化可能／意味論の確定と最終対象特定は人間確認必須）

#### Step 1（AC-9 step1相当）: 実装ブランチの破棄または revert

- **ai-loop文脈**: `target_sha`（Step 0 で確定済み）が指すコミットに対応するローカル/リモートブランチを
  破棄する、または未来のコミットが上に乗っている場合は `git revert` する
- **merge適合性の確認**: この操作は「ブランチの破棄」または「revertコミットの作成」であり、
  それ自体は merge 判断ではないため responsibility-classes.md には抵触しない
- **機械化可否**: **機械的に実行可能**（通常の git 操作。ただしリモートへの force-push 等
  破壊的操作は working-context.md「Bash 連結コマンド時の error guard」の三点照合に従う）

#### Step 2（AC-9 step2相当）: 生成済みPRのclose（該当する場合のみ）

- **ai-loop文脈**: 対象PRが**未merge**なら close する。**既にmerge済み**（＝別途正規のC-4を経ている）なら
  close の対象ではなく、revert PR の下書き作成に切り替える（§2.1 の帰結どおり、この revert PR の
  merge は通常の C-4 を経る。特別扱いしない）
- **機械化可否**: PR close/ revert PR 下書き作成のコマンド実行自体は機械化可能だが、
  「reject判断 → close実行」を無承認で連鎖させると事実上の自己完結になりうるため、
  **人間のreject意思決定を経てからAIが実行する**（人間は意思決定のみを担い、事務的な実行は
  AIに委ねてよいという既存運用知見と整合）。revert PR の **merge実行は
  常にHuman-owned**（新規/既存を問わず変更なし）

#### Step 3（AC-9 step3相当）: 当該runの成果物のinvalidationマーク

- **ai-loop文脈**: 対象は `docs/working/ai-loop-runs/*.json`（record）と `run-NNN-loopspec.md`。
  これらは append-only の監査証跡であるため、**既存recordを書き換えず**、新規ファイルへの追記で
  invalidation を表現する
- **提案**: 新設 `docs/working/ai-loop-runs/rollback-log.jsonl`（既存の
  `docs/working/_audit/skip-decision-log.jsonl` と同型の append-only パターンを踏襲）

  ```jsonc
  {"ts":"<ISO8601>","event":"POST_HOC_REJECT","run_id":"run-XXX|null","round_index":N,"target_sha":"<確定済みSHA>","original_decision":"AUTO_APPROVED","rollback_action":"branch_discarded|reverted|pr_closed|revert_pr_drafted","acknowledged_by":"<human>","acknowledged_at":"<ISO8601|null>"}
  ```

- **機械化可否**: **機械的に実行可能**（追記スクリプト化できる。記録内容は人間のreject判断という
  「事実」の転記であり、AC-9 step4 と同じ思想）

#### Step 4（AC-9 step4相当）: 監査ログへの記録

- **ai-loop文脈**: 上記 `rollback-log.jsonl` がそのまま一元ログとして機能する（ai-loopには
  TASK単位の `decision-log.jsonl` に相当する概念が現状ないため、run横断の一元ログとして新設する）
- CB-1 の step1（`policy_suspended=true` の宣言）・step3（human review queueへの昇格）も
  同ログへの追記で表現する。**ただし `policy_suspended` フラグを次回 arbiter 呼び出し時に
  実際に読んで拒否する実装は存在しない**（§1参照）。本書は記録までに留め、
  「記録された事実を人間または次回呼び出し側が確認して当該policyの使用を手動で控える」
  という**運用でのカバー**を明記する（実装提案はしない）
- **機械化可否**: **機械的に実行可能**（ログ追記のみ。実効的な自動停止は別スコープ）

#### Step 5（AC-9 step5相当・最難関）: 派生成果物（後続が参照したもの）の追従是正

- **ai-loop文脈**: 後続runが reject 対象の `target_sha` を祖先に持つコミットを前提に
  実行されていないかを `git merge-base --is-ancestor <reject対象sha> <後続runのtarget_sha>` で
  機械チェックできる（git オブジェクトが到達可能な間のみ）
- **既知の限界（過大な自動化をしない理由）**:
  - provenance record には `changed_files` が刻まれない（arbiter.py の `build_provenance()` に
    このキーは存在しない）。そのため「ファイル単位の依存」までは機械検出できず、
    **コミット祖先関係の検出に留まる**
  - `run_id`/`round_index` を欠く旧25record（Run-001〜021）は run 横断の紐付けが機械的にできず、
    連鎖検出の対象外になりうる（Step 0 と同じ制約）
  - 7桁短縮SHAの衝突可能性はゼロではない（現状は問題ないが保証がない）
- **機械化可否**: **半自動**（祖先関係の検出は機械化可能。しかし「検出された依存runを実際に無効と
  みなすか」の最終判断は**必ず人間が行う**。全自動での連鎖無効化はしない。検出結果を
  `rollback-log.jsonl` に `event:"DEPENDENT_RUN_DETECTED"` として提示し、人間の確認後に
  `event:"DEPENDENT_RUN_INVALIDATED"` を追記する2段階とする）

### 2.3 CB-1（decision-table.md §6）との対応関係

| CB-1 のステップ | 対応する本書ステップ | 現状の機械化状態 |
| --- | --- | --- |
| 1. policy_suspended=true | Step 4（ログ記録のみ） | 記録は機械化可・実効的な次回拒否は未実装 |
| 2. 可能な範囲で巻き戻し（不可逆操作除く） | Step 1・Step 2 | 機械的に実行可能（実行判断は人間のreject後） |
| 3. human review キューへ昇格 | Step 3・Step 4（rollback-log.jsonl） | 機械的に実行可能 |
| 4. 人間が原因分析・policy再承認するまで停止 | — | **Human-owned固定**（第0の承認境界・arbiter-policy.md §6、変更なし） |

---

## 3. 機械化可否 総括表

| ステップ | 内容 | 機械化可否 | 残る人手作業 |
| --- | --- | --- | --- |
| Step 0 | 対象特定（target_sha実在確認） | 半自動 | 意味論確定（計画時/実装後）・ファイル名不一致時の裁定 |
| Step 1 | ブランチ破棄/revert | **機械的に実行可能** | なし（破壊的操作は三点照合を経る） |
| Step 2 | PR close / revert PR下書き | **機械的に実行可能**（実行はreject承認後） | reject の意思決定・revert PRのmerge判断 |
| Step 3 | run成果物のinvalidationマーク | **機械的に実行可能** | なし（append-only追記） |
| Step 4 | 監査ログ記録 | **機械的に実行可能** | policy再承認の実施そのもの（Human-owned） |
| Step 5 | 派生成果物の連鎖是正 | 半自動 | 検出結果を無効とみなす最終判断 |
| CB-1 step1実効化 | 次回呼び出し時のpolicy_suspended参照 | **未実装（本書はコード化しない）** | 全て（人間が手動で使用を控える運用） |
| round上限3/escalate予算 | 実行回数・昇格件数の強制打ち切り | **未実装（本書はコード化しない）** | 全て（仕様のみ） |

---

## 4. 本設計が解消しないギャップ（明示的に残す・EPIC #822 の別項目候補）

- `target_sha` の計画時/実装後の意味論不確定（issue #782 P3）— 未解消。Step 0 の人間確認で当面カバー
- CB-1 `policy_suspended` の実効的な次回呼び出し時チェック（コード実装）— 未着手。別PBI候補
- round上限3・escalate予算（TBD値）の機械的強制 — 未着手。別PBI候補（本書スコープ外）
- 事後revert自動化 + post-merge監視（hotl-merge-entry-criteria.md 条件2）— ❌未設計のまま。
  本書の Step 1・Step 2 は「下書き作成支援」までであり、条件2の充足（自動revert+監視接続）を主張しない
- provenance への `changed_files` 追加（Step 5 のファイル単位検出精度向上）— 別途要検討。
  追加する場合は decision-table.md §5 の additive 拡張として提案し、既存フィールドは変更しない

---

## 5. 制約（既存正本との整合の再確認）

- **merge=Human-owned固定は一切変更しない**（responsibility-classes.md）
- `docs/working/ai-loop-runs/*.json`（既存record）は書き換えない。追記専用の `rollback-log.jsonl` を
  新設する形で invalidation を表現する（append-only原則・skip-decision-log.jsonl と同型）
- 「完全自動巻き戻し」「AIが判断してrevertをmergeする」等の過大主張はしない
- 変更提案は (a) `rollback-log.jsonl` のスキーマ提案（新設）、(b) `decision-table.md` §6 CB-1 への
  「巻き戻し手順の詳細は本書を参照」という相互参照リンク追加、の2点に留める。**実装コードは書かない**

---

## 6. 関連ドキュメント

- [`docs/workflows/ai-loop/decision-table.md`](../../workflows/ai-loop/decision-table.md) §5 provenance / §6 サーキットブレーカー
- [`docs/workflows/ai-loop/lite-criteria.md`](../../workflows/ai-loop/lite-criteria.md) §2 可逆性要件
- [`docs/workflows/ai-loop/loop-safety-gates.md`](../../workflows/ai-loop/loop-safety-gates.md) Gate 3（budget limit・round上限/escalate予算の参照のみ）
- [`docs/workflows/ai-loop/00_concept.md`](../../workflows/ai-loop/00_concept.md) 収束ルール（対応ラウンド上限3）
- [`docs/workflows/ai-loop/adaptive-production-loop.md`](../../workflows/ai-loop/adaptive-production-loop.md) terminal state表
- [`docs/ai/ai-loop/arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) §6 第0の承認境界 / §7 escalate予算 / §8 安全装置
- [`docs/ai/ai-loop/hotl-merge-entry-criteria.md`](../../ai/ai-loop/hotl-merge-entry-criteria.md) 条件2（事後revert自動化・未設計）
- [`docs/ai/ai-loop/asset-inventory.md`](../../ai/ai-loop/asset-inventory.md) — working-context.md C-3ロジックの not-uses 分類（AC-9 が in-the-loop 前提であることの根拠）
- [`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md) AC-9（巻き戻し5ステップの原型）
- [`.claude/rules/responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) merge=Human-owned固定
- 既存 record 実測: `docs/working/ai-loop-runs/`（25件）、監査ログ書式参考: `docs/working/_audit/skip-decision-log.jsonl`
