---
task_id: TASK-1044
artifact_type: review-self
schema_version: 1
status: draft
verdict: PASS
created_by: claude
---

# TASK-1044 セルフレビュー結果（C-1 / 17 項目）

> レビュー日: 2026-08-12
> 対象 base: `48f6971`（origin/main）/ branch: `docs/1044-plan`
> 判定: **PASS**（critical=0 / major=0 / minor=2 / WARN 2）

## Plan チェック（7 項目）

| # | 項目 | 判定 | 根拠 |
|---|---|---|---|
| C1-PLAN-01 | 受入基準網羅性 | PASS | AC-1〜7 が plan の Work Breakdown（S1〜S8）と test-cases のマッピング表に全件対応 |
| C1-PLAN-02 | Unknowns 処理 | PASS | Q-1（F-3 の fail-closed 方式）を C-3 裁定事項として分離、推奨案 + 代替案 + トレードオフを明記。Q-2 は exec 時判断で AC 影響なしを明示 |
| C1-PLAN-03 | スコープ制御 | PASS | In/Out を pbi-input に明記。層 B/C・run-tests.sh・zsh runner サポートを Out に固定。F-3 の In 判断は根拠（0921 見送り理由の非該当）つき |
| C1-PLAN-04 | テスト戦略 | PASS | TDD red（EV-3）→ 実装 → green → 変異注入 kill（call site 破壊 / #874 教訓準拠）→ 4 シェルマトリクスの層構造。TASK-0921 の R-015a/R-021/R-024 制約を Constraints に継承 |
| C1-PLAN-05 | Work Breakdown Output | PASS | S1〜S8 全 Step に Output / Owner / Risk / 🚩 を記載。S3/S4 の原子性（同一 commit）を明示 |
| C1-PLAN-06 | 依存関係 | PASS | S1→…→S8 の直列 + S3/S4 原子性。todo の T-03 以降は H-01（C-3）ゲート後と明記 |
| C1-PLAN-07 | 動作検証自動化 | PASS | TC-30〜36 は ta-61 内の自動 TC。マトリクス/変異は evidence ログ必須（EV-1〜4） |

## ToDo チェック（5 項目）

| # | 項目 | 判定 | 根拠 |
|---|---|---|---|
| C1-TODO-01 | タスク粒度 | PASS | T-01〜T-10、各 1 セッション内で完結する粒度 |
| C1-TODO-02 | depends_on 設定 | PASS | 全タスクに depends_on 記載。C-3 ゲート依存も ⚠️ 節で明示 |
| C1-TODO-03 | チェックポイント設定 | PASS | red / 実装 / green / 変異の要所 6 箇所に 🚩 |
| C1-TODO-04 | Iron Law 遵守 | PASS | main 直接変更なし・approvals/HO パス不接触・merge/publish は Human-owned のまま |
| C1-TODO-05 | 完了条件 + rollback | PASS | high-risk のため実装タスク（T-03〜06）全件に rollback 記載。読取タスクは「不要」明記 |

## TestCases チェック（3 項目）

| # | 項目 | 判定 | 根拠 |
|---|---|---|---|
| C1-TC-01 | 受入基準との紐付き | PASS | AC→TC マッピング表あり。AC-1〜7 に対応漏れなし |
| C1-TC-02 | Edge case 網羅 | PASS | basename のみの `$0` / runner 起動 2 形態 / sandbox fixture / 部分汚染（既存 TC-01b/c）を列挙 |
| C1-TC-03 | 自動化可否 | PASS | TC-30〜36 自動。4 シェルマトリクスと変異は evidence 実測と明示区分（TA 本体は dash 固定 = CI 実体一致） |

## 補足チェック（2 項目）

| # | 項目 | 判定 | 根拠 |
|---|---|---|---|
| C1-SUP-01 | Mode 判定妥当性 | PASS | 定量（ファイル 14 / AC 7）・定性（検証基盤・複数ファイル波及）とも high-risk。HO 9 カテゴリ非該当を個別確認（tests/extras・docs/working のみ）。安全側原則と整合 |
| C1-SUP-02 | 正本・既存ルール整合 | PASS | TASK-0921 plan の複製禁止規約・R-021/R-024/R-015a/R-033 系・mode 分裂禁止（L676-678）を継承。「`$0` アンカー禁止」との非矛盾を plan 内で明示説明。承認済み plan（TASK-0921）は編集しない |

