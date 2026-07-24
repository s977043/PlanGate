# EXECUTION PLAN — TASK-0907

> Issue: [#907](https://github.com/s977043/plangate/issues/907)（P1 / enhancement / area:workflow / governance）
> EPIC: [#870](https://github.com/s977043/plangate/issues/870) ai-loop vNext 運用改善
> 由来: pbi-input.md（Human 決定 verbatim 2026-07-23）/ #807（Phase 0→1 移行）の延長
> 基点: main `3b987a1`
> **C-2 確定反映済み**（`Refs: R-001〜006 / R-101〜104`・review-external.md 参照）

## Goal

`docs/workflows/ai-loop/rollout-policy.md` §2 の適用ドメインを拡張し、plangate 本体（提供元リポジトリ）の実コード変更のうち **`lite=true ∧ boundary=clean ∧ reversible` 帯**に ai-loop-workflow を適用可能にする。承認境界（§5 不変条件）は一字も緩和しない。後続の lite/clean/reversible な bug fix（#877 等）を ai-loop でドッグフーディングしながら改善知見を得る。

**ただし ai-loop 自身の判定基盤は拡張対象から carve-out する**（自己改変の auto-approve 化防止・`Refs: R-001 / R-107`）。carve-out 対象 = ①強制エンジンコード `scripts/ai-loop/**` + 配布版 ②**ai-loop policy/spec 文書 corpus 全体**（`docs/workflows/ai-loop/**` + `docs/ai/ai-loop/**`）。②は ai-loop run（run-026）の Model B が検出・一次ソースで CONFIRMED（`ho-paths.md` 原則2 = policy は現状 clean・将来 HO-policy 登録予定）。

## Constraints / Non-goals

- **§5 不変条件は不動**（NO MERGE BY AI / HO 接触＝無条件 escalate / W チェック独立 2 体 / lite AC-8 安全側）。差分で「変更なし・明示維持」を示す（AC-2）
- **承認境界は §5 のみでない**（§4 auto-approve 方針 / §6 escalate 条件 / command 実行前チェック3 / ho-paths clean 判定集合）。これらも additive-only とし escalate 条件の削除・緩和ゼロを検証する（AC-7・`Refs: R-002`）
- **実機能 auto-approve は #780 slice C（size_ok 機械算出）を前提として継承（ハード順序制約）**（B-1 Q1 Human 決定・`Refs: R-003`）。**#780 未導入下では plangate 本体の実機能 run は決定論的に escalate**（「escalate 寄り」等の非決定論的表現は用いない）。§4 順序制約と一貫（再定義せず参照）
- **判定基盤 carve-out**: §2 拡張の適用対象から ①強制エンジンコード `scripts/ai-loop/**` + 配布版 `plugin/plangate/skills/ai-loop-cycle/scripts/**` ②ai-loop policy/spec 文書 corpus 全体（`docs/workflows/ai-loop/**` + `docs/ai/ai-loop/**`）を除外（escalate 固定）。ho-paths self-protection 原則（ho-paths.md 自身が HO な理由）と同型。②は将来 `ho-paths.md` 原則2 の HO-policy 登録で機械層化するまでの規範層 carve-out（`Refs: R-001 / R-107`）
- `00_concept.md` §3.6 等の参照整合は **Out of scope**（B-1 Q2 Human 決定）
- Non-goal: `lite.size_ok` の機械算出（#780 slice C 本体）/ 導入先の §3 適用条件変更 / §5 不変条件の変更 / ai-loop engine の HO 登録（carve-out で代替・将来判断）

## Approach Overview（B-2 比較の結論）

rollout-policy §2 の拡張表現について 3 案を比較し **案 C（表行拡張＋直下注記節）を採用**（Mode=critical で差分の可読性最優先）。

| 案 | 内容 | 採否 |
|----|------|------|
| A 表セル書換のみ | 最小差分だが #780 順序制約・§5 不変・carve-out が表セルに収まらず誤読リスク | ✕ |
| B eligible 域＋別判定節 | §4 と重複・断片化 | ✕ |
| **C 表行拡張＋直下注記節** | 表行拡張＋注記に #780 ハード順序制約 + §5/§4/§6 不変明示 + carve-out + Human verbatim を集約。AC-1〜8 を最小副作用で満たす | **採用** |

## Metrics Evidence

| 対象 | 実数 | 見積もり | ratio | 判定 |
|------|------|---------|-------|------|
| touch ファイル数 | 4（AI 編集=1・sync 自動生成=2・Human patch=1） | 3〜4（pbi-input） | 〜1.0 | 採用。Mode critical 維持 |

**実数根拠**（`find` / `cmp` / `sync --dry-run` 実測・C-2 で裏取り済）:
- `rollout-policy.md` = 2 コピー: 正本 `docs/workflows/ai-loop/rollout-policy.md`（**非HO・AI 編集**）+ 配布 `plugin/plangate/skills/ai-loop-cycle/references/rollout-policy.md`（**sync が link-rewrite で自動生成**・正本と byte 一致しないのが正常）
- `ai-loop-workflow.md` = 2 コピー: `.claude/commands/ai-loop-workflow.md`（**HO・正本・Human patch**）+ `plugin/plangate/commands/ai-loop-workflow.md`（**sync が cp で自動生成**・正本と byte 一致が正常）
- → 論理変更 2 種 × 各 2 コピー = 4 ファイル。**AI が直接編集するのは rollout-policy 正本 1 のみ**。plugin 2 コピーは sync 自動生成、HO command 1 は Human patch（`Refs: R-101/R-102/R-103`）
- 論理コード変更ゼロ（docs / command md のみ）

### sync 機構の差（`Refs: R-102`・C-2 実測）

| ファイル | 正本 | plugin 派生の生成法 | drift 検証 |
|---------|------|-------------------|-----------|
| rollout-policy.md | `docs/workflows/ai-loop/`（非HO） | `_sync_ai_loop_ref_content()` が **link-rewrite**（相対パス self-contained 化）→ byte 不一致が正常 | **sync 冪等**（dry-run 変更ゼロ） |
| ai-loop-workflow.md | `.claude/commands/`（**HO**） | `sync_dir()` が **cp**（そのまま複製）→ byte 一致が正常 | `.claude`↔`plugin` cmp exit 0 |

## Work Breakdown

- **S1** rollout-policy §2 拡張（正本・非HO）
  - Output: `docs/workflows/ai-loop/rollout-policy.md` §2 適用ドメイン表の plangate 本体行を案 C で拡張 + 直下注記節（**carve-out `scripts/ai-loop/**`** / #780 ハード順序制約継承 / §5/§4/§6 不変明示 / Human verbatim）
  - Owner: agent（非HO）
  - Risk: 承認境界緩和と誤読 → 🚩 §5/§4/§6 の escalate 条件が diff で削除・緩和ゼロを自己確認
  - rollback: `git checkout -- docs/workflows/ai-loop/rollout-policy.md`
- **S2** plugin 派生の sync 再生成（rollout-policy）（`Refs: R-101`）
  - Output: `sh scripts/sync-plugin-plangate.sh` を実行し `plugin/.../references/rollout-policy.md` を**自動再生成**（手同期禁止・link-rewrite は script が担う）。`sync --dry-run` が **no change** を報告することを確認
  - Owner: agent（非HO）
  - Risk: 手同期で byte 一致させると次回 sync で revert → 🚩 必ず sync script 経由・cmp byte 一致を期待しない
  - rollback: `git checkout -- plugin/plangate/skills/ai-loop-cycle/references/rollout-policy.md`
- **S3** HO command patch 生成（`.claude/commands/ai-loop-workflow.md`）（`Refs: R-103`）
  - Output: `docs/working/TASK-0907/patches/ai-loop-workflow-command.patch`（完成形 + `ho-apply-approval.md` 手順・切り戻し）。実行前チェック3 を §2 拡張と整合（承認境界・HO 接触は通常フロー / lite/clean/reversible な本番変更は ai-loop 可）。**ガードの非後退**（HO 接触無条件 escalate / NO MERGE BY AI / touches-HO 停止規則）を保持
  - Owner: agent 生成 / **Human 適用**（HO・self-mod ガード対象）
  - Risk: AI が HO を直編集 or plugin command を先行編集（sync で revert） → 🚩 patch 生成のみ・plugin command は AI 編集しない
  - rollback: patch 未適用 no-op / 適用済みは reverse patch 同梱
- **S4** plugin command の sync 再生成（Human patch 適用後）
  - Output: Human が S3 patch を `.claude` 正本へ適用後、`sh scripts/sync-plugin-plangate.sh` で `plugin/plangate/commands/ai-loop-workflow.md` を cp 再生成。`cmp .claude/... plugin/...` = exit 0
  - Owner: agent（sync 実行）/ 前提: **H2（Human patch 適用）完了**
  - Risk: Human 適用前に sync すると plugin が旧 .claude 内容で上書き → 🚩 順序ロック: S4 は H2 の後
  - rollback: 不要（sync 再実行で復元）
- **S5** 承認境界 非後退・drift ゼロ検証（AC-2/5/6/7・`Refs: R-101/R-102/R-103`）
  - Output:
    - rollout-policy: `sync --dry-run` 変更ゼロ（冪等）
    - command: `.claude`↔`plugin` cmp exit 0（H2 適用後）
    - §5/§4/§6 escalate 条件の diff = additive-only（削除・緩和ゼロ）
    - carve-out（①`scripts/ai-loop/**` + 配布版 ②ai-loop policy/spec 文書 corpus 全体 の除外）が §2 注記に存在
  - Owner: agent / evidence/
  - Risk: HO command は Human 適用前は不整合 → 🚩 S5 の command 部は H2 の後
  - rollback: 不要（検証）
- **S6** doc V-1: リンク健全性 + 実行例到達性 + `bin/plangate doctor` 回帰なし
  - Owner: agent / evidence/
  - rollback: 不要（検証）

## Files / Components to Touch

| ファイル | HO | 変更主体 | 生成法 |
|---------|----|---------|-------|
| `docs/workflows/ai-loop/rollout-policy.md` | ✕ | **AI 編集** | 手編集（§2 拡張・唯一の AI 直接編集） |
| `plugin/plangate/skills/ai-loop-cycle/references/rollout-policy.md` | ✕ | sync 自動 | `sync-plugin-plangate.sh`（link-rewrite） |
| `.claude/commands/ai-loop-workflow.md` | ✅ | **Human patch** | patch 適用（S3/H2） |
| `plugin/plangate/commands/ai-loop-workflow.md` | ✕ | sync 自動 | `sync-plugin-plangate.sh`（cp・H2 後） |

## Testing Strategy

- Unit: なし（論理コード変更ゼロ）
- Integration: `sync --dry-run` 冪等（rollout-policy）+ `.claude`↔`plugin` command cmp（H2 後）
- 承認境界検証: §5/§4/§6 escalate 条件 diff = additive-only / carve-out 存在
- Doc V-1: リンク健全性・実行例到達性
- Verification 自動化: `bin/plangate doctor` 回帰なし

## Risks & Mitigations

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| ai-loop 自己改変の auto-approve 化（R-001/R-107） | §2 注記に carve-out（エンジンコード + ai-loop policy/spec 文書 corpus 全体）・TC-6 で grep 確認 | escalate 固定を注記に明記・将来 HO-policy 登録も選択肢 |
| 承認境界の緩和（§5 だけ見て見逃す・R-002） | §4/§6 escalate 条件 diff = additive-only（TC-2 拡張） | 注記に「§4/§6 additive のみ」明記 |
| #780 順序制約の軟化（R-003） | 注記に §4 同一のハード順序制約・TC で決定論確認 | 「寄り」表現排除・#780 未導入は escalate 固定 |
| command ガード緩和（R-004） | patch diff でガード非後退確認（TC-4 拡張） | 緩和は boundary=clean・非承認境界に限定と注記で境界画定 |
| sync drift の誤検証（R-101） | rollout-policy は sync 冪等・command は cmp（区別） | 手同期禁止・sync script 経由固定 |

## Questions / Unknowns（C-3 論点）

1. **【最重要・R-001/R-107】carve-out 方式**: §2 拡張の適用対象から ①強制エンジンコード `scripts/ai-loop/**` + 配布版 ②ai-loop policy/spec 文書 corpus 全体（`docs/workflows/ai-loop/**` + `docs/ai/ai-loop/**`）を除外（escalate 固定）で承認境界の自己改変を防ぐ方針でよいか。代替は ai-loop engine + policy を ho-paths.md に **HO 登録**（より強いが通常の開発も全て Human patch 化＝重い。ho-paths.md 原則2 の将来 HO-policy 登録に接続）。**規範層 carve-out 推奨**
2. **§2 拡張の表現（案 C）** が §5/§4/§6 の escalate 条件を diff ゼロ/additive に留めているか（C-3 で差分確認）
3. **#780 ハード順序制約継承**の文言が §4 を再定義せず参照になっているか
4. **AC-5 の是正**（cmp byte 一致 → sync 冪等）が rollout-policy に対し妥当か
5. HO command patch の byte 整合（H2 適用後の cmp）と順序ロック（S4/S5 は H2 の後）
6. ai-loop run 時 arbiter が **HUMAN_ESCALATED**（HO 接触・lite=false）を返す実証は本 PBI の doc 完了と分離（handoff 記載・R-006）

## 受入基準（pbi AC-1〜5 + C-2 派生 AC-6〜8）

- **AC-1**（R-005 機械化）: §2 plangate 本体行に `lite=true`・`boundary=clean`・`reversible` の 3 語が含まれ、かつ「本番フロー変更が適用可」の明示文が存在（grep 照合可）
- **AC-2**（R-002 強化）: §5 不変条件が一字も緩和されていない（diff ゼロ）。加えて §4/§6 の escalate 条件が additive-only（削除・条件緩和ゼロ）
- **AC-3**: Human 決定 verbatim が §2 に移行根拠として記録される
- **AC-4**（R-004 強化）: command 実行前チェック3 が §2 と整合し、かつ HO 接触無条件 escalate / NO MERGE BY AI / touches-HO 停止規則が非後退
- **AC-5**（R-101 是正）: rollout-policy は sync 冪等（dry-run 変更ゼロ）、command は `.claude`↔`plugin` cmp exit 0（H2 後）
- **AC-6**（R-001 / R-107 新規）: §2 注記に carve-out が存在し、①強制エンジンコード `scripts/ai-loop/**` + 配布版 ②ai-loop policy/spec 文書 corpus 全体（`docs/workflows/ai-loop/**` + `docs/ai/ai-loop/**`）の**両方**を拡張対象から除外・escalate 固定と明記
- **AC-7**（R-002 新規）: 本拡張で新規に auto-approve 可能化する承認境界相当パスが無いことを列挙確認（clean 判定集合の点検）
- **AC-8**（R-003 新規）: #780 未導入下では plangate 本体の実機能 auto-approve は決定論的に escalate（注記に §4 同一のハード順序制約）

## Mode 判定

**モード**: critical / **lite_eligible**: false（AC-10 Hardening Override 優先）

**判定根拠**: 変更ファイル数 4（standard 相当）だが、**承認境界周辺（rollout eligibility policy）＋ワークフロー定義（`.claude/commands/*.md`=HO）** で mode-classification 例外ルール「承認境界周辺→最低 high」＋ HO 接触の合成により critical。同期 C-3 固定。

## ai-loop run との関係

本 plan は PlanGate 標準フロー（B→C-1→C-2→C-3）で正式化。その後 `/ai-loop-workflow run TASK-0907` を実行すると arbiter は Plan Package を読み、**HO 接触（`.claude/commands/*.md`）→ boundary=touches-HO → lite=false → §5 不変により HUMAN_ESCALATED** を返す。これが「ai-loop が承認境界を遵守して人間へ escalate する」Phase 1 初実走の実証（doc 完了とは分離・R-006）。
