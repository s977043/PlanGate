# 外部レビュー結果 — TASK-0917（pbi-input 段階）

> **追記専用**（`.claude/rules/working-context.md` §review-external.md）。既存エントリは編集・削除しない。
> 実施: 2026-07-30 / 対象: `docs/working/TASK-0917/pbi-input.md`（PR 作成前のローカルレビュー）
> 基点: main `b306b12`
> 注: 本ファイルは C-2（plan ゲート外部レビュー）ではなく **pbi-input 段階のレビュー**の記録。指摘 ID は同ルールの `R-NNN` 規約に従う。

## 実施レーン

| レーン | 担当 | 判定 |
|--------|------|------|
| 敵対的レビュー（claim-vs-actual 全数照合） | `explorer-agent` | **WARN**（critical 0 / major 3 / minor 2） |
| River Review（security + docs + adversarial） | `river-review` | **FAIL**（critical 1 / major 6 / minor 5 / info 1） |

**合計: critical 1 / major 9**。River Review が FAIL 判定を出したため、**PR 作成前に全件を反映**した。

## オーガナイザーによる裏取り（実測・critical と主要 major を全件確認）

| ID | 指摘 | 裏取りコマンド | 結果 |
|----|------|--------------|------|
| R-001 | 既存 hook（EH-9）が本 PBI の実行面を守れない | `sed -n '60,66p' scripts/hooks/check-delegation-commit-boundary.sh` / `python3 -c "json.load(...)['hooks'].keys()"` | **確認**。①L62-65 が `PLANGATE_DELEGATION_NOCOMMIT != 1` で即 `allow` → L106 に到達しない ②`.claude/settings.json` の hooks は `SessionStart` / `PostToolUse` / `Stop` の **3 本のみで PreToolUse に未配線** ③PreToolUse は Bash の command 文字列のみを見る |
| R-002 | `gh pr review --approve` が禁止列挙にない（approve は MERGE_READY の load-bearing 入力） | `grep -n "review_ok" scripts/ai-loop/delivery.py` / `grep -rn "pr review --approve" scripts/hooks/*.sh` | **確認**。L290 `review_ok = review["state"] == "approved" and review["sha"] == head`。禁止ガードは **0 件** |
| R-003 | AC-1 が正本 doc §4 と矛盾 | `grep -n "stale" docs/workflows/ai-loop/delivery-state-machine.md` | **確認**。§4 は「checks と head の SHA 不整合 → stale として **`WAITING_FOR_CHECKS`**（成功扱いにしない）」。`HUMAN_ESCALATED` ではない |
| R-005 | branch protection 側の後段防衛も承認を強制していない | `gh api repos/s977043/plangate/rulesets/14939019` / `.../branches/main/protection` | **確認**。`required_approving_review_count: 0` / `dismiss_stale_reviews_on_push: false` / `require_last_push_approval: false`。classic protection は **404 Branch not protected**。required check は `Markdown lint` 1 件のみ |
| R-007 | 「mock 前例なし」という U-1 の前提が不正確 | `grep -n "def _issue" scripts/ai-loop/test_discovery.py` | **確認**。L27 に fixture 生成関数が実在 |
| R-010 | `required_checks[]` の取得元は ruleset API（classic は使えない） | 上記 `gh api` 2 本 | **確認**。ruleset は 1 本のみ・`conditions.ref_name.include = ["~DEFAULT_BRANCH"]` |
| R-012 | `canonical_hash` の実装は今すぐ読める（U-6 は Unknown でない） | `grep -n "def canonical_hash" -A 10 scripts/ai-loop/c3_contract.py` | **確認**。L71-74 に実装（`sort_keys=True` / `separators=(",", ":")` / UTF-8 / `"sha256:"` prefix） |
| R-013 | `ta-56-delivery.sh` に「51 テスト」の stale コメント | `grep -n "51" tests/extras/ta-56-delivery.sh` | **確認**（L29） |

## 監査表（指摘 → 反映）

