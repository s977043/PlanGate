# 2026-07-31: schema 配置の HO 分岐 — 4 PBI 横断裁定の判断材料

> status: **裁定済み（2026-07-31・案 2 段階方式）**。§7 に記録・4 PBI の pbi-input へ転記済み。
> 本ファイルの役割: critical 4 件が共通の C-3 論点「schema をどこに置くか」で停止している状態を、
> **Human が本ファイルを読んで 1 回で裁定できる**判断材料に集約する。決定は Human。
> 実測: 2026-07-31・main `b45ab17`。

## 1. 何を決めるのか

**新設する機械可読 schema（RunEvidence / Loop Control Contract / HarnessImprovementCandidate / Run Evaluation Result）を、どの配置に置くか** — 配置によって承認境界の強度と運用コスト（AI 完結か Human patch 毎回か）が変わる。3 PBI（#894/#874/#869）は「**C-3 で確定**」として停止しており、#908 は「**plan 段階の設計判断**」（安全側デフォルト = carve-out 内 contract から開始）を持つが、「#874 と同一側に揃える」統一要求のため本裁定に含める（RV-m3）。

| PBI | schema | 個別条件（pbi-input 実測） |
|-----|--------|--------------------------|
| #894（TASK-0894・critical） | Loop Control Contract（decision enum / budget） | 「**#874 の C-3 決定と同一の配置に揃える**」 |
| #874（TASK-0874・critical） | RunEvidence（20 フィールド） | 「schemas/=機械強制強・Human 適用 / docs/schemas/=AI 完結・機械検証は validator。**どちらを採るかを C-3 で確定**」 |
| #869（TASK-0869・critical） | HarnessImprovementCandidate（WHERE×WHY enum） | 「**#874 と同じ側に揃える（分裂させない）**」+ **enum 拡張の帰結**: `schemas/` 側だと「WHERE×WHY 語彙 1 件の追加ごとに HO patch（Human 適用）が必要」 |
| #908（TASK-0908・critical） | Run Evaluation Result（trajectory / operational） | **第 3 案を提示**: 「安全側は後者〔= `docs/workflows/ai-loop/` 配下の contract 文書（carve-out 内・非 HO）〕から開始し、Gate 接続判断の段階で `schemas/` 昇格を検討」（原文の「後者」を展開・準 verbatim）。下流 #909 / #910 が本 schema の確定待ち |

## 2. 実測: 配置 3 案 × 保護 3 層の扱い

| 配置 | EH-3（`check-plan-hash.sh` L131・**編集時に常時 block**） | ho-paths（arbiter・**ai-loop 実行時のみ**） | CI `schema-validate.yml` |
|------|---------------------------------------------------------|--------------------------------------------|------------------------|
| **案 1: `schemas/`** | glob = `schemas/*.schema.json` → **`.schema.json` 拡張子なら入れ子も含め HO**（case 文の `*` は `/` をまたぐ・実測）。AI 編集不可 = Human patch 必須 | `schemas/**`（L28・HO-schema「AI 直接編集不可。スキーマ改ざんで不変条件が崩壊する」）→ **touches-HO** | **乗る**（paths: `schemas/**/*.json`。json.tool 検査 + `bin/plangate validate-schemas`） |
| **案 2: `docs/schemas/`** | 非該当（AI 編集可） | 非該当（clean） | **乗らない**（機械検証は自前 validator を `scripts/ai-loop/` に置く） |
| **案 3: `docs/workflows/ai-loop/` 配下 contract 文書** | 非該当（AI 編集可） | **判定基盤 carve-out ②**（規範層。arbiter は clean 判定だが実行者が escalate する責務 — #916 の機械強制待ち） | 乗らない（同上） |

### ⚠️ 実測で判明した保護範囲の非対称（裁定の補足材料・RV-M1 で層帰属を是正）

- **EH-3**（case 文）: `schemas/*.schema.json` の `*` は **`/` をまたぐ**（実測: `schemas/sub/foo.schema.json` も MATCH → block）。制約は**拡張子のみ** — `schemas/foo.yaml` / `schemas/foo.json`（`.schema.json` でないもの）は EH-3 をすり抜ける
- **CI**（`schema-validate.yml` L41 の `for f in schemas/*.json`）: pathname 展開は **`/` をまたがない**ため、**入れ子配置は json.tool 構文検査から漏れる**（workflow 自体は paths `schemas/**/*.json` で起動する）
- 帰結: 案 1 を採る場合は「**`.schema.json` 拡張子必須**（EH-3 保護の前提）+ **CI 構文検査を受けるなら直下**」と書き分ける

