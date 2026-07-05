---
task_id: TASK-0121
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-07-05
author: bookkeeping-refresh (after-the-fact)
v1_release: "e6e8da6"
---

> **本 handoff はマージ後の事後発行（bookkeeping）である。** TASK-0121 は
> 2026-05-31 に PR #419（e6e8da6）として main へマージ済みだが、
> `docs/working/TASK-0121/current-state.md` が「A: PBI INPUT 作成中」の
> stale 表示のまま handoff 未発行だった。本文書は plan.md / pbi-input.md /
> test-cases.md / マージ済 PR #419 の diff・CI 結果を一次証跡として
> **事後再構成**したものであり、当時のリアルタイム記録ではない。

# Handoff Package — TASK-0121（振り返り配点 Plan-primacy 整合）

## メタ情報

```yaml
task: TASK-0121
related_issue: PR #417 のフォローアップ（振り返り配点内的不整合の解消）
author: bookkeeping-refresh (after-the-fact, 元実装は mine_take + Claude Opus 4.8)
issued_at: 2026-07-05
v1_release: e6e8da6（PR #419、2026-05-31 マージ）
```

## 1. 要件適合確認結果

| 受入基準                                                                        | 判定               | 根拠 / コメント                                                                                                                                                                                                                                                     |
| ------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AC-1: 配点を 30/15/15/10/30（合計100）に統一                                    | PASS               | e6e8da6 diff で 4 複製サイトへ反映確認（`git show e6e8da6 --stat`）                                                                                                                                                                                                 |
| AC-2: 計画精度に C-1 語彙（受入基準網羅性/スコープ制御/テスト戦略妥当性）を明記 | PASS               | commit message + diff に明記。`docs/ai-driven-development.md` 側で確認                                                                                                                                                                                              |
| AC-3: 成果物品質を「計画で定めた品質の達成度＝保全達成度」として再定義          | PASS               | commit message に明記                                                                                                                                                                                                                                               |
| AC-4: 4 複製サイトの配点・評価語彙が整合                                        | PASS               | `docs/ai-driven-development.md` / `plugin/plangate/agents/workflow-conductor.md` / `.claude/agents/workflow-conductor.md` / `.claude/agents/retrospective-analyst.md` が同一コミットで更新（HO 2 件は commit message に「人間編集」と明記）                         |
| AC-5: `.codex/agents/retrospective_analyst.toml` は thin pointer のまま変更なし | PASS               | e6e8da6 の変更ファイル一覧に含まれない                                                                                                                                                                                                                              |
| AC-6: consistency script が旧配点残存・新5軸欠落・合計100不一致を検出           | PASS               | `scripts/check-retro-scoring-consistency.sh` が新規追加（129 行）。同ファイルは origin/main に現存                                                                                                                                                                  |
| AC-7: RED→GREEN 証跡                                                            | PASS（記載ベース） | commit message に「RED→GREEN を一時 harness で実証」と明記。当時の RED ログ自体は working ディレクトリに残っていないため、根拠は commit message + script 現存確認に限る（下記 §2 既知課題参照）                                                                     |
| AC-8: pre-push / CI 配線は人間編集                                              | **未充足**         | `scripts/check-retro-scoring-consistency.sh` は origin/main 上で pre-push テンプレートにも `.github/workflows/` にも未配線（`grep -rn check-retro-scoring-consistency scripts/templates .github/workflows` 該当なし、2026-07-05 時点確認）。V2 候補として §3 に記録 |
| AC-9: HO 2 件（workflow-conductor.md / retrospective-analyst.md）は人間編集     | PASS               | commit author は `mine_take`（人間コミット）。commit message に両ファイルを「人間編集」と明記                                                                                                                                                                       |

**総合**: `8/9 PASS, 1 未充足（AC-8）`
**FAIL/未充足の扱い**: AC-8（pre-push/CI 配線）は plan.md でも「human 判断」「Unknowns」に位置付けられており、実装完了の前提条件ではなかった（ドリフトガードの script 自体は完成・機能する）。V2 候補として次スプリントへ持ち越す。

## 2. 既知課題一覧

| 課題                                                                                         | Severity | 状態                                            | V2 候補か |
| -------------------------------------------------------------------------------------------- | -------- | ----------------------------------------------- | --------- |
| pre-push / CI への consistency script 未配線（AC-8）                                         | minor    | open                                            | Yes       |
| RED 状態の実行ログが working context に残っていない（AC-7 は commit message 記載のみが根拠） | info     | accepted（事後 bookkeeping のため遡及取得不可） | No        |

**Critical 課題の対応**: Critical/major な open 課題なし。AC-8 は運用配線の欠落であり、機能自体（script）は完成・main に存在する。

## 3. V2 候補

| V2 候補                                                       | 理由                                                                  | 推定優先度 | 関連 Issue |
| ------------------------------------------------------------- | --------------------------------------------------------------------- | ---------- | ---------- |
| `scripts/check-retro-scoring-consistency.sh` の pre-push 配線 | plan.md で human 判断事項とされたまま未着手                           | Medium     | —          |
| 同 script の CI（`.github/workflows/`）配線                   | 同上（`.github/workflows/` は Hardening Override のため人間編集必須） | Medium     | —          |