| ID | lane | severity | 概要 | status | notes |
|----|------|----------|------|--------|-------|
| R-001 | River | **critical** | 最重要リスク（Executor が `gh pr merge` を発行）の一次緩和として挙げた「既存 hook で block」が **3 重に不成立**（env gate / PreToolUse 未配線 / Bash 面のみで Python の `subprocess` を見ない）。かつ既存の禁止トークン走査をそのまま Executor に適用すると `gh` を呼べず In scope と両立不能、緩めると空振り | reflected | 実測裏取り表の該当行を事実へ訂正。**AC-5 を「in-process の gh 実行ラッパ + 許可サブコマンド allowlist」方式へ全面書き換え**（禁止は allowlist の補集合として自動成立させ列挙漏れを構造的に塞ぐ）。既存トークン走査は「ラッパ以外が `subprocess` を import しない」検査に用途限定 |
| R-002 | River | major | 禁止操作の列挙が `gh pr merge` のみで、**`gh pr review --approve`** / force push / branch 削除 / PR close / 非 GET api が抜けていた。approve は `MERGE_READY` の load-bearing 入力で、account pin できる主体は自 PR を approve でき **sockpuppet 承認**が成立する | reflected | merge 境界表を allowlist / 補集合の形へ再構成し全操作を列挙。Out of scope に**包括ルール**「PR の承認状態・存在・履歴を変える操作すべて」を追加 |
| R-003 | River | major | AC-1 が「不一致なら `HUMAN_ESCALATED`」を要求していたが、正本 doc §4 は `WAITING_FOR_CHECKS` と定めており **AC-7（判定規則不変）に違反**する。かつ「snapshot を拒否」する経路は `record.jsonl` に state entry を残さず **AC-6（#894 の no-progress 検知）と接続不能** | reflected | AC-1 を「正本に従う + pre-check 失敗は `escalation_flags` に理由コードを積んで `assess()` を通す（破棄・例外 exit を禁止）」へ修正 |
| R-004 | River | major | Collector の入力契約が未定義。`validate_snapshot()` の必須 13 キーのうち **GitHub API から取れるのは 5 つだけ**で、`allowed_paths`（`EXEC_RETURN` を駆動）・`findings[]`（`REVIEW_REPAIR` と `MERGE_READY` を駆動）・`dod_evaluated` 等の供給元が書かれておらず **plan が書けない** | reflected | **snapshot キー × 供給元マップ**（GitHub / git / plan-c3 / レビュー層 / ai-loop 制御層）を追加し、各キーの scope 帰属を明記。未確定分を **U-10** として明示 |
| R-005 | River | major | Executor の repair push が **人間の C-4 承認を stale のまま残す**（ruleset の `dismiss_stale_reviews_on_push: false` 実測）。承認済みコードと merge されるコードが不一致になる経路が Risks に未計上 | reflected | Risks に 1 行追加（一次緩和 = repair push 時に既存 approve の dismiss または明示通知コメントを必須発行し receipt に記録）。「後段防衛」の実測値も裏取り表へ記載 |
| R-006 | River | major | AC-7 が **定数単位**（`STATES` / `TRANSITIONS` / `PRIORITY_ORDER`）の差分ゼロしか課しておらず、`validate_snapshot()` / `assess()` 本体へ後方互換な分岐を足しても鳴らない = **Out of scope を破っても AC が通る** | reflected | AC-7 に**ファイル単位の差分ゼロ**（`git diff --stat origin/main -- delivery.py c3_contract.py c3prime_verify.py` = 0 行）を追加 |
| R-008 | River | major | In scope 5「raw check evidence 検証」に**定義も AC も Risk も無い**（正本にも「V2 候補」の一言だけ）。検証手段のない scope は exec で「やった / やってない」が判定不能 | reflected | 暫定定義（check-run の生レスポンスを同梱し `checks[]` の導出を機械照合）を与え **AC-9** を新設。あわせて「V2 送りにするか」を plan の第一論点として明記（**issue の In scope を pbi が勝手に削らない**方針で (a) 実施を既定にした） |
| R-009 | River | minor | 「issue #917 の Out of scope を継承」という見出しが不正確（#874 連携は issue では「依存 / 位置づけ」節にあり Out of scope ではない） | reflected | 見出しを「issue の 3 項目 + 本 pbi で追加した 2 項目」に変更し、該当行に注記 |
| R-010 | River | minor | U-3 / U-9 は ruleset 実測で閉じられる | reflected | 取得元（ruleset API の JSON パス・admin 権限要）と U-9（保護は default branch のみ・head ブランチの force push / 削除を止める platform ガードは無い）を解消済みとして転記 |
| R-011 | River | minor | `sync-plugin-plangate.sh` の whitelist は **L345 / L355 の 2 箇所**にあり、片方だけの追加は sync drift になる | reflected | Mode 見込みの記述を 2 箇所に具体化 |
| R-012 | 敵対 | major | U-6（`action_id` の正規化ルール）は `c3_contract.py` を読めば今すぐ解けるのに Unknown として先送りしていた | reflected | `canonical_hash` の実装（4 行）を転記して U-6 を解消。「Reconciler はこの関数を import して再利用し独自実装しない」と明記 |
| R-013 | 敵対 | minor | `ta-56-delivery.sh` L29 に「51 テスト」の stale コメントが残る（正は 57） | reflected | 再利用資産表に「plan の todo に 1 行の是正タスクを含める」旨を追記 |
| R-014 | 敵対 | major | AC-4 / AC-8 の検証基準が曖昧（「1 周通った」の目視判定 / 「明示される」だけで分類の正しさを保証しない） | reflected | AC-4 に test repository の名前確定・`tests/extras/` の固定シナリオ化・`evidence/e2e/` への証跡保存・手動実行手順を明記。AC-8 に供給主体名の明記 + モジュール境界の特定 + 分類の単体テストを要求 |
| R-015 | 敵対 | major | In scope 4（`required_checks[]` ⊇ 照合）と Out of scope（判定規則不変）/ AC-7 が衝突しうるのに In scope 側の記述が断定形だった | reflected | In scope 4 に「第一候補は Collector 側 pre-check に限定。`delivery.py` 本体へ分岐を足す案は Out of scope 改訂と AC-7 緩和が必要 → **plan 冒頭で決着**」を明記 |
| R-016 | 敵対 | minor | carve-out 表が ①② のみで ③ を欠く | reflected | 3 項目すべて記載し「本 PBI は ①② に該当・③ は変更対象外」と明示 |