## 3. 前例（実測・実在確認済み）

| 前例 | 側 | 実体 |
|------|-----|------|
| `docs/schemas/child-pbi.yaml` | 案 2（非 HO） | 唯一の非 HO schema 前例（orchestrator-mode の子 PBI 仕様） |
| **#872 分割型 = `c0461bb` → `3ec2e24`** | 案 1（HO） | `c0461bb`（PR #889）= 非 HO 受理器（`c3prime_verify.py`）+ HO patch 群の **staging**（schemas/ には触れない・実測）。**`3ec2e24`（PR #895）= Human が HO patch 4 件を適用し `schemas/c3-prime.schema.json` を配置** — 「schemas/ への HO 配置を Human が適用した」直接前例 |
| TASK-0871 `approvals/ho-apply-approval.md` | 案 1 の運用実績 | HO patch の Human 適用 → `git apply --check --reverse` 事後検証 → c3.json 再発行までの完了記録 |
| `schemas/` 既存 **29 ファイル** | 案 1 の現状 | c3-approval / c3-prime / run-event 等の承認境界系 schema はすべて案 1 側に実在 |

## 4. 選択肢の比較

| 観点 | 案 1: `schemas/`（HO） | 案 2: `docs/schemas/`（非 HO） | 案 3: carve-out 内 contract 文書 |
|------|----------------------|------------------------------|--------------------------------|
| 承認境界の強度 | **最強**（EH-3 常時 block + ho-paths + CI） | 弱（自前 validator のみ） | 中（ai-loop 実行時は escalate。通常フローは AI 編集可） |
| 初回導入コスト | HO patch（c0461bb 型の分割 PR + Human 適用） | AI 完結 | AI 完結 |
| **反復運用コスト** | **enum 1 件追加ごとに HO patch**（#869 が名指しで懸念） | AI 完結 | AI 完結（ai-loop で回すなら毎回 escalate） |
| CI 機械検証 | schema-validate に自動で乗る（**実利は構文検査 + mapping 整合まで**。instance 検証はどの案でも `scripts/schema_mapping.py`〔非 HO〕への追記が別途必要 — RV-m5-3） | 乗らない（validator を書く。**中間手あり**: `schema-validate.yml` の paths と検査対象を `docs/schemas/` へ広げる **1 回の HO patch**〔workflows は HO〕で CI に乗せられる — RV-m5-2） | 乗らない（同左） |
| 既存 29 schema との一貫性 | **一貫**（承認境界系はすべてここ） | 分裂（2 箇所目） | 分裂（3 箇所目。ただし ai-loop 専用文書としては同居） |
| **plugin 配布同期**（#908 AC-11 が同期方針を要求 — RV-m5-1） | 新設が必要（plugin への schema 配布は現状 **0 件**・実測） | 新設が必要（同左） | **既存 sync 経路あり**（`docs/workflows/ai-loop/*.md` は `sync-plugin-plangate.sh` の同期対象。c0461bb が plugin 側 references を同時更新した実績） |
| 4 PBI の「同一側に揃える」要求 | 満たせる | 満たせる | 満たせる（ただし 3 PBI の schema を ai-loop corpus **内**へ持ち込む形になり、#916 の機械強制後は ai-loop run 内の改版が escalate 固定になる — 実質根拠は §6 参照。RV-m5-4） |

## 5. 論点の本質（1 段深く）

これらの schema は **「AI の自律ループの挙動を規定する契約」**である。#874 RunEvidence は promotion の入力、#894 は停止予算・decision enum、#869 は改善候補の語彙、#908 は eval 結果 — いずれも改ざんされると **Evolution Loop が自分に都合よく証拠を書き換えられる**類のもの。`ho-paths.md` L28 の「スキーマ改ざんで不変条件が崩壊する」という HO-schema の存在理由がそのまま当てはまる。