## 実測裏付け（plan 主張の一次証跡）

- 実測 1（issue 記載症状）: main `48f6971` で再現確認 — dash rc=0 / zsh rc=0 / bash rc=1 / sh rc=1
- 実測 2（拡大所見）: helper 存在 + 3 env 漏出 + 直接実行 = **4 シェルすべて rc=0**
  （SKIP 経路 rc=3 消失・summary 未出力を確認）→ 修正位置を mode 判定本体とする根拠
- 述語出現数: bootstrap 12（層 A grep 実測）+ ta-61 本体 1 + ta-61 fixture 複製 1 +
  helper `_pg_extra_resolve_mode` 1 = **15 出現**（AC-4 の分母を実測で確定）

## Minor Findings（2 件）

1. TC-32 の期待値（exit 4）は Q-1 裁定に依存する。裁定が代替案になった場合は
   test-cases の期待値を確定反映してから c3.json 発行（EH-3 順序と整合）。
2. zsh runner 非サポートは Constraints 明記のみで機械強制しない（README 追記は Q-2）。
   ガード誤発火方向は standalone 側 = fail-safe であり実害経路にならない。

## WARN（2 件 / ブロッカーではない）

- c3.json 未発行（当然 — C-2 / C-3 はこれから。high-risk のため autonomous 不可）
- pre-fix evidence は scratchpad 実測のみ。exec S1/T-01 で `evidence/test-runs/` へ正式採取

C1-VERDICT: PASS plan=sha256:586f8a919a253f854f616282b18b2fef774bb0c73e4a04cdaa4390a2eea0f3a4

---

## 簡易 C-1 再実行（2026-08-12 / river-review F-1〜F-5 確定反映後）

> 反映元: river-review（major 1 / minor 3 / info 1・実測裏取り済み）。c3 未発行 =
> plan 編集可能期間内の確定反映。

### 反映内容の整合確認

| F | 反映 | 判定 |
|---|---|---|
| F-1（major） | helper を変数消費形へ設計変更（関数内 `$0` 非評価・未設定 = direct 既定）。DoD を「bootstrap 2 行 × 14 箇所バイト一致 + helper 分離定義」へ再定義。挙動マトリクスへ zsh 直接実行行を追加。M-2 変異の恒久的役割（zsh 問題再発検出）を明記。**帰結（harness 模擬 fixture の `_pg_extra_direct=0` 明示化）も S5/T-06/TC-36 へ展開** | PASS |
| F-2（minor） | TC-35 の「更新」→「**新設**」へ修正（plan S5 / 正本管理表 / test-cases / todo T-06） | PASS |
| F-3（minor） | AC-4 に「行頭空白を除去して比較」の正規化規約を明記 + helper を照合対象から分離定義（F-1 の変数消費形と整合） | PASS |
| F-4（minor） | 反転案棄却理由を「source 経路で runner カウンタ流用の summary + exit 0 を出し得る = suite silent truncation。exit 4 も exit する点は同じだが診断つき fail-closed」へ書き直し | PASS |
| F-5（info） | S8 に旧 handoff「14 箇所」と新分母（bootstrap 14 = fixture 複製含む / helper 別枠）の差異注記タスクを追加 | PASS |

### F-1 新設計の sandbox 4 シェル再実測（2026-08-12）

| 経路 | dash | zsh | bash | sh |
|---|---|---|---|---|
| (A) helper 存在 + 3 env 漏出 + 直接実行 | rc=3 + summary | **rc=3 + summary** | rc=3 + summary | rc=3 + summary |
| (B) helper 欠落 + 3 env 漏出 + 直接実行 | rc=1 | **rc=1** | rc=1 | rc=1 |
| (C) runner 型 source（sh 系） | 非 exit・counters 維持 | —（runner は sh 前提） | 非 exit | 非 exit |
| (D) 清浄 env + 直接実行 | rc=3 | rc=3 | rc=3 | rc=3 |

全経路で期待どおり（関数内評価形で zsh のみ rc=0 だった F-1 経路が是正）。