## 4. 妥協点

| 選択した実装                                                                                                              | 諦めた代替案               | 理由                                                                                         |
| ------------------------------------------------------------------------------------------------------------------------- | -------------------------- | -------------------------------------------------------------------------------------------- |
| HO 2 件（`.claude/agents/workflow-conductor.md` / `retrospective-analyst.md`）を人間が直接編集し、AI は非 HO 3 件のみ実装 | AI が全 4 サイトを一括編集 | responsibility-classes.md の Hardening Override 原則（AI は HO パスを編集不可）を遵守        |
| pre-push / CI 配線を本 PBI スコープ外（Unknowns）とし script 単体の完成を優先                                             | 配線まで一括実装           | plan.md 時点で配線先（既存 template 直接追加 or dispatcher 経由）が human 判断待ちだったため |

## 5. 引き継ぎ文書

### 概要

TASK-0121 は振り返りメトリクスの配点を Plan-primacy 思想（Plan=品質の発生源
/ Exec=保全）と整合させる PBI。旧配点（計画精度15 < 効率性25 < 成果物品質30）
の因果逆転を解消し、30/15/15/10/30 へ統一。対象 4 複製サイトの同期と、今後の
配点ドリフトを機械検知する `scripts/check-retro-scoring-consistency.sh` を
新設した。2026-05-31 に PR #419（e6e8da6）として main へマージ済み、CI 全項目
PASS（check / Markdown lint / plangate CLI tests / privacy / settings wiring
drift / SKIP_REASON 追認 / validate）。

本 handoff は、current-state.md が古い「A: PBI INPUT 作成中」表示のまま
放置されていたための **事後 bookkeeping 発行**である。実装内容そのものは
plan.md の Work Breakdown と概ね一致しているが、AC-8（pre-push/CI 配線）
のみ未着手のまま完了扱いになっていることが判明したため、本文書で明示した。

### 触れないでほしいファイル

- `scripts/check-retro-scoring-consistency.sh`: 配点ドリフトガードの正本。
  変更する場合は 3 形式（インライン / 表値 / 表分母 `{N}/X`）の検証パターンを壊さないこと
- `.claude/agents/workflow-conductor.md` / `.claude/agents/retrospective-analyst.md`:
  HO 対象。AI が直接編集せず、apply-script 経由で人間が適用すること

### 次に手を入れるなら

- AC-8（pre-push / CI 配線）を別 PBI として起票し、`scripts/templates/pre-push.sample`
  への追加 or 専用 dispatcher 経由での配線方針を人間が決定する
- 配線後は `rg 'check-retro-scoring-consistency.sh' scripts/templates .github/workflows`
  で参照が確認できることを完了条件とする（test-cases.md TC-09 相当）

### 参照リンク

- PR: https://github.com/s977043/plangate/pull/419
- plan.md: `docs/working/TASK-0121/plan.md`
- pbi-input.md: `docs/working/TASK-0121/pbi-input.md`
- test-cases.md: `docs/working/TASK-0121/test-cases.md`
- approvals/c3.json: `docs/working/TASK-0121/approvals/c3.json`（APPROVED）

## 6. テスト結果サマリ

> テスト結果は再実行によるものではなく、**マージ済み PR #419 の CI PASS を
> 根拠に事後記載**したものである（実行ログの再現・捏造は行っていない）。

| レイヤー                                            | 件数     | PASS                                      | FAIL / SKIP | カバレッジ                                                                                                 |
| --------------------------------------------------- | -------- | ----------------------------------------- | ----------- | ---------------------------------------------------------------------------------------------------------- |
| CI（PR #419 statusCheckRollup）                     | 7 checks | 7 SUCCESS                                 | 0           | check / Markdown lint / plangate CLI tests / privacy / settings wiring drift / SKIP_REASON 追認 / validate |
| Structural（test-cases.md TC-01〜05, TC-08, TC-10） | 7        | 未再実行・PR diff 内容から妥当性確認のみ  | —           | AC-1〜5, AC-9                                                                                              |
| RED/GREEN（TC-06, TC-07）                           | 2        | commit message 記載のみ（実行ログ非現存） | —           | AC-7（根拠限定的）                                                                                         |
| 配線確認（TC-09）                                   | 1        | FAIL（未配線を確認）                      | —           | AC-8 未充足の直接証跡                                                                                      |

**FAIL/SKIP の詳細**: TC-09 相当（pre-push/CI 配線確認）は 2026-07-05 時点で
未配線を確認しており、AC-8 未充足の裏付けとなる。他は PR #419 の CI green
と diff 内容の整合で PASS 相当と判断した（再実行はしていない）。

## 7. Metrics summary

該当なし（opt-in 未設定、事後 bookkeeping のため再収集は行わない）。
