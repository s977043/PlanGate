# 振り返り 2026-05-01 (s4): Issue #169 EPIC 完走 + v8.5.0 リリース

> 対象 PR: [#183](https://github.com/s977043/PlanGate/pull/183) / [#184](https://github.com/s977043/PlanGate/pull/184) / [#185](https://github.com/s977043/PlanGate/pull/185) / [#186](https://github.com/s977043/PlanGate/pull/186)
> Issue: [#169](https://github.com/s977043/plangate/issues/169)（**CLOSED**、4 セッション × 11 PR で完走）
> リリース: [v8.5.0](https://github.com/s977043/PlanGate/releases/tag/v8.5.0)
> 期間: 2026-05-01（同日 4〜7 セッション目、Auto Mode）

## サマリ

**Issue #169 残 Hook EPIC を 4 セッション × 11 PR で完走**、10/10 hooks 実装達成 → **v8.5.0 として節目化**（v8.4.0 → v8.5.0、同日 2 リリース連続）。同日累計で 7 セッション、25 PR マージ、12 Issue close、16 PBI 完走、Open Issue / Open PR ともに 0 へ到達。

| 指標 | 値（s4 単独） | 値（s1〜s7 累計）|
|------|------------|----------------|
| 完了 PBI | 3（TASK-0056〜0058）| **16 件**（TASK-0045〜0058 + retro × 4）|
| マージ PR | 4（#183〜#186）| **25 件**（#161〜#186）|
| Issue auto-close | **#169** | **12 件**（#155〜#159 + #167〜#172 + **#169**）|
| Hook 実装 | 0 → **7（追加）= 10/10 完了** | 0 → **10/10** |
| Hook 単体 test | 12 → **42 件 PASS** | 0 → **42** |
| **release** | v8.4.0 → **v8.5.0** | v8.3.0 → v8.4.0 → **v8.5.0** |

## 対応マッピング（s4 = #169 EPIC のセッション A/B/C + v8.5 release）

| Session | Hook | PR | TASK | mode |
|---------|------|----|----|------|
| A | EH-1 + EH-3 | #183 | TASK-0056 | critical |
| B | EH-4 + EH-5 + EH-6 | #184 | TASK-0057 | critical |
| C | EH-7 + EHS-1 | #185 | TASK-0058 | critical |
| release | CHANGELOG v8.5.0 | #186 | — | release |

## Keep（うまくいったこと）

### K-1. EPIC を「3 セッション分割」設計通りに完走できた

s3 retrospective Try T-1 で「#169 を A/B/C の 3 セッションに分割」と計画した通り、各セッションで 2〜3 hook を実装し 1 セッションあたり 60〜90 分で完了。**事前の段階分割計画が時間管理に直結**した。critical mode の 7 hook を一気に詰め込まず、グループ別（plan / scope / merge）に分けたことで pattern reuse が効率化された。

### K-2. 既存 hook（check-c3-approval.sh）の structure 踏襲が圧縮効果を生んだ

セッション A で EH-1 / EH-3 を実装する際、既存 EH-2 の `emit_judgment` / `log_event` ヘルパパターンをコピーして type 別に書き換える形で進行。新規実装のうち約 60% が「pattern コピー」で完了。critical mode でも安全に進められた。

### K-3. tests/extras/ 構造（#170）が連続 PR で衝突ゼロを実現

s2 で導入した `tests/extras/*.sh` 分離 + s3 で追記した「set -e 互換書法」が今回の 4 PR（#183〜#186）でフル発揮。`tests/run-tests.sh` 末尾領域の衝突ゼロ、各 PR が main から最新化なしで CLEAN merge 可能だった。**過去 retrospective Try が複利的に効いた**好例。

### K-4. v8.5.0 リリースが軽量実行可能だった（v8.4 釣果の流用）

v8.4.0 で確立した release flow（CHANGELOG 章追加 + bin/plangate version bump 不要 + tag + GitHub Release CHANGELOG 抽出）を v8.5.0 でそのまま再利用。release PR 作成 → マージ → tag/Release まで 30 分以内に完了。**release ハンドリングの自動化** が 2 release 目で標準フロー化された。

### K-5. 全 10 hook で 3 mode 設計を統一できた

10 hook 全てで `default warning / PLANGATE_HOOK_STRICT=1 で block / PLANGATE_BYPASS_HOOK=1 で escape` を統一。さらに監査ログ（`docs/working/_audit/hook-events.log`）も統一フォーマットで出力。**API として一貫性ある自動化基盤** を構築できた。

## Problem（課題・反省）

### P-1. EH-6 で独自 YAML mini-parser を採用した（PyYAML 委譲を見送り）

`scripts/hooks/check-forbidden-files.sh` の YAML 抽出は python3 の独自正規表現実装。PyYAML 依存を増やさない判断は妥当だが、複雑な child PBI YAML（ブロック内ブロック、コメント混入）で parse 失敗するリスクが残る。本 PBI 範囲では fixture テストでカバーしているが、運用拡大時に robust 化が必要。

**対策**: V2 候補として「EH-6 の PyYAML 委譲」を retrospective Next EPIC 候補に明示済（CHANGELOG v8.5.0 § Next EPIC 候補 No.7 隣接）。

### P-2. EH-7 の GitHub branch protection 自動連携を断念した

EH-7 spec には「GitHub branch protection / Hook で block」とあるが、本 PBI では **CLI 検証のみ**に絞った。branch protection ruleset の自動適用は外部 API 操作 + 戻せない変更のため、独立 PBI 推奨。

**対策**: V2 候補として明示。実装時は「設定だけ生成して user が手動 apply」のフローも候補。

### P-3. EHS-1 で C-2 と V-3 の review-external.md を区別していない

現状の EHS-1 は「`review-external.md` があれば PASS」と判定。これは C-2（外部レビュー）と V-3（外部 model レビュー）が同じファイルを使う運用を許容しているが、phase 分離が必要な運用ではこの hook では不十分。

**対策**: V2 候補（CHANGELOG § Next EPIC 候補 No.2）。優先度 Low、運用知見蓄積後に判断。

### P-4. retrospective を都度 PR 化する負担

main 直接 commit が ruleset で拒否されるため、retrospective も毎回別 branch + PR 化が必要。s1〜s4 で 4 回繰り返しており、軽量とはいえ手数。

**対策**: ruleset 緩和は selectivity が低い（main 全体に影響）。代替として「retrospective-batched」フローで 1 PR に複数 retro をまとめる運用を検討（次回 V2 candidate）。

## Try（次にやること）

### T-1. v8.5.0 リリース後の運用検証

`docs/working/TASK-0046` の v8.3 baseline / `TASK-0055` の v8.4 baseline と同様、v8.5 baseline を取得：

```sh
for t in TASK-0039 TASK-0040 TASK-0041 TASK-0042 TASK-0043 TASK-0044; do
  python3 scripts/eval-runner.py $t --no-write
done
```

→ 数値変化なしで OK（v8.4 と同 PBI 群）、しかし「全 10 hook 環境下での再測定」として記録価値あり。優先度 Medium。

### T-2. `.claude/settings.json` への手動 opt-in 検証

`.claude/settings.example.json` の 4 hook（EH-1/2/3/6）+ SessionStart を本リポ作業者の `.claude/settings.json` に登録、1 セッションでの誤検出 / false-positive / strict mode 動作を実測。優先度 Medium。

### T-3. EH-7 上位拡張（branch protection 自動連携）

V2 候補 No.1。優先度 Medium。実装案: `gh api repos/:owner/:repo/rulesets` で ruleset 生成、`scripts/hooks/apply-branch-protection.sh` を新設。

### T-4. claude-cli session log parser

#168 v2、retrospective 2026-05-01 s3 P-2 で memory 記録済（`reference_claude_session_logs.md`）。優先度 Medium、出発点は `~/.claude/projects/<encoded-cwd>/<sessionId>.jsonl`。

### T-5. hook subcommand 統合（`bin/plangate hook <name>`）

V2 候補 No.3。優先度 Low、UX 改善のみ。10 hook が増えてきた今、CLI 統合はメリットあり。

### T-6. retrospective batched フロー

P-4 の対応。1 PR に複数 retrospective を集約するか、PR template として retrospective ごとに 1 commit する運用ガイドを検討。優先度 Low。

## メトリクス

| 指標 | s4 単独 | 同日累計（s1〜s7）|
|------|--------|----------------|
| 計画 PR 数 | 4 | 25 |
| 計画外 PR | 0 | 0 |
| マージコンフリクト | 0 件 | 5 件（s1 で 3、tests/extras/ 効果で s2〜s7 ゼロ）|
| handoff 必須 6 要素完備率 | 3/3 = 100% | **15/15 = 100%** |
| Hook 単体 test PASS 率 | 42/42 = 100% | 42/42 = 100% |
| Integration test PASS 率 | 24/24 = 100% | 24/24 = 100% |
| CI 緑率 | 4/4 = 100% | **25/25 = 100%** |
| Issue auto-close 率 | 1/1 = 100% | 12/12 = 100% |
| **新 release tag** | **v8.5.0** | v8.3.0 → v8.4.0 → **v8.5.0** |
| **EPIC 完走** | **#169（10/10 hooks）** | #169 ✓ |

## 関連リンク

- 親 retrospective: [`retrospective-2026-05-01.md`](retrospective-2026-05-01.md) / [`-s2.md`](retrospective-2026-05-01-s2.md) / [`-s3.md`](retrospective-2026-05-01-s3.md)
- マージ済 PR: #183〜#186
- 完了 PBI: TASK-0056 / 0057 / 0058
- v8.5.0 リリース: <https://github.com/s977043/PlanGate/releases/tag/v8.5.0>
- 全 10 hook の表: [`docs/ai/hook-enforcement.md`](../ai/hook-enforcement.md) § 4
- 監査ログ: `docs/working/_audit/hook-events.log`（local のみ、`.gitignore`）

## 同日累計のハイライト（s1〜s7）

| カテゴリ | 値 |
|---------|---|
| 完走 PBI | **16 件**（TASK-0045〜0058 + retrospective × 4）|
| マージ PR | **25 件**（#161〜#186）|
| Issue closed | **12 件**（auto-close 100%）|
| 起票 V2 候補 → 同日解消 | 起票 6 / 解消 5（残: GitHub branch protection 等の Next EPIC）|
| 残 Open | **0 件**（Issue / PR ともに）|
| **release** | **v8.3.0 → v8.4.0 → v8.5.0**（同日 2 リリース連続）|
| 新 CI workflow | 2（schema-validate / check-pr-issue-link）|
| 新 CLI コマンド | 2（validate-schemas / eval）|
| 新 hook | **10/10**（EH-1〜EH-7 + EHS-1〜EHS-3）|
| ローカル test | 10 → 24 + hook 42 = **計 66 件 PASS** |

PlanGate v8.5.0 で **「自動化基盤の節目」（v8.4）→「Hook enforcement 完成」（v8.5）** という 2 release 連続の節目化を達成し、ガバナンス層・実装層が完全に空状態に到達した。次セッションは V2 候補 7 件から優先順位選定 + 新規要求の起点判断が論点。