### 判定

- Plan 7 / ToDo 5 / TestCases 3 / 補足 2 の全 17 項目: 反映後も PASS 維持
  （C1-PLAN-01: AC-4 の再定義は TC-35 と双方向に更新済み / C1-SUP-02: 「述語常に同一」
  制約を「確定値の消費 + 残り 3 条件同一」へ首尾一貫して書き換え、plan 内矛盾なし）
- 旧「15 出現」表記の残存: plan / pbi-input / test-cases / todo / INDEX で 0 件を grep 確認
  （本ファイルの初回 C-1 記録内の言及は履歴として保持）
- Minor 1（TC-32 の Q-1 依存）/ Minor 2（zsh runner 非強制）: 不変

C1-VERDICT-2: PASS plan=sha256:64337b7f45dbb069c0f91bb7706cff661a6c521ca00d517511bc9e04cadc025f

---

## 簡易 C-1 再実行 #2（2026-08-12 / C-2 指摘 R-001〜R-013 の 1 回確定反映後）

> 反映元: **C-2 外部レビュー**（`review-external.md` / 2 レーンとも REJECT・
> 統合 major 7 / minor 5 / info 1）。plan パッケージは PR #1049 で main へマージ済み
> （`6089e23`）だが C-2 未実施だったため、branch `docs/1044-c2-reflect` で追補実施。
> **`approvals/c3.json` 未発行** = plan 編集可能期間内の確定反映（EH-3 mismatch なし）。

### 反映内容の整合確認（R-001〜R-013 全 13 件）

| R | severity | 反映 | 判定 |
|---|---|---|---|
| R-001 | major | 「帰結」節を全面書き換え — 空振り 4 本の実測表 / fixture 更新規約 3 点（**standalone 期待の `tc01b.sh` にも `_pg_extra_direct=0`**）/ **AC-8 新設**（未設定 fixture 0 件の静的検査）/ **変異 M-4 追加**（3 env → 1 条件退行で TC-01b/01c kill）/ **TC-37 新設** / test-cases エッジケース「不変」記述の**訂正** | PASS |
| R-002 | major | 更新対象 fixture を **4 本完全列挙**（`tc01.sh` `:383` / `tc01b.sh` `:410` / `tc21.sh` `:582` / `tc26-runner.sh` `:631`）+ 導出根拠（`grep -n 'PG_HARNESS_SOURCED=1'`）を plan 帰結節・TC-36・T-06 へ展開。**AC-4 の照合網が fixture を含まない**ことを明記 | PASS |
| R-003 | major | 正本管理表に **evidence 継承行**を追加し **(b) superseded 宣言を採用**（(a) 18 本再走は不採用・理由明記）+ **AC-9 新設** + **TC-38 新設** + **T-11 新設**（TASK-0921 handoff への追記タスク） | PASS |
| R-004 | major | AC-2 を **AC-2a / 2b / 2c / 2d** へ分割（rc 契約 / summary 書式 / **7 env unset の実測** / カウンタ初期化）+ TC-31 の期待出力を 4 点へ拡張 + Testing Strategy に AC-2c の実測手順 | PASS |
| R-005 | major | AC-4 を **bootstrap marker 由来の動的導出**へ書き換え（**絶対件数を契約値にしない**・14 は実測値）+ plan DoD / TC-35 / S5 / T-06 を同期。先例 `ta-26` TC-33 を明記 | PASS |
| R-006 | major | pbi-input Out of scope に **「残存エクスポージャ」節を新設**（5 本を表で明示列挙 + 各々 2 env AND）+ 正本管理表 + S8 / T-10 に handoff 必須行 | PASS |
| R-007 | major | Constraints に **R-024 の明示 carve-out** を追記（init 前 finalize に限定）+ AC-6 に carve-out 併記 + **Q-1 を 2 段の設問へ拡張**（方式 / carve-out 可否）+ H-01 に反映 | PASS |
| R-008 | minor | pbi-input Notes に新漏出面の明記 + **TC-30b 新設**（`_pg_extra_direct=0` を export しても standalone = **無条件代入の pin**）+ Risks 行追加 | PASS |
| R-009 | minor | EV-1 / EV-2 に **シェル実体・測定ホストの記録を必須化**（`ls -l /bin/sh` / `$BASH_VERSION` / `dash --version` / `zsh --version` / `uname -a`）+ S8 / T-09 / Testing Strategy へ展開 | PASS |
| R-010 | minor | Mode 節に **「working context 成果物は分母に含めない」**を明記（例外 = 他 PBI 完了資産への追記 = `TASK-0921/handoff.md`） | PASS |
| R-011 | minor | F-3 節に **挿入位置 = `_PG_EXTRA_ORIGINAL_RC=$?` の直後**を固定（前置は `$?` を潰し TC-06 が壊れる旨つき）+ T-04 へ展開 | PASS |
| R-012 | minor | **Q-2 を「README 規約 8 へ追記する」で決着** + Files 節へ `tests/extras/README.md` を追加 + S5 / T-06 / エッジケースへ展開（AC-8 の静的 TC で担保） | PASS |
| R-013 | info | AC-5(b) を **M-1 / M-2 / M-3 / M-4 の列挙形**へ + S7 / T-08 / EV-4 を同期 | PASS |

