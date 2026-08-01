# Changelog

> このページは [CHANGELOG.md](https://github.com/s977043/PlanGate/blob/main/CHANGELOG.md) を
> リリース時に自動同期したものです（手動編集しない）。生成: scripts/sync-release-docs.sh


PlanGate の主要リリース履歴。

このファイルは各リリース時点の内容を記録するものであり、この pull request の差分一覧ではない。

## Unreleased

## v8.18.0 (2026-07-31)

feat: 実 PR 収束（`MERGE_READY`）の一気通貫 — delivery 判定エンジン + GitHub Collector / Action Executor / Reconciler + Plan-first C-3' 束縛

v8.17.1 タグ以降 main に蓄積した 46 マージ（+49k 行）を反映するリリース。EPIC #870 の close blocker だった「PR 作成後の CI / review repair → `MERGE_READY` 実収束」が実 PR 実走証跡付きで完成し、ai-loop の Delivery 層が動く状態になった。承認境界は不変（NO MERGE BY AI・C-4 / merge は Human-owned 固定）。

### Added

- **MERGE_READY 状態機械 `delivery.py`** — 決定論判定エンジン（純判定器・外部作用ゼロをソース走査で固定・7 状態 + EXITS・`PRIORITY_ORDER`・intent / receipt 2 段・contract ブロックの byte 一致検証）（#873、#905）
- **実 PR 収束 — GitHub Collector / Action Executor / Reconciler**（#917、#941）— head SHA 束縛 snapshot 取得（stale check 排除・旧 head の APPROVED 不採用）/ `required_checks[]` ⊇ 照合で部分登録 green を fail-closed 拒否 / raw check evidence の自己照合 / intent → 実行 → receipt → reconcile の冪等系 / **実 PR 1 周の実走証跡**（probe PR #940・`evidence/e2e/` に完全保存）
- **実行境界検査器 + gh / git 実行ラッパ** — 許可サブコマンド allowlist 方式（禁止は補集合として自動成立: `gh pr merge` / `gh pr review --approve` / close / force-push / branch 削除 / 非 GET api。実走 spawn ledger で違反 0 件を実証）（#917 AC-5、#941）
- **`ci_failure_taxonomy` 供給主体 `ci_taxonomy.py`** — manual entry 優先・`code` を機械が断定しない・未該当は既存 fail-closed に委ねる（#941）
- **c3-prime 受理器 + Plan-first 束縛** — `c3prime_verify.py`（非 HO 受理器）+ HO patch 群の Human 適用（`ai-loop run TASK-XXXX` の Plan Package 束縛・schema 配置）（#872、#889、#895）
- **`c3_contract.py` 共通契約層化** — `canonical_hash` 等の検証ロジックを arbiter / c3prime / delivery が共用（#896、#902）
- **rollout-policy §2 の本体拡張** — plangate 本体の lite / clean / reversible 帯へ適用ドメインを拡張 + **判定基盤 carve-out**（自己改変防止 glob・規範層。機械層強制は #916 で追跡）（#907、#912）
- **ai-loop 正本定義統合** — `00_concept.md` の正本昇格 + rollout-policy 分離（5 責務・terminal state・C-3' 経路の単一正本化）（#871、#879〜#883）

### Fixed

- **mass-delete safety guard の fail-closed 化** — `guard_fired` → 終端 exit 3 + `PLANGATE_ALLOW_MASS_DELETE=1` override + stale ベース判定で dry-run / 実行の判定一致（#877、#915）。残る 2 経路への適用は #914（plan C-3 待ち）
- **orphan SKILL.md 7 件の正本移設** — `.agents/skills/` 正本へ移設し sync / drift check の担保下へ（plugin 配布正確性）（#862、#865）
- **ta-26 の実リポジトリ非破壊化 + sync safety guard**（#861、#875）/ **HO リスト二重管理の整合 + sync CI trigger 拡張**（#842、#860）
- probe PR #940 マージ後の記述実態訂正・ta-13 の worktree SKIP 差異等は handoff 既知課題として記録

### Changed

- **ai-dev / ai-loop 境界の重心決定を正本化** — 「重心を Delivery へ移す」（C-3' は eligible run 限定の入口最適化に格下げして維持。本体価値 = PR 後の収束 + Evolution）を議論 doc として記録（#926）
- **schema 配置の横断裁定（案 2 段階方式）** — Phase 1 は `docs/schemas/`（非 HO）で 4 PBI（#894/#874/#869/#908）同側に統一 → 本番接続の C-3 で `schemas/` へ 1 回の HO patch 昇格（#930、#932）
- **pbi / plan の整備**（多くは 2 レーンレビュー済み）: #914（plan・C-3 待ち）/ #913 / #916 / #921 / #923 / #894 / #874 / #869 / #908 / #867 / #863 / #866 / #868 / #917（plan → exec 完了）
- **plugin version を 8.18.0 に更新**（marketplace.json / plugin.json。`claude plugin update` での追従を可能にする）

## v8.17.1 (2026-07-13)

fix: plugin bundle の同期漏れを追従（v8.17.0 tag に未収載だった `.claude/` → `plugin/plangate/` 差分の取り込み）

### Fixed

- **plugin bundle 同期** — `arbiter.py`（+37行）/ `decision-table.md`（+20行）/ `test_arbiter.py`（+196行）/ `test_metrics.py` / rules 2 ファイル / README を `.claude/` 正本と同期（plugin-sync 自動検出 run-29216958418 由来）
- **plugin version を 8.17.1 に更新**（patch。機能追加なし・bundle 完全性の追従のみ）

## v8.17.0 (2026-07-13)

feat: ai-loop Phase 1 移行（導入先実リポジトリ検証の正式化）+ 安全前提の機械層配線 + 計測基盤の実データ稼働 + HOTL 境界正本化

v8.16.0 タグ以降 main に蓄積した ai-loop / HOTL / スキル群の変更を plugin 配布に反映するリリース。plugin bundle（`plugin/plangate/skills/ai-loop-cycle/`）は references 全面更新 + `metrics.py` / `test_metrics.py` / `agentic-six-stage-loop.md` / `stop-rollback.md` を新規同梱する。

### Added

- **ai-loop Phase 1 移行 — 導入先実リポジトリでの検証を正式化**（#807 / #808）
- **ai-loop 計測基盤** — decision record 集計 `metrics.py`（#780 Slice D 前半、#812）+ arbiter が record に run メタを刻印（Slice D 後半、#815）+ HOTL 健全性メトリクス（escalate / human_intervention / reversal rate、#822 項目3、#831）
- **ai-loop plan 品質ゲート priority 1.7** — C-1 / breakdown を auto-approve 必要条件に（#780 Slice B、#817）+ gates を provenance に刻む（#819）
- **size_ok の機械検証** — changed_files 実数で判定 + POLICY_REF @v3（#780 Slice C、#820）
- **LoopSpec cost_cap** — round 予算超過を arbiter が escalate（#749 C案(2)層、#840）
- **ai-loop discovery** — D-2 read-only 候補提示 CLI（#824）/ D-3 recommended_next 構造化 + `--emit-next-command`（#826）/ A-1 HO 事前判定強化（HO-plugin 語彙追加、#841）
- **HOTL 不変条件の回帰テスト**（merge / HO / fail-closed / escalate 自己解決禁止、#822、#830）
- **スキル新設・改名**: `breakdown-gate`（#802）/ `ref-integrity-scan`（#801）/ `self-review` → `diff-audit` 改名 + Iron Law 8 / Phase 13 正本化（#796）/ `setup-team` → `subagent-team-design` 改名 + 命名ポリシー正本化（#806）
- **review-gate 拡張** — growth-core 由来 4 観点レーン追加（#795）+ UI/UX パック（レーン5 + UI 専用 V-1、#805）
- **workflow-conductor plan 再実行ガード**（#676、#845）

### Fixed

- **ai-loop Phase 1 安全前提の機械層配線** — fail-closed + allowed_paths + パス正規化（#809、#813）
- **plugin bundle の dead link ゼロ自己完結化**（#790、#793）+ `test_metrics.py` の bundle 追加（#821）
- **check-tag-main-parity をリモート tag 実体照合に変更**（偽 PASS 解消、#787）

### Changed

- **HOTL 境界の正本化** — 非ブロック化部分と Human 固定部分の対応表（#822 項目1、#827）+ stop 条件と巻き戻しの正本化（#832）+ W check = C-3' 命名接続（#828）
- **ai-loop arbiter の分岐テーブル化 + 責務抽出**（動作不変、#814、#816）
- **plugin version を 8.17.0 に更新**（marketplace.json / plugin.json。`claude plugin update` での追従を可能にする）

## v8.16.0 (2026-07-08)

feat: ai-loop 初回実運用 Run-001〜021 の摩擦是正閉ループ + plangate プラグインへの ai-loop 同梱 + Hook Enforcement 物理配線 6/12 → 11/12 + サブエージェント委譲プロトコル正本

次世代ワークフロー「ai-loop」（旧 Arbiter）を Phase 0〜4 の仕様策定に続いて**初めて実運用に投入**し、Run-001〜021 で摩擦（friction）検出 → W チェック（3R 合議）→ loopspec.md / execution-runbook.md への正本化を反復するセルフチューニング閉ループ（F-1〜F-41）を確立した。`ai-loop-cycle` スキルは Agent Skills bundled resources 方式で plangate プラグインへ同梱し、他プロジェクトでの低リスク帯検証を可能にした（#771/#773）。Hook Enforcement は CLI 層 5 件（EH-4/5/EHS-1/2/3）の物理配線を追加して 6/12 → 11/12 に到達（TASK-0141/0143〜0147）。サブエージェント委譲プロトコル正本、doctor 3 チェック追加、review-gate skill 正本化、PostToolUse/Stop 軽量 hook（EH-10/EH-11 候補）、improvement-seeds hygiene 仕様、PreCompact memory guard、plangate-working-discipline skill（v1/v2）も追加。

### Added

- **Hook Enforcement 物理配線 6/12 → 11/12（TASK-0141 / 0143〜0147）**（#625 / #627〜#639 / #642〜#643 / #645〜#647）
  — CLI 層 5 件（EH-4 / EH-5 / EHS-1 / EHS-2 / EHS-3）の hook 物理配線を追加し **6/12 → 11/12** に到達。
  `bin/plangate` / `scripts/hooks/*.sh` / `schemas/*.schema.json` への実適用が **コミット済みで main に
  反映済み**（apply-script の `--apply` 実行結果を含む、仕様のみではない）。
  - **実装は 12/12（既存）／物理配線は 11/12**。EH-7（2 段階レビューなしマージ block）は `bin/plangate doctor`
    可視化のみ・GitHub branch protection 依存で **未配線**（#500 後続）。正本: `docs/ai/hook-enforcement.md`。
  - 追加配線した EH-4/5/EHS-1/2/3 は **CLI 層**で `bin/plangate verify` / `handoff --verify` 実行時に発火。
    完全手動・AI 任せ運用では休眠する（**常時強制は層 A/B の EH-1/2/3/6/8/9**）。
  - TASK-0143: plan（#627）→ 群A hook 配線 EH-4/5/7・C-3 APPROVED（#628）→ EH-4/5/7 CLI 配線 +
    ta-44 テスト + EHS-1〜3 設計（#625）→ bin/plangate EH-4/5 CLI 配線（#629）→ 重複成果物除去（#633）
  - TASK-0141: EH-2 strict JSON 化 + EH-1/2 stdin fallback（#630）
  - TASK-0144: C-3 approval mode（cli/conversation）設計（#631）→ **HO パス実適用**
    （`apply-task-0144-c3-mode.sh --apply` 結果、#632）
  - TASK-0145: EHS-1 strict 発火配線 増分1（#634）→ handoff.md 発行 + 配線状態更新（#636）
  - TASK-0146: EHS-2/3 配線 増分2/3（#637）→ Gemini medium 対応・BLOCK コメント追加（#638）
  - TASK-0145/0146 合流: EHS-1/2/3 bin/plangate 実適用（apply-script 結果、359 PASS、#639）
  - TASK-0141/0143/0144: handoff.md 発行（WF-05 完了資産、#635）
  - 配線実態ドキュメント同期: 6/12→11/12（#642）→ 運用モード別強制実態（CLI 依存度）追記（#647）
  - TASK-0147: validation_bias conductor export 配線 follow-up plan（#643）→ 配線実装
    （apply-script 方式、#645）→ bin/plangate / conductor 実適用（apply-script 結果、#646）

- **ai-loop（旧 Arbiter）Phase 0〜4 + L2 裁定エンジン PoC**（#660〜#662 / #665 / #668〜#669 /
  #671 / #673 / #675 / #678 / #680 / #682 / #696）
  — ai-loop ワークフロー仕様の Phase 0〜4 策定と L2 裁定エンジン PoC。**現状は仕様策定・PoC
  検証段階であり、ai-loop への本番運用切り替えや既存 plan→exec フローの置換は未実施**（既存
  ワークフローと並存、#687 の共存ガイド参照）。
  - Phase 0: コンセプト固定・資産棚卸し・検証スコープ定義（#660）
  - Phase 1/2a: arbiter-policy 正本化 + W チェック拡張フロー（#661）
  - Phase 2b: decision-table.md（二分ルール Decision table・provenance schema・CB）（#662）
  - Phase 2 follow-up: provenance 正本一元化・安全側 severity 既定・責務範囲明記（#665）
  - Phase 1 改訂: lite 判定基準（可逆性要件）+ severity 分類主体確定（#675）
  - Phase 2: L2 裁定エンジン PoC `scripts/ai-loop/arbiter.py` + 59 テスト + runbook（#678）
  - Phase 3: phase3-impact-report.md（影響評価・分岐判断基準・未解決リスク）（#669）
  - L4 PoC: review-feedback-loop.md（レビュー指摘の事前チェック還元閉ループ）（#668）
  - 改称: Arbiter-workflow → ai-loop-workflow（#673）
  - 概念改定: C-2 まで PlanGate 共通化・C-3 を AI 裁定ゲート「C-3'」に置換・merge-ready 責務明記（#680）
  - 3 系統振り返りレビュー指摘 7 件の修正（severity 別軸・class 軸・セクション番号ほか）（#671）
  - 3 レーン監査の還元: §7 欠番解消・D-6/C-6 新設・suppression 初登録・コンフリクト対応手順（#682）
  - 初回実走: runbook に実行スキル 2 件を追記 + provenance 刻印（#696）

- **Plan Review Readiness Gate**（#653 / #663）
  — C-1 self-review 前に `pass / needs_revision / blocked` を判定する計画実行準備ゲートを
  追加。WF-03 完了条件・plangate-insertion-map・plan.md テンプレートを更新（#653）。ドキュメント
  仕様変更向けのレビュー観点を追加（#663）。

- **exploratory intent 追加（8 分類化）・hypothesis-logger スキル実装・WF-07 接続**（#651）
  — intent-classifier に `exploratory` を 8 番目の intent として追加。仮説採番・記録スキル
  `hypothesis-logger` を新規実装。WF-00 に exploratory 判定時の WF-07 推奨 advisory を追加。

- **新規スキル: ai-loop-cycle / pr-watch**（#694 / #695）
  — `ai-loop-cycle`（ai-loop 1 サイクル実行手順 + Model A/B/C/D 委託プロンプト定型、#694）、
  `pr-watch`（PR 監視・状態把握手順、#695）を新設。`subagent-driven-development` に worktree
  委託の安全ルールを追加（#695）。

- **self-review スキル拡張**（#666）
  — シェル/ドキュメント品質観点 + 文章品質チェックを追加。

- **repo-owned 整合性検出スクリプト 2 種**（#700 / #703）
  — stale パス参照検出 `scripts/check-stale-skill-refs.py`（#700）、plugin/repo-local スキル名
  多重定義検出 `scripts/check-skill-name-collisions.py` + 優先順位ガイド（#703）。

- **gh account ドリフト検証の pre-push opt-in 拡張**（#702）
  — 既存 #360 pre-push hook に gh アクティブアカウントのドリフト検証を opt-in 拡張。

- **段階的導入ドキュメント 3 種**（#697〜#699）
  — plugin-only 環境の動作境界と CLI 非依存の最小導入パス（#699）、既存 plan→exec ワークフロー
  との共存・部分導入ガイド（#698）、改称移行（arbiter→ai-loop 等）の grep チェックリスト
  正本（#697）。

- **ai-loop（旧 Arbiter）初回実運用 Run-001〜021 + 摩擦是正閉ループ F-1〜F-41**
  （#734 / #738 / #740 / #743 / #745 / #747〜#748 / #750 / #752 /
  #755 / #757 / #759 / #761 / #763〜#770）
  — Phase 0〜4 の仕様策定に続き、**初めて実運用（本番セッション）に投入**。
  `HUMAN_ESCALATED → 人間判断 → AUTO_APPROVED` のフル経路を完走（Run-001/002、
  #738）した後、Run-003〜021 で摩擦（friction）検出 → W チェック（3R 合議）→
  loopspec.md / execution-runbook.md への正本化、を反復するセルフチューニング
  閉ループを確立した。
  - intake batch1: LoopSpec / loop-safety / Unknown Discovery / HOTL 入口基準
    （#726/#728/#729/#733-A、#734）
  - Run-003: provenance に `reject_category` 追加（初のコード run、#740）
  - Run-004: enum verbatim 強制 + 検証コマンド実機事前検証（#743）
  - Run-005: 検証申告への証跡要求（#745）
  - Run-006: `deterministic` 欄の構造化（cmd/expect_exit/note、#747）
  - Run-007〜010: `#746`/`#749`/`#751`/`#753` intake（loop 4 型の語彙吸収、
    `scope.allowed_paths` 追加、Managed Agents trust boundary 語彙、memory
    trust boundary 宣言機構、#748/#750/#752/#755）
  - doctor に W-6 検知 / skill 名衝突 / pre-push ガード検査を追加
    （#720/#721/#722、#757）
  - Run-012: F-27/F-28 正本化 + **auto-merge 廃止**を運用へ反映（#759、
    以降は merge-ready 運用に一本化）
  - review-gate skill を `.agents/skills` へ正本化（#737、#758）
  - Run-013: improvement-seeds hygiene 仕様正本化 + digest サンプル #001
    （#754、#761）
  - PostToolUse/Stop 軽量品質 hook（EH-10/EH-11 候補）を配線（#760、#762）
  - Run-014〜016: F-29/F-30 正本化（#763）、PR #762 レビュー対応の run 記録
    （#764）、run 採番 2 点照合 + AC 転記規律（F-34/F-35、#765）
  - Run-016（続）: exec 差分への **rubric grader 再試行ループ**を Step 5.5
    として追加（#753 gap 2 PoC、5 項目採点 + 証跡引用義務 + 再試行 ≤2 →
    HUMAN_ESCALATED、#766）
  - Run-018/019: conflict 同定規律 + 参照値転記規律（F-36/F-37、#767）、
    **摩擦 ID 台帳の単一権威化**（F-35〜F-40 索引転記 + 新 ID 発行規律、
    並行セッション由来の転記誤りを 3R で是正、#768）
  - Run-020/021: 実践主張の出典検証 + 実挿入形 AC 事前検証（F-38/F-39、
    #769）、件数集計型 AC の silent pass 対策（F-41、#770）

- **ai-loop-workflow を plangate プラグインへ同梱（#771/#773）**
  — `ai-loop-cycle` スキルを Agent Skills **bundled resources 方式**（skill
  ディレクトリ内に `references/`（正本 docs 17 本のミラー）+ `scripts/`
  （`arbiter.py` 一式）を自己完結同梱）で再設計し、
  `plugin/plangate/skills/ai-loop-cycle/` として配布。
  `sync-plugin-plangate.sh` を拡張し正本 → plugin の同期を冪等化。
  plugin README に導入手順・適用境界（低リスク帯
  限定・PlanGate 本番非適用）を明記。検証: plugin 配下 arbiter 63 テスト
  自立 PASS、フルスイート 387 passed。**他プロジェクトでの検証用途**であり
  PlanGate 本体の運用を置き換えるものではない。

- **サブエージェント委譲プロトコル正本を新設（#710/#711-716）**（#723）
  — 複数エージェントへの作業委譲時の責務分界・引き継ぎ形式・検証手順を
  正本化。

- **PreCompact memory guard**（#742 / #744）
  — `/compact` 実行前に作業コンテキストの鮮度を検査する仕様 + apply-script
  （warn 既定）。

- **plangate-working-discipline skill（v1/v2）**（#735 / #741）
  — Fable 5 の作業規律を PlanGate skill として明文化（8 ファイル）。v2 で
  ai-loop 実運用の学習（原則11/12・停止規律・追加指示の扱い）を還元。

- **secret 判定の policy-grounding ガード**（#731 / #736）
  — secret 判定ロジックに根拠となるポリシー参照を必須化し、`#727` の
  gap 分析をクローズ。

- **ai-loop 設計思想正本 design-philosophy.md**（#732）
  — I-1〜I-9 の設計原則、成長メカニズム、文書地図を新設。

- **ai-loop の bounded adaptive production loop 定義**（#724）
  — 有界な適応的プロダクションループとしての ai-loop の定義を追加。

### Changed

- **improvement-seeds スキーマの OSS 非依存化**（#650）
  — 「1 人運用」記述を「ツール・プロセス上の摩擦点」に変更（既存エントリは append-only の
  ため不変）。
- **依存関係更新**（#649）
  — dependabot による github-actions グループ更新 5 件（`codeql.yml` / `schema-validate.yml`）。
- **依存関係更新（続）**（#730）
  — dependabot による github-actions グループ更新 5 件（追加分）。

### Fixed

- **PR#651/#653 マージ後ドキュメント整合性修正**（#654）
  — skill-policy-router / plan-review-readiness-gate / plangate-plugin-migration /
  00_intent_intake の記述不整合を解消。
- **hypothesis-logger の壊れた相対リンク 3 件を修正**（#701）
  — #700 の stale パス検出スクリプトが検出した実バグを dogfooding 修正。
- **TASK-0123 の偽 DONE を実態へ是正**（#718）
  — Part A は deployed 済みだが Part B（HMAC）は未適用であるにもかかわらず DONE と記録されて
  いた不整合を是正。Part B の適用可否は Human 判断待ちとして明示。
- **stale current-state 是正 + handoff/c3-review 取込（state-audit bookkeeping）**（#717）
  — stale な current-state 9 件を Done へ是正し、未発行 handoff 3 件を発行、c3-review 6 件を
  取り込んで台帳を整合。

### Specification（仕様 + apply-script 提供のみ・HO 実適用は Human 待ち）

> 以下は「仕様策定 + Human-owned 適用スクリプト（`--dry-run` 既定）の提供」までが完了した
> 項目。Hardening Override（HO）対象パス（`.claude/rules/*.md` 等）への実適用（`--apply`）は
> Human-owned であり、本ドラフト時点では**未実行**。上記 Hook Enforcement 項目（実適用済み）
> とは異なり、**enforcement は live ではない**（working-context.md「settings タスクロック」と
> 同型のギャップ）。

- **品質コマンド実行証跡の必須化 仕様**（#706）
  — PR/handoff ゲートでプロジェクト定義の品質コマンド実行証跡（evidence-ledger EvidenceItem）
  を必須化する仕様 `docs/ai/quality-command-evidence.md` + 適用スクリプト
  `scripts/apply-quality-command-gate.sh`（dry-run 既定、`--apply` は Human-owned）。
- **レビュアー沈黙時のフォールバック + 証跡必須化 仕様**（#705）
  — `docs/ai/reviewer-silence-fallback.md` + `scripts/apply-reviewer-silence-gate.sh`
  （dry-run 既定）。
- **workflow-conductor の plan 再実行ガード動的フェーズ表示化 仕様**（#708）
  — `scripts/apply-conductor-dynamic-phase.sh`（dry-run 既定、HO 実適用は未実施）。
- **W-6 autonomous APPROVE の人間著者導入手順 + doctor 検知 仕様**（#707）
  — `docs/ai/w6-autonomous-approve-introduction.md`（仕様のみ、導入自体は未実施）。
- **R-NNN 監査表の C-4 拡張 仕様**（#704）
  — `docs/ai/review-feedback-c4-extension.md` + `scripts/apply-rnnn-c4-extension.sh`
  （dry-run 既定）。

## v8.15.0 - 2026-06-25

feat: Review Gate 機械化 + EH-3 doc-light + approve 強化 + CLI テスト完備 + OpenSSF Scorecard 対応 + Best Practices Passing 取得

外部レビュー結果（Decision / risk）を c3_status へ自動マッピングし承認境界を機械執行する Review Gate（TASK-0129）、EH-3 フックに非 HO `.md` ファイルを記録付きで自動 SKIP する doc-light 経路（TASK-0138）、approve サブコマンドのハードニング（TASK-0139）、CLI サブコマンドの統合テスト完備（TASK-0140）を追加。OpenSSF Scorecard 対応（Pinned-Dependencies / SLSA / Fuzzing / Branch-Protection / SAST / Token-Permissions / SecurityPolicy）と Best Practices Passing バッジ取得を含む。

### Added

- **Review Gate 機械化（TASK-0129 / #543）** — 外部レビューの `Decision`（go / revise_plan / human_approval_required / no_go）と `review_risk`（low / medium / high）を `c3_status` へ自動マッピングし、`bin/plangate exec` での機械執行を実現。`apply-task-0129-schema.sh` / `apply-task-0129-wc.sh` で c3-approval スキーマと working-context を更新。C-1 Loop check（計画ループ検出）を同梱。
- **EH-3 doc-light 経路（TASK-0138 / #528）** — `check-plan-hash.sh` に非 HO `.md` ファイルを記録付き自動 SKIP する doc-light 経路を追加。maintenance ファイル存在時はトークンライフサイクルを優先し doc-light を発火させない。`skip-decision-log.jsonl` に `EH-3_DOC_LIGHT_SKIP` イベントを記録。`ta-39` で 6 TC / 303 PASS。
- **`plangate approve` ハードニング（TASK-0139 / #550）** — approve サブコマンドに `read -r` による理由・条件・確認の対話入力、`PLANGATE_TEST_MODE` ガード、c3.json 上書きブロック（`--force` で上書き可）を追加。ADR `docs/decisions/adr-001-approve-out-of-band.md` を同梱。`ta-41` で 302 PASS。
- **CLI サブコマンド統合テスト（TASK-0140 / #515 #529）** — `ta-42` を新規追加し `bin/plangate` の全サブコマンド（plan / exec / review / approve / validate-schemas / metrics / doctor 等）を統合テストでカバー。302 PASS / 0 FAIL。
- **OpenSSF Scorecard 対応（#616〜#619）** — SHA ピン（actions/checkout@v7 / actions/setup-python@v6 / pip --require-hashes）、Token-Permissions 最小権限化、SECURITY.md 脆弱性報告 URL 追記、CodeQL `security-extended` 追加、SLSA provenance attestation（リリース時 build provenance 自動生成）、atheris Fuzzing（`fuzz/fuzz_render_review.py`）、Branch-Protection（1 reviewer 必須 + stale review dismiss）。
- **OpenSSF Best Practices Passing 取得（#621）** — bestpractices.dev プロジェクト登録・全項目回答・Passing レベル達成。バッジを README / README_en に追加（project ID: 13340）。
- **Code-Review auto-approve apply script（#620）** — `scripts/add-auto-approve-workflow.sh`。APPROVE_PAT（別アカウント PAT）設定後に `--apply` で `auto-approve.yml` を生成。

### Fixed

- **WF-07 Markdown lint（#617）** — `docs/workflows/07_exploratory_debug.md` の MD031/MD032/MD040 11 件 + `execution-sequence.md` の MD012 を解消。
- **pip hash pinning（#616）** — `requirements/schema-validate.txt` を追加し `schema-validate.yml` で `--require-hashes` を強制（OpenSSF Pinned-Dependencies 対応）。
- **README_en v8.15.0 同期（#622/#623）** — 英語 README に v8.14.0〜v8.15.0 の変更点・OpenSSF Best Practices バッジの意義を追記。
- **plangate-setup スキル + Codex スキル追加** — plangate-setup スキル修正・Codex スキル追加・リリースフローへのプラグイン同期組み込み（#597）
- **intent-classifier / skill-policy-router** — PlanGate CLI ops 認識を追加（#593）
- **Gemini V-3 指摘対応** — ta-39 / ta-41 / ta-42 / apply スクリプト群の HIGH・medium 指摘を複数ラウンドで解消（#607）

## v8.14.0 - 2026-06-15

feat: C-3 レビュー HTML 出力（plangate render）+ 人間ワンアクション C-3 承認（plangate approve）

利用者の声「MD は確認しづらい / ファイルが多い / ブラウザで見たい」に応え、C-3 レビュー成果物をブラウザで横断把握できる HTML 出力を導入。あわせて「人間は承認の判断のみ、JSON/CLI 作業は負わない」という PlanGate コンセプトを実機化する承認 CLI を追加。

### Added

- **`plangate render`（C-3 レビュー HTML 出力 / TASK-0127・#546・#552）** — C-3 対象 7 種 MD（pbi-input / plan / todo / test-cases / review-self / review-external / handoff）を **1 枚の自己完結 HTML** に集約。目次アンカー / GFM 表 / チェックボックス / コードブロック / インラインをレンダリングし、HTML エスケープで XSS を防止。外部 CDN / script / 画像参照ゼロ（オフライン・ブラウザ直開き可）。実装 `scripts/render_review.py` は **Python 標準ライブラリのみ**（新規依存なし）。
- **`plangate approve`（人間ワンアクション C-3 承認 / TASK-0128・#546）** — 対話 TTY で承認意思を示すだけで、plan_hash 自動算出・approved_by を git config 解決・`schemas/c3-approval.schema.json` 準拠の c3.json を自動生成（JSON 手書き不要）。`maintenance` 由来の L1-L4 Human-presence 検証（**best-effort**）で非対話実行からの自己承認を抑止。`check-approval-token-write.sh` を Edit\|Write + Bash matcher で配線し承認トークンへの直接書込を block。
- **Loop 安全制御 討議メモ**（#544 / #545）— Loop Engineering の安全制御要素（Verification / Stop Condition / Replan Rule）の PlanGate 取り込み方針。

### Notes

- `plangate approve` の L1-L4 は **best-effort 多層防御**（疑似 TTY バイパスが理論上残る）。out-of-band 化（HMAC 署名 + OS keychain）による strict enforcement は #550 / #527 で継続。
- `plangate render` の SVG 図解（html-diagram）・構造化 html-plan ナビは #548 / #549 で継続。

## v8.13.0 - 2026-06-11

feat: 全体健全化リリース — 監査駆動の鮮度・整合・隔離改善 + エージェント model tier

リポジトリ全体監査（2 ラウンド + Shadow Spec 棚卸し）を起点に、ドキュメント鮮度の回復、テストの実 docs/working 汚染の根治、未使用エージェント/スキルのスリム化、エージェント model tier（Claude: sonnet/inherit、Codex: low/medium effort）の導入、Hook enforcement の実装/配線の実態整合、yaml schema 検証、CLI テストカバレッジ完了（290 PASS）までを収録。

### Added

- **エージェント model tier**（#519）— エージェントを「定型・構造化 / 判断系」の 2 tier に分類し、Claude Code は frontmatter `model:`（sonnet / inherit）、Codex は `model_reasoning_effort`（low / medium、GPT-5.5 の high はトークン消費の運用判断で不採用）で表現。正本 [`docs/ai/model-profiles.md`](docs/ai/model-profiles.md) §11。plugin 配布版は `sync-plugin-plangate.sh` が `model: inherit` へ自動正規化し、利用者環境にモデル固定を持ち込まない。tier の崩れは `tests/extras/ta-33` が CI で機械検査

- **status の BLOCKED 状態 + Deferred ゲート**（#498 / #510）— 外部依存で着手不能なタスクを未着手と区別して明示し、解除条件を一覧化
- **V-1 テスト実行の単一プロセス既定化**（#497 / #509）— 並行 flaky な timeout を fix loop に流す前に単独再実行で切り分け
- **doc-light モード適用スクリプト**（#496 / #503）— mode 分類に変更種別軸 + doc-light を追加する Human 適用スクリプト
- **ブランチ base verify 規範の apply スクリプト**（#505 / #506）— `scripts/apply-responsibility-classes-branch-base.sh`（HO 適用は Human）

### Changed

- **Iron Law #8「NO CLAIM WITHOUT SOURCE CROSS-CHECK」追加**（#494 / #501）— core-contract に主張時の出典突合を義務化
- **ワークフロー責務範囲の明文化**（#487 / #491・#492）— ワークフローは C-4 まで・リリース/公開は責務外。CI 縮退・C-4 自律承認を Specification として正本化
- **WF-05 PR 変更ファイル検証 + HO 仕様+apply フロー正本化**（#505 / #507）、**retro 単発セッション捕捉の改善仕様**（#505 / #508）
- **Wiring Integrity Enforcement 仕様の策定**（#500 / #504）
- **L-0 カスタム静的解析の false-positive canary 必須化ガイド**（#499 / #502）
- **ドキュメント整理 Phase 3**（#488〜#490）— philosophy / oss-governance を docs/pages/ へ移行、markdownlint glob・apply-ho-followups.sh を追随

### Fixed

- **全体監査 + テスト分離**（#511）— ドキュメント鮮度更新（v8.12.0 表記・テスト数実測・管理ディレクトリ文書化）、hooks テストのサンドボックス隔離、tracked 成果物汚染（TASK-9991 残骸・TASK-0059 eval-result・監査ログ fixture ノイズ 114 行）の根治

## v8.12.0 - 2026-06-07

feat: 並列レビューア実行 + Plugin sync 品質ガード + 導入促進・運用ガード整備

`bin/plangate review` の並列レビューア実行（TASK-0122）を追加。Plugin マニフェストの version 二重管理ガード・Codex Plugin 状態検査 helper・実 SSoT 汚染の CI 可視化など plugin sync 周辺の品質を強化。導入検討者向けランディング（Why PlanGate）と HO 待ち運用ガード（status 日時必須・外部レビュー実行不可記録・runtime conductor 運用・AGENTS.md 汚染除去）を整備。3 視点レビュー（セルフ + 別視点 + Gemini）で検出した多数の指摘を反映。

### Added

- **並列レビューア実行**（TASK-0122）— `bin/plangate review` に複数外部レビューアの並列実行を追加。spec ファイルのコマンドに `shlex.quote` を適用。
- **Why PlanGate ランディングページ**（#468-470）— 導入検討者が 3 分で必要性を判断し 5 分で導入を始められる訴求ページ `docs/pages/explanation/product/why-plangate.md`。3 つの価値・段階的導入・成功イメージ・CTA を整理。
- **Codex Plugin 状態検査 helper**（#451 / #472）— `scripts/check-codex-plugin-status.sh`。Codex Plugin の登録 / version / skill 数をネットワーク非依存でローカル検査。`bin/plangate doctor` に non-fatal セクションとして配線。
- **HO 適用スクリプト**（#479）— `scripts/apply-ho-followups.sh`。HO パス変更を Human が冪等・`--dry-run` 付きで 1 コマンド適用。

### Changed

- **Plugin sync 品質改善**（#476 / #478）— 重大度ラベル統一（`MISMATCH` → `ERROR`）、リポジトリ slug 表記ゆれ統一、shallow clone での tag 空テスト追加。
- **運用ガード整備**（#463 → #480）— `status.md` フェーズ履歴の日時 `YYYY-MM-DD HH:mm` 必須、外部レビュー実行不可時の記録規約（§7-ter）、Codex runtime での conductor 相当運用を正本に反映。
- **/plangate-setup 前提条件明示**（#454 → #480）— `bin/plangate` 前提と clone 必要性を `plangate-setup.md` / `setup-coordinator.md` に追記。

### Fixed

- **Plugin version 二重管理ガード**（#456 / #471）— `plugin.json` ↔ `marketplace.json` の version を sync で同期・check で検証。parse 失敗 / 未定義 / 空を ERROR 化。
- **AGENTS.md 汚染除去 + CI 可視化**（#452 → #473 / #480）— `<claude-mem-context>` 汚染ブロックを除去。実 SSoT 汚染を run-tests で可視化（warn-only / `STRICT_AGENTS_CHECK` 切替）。
- **テスト堅牢化**（#474 / #475 / #477 / #478）— sourced テストの `trap` 親シェル汚染をサブシェル隔離で解消、semver 検証の `grep -E` 厳格化、`mktemp` リーク防止、`--online` カバレッジ補完。

### Meta

- 本リリースは issue #451 / #452 / #454 / #456 / #463 / #476 を close。

## v8.11.0 - 2026-06-04

feat: Claude Code / Codex Plugin 正式配布対応 + retrospective scoring 配点変更

Plugin を Claude Code / Codex 双方で `marketplace add` / `install.sh` から導入できる正式配布状態に整備。Codex/Gemini レビューと ultracode 検証 Workflow（5観点並列）で発見した配布ブロッカー（実在しない `codex plugin install` の誤記、install.sh のパス注入・symlink・dry-run 副作用、openai.yaml 仕様非準拠など）を解消。

### Added

- **Plugin 正式配布対応**（TASK-0124〜0126 後続）— Claude Code / Codex Plugin を正式配布可能な状態に整備。
  - `install.sh`: ワンコマンドインストール（`--claude` / `--codex` / `--force` / `--uninstall` / `--version` / `--dry-run`）
  - `.claude-plugin/marketplace.json`: `/plugin marketplace add s977043/PlanGate` / `codex plugin marketplace add s977043/PlanGate` 対応
  - `scripts/check-codex-skill-spec.sh`: openai.yaml 仕様チェック（short_description 25-64 文字・default_prompt `$skill-name` 形式・brand_color）
  - `scripts/install-plangate-skills-to-codex.sh`: `.agents/skills/` → `.codex/skills/` 変換スクリプト
  - `plugin/plangate/scripts/install-plangate-skills.sh`: Plugin 自己完結 Codex インストールスクリプト
  - `.codex/skills/`: 28 スキルを openai.yaml 付きで展開（公式仕様準拠）
  - `plugin.json`: `skills` / `repository` / `license` / `keywords` フィールド追加（公式ベストプラクティス）
  - CI: `sync-plugin-plangate.yml` に仕様チェックステップを追加

### Changed

- **retrospective scoring 配点変更**（TASK-0121）— 振り返りメトリクスを Plan-primacy 思想に整合。計画精度 15→30・効率性 25→10・成果物品質 30 維持（計画で定めた品質の達成度 = 保全達成度として再定義）。計画精度の評価基準に C-1 語彙（受入基準網羅性・スコープ制御・テスト戦略妥当性）を追加。`docs/ai/reporting.md`（§2-bis 新設） / `docs/ai-driven-development.md` を更新、`scripts/check-retro-scoring-consistency.sh` を新規追加。

### Fixed

- **Plugin 配布の堅牢化**（PR #447 / #448 — Codex/Gemini レビュー + ultracode 検証 Workflow）:
  - **Critical**: 4 ドキュメントの `codex plugin install plangate` を削除（`codex plugin` に install サブコマンドは無く配布の入口でエラー）→ `marketplace add` + `install.sh --codex` に修正
  - install.sh: Python コードへのパス直接展開を `sys.argv` 渡しに変更（パス注入防止）、`cp` のシンボリックリンクスキップ、`--dry-run` の mkdir 副作用解消、uninstall の空ディレクトリ除去、python3 ガード
  - openai.yaml 生成: `default_prompt` を `$skill-name` 形式に・`brand_color` 追加・`short_description` を 64 文字以内に UTF-8 安全切り詰め
  - install-plangate-skills-to-codex.sh: awk シングルクォート除去の正規表現破綻を修正（frontmatter 抽出が機能していなかった）
  - sync-plugin-plangate.sh: plugin.json version 比較の v プレフィックス不一致で CI が毎回無駄 PR を作る問題を解消

## v8.10.0 - 2026-05-29

feat: Codex CLI parity 完成 + Hook/Guard 拡充 + Skill 整備 + ドキュメント品質向上

v8.9.0（EPIC #193 完遂）以降に蓄積した TASK-0107〜0120 / Issue #353 の実装群。Codex CLI parity の完成、セキュリティ hardening（INC P-1/P-3 対応）、pre-commit/pre-push guard 拡充、skill 整備、C-3 Autonomous APPROVE ルール明文化を含む。

タグ対象 SHA: `1bde312`（#415 main HEAD）

### Added

#### Codex CLI parity（EPIC #338 / 100% 達成）

- `.codex/hooks.json` + `.codex/hooks/eh-bridge.sh`: Codex CLI 用 PreToolUse hook bridge を新設 (#336 / #347)。EH-1/EH-2/EH-3/EH-6/EH-9 が Codex session 中にも物理発火する。
- `scripts/codex-guarded.sh`: Codex CLI 用 guarded entrypoint (#336 / #343)。session 前後で validate / doctor --check-settings / plan_hash drift 検知を実行。
- `docs/rfc/provider-codex.md`: Codex provider 完全対応ドキュメント (TASK-0109 / #315)。
- `tests/extras/ta-14-codex-guarded.sh` / `ta-15-codex-hook-bridge.sh`: 8 + 7 観点回帰テスト (#345 / #347)。
- `docs/rfc/ai-self-set-gate-hook-enforcement.md`: RFC EH-10 Draft (#339)。
- `docs/ai/settings-wiring-contract.md`: EH-1〜EH-9 強制マトリクス明文化 (#348)。

#### Skill 整備（#325 / #327 / #330 / TASK-0118）

- `.agents/skills/ai-dev-exec` / `ai-dev-verify` / `local-exec-handoff`: Codex CLI / Claude Code 共用 skill 3 本を新設。
- `.claude/commands/codex-mvp-split.md` + skill: MVP 分割判断 command/skill 実装 (TASK-0118 / #352)。
- 既存 5 skill を PlanGate 固有要素（mode 5 段階 / lite_eligible / C-1 17 項目）に整合 (#325 / #327 / #330)。

#### セキュリティ・Guard 拡充

- `scripts/hooks/check-pre-push.sh`: main 直接 push を技術層でブロック (TASK-0114 / #360 / INC P-1)。
- `scripts/check-git-add-scope.sh`: pre-commit で scope 外ファイル混入を機械検知 (TASK-0119)。
- `scripts/hooks/check-ai-memory-pollution.sh`: claude-mem 自動挿入を pre-commit で検知 (TASK-0113 / #355)。
- `scripts/check-tag-main-parity.sh`: NO RELEASE WITHOUT TAG-MAIN PARITY Iron Law (TASK-0116 / #354)。
- `scripts/batch-acknowledge-skip-decisions.py`: skip-decision-log.jsonl 一括追認 CLI (TASK-0110 / #301)。
- `tests/extras/ta-16〜ta-23`: 上記 guard/helper 群の回帰テスト追加。

#### ヘルパー・UX

- `scripts/gh-s977043.sh`: gh account pinning helper (TASK-0120)。
- `/plangate-setup` Command + setup-coordinator Agent + plangate-setup Skill (TASK-0107 / #312)。
- Cursor provider サポート（RFC / quickstart / hook adapters）(#292)。

#### ドキュメント・公開ページ

- `docs/pages/guides/getting-started.md`: 新規ユーザー向け Quickstart を追加。
- `docs/pages/explanation/product/plan-creation-process.md`: 実行計画プロセス解説ガイド。
- `docs/pages/` 全体の相互リンク・品質向上 (#414)。
- `docs/working/incidents/2026-05-26-empty-commit-direct-push.md`: INC-2026-05-26-001 インシデント記録。

#### C-3 運用改善

- C-3 Autonomous APPROVE 基準を明文化 (#353 / #413)。
- plan 事前メトリクス検証 mandatory gate 実装 (TASK-0117 / #351)。

### Changed

- `.claude/rules/mode-classification.md`: 承認境界周辺 9 カテゴリを `lite_eligible=false` 強制 + Standard C-3 同期固定に拡張 (TASK-0112)。
- `.claude/rules/responsibility-classes.md`: Bash 連結コマンド error guard (INC P-3 / TASK-0115) + 自己設置 Gate 非緩和原則を明文化。
- `docs/pages/` を `pages/` から移設 (TASK-0111 / #295)。
- `.mailmap`: kominem-unilabo を s977043 へ非破壊再マッピング (#406 / #407)。
- 既存 5 skill を PlanGate 固有要素に整合、Shadow Prompting 解消 (#325 / #327 / #330)。
- `AGENTS.md`: `.codex/agents/` からの bridge 方針を明記 (#341)。

### Security

- pre-push hook による main 直接 push の技術層ブロック (TASK-0114)。
- claude-mem 自動挿入の pre-commit 検知 (TASK-0113)。
- git add scope guard による scope 外ファイル混入防止 (TASK-0119)。
- `plan-review-gate` skill に `bin/plangate review` 誤起動警告を追加 (#327)。

### Process Notes

- **Codex CLI parity 完成**: EPIC #338 100% 達成。EH-1/2/3/6/9 の物理強制が Codex session にも適用。
- **INC-2026-05-26-001 対応完遂**: empty commit 直接 push 事故に対し規範層 + 技術層 + repo-wide の三段防御を実装。
- **承認境界 Hardening**: 設定ファイル・hook スクリプト等 9 カテゴリへの変更は自動的に high 以上モード + 同期 C-3 が強制。

## v8.9.0 - 2026-05-19

feat: Reporting & Retrospective v1 + reporting 精度 follow-up — EPIC #193 完遂

EPIC [#193 Harness Improvement Roadmap](https://github.com/s977043/plangate/issues/193) の **v8.9.0 milestone（#200）を完走し、roadmap を完全完遂**。Reporting & Retrospective v1（PBI-HI-006 / TASK-0098）で sprint retrospective 統合の基盤を実装し、その後 v1_first_pass / fix_loop の events 由来厳密化（TASK-0102）、test/dev フィルタ + run スコープ（#281 / TASK-0103）、roadmap 完了状態同期（TASK-0104）、EH-3 c3.json plan_hash 抽出の strict JSON 化（#282 / TASK-0105）まで follow-up を継続し、reporting の精度と決定論性を確定させた。

タグ対象 SHA: `345620c`（#285 / TASK-0105、main HEAD）

### Added

- **Reporting & Retrospective v1**（**PBI-HI-006** / #200 / TASK-0098 / PR #274） — events.ndjson から sprint retrospective を導出する reporting 基盤。v1_first_pass / fix_loop など run 成果を集計
- **reporting 精度 follow-up — test/dev フィルタ + run スコープ**（#281 / TASK-0103 / PR #283） — テスト / 開発用 run を集計対象から除外、run 単位スコープで集計精度を向上

### Changed

- **reporting の v1_first_pass / fix_loop を events 由来で厳密化**（#200 v2 / TASK-0102 / PR #280） — 推定ベースから events.ndjson 由来へ切り替え、決定論的集計化
- **scripts パス定数を `_paths.py` へ共有化**（#277 / TASK-0101 / PR #278） — reuse M-2、scripts 横断のパス定数 DRY 化
- **Plan Hash Utility 共有化**（#193 follow-up / TASK-0100 / PR #276） — plan hash 算出の重複排除
- **`/simplify` follow-up — #198 / #199 局所クリーンアップ**（TASK-0099 / PR #275） — Keep Rate / Dynamic Context Engine の局所整理（挙動不変）
- **EH-3 c3.json plan_hash 抽出を strict JSON 化**（#282 / TASK-0105 / PR #285） — 正規表現抽出から厳密 JSON parse へ、plan_hash 突合の堅牢化
- **`docs/ai/harness-improvement-roadmap.md`**: 完了状態へ同期（TASK-0104 / PR #284） — EPIC #193 完遂を roadmap に反映

### Process Notes

- **EPIC #193 完遂**: v8.6.0（P0）→ v8.7.0（P1）→ v8.8.0（P1/P2）→ v8.9.0（P2 / #200）で Harness Improvement Roadmap を完全クローズ。残課題は #277（M-2 V2 backlog）のみ
- **follow-up の継続**: v1 実装（TASK-0098）後に精度・決定論性 follow-up（TASK-0099〜0105）を 5 連続で実施し、reporting を「推定」から「events 由来の厳密集計」へ確定
- **タグ方針**: v8.6.0 リリース後に main へ蓄積された成果を時系列保全するため、当時の版境界コミットに annotated tag を打つ。v8.9.0 は main HEAD `345620c`

## v8.8.0 - 2026-05-18

feat: Keep Rate v1 / Dynamic Context Engine v1 / Model Profile v2 / Gate Event Normalization / Dogfooding Eval v1

EPIC [#193](https://github.com/s977043/plangate/issues/193) の **v8.8.0 milestone（5 件: #197 #198 #199 #230 #231）を完走**。Gate Event Normalization 正本（#230）と Dogfooding Eval v1（#231）で events / 評価基盤を整え、その上に Model Profile v2（#197）/ Keep Rate v1（#198）/ Dynamic Context Engine v1（#199）を実装。harness の自己評価・context 分離・モデル特性対応が揃った。

タグ対象 SHA: `7e3ea4e`（#273 / TASK-0097 #199 Dynamic Context Engine v1、v8.8.0 milestone 最終マージ）

### Added

- **Gate Event Normalization 正本**（**PBI-HI-014** / #230 / PR #261） — Gate イベントの正規化スキーマを正本化（v8.8.0）
- **Dogfooding Eval v1**（#231 / PR #262） — single judge + rationale 形式の自己評価 eval（v8.8.0）
- **Model Profile v2**（**PBI-HI-003** / #197 / TASK-0095 / PR #271） — edit interface preference / retry strategy / provider capability / unknown model fallback
- **Keep Rate v1**（**PBI-HI-004** / #198 / TASK-0096 / PR #272） — Code / Plan / Acceptance / Handoff Keep Rate の計測
- **Dynamic Context Engine v1**（**PBI-HI-005** / #199 / TASK-0097 / PR #273） — context manifest による契約 / 作業 context 分離

### Changed

- events / schema 基盤を Gate Event Normalization（#230）で正規化し、後続の Keep Rate / Dynamic Context / Reporting が同一 events 源を参照できる構造に統一

### Process Notes

- **依存順守**: events 正規化（#230）/ Dogfooding Eval（#231）を先に置き、その上に #197 / #198 / #199 を実装
- **版境界の近似**: v8.7.0 と v8.8.0 の作業はマージ時系列が交錯している（#230 / #231 が v8.7.0 の #224〜#227 / #196 / #203 / #204 / #213 より先にマージ）。SHA を版単調にするため、v8.8.0 タグは v8.8.0 milestone の最終マージ `7e3ea4e`（#199）に打つ。この SHA は #230 / #231 を含む全 v8.8.0 作業を内包する（v8.7.0 タグ `d0bd6cc` 配下に #230 / #231 が含まれる点は既知の近似として許容）
- **タグ方針**: 当時の版境界コミットに annotated tag を打つ（v8.8.0 = `7e3ea4e`）

## v8.7.0 - 2026-05-18

feat: Harness Improvement Roadmap P1 + TASK-0071 Governance Hardening / Feedback F1〜F5 完遂

EPIC [#193](https://github.com/s977043/plangate/issues/193) の **v8.7.0 milestone（9 件: #196 #203 #204 #213 #224 #225 #226 #228 #229）を完走**。加えて同期間に milestone 外の **TASK-0071 群**（Feedback F1〜F5 / Governance Hardening / #227 river-reviewer 標準 IF 正本化 / TASK-0089）を完遂し、exec 委譲デッドロック恒久対処・委譲 commit 境界強制・Lite 分岐 + C-3 条件付き降格・責務 4 分類正本化・Shadow Config ロック + drift CI を導入。harness の強制力と運用堅牢性が大きく前進した。

タグ対象 SHA: `d0bd6cc`（#270 / TASK-0094 #204 PlanGateBench Fixture Suite、v8.7.0 milestone 最終マージ）

### Added

- **Eval comparison for harness changes**（**PBI-HI-002** / #196 / TASK-0092 / PR #268） — mode 別 release blocker 判定、metrics v1 連携
- **Tool Error Taxonomy and Recovery Policy**（**PBI-HI-010** / #203 / TASK-0093 / PR #269） — tool error 分類・回復・計測
- **PlanGateBench Fixture Suite**（**PBI-HI-011** / #204 / TASK-0094 / PR #270） — eval fixture 固定 + regression 検知
- **Lightweight Plan Quality Checks**（**PBI-PQ-001** / #213 / TASK-0091 / PR #267） — 軽量 plan 品質チェック
- **Run Outcome Review v1 テンプレート**（**PBI-HI-012** / #228 / PR #259） — run 結果レビュー定型（v8.7.0）
- **Trace Timeline v1**（#229 / PR #260） — schema 1.1 additive + `metrics --timeline`（experimental / v8.7.0）
- **Plugin モード成熟化と手動コピーからの移行パス**（#224 / TASK-0090 / PR #266）
- **バージョニング安定性ポリシー正本化**（#225 / TASK-0087 / PR #263）
- **段階的導入ガイド（ultra-light→standard 成長パス）**（#226 / TASK-0088 / PR #264）
- **river-reviewer 外部レビューア標準 IF 正本化**（#227 / TASK-0089 / PR #265） — `docs/ai/external-reviewer-interface.md`
- **TASK-0071 Feedback F1〜F5**:
  - F1: exec 委譲デッドロック恒久対処（ケイパビリティ分岐 + 直接実行フォールバック / TASK-0072 / PR #245）
  - F2: exec 強制力ギャップ（委譲 commit 境界強制 + exec 前プリフライト / TASK-0073 / PR #246、§5-bis 統合 TASK-0078 / PR #252）
  - F3: Design/UI Addendum（UI 条件付き・Figma 有無で真実源分岐 / TASK-0074 / PR #247）
  - F4: opt-in 終端 Retro フェーズ（振り返りドラフト自動生成・承認境界維持 / TASK-0075 / PR #248）
  - F5-BC: C-2 責務分離 + 反映差分管理（TASK-0076 / PR #249）
  - F5-AD: Lite 分岐 + C-3 条件付き降格（計画 TASK-0077 / PR #250、実装 TASK-0079 / PR #253）
- **Governance Hardening**: Manual Gate + Shadow Config ロック + drift CI（TASK-0080 S1+S2 / PR #254）、責務 4 分類 rules 正本化（TASK-0081 / PR #256）、EH-3 メンテモード + SKIP_REASON（TASK-0082 S3 / PR #257）
- **EH-3 P4(d) file-path-sensitive SKIP**（TASK-0070 / PR #243）
- **doctor hook-wiring check + deterministic `--fix`**（TASK-0069 / PR #240 ほか）

### Changed

- **`bin/plangate doctor`**: hook-wiring check と決定論的 `--fix` を追加（TASK-0069）
- **`.claude/rules/`**: 責務 4 分類正本（`responsibility-classes.md`）を追加し、hybrid-architecture / orchestrator-mode / working-context から参照
- **EH-3 hook**: メンテモード + `SKIP_REASON` 対応（TASK-0082）、file-path-sensitive SKIP（TASK-0070）
- **codex sandbox_mode**: 不正値 `"workspace-read"` を `"read-only"` に修正（PR #242）
- **`docs/ai/harness-improvement-roadmap.md`**: v8.7.0 ロードマップを Option D に組み替え（PR #232）
- **README / philosophy**: PlanGate の本質的価値メッセージを反映（PR #233）
- **v8.6.0 リリース後改善 7 PR**（#215〜#221）: metrics privacy 強制 / 利用者向け doc 強化 / metrics 自動取得 / baseline 正式化 / 整合性検査強化 / observability / 機械可読化（retrospective #222 で集約）

### Process Notes

- **TASK-0071 完全クローズ**: F1〜F5 + Governance Hardening + #227 / TASK-0089 を含む TASK-0071 群を D-1 全 3 スライス完了で親 handoff 発行（PR #258）
- **承認境界不変**: F5-AD（Lite 分岐 / C-3 条件付き降格）は承認境界を撤廃せず「同期 / 非同期の選択」に限定。opt-in 既定 OFF で既存挙動不変
- **版境界の近似**: マージ時系列が v8.7.0 / v8.8.0 で交錯（#230 / #231 が v8.7.0 群より先にマージ）。SHA 単調性を優先し、v8.7.0 タグは v8.7.0 milestone の最終マージ `d0bd6cc`（#204）に打つ。この SHA は全 v8.7.0 作業を内包するが、先にマージされた #230 / #231（v8.8.0）も含む。これは交錯マージ下での最善近似であり、v8.8.0 タグ `7e3ea4e` が #230 / #231 を含む全 v8.8.0 作業を内包することで版の意味は保たれる
- **タグ方針**: 当時の版境界コミットに annotated tag を打つ（v8.7.0 = `d0bd6cc`）

## v8.6.0 - 2026-05-04

feat: Harness Improvement Roadmap Phase 0/1 + Governance — v8.6.0 milestone 完走

EPIC #193 [Harness Improvement Roadmap](https://github.com/s977043/plangate/issues/193) の **v8.6.0 milestone P0 4 件すべて完走**。改善前 baseline 固定（#194）と運用 governance（#201, #202）を先に置き、その上に Metrics v1（#195）を実装。これにより以後の harness 改善（#196 Eval expansion / #197 Model Profile v2 / #198 Keep Rate / #199 Dynamic Context）を **比較で判断** できる基盤が整った。

### Added

- **`docs/ai/issue-governance.md`**（**PBI-HI-007** / #201 / TASK-0059） — Issue 必須セクション / Label taxonomy（kind / area / priority / status の 4 軸）/ Milestone mapping policy（推測禁止条項）/ Roadmap PBI 作成 checklist（10 項目）/ Issue template policy / EPIC governance を正本化
- **`.github/ISSUE_TEMPLATE/plangate-roadmap-task.yml`**（#201） — Roadmap PBI 用 GitHub Issue Form。Why / What / AC / Non-goals / Labels / Milestone を必須入力として強制
- **`docs/ai/metrics-privacy.md`**（**PBI-HI-008** / #202 / TASK-0060） — Metrics v1 実装前の privacy / public data policy。保存可能 12 カテゴリ / 禁止 9 カテゴリ / file path / stack trace / command output / provider metadata の扱い / redact / sanitize / 完全除外 / retention 90日 / public-private 別運用差分
- **`docs/ai/eval-baselines/2026-05-04-baseline.{md,json}`**（**PBI-HI-000** / #194 / TASK-0061） — v8.5.0 直後の baseline。代表 5 TASK（TASK-0050/0054/0055/0056/0057）で 8 観点 eval、機械可読 JSON snapshot、後続改善との比較ポイント
- **`schemas/plangate-event.schema.json`**（**PBI-HI-001** / #195 / TASK-0062） — 11 events（task_initialized / plan_generated / c3_decided / exec_started / hook_violation / v1_completed / fix_loop_incremented / external_review_completed / pr_created / c4_decided / handoff_completed）。conditional required（c3 / c4 / v1 / hook / fix_loop）。privacy §3 Allowed のみ（§4 Forbidden は schema 上に存在させない）
- **`scripts/metrics_collector.py`**（#195） — TASK ディレクトリから 6 events 自動導出 + NDJSON append。`--dry-run` / `--events-log` 対応。mode 自動検出、AC count を ✅PASS/❌FAIL/⚠️WARN マーカーから抽出
- **`scripts/metrics_reporter.py`**（#195） — events.ndjson から TASK / aggregate summary。`--json` 対応、hook violation / C-3 / V-1 / C-4 / fix_loop_max / mode を集計
- **`docs/ai/metrics.md`**（#195） — 9 章運用 guide（CLI 使用例 / privacy / schema 検証 / baseline 比較 / 後続改善との接続点）
- **`tests/extras/ta-09-metrics.sh`**（#195） — 8 test cases（schema validation / c3_decided 検出 / v1_completed 検出 / aggregate report / JSON output 含む）
- **`pages/`**（PR #205） — River-Reviewer 参考の公開ドキュメント構造（overview / pm-po-elevator-pitch / before-after / positioning / value-proposition-canvas / demo-script / FAQ / governance/documentation-management）+ `sidebars.js`
- **`docs/ai/harness-improvement-roadmap.md`**（PR #192） — EPIC #193 の正本ドキュメント

### Changed

- **`bin/plangate`**: `metrics` サブコマンド追加（`--collect` / `--report` / `--aggregate` / `--json` / `--events-log`）。help text と dispatcher も更新
- **`.gitignore`**: `docs/working/_metrics/events.ndjson` を除外（[metrics-privacy.md §8](docs/ai/metrics-privacy.md) 準拠、public repo に commit させない）
- **`pages/guides/governance/documentation-management.md`** 冒頭に `Related: docs/ai/issue-governance.md` を追記（doc 配置側 / Issue 運用側の 2 ファイル体制を明示）
- **README.md / README_en.md**（PR #190） — v8.5.0 状態に同期、Hook enforcement 10/10、CLI tests 24 PASS / Hook tests 42 PASS、最新状態セクション追加
- **GitHub milestones**: `v8.6.0` / `v8.7.0` / `v8.8.0` / `v8.9.0` を新規作成。EPIC #193 配下の子 PBI 11 件 (#194〜#204) を EPIC の表通りに一括訂正（v7.x 誤紐付けからの復元）
- **`tests/run-tests.sh`**: 24 → **32 PASS**（ta-09 で +8 件、既存 24 件は 0 件 regress）

### Process Notes

- **v8.6.0 milestone P0 完走**: #194 Baseline alignment / #201 Issue/Label/Milestone Governance / #202 Metrics Privacy / #195 Metrics v1 の 4 件、すべて 1 セッション内で連続実装・マージ
- **依存順守**: governance（#201）/ privacy（#202）/ baseline（#194）を先に整備してから Metrics v1（#195）を実装。schema 設計時に privacy §3/§4 が先行参照され、§4 Forbidden は schema 上に存在しない設計を強制
- **マージ戦略**: 全 PR を admin squash merge（branch protection 下、CI all green、thread resolve 後）
- **PR 連動**: 8 PR（#190 / #192 / #205 / #206 / #207 / #208 / #209 + 本リリース PR）を v8.5.0 → v8.6.0 期間にマージ
- **再発防止**: milestone 不整合（11 PBI が誤って v7.x 系列に紐付き）は本リリースで全件訂正。今後は `plangate-roadmap-task.yml` テンプレートと issue-governance.md §4「推測禁止条項」で再発防止

### Next EPIC 候補（v8.7.0 / v8.8.0 / v8.9.0）

- **v8.7.0 (P1, 4 件)**:
  - #196 Eval comparison for harness changes — mode 別 release blocker 判定、metrics v1 連携
  - #197 Model Profile v2 — edit interface preference / retry strategy / provider capability / unknown model fallback
  - #203 Tool Error Taxonomy and Recovery Policy — tool error 分類・回復・計測
  - #204 PlanGateBench Fixture Suite — eval fixture 固定 + regression 検知
- **v8.8.0 (P1/P2, 2 件)**:
  - #198 Keep Rate v1 — Code / Plan / Acceptance / Handoff Keep Rate
  - #199 Dynamic Context Engine v1 — context manifest による契約 / 作業 context 分離
- **v8.9.0 (P2, 1 件)**:
  - #200 Reporting & Retrospective — sprint retrospective 統合
- **その他**:
  - Hook 側からの metrics 自動 emit（v8.7+ 候補、Metrics v1 完了で道筋確定）
  - GitHub API 経由 pr_created / c4_decided 取得（metrics v1 v2 候補）

## v8.5.0 - 2026-05-01

feat: Hook enforcement 完成 — 10/10 hooks 実装 (#169 EPIC 完走)

v8.4.0 で確立した 3 mode hook 設計（default warning / strict block / bypass escape）を全 spec に適用し、**Issue #169 残 Hook EPIC を完走**。`docs/ai/hook-enforcement.md` の Status は v3 → **v5 (Implementation: 10/10 hooks Done)** に到達、`tests/hooks/run-tests.sh` は 21 → **42 件 PASS** に成長。同 release で v8.4 baseline 自動測定 + extras README 拡充も完了。

### Added

- `scripts/hooks/check-plan-exists.sh`（**EH-1**、PreToolUse） — plan.md なし production code 編集 block（#183 / TASK-0056）
- `scripts/hooks/check-plan-hash.sh`（**EH-3**、PreToolUse + CLI） — c3.json plan_hash と現 plan.md sha256 突合（#183 / TASK-0056）
- `scripts/hooks/check-test-cases.sh`（**EH-4**、CLI） — V-1 前に test-cases.md 不在を warn / block（#184 / TASK-0057）
- `scripts/hooks/check-verification-evidence.sh`（**EH-5**、CLI） — PR 作成前に evidence/ verification 系不在を warn / block（#184 / TASK-0057）
- `scripts/hooks/check-forbidden-files.sh`（**EH-6**、PreToolUse + CLI） — 子 PBI YAML の forbidden_files glob と編集対象 path を fnmatch で突合（#184 / TASK-0057）
- `scripts/hooks/check-merge-approvals.sh`（**EH-7**、CLI） — マージ前に c3.json + c4-approval.json の両 APPROVED を確認（#185 / TASK-0058）
- `scripts/hooks/check-v3-review.sh`（**EHS-1**、CLI、mode 連携） — standard / high-risk / critical で V-3 review 必須化、light / ultra-light は SKIP（#185 / TASK-0058）
- `tests/extras/README.md` に「set -e 互換書法」セクション — command substitution の exit code 捕捉パターン（#182）
- `docs/ai/eval-comparison-template.md` に **v8.4 baseline** 行 + v8.3→v8.4 比較テーブル（#181 / TASK-0055）
- `docs/ai/eval-baseline-procedure.md` を v2 化（自動手順を主、v8.3 手動を後方互換）

### Changed

- `docs/ai/hook-enforcement.md` Status v3 → **v5**（10/10 hooks Done、§ 4 表に全 hook 完備、§ 4.5「全 10 hook 完了 (#169 完走)」）
- `.claude/settings.example.json`: PreToolUse に EH-1 / EH-3 / EH-6 を追加（**EH-1 + EH-2 + EH-3 + EH-6** の 4 hook 構成）
- `tests/hooks/run-tests.sh`: 12 → **42 件 PASS**（fixture 8 種追加）
- `tests/run-tests.sh`: 24 件 PASS 維持（変動なし、loader 経由）

### Process Notes

- **Issue #169 EPIC を 4 セッション × 計 11 PR で完走**（#157 前段の EH-2/EHS-2/EHS-3 + #183 EH-1/EH-3 + #184 EH-4/EH-5/EH-6 + #185 EH-7/EHS-1）
- 同日（2026-05-01）に 7 セッション連続実行で 16 PBI 完走、25 PR マージ、12 Issue close、累積 V2 候補ゼロを達成
- 全 10 hook で **3 mode 設計**（default / strict / bypass）+ 監査ログを統一、`tests/extras/` 構造（#170）でマージ衝突源を根絶した状態を維持

### Next EPIC 候補（V2）

1. **EH-7 上位拡張**: GitHub branch protection / ruleset 自動適用（外部 GitHub API 操作、別 PBI）
2. **EHS-1 phase 分離**: C-2 vs V-3 で review-external.md を分離する運用モデル
3. **Hook subcommand 統合**: `bin/plangate hook <name>` への CLI 統合
4. **claude-cli session log parser**（#168 v2、対話履歴 JSONL 統合）
5. **tool_call_count 抽出**（codex JSONL の response_item 解析）
6. **session log 自動検出**（cwd → 最新 rollout 推測）
7. **共通 hook helper**（`scripts/hooks/_lib.sh` で emit_judgment / log_event を集約、現状は 10 ファイル × 各 50〜100 行で許容範囲）

## v8.4.0 - 2026-05-01

feat: 自動化基盤の節目 — eval runner / schema validate CI / hook enforcement / 環境改善

v8.3.0（最新実行モデル対応 + eval framework 仕様）で整備した基盤を、**実 CI / 実 CLI / 実 hook** に落とし込んだリリース。retrospective Try T-1〜T-6 のうち 6 件 + 派生 V2 候補 5 件を消化、合計 11 PBI（TASK-0045〜0054）を完走。マージ済 18 PR（#161〜#178）。

### Added

- `scripts/check-pr-issue-link.sh` + `.github/workflows/check-pr-issue-link.yml` — 子 PBI auto-close 漏れ防止 CI（PBI #170 / Issue #159 → TASK-0045）
- `docs/ai/eval-comparison-template.md` の v8.3 baseline 行 + `docs/ai/eval-baseline-procedure.md` — 8 観点 baseline + 集計手順（PBI #155 → TASK-0046）
- `scripts/validate-schemas.py` + `bin/plangate validate-schemas` + `.github/workflows/schema-validate.yml` — JSON artifact の schema 機械検証（PBI #158 → TASK-0047）
- `docs/ai/contracts/{plan,review,verify,handoff,classify}.md` に schema reference を追加（PBI #158）
- `scripts/hooks/check-c3-approval.sh` / `check-handoff-elements.sh` / `check-fix-loop.sh` — EH-2 / EHS-2 / EHS-3 の 3 mode 設計 hook（default warning / `PLANGATE_HOOK_STRICT=1` で block / `PLANGATE_BYPASS_HOOK=1` で escape）（PBI #157 → TASK-0048）
- `.claude/settings.example.json` — opt-in な PreToolUse / SessionStart hook 登録例
- `tests/hooks/run-tests.sh` + 各 fixture — hook 単体テスト 12 ケース
- `bin/plangate eval` + `scripts/eval-runner.py` + `schemas/eval-result.schema.json` — 8 観点機械評価 CLI、baseline 比較、release blocker 違反検知（PBI #156 → TASK-0049）
- `docs/ai/eval-runner.md` — eval CLI の正本仕様
- `tests/extras/` ディレクトリ + `tests/extras/README.md` — 拡張テストブロック分離による衝突源根絶（PBI #170 → TASK-0050）
- `scripts/schema_mapping.py` — `FILENAME_TO_SCHEMA` を 1 箇所集約（DRY、PBI #172 → TASK-0051）
- `scripts/gh-pin-account.sh` + SessionStart hook — gh CLI active account 自動固定 shim（PBI #171 → TASK-0052）
- `scripts/parsers/codex_log_parser.py` + `--session-log` option — Codex JSONL から latency / tokens を実測値化（PBI #168 → TASK-0054）
- `tests/fixtures/codex-log/sample.jsonl` — 実 codex rollout の最小 fixture
- `docs/working/retrospective-2026-05-01.md` + `retrospective-2026-05-01-s2.md` — 2 セッションの振り返り

### Changed

- `bin/plangate` v0.1.0 → **v0.2.0** — `validate-schemas` / `eval` サブコマンド追加、help 拡充
- `scripts/eval-runner.py` v1.0.0 → **v1.2.0** — schema_mapping 共通化（v1.1）+ codex session log parser 統合（v1.2）
- `schemas/c3-approval.schema.json` / `schemas/c4-approval.schema.json` — `patternProperties: { "^_": {} }` を追加し human-readable annotation を許容（PBI #167 → TASK-0053）
- `docs/ai/hook-enforcement.md` — Status v1（Spec only）→ **v2 (Implementation: Done)**、§ 4 全面書換
- `docs/ai/eval-plan.md` 引き継ぎ先を eval-runner / structured-outputs CI に明記
- `docs/ai/structured-outputs.md` — § 8 マイグレーションガイド追記
- `docs/ai/eval-cases/format-adherence.md` — Detection 手順を新 CI に整合
- `docs/schemas/child-pbi.yaml` — optional `related_issue: <int>` フィールドを追記
- `tests/run-tests.sh` — base test + extras loader 構造に再設計、合計 21 → **24 件 PASS**

### Fixed

- 既存 PBI（PBI-116 配下）の c3.json schema 違反問題を schema 緩和で解消（PBI #167 → TASK-0053）

### DX / Process

- gh CLI active account 自動固定により、plangate 作業中の auth 切戻による mutation 失敗を抑止
- handoff.md 必須 6 要素を全 11 PBI で 100% 出力（Rule 5 遵守）
- eval-result.json は `release_blocker_violations` 配列に違反を記録、stderr WARNING + exit 1 で CI 統合可能

### Process Notes

- **Auto Mode 連続実行**: 同日（2026-05-01）に 3 セッションで 11 PBI を完走、合計 12 PR マージ・10 Issue close（うち 5 件は同日中に起票・解消）
- **マージコンフリクト**: 5 PR 連続実装の後半（#163 / #164 / #165）で `tests/run-tests.sh` 末尾領域に衝突発生 → PBI #170 で `tests/extras/` 分離に再設計し根絶
- **3 モード Hook 設計**: critical mode の作業妨害リスクを default warning で回避、strict は環境変数で opt-in、bypass は監査ログに記録

### Next EPIC 候補（V2）

1. **#169 残 Hook 実装**（EH-1 / EH-3〜EH-7 / EHS-1 = 7 hook、3 セッション分割推奨）
2. claude-cli session log parser（codex のみ実装済、対話履歴の保存場所要調査）
3. tool_call_count 抽出（codex JSONL の response_item 解析）
4. session log 自動検出（cwd → 最新 rollout 推測）

## v8.3.0 - 2026-04-30

feat: 最新実行モデル対応 — Outcome-first / Model Profile / Prompt Assembly / Eval 基盤 (EPIC #116)

PlanGate v8.2 milestone 中核 EPIC として、GPT-5.5 以降の outcome-first モデルに対応する基盤を整備。
Orchestrator Mode 実運用ケース第一号として親 PBI（PBI-116）を 6 子 PBI に分解、4 phase で実行。
17 PR（#126〜#151）をマージ、parent-AC × 8 全 PASS / Open Gap 0 / Release blocker 0 で完了。

### Added

- `docs/ai/core-contract.md` — Iron Law 7 項目を outcome-first 形式で正本化（PBI-116-01）
- `docs/ai/model-profiles.yaml` — 実行モデル別 4 profile（gpt-5_5 / gpt-5_5_pro / gpt-5_mini / legacy_or_unknown）（PBI-116-02）
- `schemas/model-profile.schema.json` — Model Profile JSON Schema（PBI-116-02）
- `docs/ai/prompt-assembly.md` — 4 層 Prompt Assembly（base_contract / phase_contract / risk_mode_contract / model_adapter）（PBI-116-03）
- `docs/ai/contracts/` × 7（各 phase 別 contract 定義）+ `docs/ai/adapters/` × 4（profile 別 adapter）（PBI-116-03）
- `docs/ai/structured-outputs.md` + 4 schema（review-result / acceptance-result / mode-classification / handoff-summary）（PBI-116-04）
- `docs/ai/responsibility-boundary.md` / `docs/ai/tool-policy.md` / `docs/ai/hook-enforcement.md`（PBI-116-04, 06）
- `docs/ai/eval-plan.md` — model migration eval framework 8 観点 / 4 観点を release blocker（PBI-116-05）
- `docs/ai/eval-cases/` × 8 — scope-discipline / approval-gate / verification-honesty / format-adherence（release blocker）+ ac-coverage / stop-behavior / tool-overuse / latency-cost（WARN）（PBI-116-05）
- `docs/ai/eval-comparison-template.md` — prompt × model profile × reasoning effort 比較表（PBI-116-05）
- `docs/working/PBI-116/` 親 PBI artifact 一式（parent-plan / dependency-graph / parallelization-plan / integration-plan / risk-report / handoff / approvals）

### Changed

- `CLAUDE.md` — 43 行 → 21 行に薄型化、Iron Law を `core-contract.md` に分離参照（PBI-116-01）
- `AGENTS.md` — 61 行 → 29 行に薄型化、Codex 共有プロンプトを Core Contract 経由に統合（PBI-116-01）

### Process Notes

- Orchestrator Mode 実運用ケース第一号として 4 phase 構成（並行 → 順次 → 順次 → 順次）で運用検証
- Phase 2 の 3 並行子 PBI を Codex C-2 統合レビュー 1 回で処理（呼び出しコスト 1/3 圧縮）
- 全 6 子 PBI で `handoff.md` 必須 6 要素出力（Rule 5 遵守）
- Parent Integration Gate 通過記録: `docs/working/PBI-116/approvals/parent-integration.json`
- 振り返り: `docs/working/retrospective-2026-04-30.md` § PBI-116 EPIC 完了

### Next EPIC 候補（V2）

1. v8.2 baseline 測定 PBI（本 eval framework での初回測定）
2. eval runner 実装 PBI（reasoning_token / latency / tool call 集計の自動化）
3. Hook enforcement 実装 PBI（plan 未承認 block 等のハード強制）
4. Structured Outputs 実 LLM 適用 PBI（schema validate CI 統合含む）

## v8.2.0 - 2026-04-28

feat: Parent-Child PBI Orchestrator Mode 仕様策定 + ドキュメント同期 (#111 #112 #113 #114)

### Added

- `docs/orchestrator-mode.md` — Parent-Child PBI Orchestrator Mode のアーキテクチャ正本（Issue #109、Spec only / 実装は別 PBI）
- `docs/schemas/child-pbi.yaml` — 子 PBI YAML スキーマ + バリデーション規則
- `docs/workflows/orchestrator-decomposition.md` — 親 PBI → 子 PBI 分解 Workflow（D-1〜D-7）
- `docs/workflows/orchestrator-integration.md` — 子 PBI 統合 → 親 PBI 完了判定 Workflow（I-1〜I-4 + Gap 分岐）
- `docs/working/templates/parent-plan.md` / `dependency-graph.md` / `parallelization-plan.md` / `integration-plan.md` — 親 PBI 用 4 種テンプレート
- `.claude/rules/orchestrator-mode.md` — Gate 不変条件（ChildExecAllowed / ParentDone / NewChildPBIAllowed）の正本
- `docs/rfc/plangate-decompose.md` — `plangate decompose` CLI RFC（Status: Draft）
- `scripts/check-orchestrator-docs.sh` — Orchestrator Mode ドキュメント整合性検証スクリプト（TC-01〜TC-20）
- README に CLI セクション追加（`bin/plangate init/status/validate/review/exec` の使用例）
- README「中核アイデア」表に Control OS 行追加

### Changed

- `docs/plangate-v7-hybrid.md` — Mode×Gate×Skill 表を `skill-policy-router` 正本に同期、`critical` の rollback / security review / staged deploy を補足
- `docs/plangate-plugin-migration.md` — Rules (8) → (9) 修正、Provider RFC と Workflow DSL 接続を「完了済み」に移動、14 skills 呼び出し例追加
- `docs/plangate.md` — 「ライト / フル」2 分類 → 5 モード表へ置換
- `docs/ai-driven-development.md` — `フルのみ` → `high-risk / critical のみ` に置換、5 モード表へ更新
- `README.md` / `README_en.md` — install warning を NOTE に緩和（dual-mode 可・`plangate:` prefix 注記）、Repository Layout に `/bin` `/workflows` `/tests` を追加、Testing を v8.1.0 の 10 件テストに更新
- `docs/index.md` — Orchestrator Mode 仕様へのリンク追加

## v8.1.0 - 2026-04-27

feat: Provider CLI 対応 — validate --mode、review（Gemini CLI）、exec（OpenCode）コマンド追加 (#107)

### Added

- `bin/plangate validate --mode <mode>` — `workflows/<mode>.yaml` を読み込み、`gate_enforcement.c3.required_artifacts` から artifact リストを動的決定
- `bin/plangate review <TASK-XXXX>` — 外部 AI レビューコマンド。`PLANGATE_EXTERNAL_REVIEWER=gemini` で Gemini CLI を呼び出し、結果を `review-external.md` に書き出す
- `bin/plangate exec <TASK-XXXX>` — 実装エージェント dispatch。C-3 gate をクリアしないとブロック。`PLANGATE_IMPL_AGENT=opencode` で OpenCode を起動
- `bin/plangate doctor` — gemini / opencode CLI の存在を INFO として表示（次セクション参照）
- `tests/run-tests.sh` — validate --mode、review、exec の新規テスト 6 件追加（合計 10 件）

## v8.0.2 - 2026-04-27

docs: README 日本語メイン化・plugin migration guide 0.5.0 対応 (#100 #101 #102 #103)

### Changed

- `README.md` — 日本語版に差し替え（English README は `README_en.md` へ移動）
- `README_en.md` — 新規作成（English primary README、旧 README.md の内容）
- `docs/plangate-plugin-migration.md` — plugin 0.5.0 対応・手順を最新化
- `docs/working/README.md` — `full` → `high-risk` 表記を修正

## v8.0.1 - 2026-04-27

docs: examples/minimal-node/ 追加 — Node.js 最小構成サンプル (#93)

### Added

- `examples/minimal-node/README.md` — Node.js/Express プロジェクトへの PlanGate 導入手順サンプル
- `examples/minimal-node/CLAUDE.md` — プロジェクト向け最小 CLAUDE.md テンプレート

## v8.0.0 - 2026-04-27

feat: v8.0 — Workflow DSL・Provider RFC・CLI テストスイート (#81 #82 #83) (#98)

### Added

- `workflows/` — Workflow DSL (YAML) 5種（ultra-light / light / standard / high-risk / critical）
  - 各フェーズの完了条件・入出力・担当エージェントを機械可読形式で定義
- `docs/rfc/provider-gemini-cli.md` — Gemini CLI Provider RFC（外部レビュー役割）
- `docs/rfc/provider-opencode.md` — OpenCode Provider RFC（実装エージェント役割）
- `tests/run-tests.sh` — plangate CLI テストスイート（シェルスクリプト）
- `tests/fixtures/` — テスト用フィクスチャ 4種（complete-task / missing-approval / stale-plan-hash / broken-pbi）
- `.github/workflows/test.yml` — plangate CLI テスト CI workflow
- `CONTRIBUTING.md` — 新規 Provider 追加手順（`#adding-a-new-provider`）を追加
- `README.md` — Testing セクション・Provider Support セクションを追加

## v7.5.2 - 2026-04-27

fix: python3 で JSON パースするよう timeline コマンドを修正 (#96)

- `bin/plangate` — `python` → `python3` に変更（macOS デフォルト環境対応）

## v7.5.1 - 2026-04-27

feat: bin/plangate CLI v0.1.0 追加 (#95)

### Added

- `bin/plangate` — plangate CLI シェルスクリプト
  - `init TASK-XXXX` — タスクフォルダとテンプレートファイルを生成
  - `doctor` — 環境セットアップをチェック（Claude Code plugin / Codex CLI / 必須コマンド等）
  - `status TASK-XXXX` — 現在フェーズと次アクションを表示
  - `validate TASK-XXXX` — 成果物・承認状態・plan_hash 整合性を検証
  - `abort TASK-XXXX` — abort イベントを run.ndjson に記録
  - `timeline TASK-XXXX` — run.ndjson イベントログをタイムライン表示
  - `resume TASK-XXXX` — current-state.md を表示してセッション再開

## v7.5.0 - 2026-04-27

docs: v7.5 — Deferred Decisions 判断記録・Discussions 設定確認・導線追加 (#88 #89) (#94)

### Added

- `docs/pages/guides/governance/oss-governance.md` — Deferred Decisions 判断結果を記録（Required approvals / Scorecard required check / GitHub Actions allowlist）
- `docs/pages/guides/governance/oss-governance.md` — GitHub Discussions 設定確認セクション追加（6カテゴリ・利用方針）
- `.github/ISSUE_TEMPLATE/config.yml` — Q&A / Ideas カテゴリへの Discussions リンクを追加

## v7.4.0 - 2026-04-26

docs: v7.4 — CONTRIBUTING.ja・TROUBLESHOOTING・JSON schemas・gate enforcement spec (#92)

### Added

- `CONTRIBUTING.md` — 日本語貢献フロー・セットアップ手順・コミットメッセージ規約を追記
- `TROUBLESHOOTING.md` — 導入・設定・ワークフロー・CI トラブル対応ガイドを新規追加
- `schemas/` — Artifact JSON Schema 7種（pbi-input / plan / todo / test-cases / review-self / review-external / handoff）
- `docs/working/templates/` — 全テンプレートに frontmatter 追加（task_id / artifact_type / schema_version / status）
- `docs/working/TASK-XXXX/approvals/c3.json` — gate enforcement 仕様を新規定義

## v7.3.3 - 2026-04-27

docs: v7.3 governance — CI/Scorecard badges + docs/working/ public policy (#84 #87) (#91)

### Added

- `README.md` — CI / OpenSSF Scorecard バッジを追加
- `docs/pages/guides/governance/oss-governance.md` — docs/working/ 公開方針・AGENT_LEARNINGS.md 位置づけを明示

## v7.3.2 - 2026-04-26

docs: v7.3 onboarding — English README, examples/, plugin install guide (#73 #74 #75 #76)

### Added

- `README.md` — English primary README: 30s/2min/10min structure, plugin install at top, dedup warning
- `README.ja.md` — Japanese version (restructured from previous `README.md`)
- `examples/` — Worked example of PlanGate artifacts (Node.js user registration scenario)

## v7.3.1 - 2026-04-26

plugin v0.5.0: setup-team を skill 一覧に追加、broken reference 制約の削除、README バージョン更新。

- `plugin/plangate/README.md` — skill 数 11 → 14、setup-team 追加、既知制約から解消済み broken reference を削除
- `plugin/plangate/.claude-plugin/plugin.json` — v0.4.0 → v0.5.0、description に Setup Team を追記
- `docs/working/TASK-0037/handoff.md` — Rule 5 完了資産を発行

## v7.3.0 - 2026-04-26

モード命名の完全統一、setup-team スキル追加、pg-check × skill-policy-router 連携明示を行ったリリース。

### setup-team スキル追加（TASK-0035）

- `plugin/plangate/skills/setup-team/` — タスク規模・モードに応じたマルチエージェントチーム設計スキルを追加
- `.claude/skills/setup-team/` / `.agents/skills/setup-team/` にも同一ファイルを配置
- `skills/codex-multi-agent/SKILL.md` の broken reference（`../setup-team/SKILL.md`）を解消

### full → high-risk モード命名完全統一（TASK-0036）

- `plugin/plangate/agents/workflow-conductor.md` — 5 箇所置換（フェーズ表、判定ロジック、status.md テンプレート、V-2 記述）
- `plugin/plangate/agents/code-optimizer.md` — frontmatter description + When You Should Be Used
- `plugin/plangate/rules/working-context.md` — V-2 記述・plan.md テンプレート・status.md テンプレート
- `plugin/plangate/commands/ai-dev-workflow.md` — Mode判定テンプレート
- `.claude/` 側の対応ファイル（agents/workflow-conductor.md, agents/code-optimizer.md, agents/README.md, rules/mode-classification.md, rules/working-context.md, commands/ai-dev-workflow.md）も同様に更新

### pg-check × skill-policy-router 連携明示（TASK-0037）

- `plugin/plangate/commands/pg-check.md` — GatePolicy との連携セクションを追加
- `skill-policy-router` が `check` を requiredSkills に含む場合に `/pg-check` が自動要求される旨を明記

## v7.2.0 - 2026-04-26

Epic [#53](https://github.com/s977043/plangate/issues/53)「PlanGate を AI コーディングの開発統制 OS へ拡張する」の Phase 1〜3 を完了したリリース。

### Phase 1: 軽量スキル基盤（#54/#55/#56）

- `skills/intent-classifier/` — User Request を 7 分類（feature / bug / refactor / research / review / docs / ops）
- `skills/skill-policy-router/` — Intent + Mode → GatePolicy（requiredSkills / requiresEvidence / requiresFailingTestFirst / requiresWorktree）
- `skills/evidence-ledger/` — EvidenceLedger スキーマ・証拠記録・Completion Gate 連携
- `rules/evidence-ledger.md` — Completion Gate ブロック条件正本
- `rules/mode-classification.md` — `full` → `high-risk` リネーム + GatePolicy 定義追加
- `/pg-think` / `/pg-hunt` / `/pg-check` / `/pg-verify` コマンド追加

### Phase 2: 強制ゲート基盤（#57）

- `rules/design-gate.md` + `skills/design-gate/` — high-risk 以上で Design Artifact 8 項目必須
- `commands/pg-tdd.md` — Red→Green→Refactor TDD cycle + Evidence Ledger 連携
- `rules/review-gate.md` + `skills/review-gate/` — 6 観点レビュー、critical finding → Completion Gate ブロック
- `rules/completion-gate.md` — 全 Gate 通過を一元管理する 5 条件チェックポイント
- `rules/mode-classification.md` — Gate 適用マトリクス追加

### Phase 3: エージェント統制基盤（#58）

- `skills/context-packager/` — Allowed Context 6 要素を構造化して出力
- `rules/subagent-roles.md` — 6 ロール定義（planner / implementer / reviewer / security-reviewer / test-reviewer / documentation-reviewer）
- `skills/subagent-dispatch/` — 依存関係グラフ生成・並列実行可能タスク特定・dispatch
- `rules/worktree-policy.md` — high-risk: 必須(推奨), critical: 必須(強制)。`requiresWorktree` フラグ接続
- `skills/pr-decision/` — Evidence Ledger + Review Gate + GateStatus から APPROVE / BLOCK / CONDITIONAL 判定

### ドキュメント・その他

- `docs/plangate-v7-hybrid.md` — PlanGate Control OS 理想ワークフロー節を追加
- `plugin.json` — v0.3.0 → v0.4.0

## v7.1.0 - 2026-04-23

README 刷新、GitHub Pages 公開、Claude Code / Codex CLI 共用スキルの整備を行ったリリース。

- README をハーネスエンジニアリング上の位置づけを軸に再構成
- `docs/pages/explanation/product/philosophy.md` を追加し、思想・問題設定・PlanGate の設計解釈を分離
- GitHub Pages 用の `docs/index.md` と `docs/_config.yml` を整備
- MIT `LICENSE` を追加
- `.agents/skills/` に Codex CLI / Claude Code 共用スキルを追加
- GitHub Pages を `main` / `docs` で公開

## v7.0.0 - 2026-04-20

Workflow / Skill / Agent の 3 層で実行層を再構築したハイブリッドアーキテクチャのリリース。

- `docs/plangate-v7-hybrid.md` を追加
- WF-01〜WF-05 の Workflow 定義を追加
- v7 用 Skill / Agent の責務分離を整理
- `design.md` と `handoff.md` を成果物として強化

## v6.0.0 - 2026-04-09

Context Engineering、18 エージェント体制、5 段階モード分類を含むロードマップリリース。

- `docs/plangate-v6-roadmap.md` を追加
- context engineering 統合の方向性を整理
- タスク規模別の実行モード分類を整理

## v5.0.0 - 2026-04-09

L-0 リンター自動修正とハーネスエンジニアリング知見を統合したリリース。

- L-0 リンター自動修正ループを設計
- V-1〜V-4 の検証段階を整理
- ハーネスエンジニアリング観点を PlanGate に統合

## v4.0.0 - 2026-04-09

takt 知見を統合し、実装後検証と C-3 三値ゲートを強化したリリース。

- V-1〜V-4 の検証構造を導入
- C-3 ゲートを APPROVE / CONDITIONAL / REJECT の三値に整理
- マルチエージェント協調の実践知見を反映

## v3.0.0 - 2026-04-09

AI 駆動開発ワークフローの基盤リリース。

- PBI から Plan / ToDo / Test Cases を生成する基本フローを整理
- 計画承認後に Agent 実行へ進むゲート型モデルを定義
- Claude Code を中心とした AI 駆動開発ワークフローを文書化
