---
task_id: TASK-1197
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-11-12
issued_at_commit: 82395dbe1221c29357509cb2877c6ca8b5c08054
author: qa-reviewer
v1_release: ""
---

# TASK-1197 Handoff Package

## メタ情報

```yaml
task: TASK-1197
related_issue: https://github.com/s977043/plangate/issues/1197
author: qa-reviewer
issued_at: 2026-11-12
issued_at_commit: 82395dbe1221c29357509cb2877c6ca8b5c08054
v1_release: ""
```

> 本文の数値は `issued_at_commit`（HO 適用 commit）時点の測定値。

## 1. 要件適合確認結果

test-cases.md を全件突合した（run-tests ログの ta-119 出力、P レーン = 実 hook、R レーン = PG-PATCH 抽出）。

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-1 | PASS | TC-D01: `docs/workflows/ai-loop/rollout-policy.md` に「起動条件と no-task セッションの挙動（#1197）」節がある |
| AC-2 | PASS | TC-D02: 同節に 3 分岐（作成 / 再起動案内 + escalate / 虚偽の `gates.c1` 禁止）。意味の妥当性は C-4 で目視（grep は意味を保証しない） |
| AC-3 | PASS | TC-05 / TC-06 / TC-07a / TC-07b が P・R 両レーンで block。変異 M1 は適用前の mutation 実行で killed（killed=26 / survived=0 / equivalent=5）。適用後に mutation レーンは再実行していない |
| AC-4 | PASS | TC-D03: Bash 経路・BYPASS・消して再作成の禁止と「#1104 は open」を明記。TC-04a / TC-04b（Edit / MultiEdit）は block |

**総合**: `4/4 基準 PASS`、**V-1 総合判定 = WARN**

**WARN の理由**:

- settings タスクロック: `sh bin/plangate doctor --check-settings`（feat worktree）が **FAIL, rc=1**（`.claude/settings.json 不在（settings 未適用）`）。PASS 扱いにしない。Human が `sh scripts/apply-claude-settings.sh` を実行して再測定するまで V-1 / handoff は完了扱いにできない
- T-02（実 Claude Code の Write payload で `PLAN_CREATE_ALLOW` を確認）は未実施
- run-tests で ta-10 TC-7 が FAIL（§6）

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| #1646: legacy c3.json の plan_hash 欠落等を exec が受理する fail-open、c3.json が task_id に束縛されない（bin/plangate 既存欠陥） | major | open | Yes |
| #1647: file_path の孤立サロゲートで jq parse 失敗 → fallback で OUTSIDE_REPO_SKIP（D-11、origin/main でも同じ。TC-B6 は KNOWN-GAP 表示） | major | open | Yes |
| #1648: macOS でのテスト移植性 | minor | open | Yes |
| ta-61 は apply 後・commit 前に run-tests を流すと落ちる | minor | accepted | No |
| `scripts/ai-loop-v2/__pycache__/` が gitignore されていない | minor | open（issue 候補・未起票） | Yes |
| ta-10 TC-7 が worktree の絶対パス `/Users/` を doctor 出力に含み FAIL する | minor | open（issue 候補・未起票） | Yes |
| T-02（実 Write payload）未実施 | minor | open | No |
| 兄弟 worktree の untracked plan.md は検査しない / env 渡し（Codex）経路は許可分岐に入らない（D-3） | minor | accepted（残存脅威として hook に明記） | No |
| prunable / 削除済み worktree・別 clone の approvals は見えない（D-6、ベストエフォート） | minor | accepted（保証の主体は exec の plan_hash 拒否） | No |
| `docs/working/_reports/1197-eh3-plan-create-patch.md` の「適用状態: 未適用」が適用後も未更新 | minor | open | No |