### 17 項目の再判定

| 区分 | 判定 | 根拠 |
|---|---|---|
| C1-PLAN-01（受入基準網羅性） | PASS | AC↔TC マッピングを再構築し **orphan 0 件**を確認 — AC-1→TC-30 / AC-2a〜2d→TC-31 (1)〜(4) / AC-3→TC-33・34 / AC-4→TC-35 / AC-5→EV-3・EV-4 / AC-6→TC-32 / AC-7→TC-36 / AC-8→TC-37・EV-4(M-4) / AC-9→TC-38。TC-30b のみ AC 非対応だが「R-008 の pin」として表に明示 |
| C1-PLAN-02（Unknowns 処理） | PASS | Q-1 を 2 段設問へ拡張・Q-2 を決着・**Q-3 を新設**（AC 分割に伴う mode 件数の読み替えを AI 解釈のまま通さず C-3 追認へ回した） |
| C1-PLAN-03（スコープ制御） | PASS | **残存エクスポージャ節**で「塞ぐ範囲 = bootstrap 系 13 本 + helper / 未塞ぎ = 5 本」を明示。Files 節に `README.md` と `TASK-0921/handoff.md` を追加し、scope 拡大分を可視化 |
| C1-PLAN-04（テスト戦略） | PASS | 空振り対策が **fixture 完全列挙（規約）+ AC-8（静的）+ M-4（変異）** の 3 層になり、単層依存が解消 |
| C1-PLAN-05（WBS Output） | PASS | S5 / S7 / S8 の Output を更新。S8 に 🚩 を追加（handoff 追記を伴うため） |
| C1-PLAN-06（依存関係） | PASS | **T-06 fixture 更新 ↔ T-08 (d) M-4 の対**、T-11 は T-08 後 を ⚠️ 節へ明記 |
| C1-PLAN-07（動作検証自動化） | PASS | TC-30b / TC-37 は自動。TC-38 のみ手動（V-1 チェックリスト）と**明示区分**した（`tests/` から `docs/working/` を assert する結合を避けるため） |
| C1-TODO-01〜05 | PASS | T-11 追加で 11 タスク。T-11 の rollback は「追記行の revert（既存行は編集しない）」と明記。他 PBI 資産への追記であるため append-only 規律を明示 |
| C1-TC-01〜03 | PASS | AC↔TC 双方向更新済。エッジケースは「不変」の誤りを訂正し、`_pg_extra_direct` 漏出 / 同一シェル連続 source の 2 件を追加 |
| C1-SUP-01（Mode 妥当性） | **WARN** | 変更ファイル数 15（README 追加）で high-risk 帯を維持するが、**AC 行数 12 は定量表で critical 帯（11+）に触れる**。plan は実質 9 と読み替えて high-risk を維持している。安全側原則（判定不能なら引き上げ）に照らすと **AI 単独で確定してよい判断ではない**ため **Q-3 として C-3 追認へ回した**。HO 9 カテゴリは引き続き非該当（`tests/extras/` / `docs/working/` のみ） |
| C1-SUP-02（正本・既存ルール整合） | PASS | R-024 の carve-out を Constraints 側にも明記し **plan 内の自己矛盾を解消**（従来は Constraints 無条件 vs AC-6 無条件で衝突）。TASK-0921 は **handoff への追記のみ**で plan.md は不変（承認済み歴史文書）。C-2 反映順序は `working-context.md`（集約 → 1 回確定反映 → 簡易 C-1 → c3.json）に準拠 |