一方で 4 PBI とも **Phase 1 は shadow / fixture 駆動の隔離 PoC**（本番から呼ばれない）であり、初版 schema は高頻度で改版される見込み（とくに #869 の enum、#908 の trajectory 内訳）。**設計が固まる前に HO で固定すると、改版のたびに Human patch が発生する**。#869 が名指しするのは「HO patch が必要になる帰結の受容可否」までであり、それが**形骸化（雑な一括承認）を招きうる**というのは本文書自身の解釈（RV-m1）。

## 6. 推奨案（AI 提案・決定は Human）

**段階方式: Phase 1（shadow）は案 2 `docs/schemas/` で 4 PBI 同側に統一 → 本番接続（promotion gate / Gate 接続）の段階で `schemas/` へ 1 回の HO patch で昇格**

- Phase 1 の改版反復を AI 完結で回せる（4 PBI とも fixture 駆動の隔離 PoC であることと整合）
- 「同一側に揃える」を最初から満たし、#869 の enum 拡張も昇格まで AI 完結
- 昇格時は **c0461bb 型（非 HO validator + HO patch）の前例**をそのまま踏襲し、schema が安定した状態で 1 回だけ Human 適用
- 昇格のトリガーは「本番接続 = promotion gate / Gate 接続の C-3」と定義する。**検知の実体は機械ではなく人間**: Gate 接続 PR は HO ファイル（`bin/plangate` / hooks / workflows）への接触が不可避で必ず Human escalate になるため、**その C-3 チェックリストに「schema 昇格済みか」を載せて人間が検査する**（機械検知は #916 系の後続。#811 promotion gate は未実装・OPEN — RV-m4）
- 案 3 は #908 単独では合理的だが、4 PBI 統一先としては carve-out との関係が複雑になる（#916 の機械強制が入ると ai-loop でのschema 改版が escalate 固定になる）ため次点

**留保**: 「Phase 1 から最強保護であるべき」（案 1 直行）という立場も成立する。その場合のコストは「4 PBI × 改版ごとの HO patch」であり、TASK-0871/0872 の運用実績から 1 回あたりの Human 手数は小さい（apply → check --reverse → 承認記録）。改版頻度の見込みが小さいなら案 1 直行が優る。

## 7. 裁定記録（Human 記入欄）

```text
裁定: 案 2 段階方式
昇格トリガー（段階方式の場合）: 本番接続（promotion gate / Gate 接続）の C-3。
  Gate 接続 PR は HO 接触で必ず Human escalate になるため、その C-3 チェックリストに
  「schema 昇格済みか」を載せて人間が検査する（§6 のとおり）
日付・裁定者: 2026-07-31 / s977043（AskUserQuestion への回答として裁定。
  本欄への記入は AI が回答を転記したもの — 承認トークンではなく記録）
補足条件: なし（4 PBI 一括適用。各 pbi-input へ転記済み）
```

## 8. 裁定後のアクション

1. 4 PBI の pbi-input の C-3 論点欄（#894 論点 3 / #874 Notes / #869 **追補**論点 3-4 / #908 Notes）へ裁定結果を転記（追記専用・plan 生成時に消費）
2. #894 と #874 の残 C-3 論点（例: 2 分割 / terminal 語彙。**全量は各 pbi-input の論点一覧を正とする**）は本裁定と独立に各 C-3 で確定
3. 段階方式の場合、昇格 PBI（HO patch）を #870 の後続タスクとして予約起票するかを plan 段階で判断

## 9. 参照

- [`docs/ai/ai-loop/ho-paths.md`](../../ai/ai-loop/ho-paths.md) L28（HO-schema）
- [`scripts/hooks/check-plan-hash.sh`](../../../scripts/hooks/check-plan-hash.sh) L131（EH-3 glob）
- [`.github/workflows/schema-validate.yml`](../../../.github/workflows/schema-validate.yml)
- pbi: [`TASK-0894`](../TASK-0894/pbi-input.md) / [`TASK-0874`](../TASK-0874/pbi-input.md) / [`TASK-0869`](../TASK-0869/pbi-input.md) / [`TASK-0908`](../TASK-0908/pbi-input.md)
- 前例: `docs/schemas/child-pbi.yaml` / commit `c0461bb`（#872 PR-2）/ `docs/working/TASK-0871/approvals/ho-apply-approval.md`