**Critical 課題の対応**: critical は無い。

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue（あれば） |
|--------|------|----------|-----------------|
| Bash 経路のガード配線 | 本 PBI の範囲外 | High | #1104 |
| exec の legacy c3 fail-open 是正 | 保証の主体とした層の既存の穴 | High | #1646 |
| 孤立サロゲートの fallback 経路 | HO 対象の既存経路 | Medium | #1647 |
| Codex / Cursor 橋渡しの TASK 自動導出の非対称 | Out of scope | Medium | #1642 |
| TASK 文脈ありで別 TASK の plan.md を編集できる挙動 | Out of scope | Medium | #1641 |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| prunable worktree は件数を記録して skip・allow（D-6） | prunable が 1 件でもあれば block（D-1） | prune 案内どおりに実行するとトークンが見えなくなり block は保証にならない。実 repo に prunable が 7 件あり正常系が止まる。Human 裁定 |
| 相対パスは常に block（D-2） | 正規形が条件を満たせば allow | hook の解決基準と書き込み主体の cwd がずれる |
| common dir 検査を置かない（D-4） | 独立した検査 | worktree 一覧照合で別 repo のパスは拒否される |
| 等価変異 5 件を EQUIV として別枠集計（D-9） | 全変異 killed を要求 | 多重防御の検査は単独で止める入力が見つからない。EQUIV が killed になれば survived に数える |
| payload を pipe で python に渡す（D-10） | env 渡し | 約 1MB 超で E2BIG |
| 変異レーンは opt-in（D-13） | CI 既定経路に入れる | 所要約 8 分 |
| 許可分岐の入口に字句判定（D-14） | 全 Write で python 判定 | fork 増加は計画違反 |

## 5. 引き継ぎ文書

### 概要

issue #1197 の案 B として、EH-3（`scripts/hooks/check-plan-hash.sh`）の no-task 分岐に、C-3 承認トークンも履歴も無い TASK の `docs/working/TASK-<id>/plan.md` を Write で初回作成するときだけ rc=0（`PLAN_CREATE_ALLOW`）とする許可経路を追加した。既存 plan.md の改変、Edit / MultiEdit、承認トークンや履歴のある TASK、判定不能は従来どおり block。HO のため Human が 82395dbe で適用し pending flag を削除した。rollout-policy.md に起動条件・no-task 挙動・迂回禁止を明記した。

現状は verify 中。V-1 は WARN（AC 4/4 PASS だが settings タスクロック FAIL）。push・PR は未実施。`approvals/c3.json` は plan worktree（`.claude/worktrees/plan-TASK-1197/`）にのみ untracked で存在し、Human-owned の承認トークンなのでこの branch には commit していない。保管先は Human 判断。

### 触れないでほしいファイル

- `docs/working/TASK-1197/plan.md`: plan_hash 対象。1 byte でも変えると c3.json の plan_hash と不一致になる（sha256 `ff34c38b0fc78c4287fea08f3faeb12f1313d9dc293da21e5c0095a37d4f88dc`）
- `scripts/hooks/check-plan-hash.sh`: HO。AI は編集しない

### 次に手を入れるなら

- Human が settings を適用 → `doctor --check-settings` 再測定 → T-02 → V-2〜V-4 → PR
- PR は `Refs #1197` とし closing keyword を使わない
- plugin/ に差分があるためリリース時に version bump ゲート（#1257）の対象

### 参照リンク

- issue: <https://github.com/s977043/plangate/issues/1197>
- patch 文書: `docs/working/_reports/1197-eh3-plan-create-patch.md`
- status.md: `docs/working/TASK-1197/status.md`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| run-tests 全体（82395dbe、2026-11-12 07:39〜08:00、load 10〜11） | 1694 | 1693 | 1 FAIL | — |
| ta-119（P / R 両レーン、上記に内包） | 137 PASS（TC-00 系 3 + P・R 各 67）+ KNOWN-GAP 各 1 | 全 PASS | 0 | — |
| 適用前 cases | 67 | 67 | 0 | — |
| 適用前 mutation | 31 | killed 26 | survived 0 / equivalent 5（M19, M21b, M22, M24, M26） | — |

**FAIL / SKIP の詳細**:

- ta-10 TC-7（`doctor-fix TC-7: json scope behavior or privacy wrong`）: `doctor --json --scope hooks` が worktree の絶対パス `/Users/...` を出力し TC-7 のプライバシー検査（`/Users/` 禁止）に当たる環境依存と帰属。HO patch は doctor に触れない。ログでは FAIL 行を確認した。origin/main 9c5b3262 standalone で同じ TC が FAIL する対照は本 handoff 作成者は再実行していない（exec 側の測定による）
- TC-E06 は判定 60 秒 / 偽 git 120 秒に是正後、M12 killed を確認済み
- 適用時の apply スクリプトは ta-119 / 79 / 80 / 65 / 39 が rc=0
- KNOWN-GAP: TC-B6-lone-surrogate rc=0（#1647、計数外）

## 7. Metrics summary

該当なし（未取得）。