### 判定

- **PASS（WARN 1 / C1-SUP-01）**。WARN は Q-3 として C-3 裁定へ委譲済みでブロッカーではない
- 「14 箇所」を**契約値**として書いた箇所の残存: `grep -n '14 箇所'` で全件を再点検し、
  DoD / 述語見出し / 正本管理表 / S4 / T-05 / pbi-input In-scope の**計 6 箇所を
  「marker 由来の照合対象すべて（実測母数 14・契約値ではない）」へ書き換え済み**。
  残存する `14` の言及は「実測母数」「旧 handoff との分母差の注記」のみ = 意図どおり
- AC 行数の表記ゆれ（11 / 12）: plan Mode 節・Q-3・todo H-01・current-state を
  **12 行（実質要件 9）**へ統一済み
- Minor 1（TC-32 の Q-1 依存）: 不変。Minor 2（zsh runner 非強制）: 不変

C1-VERDICT-3: PASS plan=sha256:9c93cbf9268cfe4f6665b2b5a5baf47db91ac6482a64dad925c427608982e920

---

## 簡易 C-1 再実行 #3（2026-08-12 / C-2 Round 2 指摘 R-014〜R-020 の 1 回確定反映後）

> 反映元: **C-2 Round 2**（`review-external.md`「C-2 Round 2」節 / 2 レーンとも REJECT・
> 統合 major 2 / minor 4 / info 1）。**Round 1 の major 7 件はすべて実質解消**と両レーンが確認。
> `approvals/c3.json` は依然未発行 = plan 編集可能期間内の確定反映（EH-3 mismatch なし）。

### 反映内容の整合確認（R-014〜R-020 全 7 件）

| R | severity | 反映 | 判定 |
|---|---|---|---|
| R-014 | major | plan「帰結」規約 3 の見出しを **「挙動が変わる fixture（部分集合）」**へ改題 + **規約 3-bis**（走査母数 = `. "$T61_HELPER"` 由来で動的導出・本 PR 実測 12 本・件数は契約値にしない）+ **規約 3-ter**（`tc26` は TC-37 が検査する `tc26-file1.sh` 側へ置く）+ S5 / Testing Strategy / TC-36 / TC-37 / T-06 / AC-8 を同期 | PASS |
| R-015 | major | Mode 節の分母定義を **「他 PBI の完了資産も規模軸に算入しない = 15 で確定・例外規定を作らない」**へ書き切り（自己矛盾解消）+ **Q-3 を 2 軸へ拡張**（AC 行数 12 / 分母定義 15 か 16 か）+ 最終判定を **「high-risk（暫定 / Q-3 で確定）」**へ + todo H-01 に Q-3 (1)(2) を展開 | PASS |
| R-016 | minor | **AC-9 に 1 句追加** — 「本 PBI handoff に『未塞ぎ = 5 本』の行が存在すること」+ **TC-38 を確認対象 2 点**へ + T-10 (2) に「AC-9 後段 / TC-38 (2) の検証対象」を明記 | PASS |
| R-017 | minor | 正本管理表の evidence 継承行を **「14 本 superseded / 4 本（M-01・M-02・M-03・M-16）は新 HEAD で再走」**へ精密化 + **AC-9 の文言を同期** + **`TASK-0921/handoff.md` L43 / L119 への参照付加**を Files / S8 / T-11 へ + **T-11b（旧 4 本再走）を新設** | PASS |
| R-018 | minor | M-4 の期待値を **「TC-01c が kill（rc=65）/ TC-01b は原理的にヒットしない」**へ訂正 + **M-4b を新設**（`PG_HARNESS_SOURCED` 条件を落とす対称変異で TC-01b を kill）+ AC-5 / S7 / 帰結節 5 / EV-4 / T-08 / Testing Strategy を同期 | PASS |
| R-019 | minor | Q-3 に **安全側の向きの両論**（整合レーン = 既定 critical が規定どおりの向き・ただし C-3 明示裁定なら穴ではない / 設計レーン = high-risk 維持が substance）を表で併記 + 最終判定を「暫定」と明示 | PASS |
| R-020 | info | T-06 と Files 節に **「追記のみ・既存文言を編集しない」**を明記（`ta-26` TC-30 が README の 4 語を静的 grep するため） | PASS |

