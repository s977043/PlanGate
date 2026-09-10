# follow-up issue 下書き（#1275 の (b) 決着に伴う）

> **この文書は下書きである。** issue はまだ起票していない（起票はオーガナイザー / Human が行う）。
> 起票後は本ファイルに issue 番号を追記する。

## タイトル案

- 第 1 案: `ai-loop V2: canon 7 本の I1 例外が失効したら I4 レビューへ移行する（#1275 (b) の follow-up）`
- 第 2 案: `ai-loop V2 canon の Independence Level 例外（I1）の失効検知と I4 移行`

## Labels（案）

`ai-loop-v2` / `governance` / `phase-1`

## 本文（案）

### Context / Why

Issue #1275（Phase 0.1 Canon Hardening）の唯一の未決だった「canon docs 自身に要求する Independence Level を I1 のままにするか I4 へ上げるか」は、2026-09-10 に Human が**選択肢 (b)** を選んで決着した。決定と根拠は
[`docs/ai/ai-loop-v2/phase0-migration.md`](../../ai/ai-loop-v2/phase0-migration.md) §7「Human 判断事項（2026-09-10 決着 / 選択肢 (b) を採用）」に記録済み。

(b) は「canon 7 本はそれを強制する実行系をまだ持たない仕様文書であるから、
[`evaluation-trust-boundary.md`](../../ai/ai-loop-v2/evaluation-trust-boundary.md) §3（Evaluation Harness そのものの変更は I4 でのみ採用する）の**明示的な例外**として I1 を認める」というもので、
**例外は期限ではなく条件で切れる**。本 issue はその**失効時にやること**を保持する。

### What（Scope）

**In scope**:

1. §7 の M-1 / M-2 / M-3 を **Phase 1 の Architecture / Contract design 着手時に 1 回**再測定し、結果を §7 の baseline 欄へ反映する。
2. いずれかが baseline から動いていた場合:
   - 例外の失効を §7 に明記する（失効日・どの条件が動いたか・実測出力）。
   - **以後の** canon 7 本の規定変更に I4（Human 判断と機械 evidence の両方）を要求する運用へ切り替える。
   - Phase 1 の exit criteria に「canon 7 本の I4 レビュー」を 1 項目として立てる。
3. canon 7 本を変更する PR ごとに M-1 / M-2 / M-3 を測る運用を、どこに置くか決める（PR チェックリスト / CI / doctor のいずれか）。本 issue の時点では**機械化を前提にしない**。

**Out of scope**:

- `evaluation-trust-boundary.md` §3 の規定内容の変更（(b) は §3 を弱めない）。
- Phase 0 / Phase 0.1 の充足記録の遡及的な作り直し（**失効は遡及しない**）。

### 受入基準

- [ ] AC-1: M-1 / M-2 / M-3 の再測定を実施し、実測出力（コマンドと出力）を §7 または本 issue に記録した。
- [ ] AC-2: baseline から動いた条件が 0 件だった場合は「例外継続」を、1 件以上だった場合は「失効」を §7 に明記した。
- [ ] AC-3: 失効した場合、Phase 1 exit criteria に canon 7 本の I4 レビュー項目が 1 行として存在する。
- [ ] AC-4: canon 7 本を変更する PR での再測定タイミングの置き場所（チェックリスト / CI / doctor）が 1 つに決まっている。

### 判定コマンド（§7 と同じもの・正本は §7）

```sh
echo "== M-1 =="; ls schemas/ | grep -Ei 'harness|loop-contract|run-state|runstate' || echo "(none)"
echo "== M-2 =="; ls -d scripts/ai-loop-v2 bin/ai-loop-v2 2>/dev/null || echo "(none)"
echo "== M-3 =="; git grep -lE 'HarnessManifest|harness_id|distribution_digest|protected_surfaces|independence_level|LoopContract' -- scripts bin schemas .github/workflows | sort
```

`9f1b9f63` 時点の baseline: M-1 = 出力なし / M-2 = 出力なし / M-3 = `scripts/ai-loop/corpus_hash.py` の 1 本のみ。

### Notes / Risks

- **判定不能なら失効側（I4 要求）に倒す**（fail-closed）。M-3 に新しく現れたファイルが説明コメントのみだと判断して baseline を更新する場合は、根拠を §7 に残すこと。
- M-3 の語彙から `RunEvidence` を外しているのは、Legacy #874 の実装が既に存在して常時ヒットし検出力を失うため。Legacy を語彙に足し戻さないこと。
- 本 issue は #1275 の close をブロックしない（#1275 の exit criteria は §7 の決着記録で充足する）。

### Refs

- #1275（Phase 0.1 Canon Hardening）
- [`docs/ai/ai-loop-v2/phase0-migration.md`](../../ai/ai-loop-v2/phase0-migration.md) §7
- [`docs/ai/ai-loop-v2/evaluation-trust-boundary.md`](../../ai/ai-loop-v2/evaluation-trust-boundary.md) §3 / §4
- [`docs/working/_reports/1275-phase0-01-independent-review.md`](./1275-phase0-01-independent-review.md) §5-0 / §7-2（R2 レビュアーによる「ラウンドを重ねても解消しない」申告）