## レビューが「問題なし」と確認した事項（再検証不要の記録）

- **claim-vs-actual**: 敵対レビューが 14 項目中 13 項目一致、River Review が 12 項目中 11 項目一致と判定。不一致はいずれも本監査表に計上済み（R-007 / R-016）
- **リンク健全性**: pbi が参照する **18 パスすべて実在**（MISS ゼロ）
- **issue AC の網羅性**: issue #917 の AC-1〜6 は**漏れなく** pbi に反映されている（AC-7 / AC-8 / AC-9 は pbi 独自の追加で、いずれも Out of scope の裏付け or 未定義事項の固定として整合的）
- **Mode = critical の妥当性**: ファイル数の検算（Collector / Executor / Reconciler の実装 + テスト = 6 / sync whitelist / doc / E2E シナリオ / plugin 追従 = **9〜12 本**）が pbi の「10 本超」見積りと整合。TASK-0873（接続先・critical）との一貫性も確認され「**過剰ではない**」と判定
- **U-2 / U-4 / U-5 / U-7 / U-8 は正当な plan 送り**（設計判断・外部依存の状態次第）

## 次アクション

1. ✅ 本ファイルへ R-NNN 集約
2. ✅ pbi-input への反映（critical 1 + major 9 + minor 6 の全件）
3. ⏳ PR 作成 → C-4（Human レビュー・マージ）
4. ⏳ マージ後に `PLANGATE_HOOK_TASK=TASK-0917` の専用セッションで plan 生成（**plan 冒頭の決着事項**: In scope 4 の実装層 / In scope 5 の去就 / AC-5 の allowlist 設計 / U-10 の supply chain）