### 17 項目の再判定

| 区分 | 判定 | 根拠 |
|---|---|---|
| C1-PLAN-01（受入基準網羅性） | PASS | AC↔TC マッピングを再点検し **orphan 0 件**を維持。AC-9 の追加要件（本 PBI handoff の 5 本行）は TC-38 (2) に対応づけ済み。AC-5 の M-4b 追加は EV-4 に反映 |
| C1-PLAN-02（Unknowns 処理） | PASS | **Q-3 を 2 軸へ拡張**し、「critical 帯に触れる定量軸のうち AI が独自に下げたものが 1 つも残っていない」状態にした。安全側の向きの両論も併記済み |
| C1-PLAN-03（スコープ制御） | PASS | scope 不変（`tests/extras/` + `docs/working/`）。T-11b は既存 evidence の再走であり新規ファイル追加を伴わない |
| C1-PLAN-04（テスト戦略） | PASS | 走査母数の動的導出化で **AC-8 が手書きリストへ退化するリスクを解消**。M-4 / M-4b の対称化で **3 env AND の 3 条件すべてに検出力**が付いた |
| C1-PLAN-05（WBS Output） | PASS | S8 の Output に (4) 本 PBI handoff の 5 本行を追加。T-11b の Output = `mutation-0921-rerun-*.log` |
| C1-PLAN-06（依存関係） | PASS | **T-11b（T-08 後）→ T-11** の順序を ⚠️ 節へ明記。T-06 ↔ T-08 (d)(e) の対も更新 |
| C1-PLAN-07（動作検証自動化） | PASS | TC-37 の母数は動的導出（自動）。TC-38 は引き続き手動（V-1 チェックリスト）で確認対象が 2 点へ |
| C1-TODO-01〜05 | PASS | T-11b 追加で 12 タスク。T-11b の rollback は「変異は sandbox 複製上でのみ実施し本体に触れない」 |
| C1-TC-01〜03 | PASS | TC-36 の表を `tc26-file1.sh` 基準へ訂正し、TC-37 の母数注記と整合。EV-4 に M-4b を追加 |
| C1-SUP-01（Mode 妥当性） | **WARN** | 分母定義を 15 で書き切り自己矛盾は解消したが、**critical 帯に触れる 2 軸（AC 行数 12 / 分母定義）はいずれも AI の解釈**であるため **Q-3 (1)(2) として C-3 追認へ回した**（前回 WARN の継続・範囲を 1 軸から 2 軸へ拡大）。最終判定は **high-risk（暫定）**。HO 9 カテゴリは引き続き非該当 |
| C1-SUP-02（正本・既存ルール整合） | PASS | R-014 の是正で **AC-4（件数を契約値にしない）と AC-8 の規約が一致**し、plan 内の自己矛盾がもう 1 つ解消。R-020 で `ta-26` TC-30 の既存契約との衝突を予防。追記専用規約（review-external Round 1 / TASK-0921 handoff）を遵守 |

### 判定

- **PASS（WARN 1 / C1-SUP-01）**。WARN は Q-3 (1)(2) として C-3 裁定へ委譲済みでブロッカーではない
- 「4 本」を **TC-37 の母数**として書いた箇所の残存: plan 規約 3 / S5 / test-cases TC-36 /
  todo T-06 を再点検し、**すべて「挙動が変わる部分集合」と明示するか 12 本の動的導出へ
  書き換え済み**
- Round 1 の R-001〜R-013 記述および TASK-0921 の plan.md は**不変**
- Minor 1（TC-32 の Q-1 依存）: 不変。Minor 2（zsh runner 非強制）: 不変

C1-VERDICT-4: PASS plan=sha256:cce20c06ba273a6d4297f63f47fab4e0837519f394012b5a0b3aa2a0866f0352
