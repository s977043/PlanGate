# ai-loop rollout policy — Phase 1 適用制限（rollout eligibility）

> 本ドキュメントは ai-loop-workflow の **rollout eligibility policy 専用**の正本である。
> どのリポジトリ・どの変更に ai-loop を適用してよいか（適用フェーズ・判定条件・
> 安全側不変条件・escalate 条件）のみを定める。ai-dev / ai-loop の恒久的な
> アーキテクチャ・責務定義は書かない（それらの単一正本は
> [`00_concept.md`](./00_concept.md)）。

---

## 1. 目的

ai-loop-workflow の適用範囲は、恒久アーキテクチャ（責務・terminal state・
C-3'/Human C-3 経路）とは独立に、**rollout 段階（デプロイフェーズ）ごとに
制限される**。本ドキュメントはその制限の現在値と、適用可否の判定条件
（lite / clean / reversible）、および rollout 段階によらず緩和されない
安全側不変条件を一箇所に集約する。

> 注: 本ドキュメントの「Phase 0 / Phase 1」は**デプロイ段階**の番号系である。
> ワークフロー構築フェーズ（Phase 2 / Phase 3 等）とは別系であり、無関係。

## 2. 適用フェーズ（Phase 1: 導入先適用）

> Human 決定（2026-07-10・verbatim）:
> 「ai-loopのPoCとして、実際に開発中のリポジトリでの動作を検証していきたい。このフェーズに入ったと考えており、制限を調整したい」
> （issue [#807](https://github.com/s977043/plangate/issues/807)）

ai-loop-workflow は Phase 0（ワークフロー提供元リポジトリの
`docs/workflows/ai-loop/` 配下限定の隔離 PoC）から **Phase 1（導入先実
リポジトリでの検証）** へ移行した（Run-001〜021 の dogfooding + issue
[#782](https://github.com/s977043/plangate/issues/782) の導入先実走 1 件の
完了を根拠とする）。

### 適用ドメイン（Phase 1 現在値）

| 対象 | 適用可否 |
|------|---------|
| ワークフロー提供元リポジトリ（plangate 本体） | **`lite=true ∧ boundary=clean ∧ reversible` 帯の本番フロー変更**（下記注記の判定基盤 carve-out＝ai-loop policy/spec/engine corpus を**除く**）。本番承認フロー（PlanGate WF-00〜07）の **C-3 は常に Human・§5 不変**。実機能の auto-approve は §4 の #780 slice C 前提を継承 |
| 導入先リポジトリ | §3 の前提 2 条件を満たす場合に適用可 |

#### plangate 本体拡張の注記（TASK-0907 / [#907](https://github.com/s977043/plangate/issues/907)）

> **Human 決定（2026-07-23・verbatim）**:
> 「適用ドメインを拡張し ai-loop で開発」
> 「基本的に開発は ai-loop-workflow を使って開発をして欲しい 改善をすすめたいため」

plangate 本体（提供元リポジトリ）の実コード変更のうち、§4 の lite 4 軸（`lite=true`）・`boundary=clean`・`reversible` をすべて満たす帯を、導入先と同一扱いで `AUTO_APPROVED` 対象に含める（ドッグフーディングで改善知見を得るため）。本拡張でも**緩和しない／対象外**とする境界は以下:

- **§5 不変条件は不動**（NO MERGE BY AI / HO 接触＝無条件 escalate / W チェック独立 2 体 / lite AC-8 安全側）。本拡張は §5 を一字も変更しない。
- **§4／§6 の escalate 条件は additive-only**（削除・条件緩和なし）。
- **#780 ハード順序制約の継承**: plangate 本体の実機能 auto-approve の実運用開始も、§4 と同様に `lite.size_ok` の機械算出（[#780](https://github.com/s977043/plangate/issues/780) slice C）導入を**前提とする**。#780 未導入下では plangate 本体の実機能 auto-approve は**決定論的に escalate** する（申告制 `size_ok` のままでは実機能は eligible にならない）。
- **判定基盤 carve-out（自己改変防止・glob）**: 本拡張の適用対象から ai-loop 自身の判定基盤を**除外し escalate 固定**とする。**列挙でなく glob** で塞ぐ（判定・思想・契約・停止・merge 入口の正本群を漏れなく包含するため）:
  - ①強制エンジンコード: `scripts/ai-loop/**`
  - ②ai-loop policy／spec 文書 corpus 全体: `docs/workflows/ai-loop/**`・`docs/ai/ai-loop/**`（本ファイル自身を含む）
  - ③ai-loop 実行手順スキル: `.agents/skills/ai-loop-cycle/**`・`.claude/skills/ai-loop-cycle/**`（W チェック委託定型・`reject_category` enum・escalate 分岐・grader 上限を保持する判定基盤）
  - **配布派生の扱い**: 上記 ①〜③ の配布コピー（`plugin/plangate/skills/ai-loop-cycle/**` 等）は `sync-plugin-plangate.sh` が生成する派生成果物であり、正本を carve-out することで実質的に保護される。配布側の独立改変は CI の sync drift-check で検出する（正本と非対称に直接編集しない）。
  - **規範層である旨の明示**: arbiter（`arbiter.py`）の `boundary_check` は ho-paths.md の HO 表からのみ touches-HO を導出するため、上記 carve-out パスは現状 **boundary=clean と判定される**（機械層では escalate しない）。よって本 carve-out は**規範層**であり、eligible 判定時に実行者が escalate する責務を負う（W チェック 2 体が併せて担保）。
  - **機械層化の射程（V2）**: `ho-paths.md` 原則 2 は本来 **policy ファイル**（`auto-approve-lite-clean@v1` 等）を対象とし、エンジンコード・doc corpus 全体・skill の将来登録までは約束していない。機械層強制は同原則 2 の**拡張**として、①〜③ を含む HO 登録を V2 で行う（`ho-paths.md` 自身が HO である self-protection 原則と同型）。

> **§3 前提 2 条件との関係**: §3 は表題どおり導入先向けだが、`allowed_paths` 宣言（前提 2）は arbiter が全 run で非空必須検証するため **plangate 本体 run にも同様に適用**される（ho-paths は本リポジトリで確定済み＝前提 1 充足）。

### Phase 0 → Phase 1 移行履歴

Phase 0（隔離 PoC・提供元リポジトリ限定）→ Phase 1（導入先実リポジトリでの
検証・lite 全域 auto-approve 可）。移行判断は issue
[#807](https://github.com/s977043/plangate/issues/807)（Human 決定 verbatim 上記）。

## 3. 前提（導入先で適用可能とする 2 条件）

1. **ho-paths の導入先確定**: 導入先プロジェクトが自身の HO（Hardening
   Override）境界を [`ho-paths.md`](./ho-paths.md) 相当の形で
   確定していること。未確定のまま run を開始することは**規範違反**であり、
   L1 は run を開始してはならない（`arbiter.py` は ho-paths.md を実行時解決
   し、導入先 ho-paths の未確定・パース結果 0 件時は全件 human escalate する
   fail-closed 機械化を実装済み — [#809](https://github.com/s977043/plangate/issues/809)）
2. **LoopSpec `scope.allowed_paths` の宣言**: [`loopspec.md`](./loopspec.md)
   の既存必須フィールドで、run ごとの変更可能範囲を宣言していること

## 4. 適用可否の判定条件（lite / clean / reversible）

run が C-3' の auto-approve 候補（eligible run）となるには、以下をすべて
満たす必要がある。判定の詳細正本は各参照先に従う。

| 条件 | 内容 | 判定正本 |
|------|------|---------|
| `boundary = clean` | 変更が HO パスに接触しない（touches-HO でない）。判定は導入先 ho-paths の実行時解決による | [`decision-table.md`](./decision-table.md) §2 / [`ho-paths.md`](./ho-paths.md) |
| `lite = true` | lite 4 軸（変更規模 / 新規設計なし / 既存パターン踏襲 / **可逆性（reversible）**）を申告制・**AND** で満たす。`size_ok` は機械検証（`changed_files` 実数突合） | [`lite-criteria.md`](./lite-criteria.md) §2 |
| reversible（可逆性） | 変更が可逆である（`git revert` 等の機械的な巻き戻し手順で完全復元できる）。lite 4 軸の 1 軸として必須 | [`lite-criteria.md`](./lite-criteria.md) §2「可逆性」 |

### auto-approve 方針（Phase 1 更新）

導入先での auto-approve 適用範囲は、**lite 4 軸（[`lite-criteria.md`](./lite-criteria.md)
§2）を申告制・AND・判定不能→false（AC-8 安全側）で満たせば、実機能も
`AUTO_APPROVED` 対象に含めてよい**（Human 決定・2026-07-10）。Phase 0 時点の
「事実上 docs 級のみ」（issue [#782](https://github.com/s977043/plangate/issues/782)
実測）から拡張する。`lite.size_ok` は当面**申告制のまま**とし、git 由来の
機械算出 blast-radius boolean への置換（[#780](https://github.com/s977043/plangate/issues/780)
slice C）が、申告制に伴う保証強化の unlock として残る。導入先での実機能
auto-approve の実運用開始は `lite.size_ok` の機械算出（#780 slice C）導入を
前提とする（順序制約）。

## 5. 不変条件（安全側 — 承認境界は不動。Phase 1 でも緩和しない）

- HO 接触（`boundary = touches-HO`）= 無条件 escalate（fail-closed）。
  ho-paths 未確定時の全件 escalate は**規範層**（§3 前提 1 の開始禁止）に
  加え、`arbiter.py` の実行時解決 fail-closed（#809）で**機械層のガードも
  実装済み**
- **NO MERGE BY AI** / escalate の自己解決禁止 / 対応ラウンド上限 3
- W チェック独立 2 体（Model A/B、必要なら C/D）
- lite 4 軸の AC-8 安全側（判定不能→false・虚偽宣言禁止）
- `allowed_paths` に HO パスを書いても escalate は免れない
  （LoopSpec 既存規定・[`design-philosophy.md`](./design-philosophy.md) I-1）

## 6. escalate 条件（Human C-3 への降格）

以下のいずれかに該当する run / 裁定は auto-approve の対象外であり、
Human へ escalate する（経路定義の正本は [`00_concept.md`](./00_concept.md)）:

| 条件 | 動作 |
|------|------|
| touches-HO（HO パス接触） | 無条件 human escalate（W チェック結果にかかわらず固定） |
| lite = false（4 軸のいずれか未充足） | human escalate |
| 判定不能（ho-paths 未解決 / 申告根拠不足 / gate 未充足等） | **安全側 = false / escalate**（fail-closed） |
| W チェック不一致が重大（severity 分類で auto 裁定不可） | human escalate |
| 対応ラウンド上限 3 超過 | human escalate |

escalate は従来の人間 C-3 への降格であり、承認境界の撤廃ではない。
C-4 / merge は Human-owned 固定（**NO MERGE BY AI**）。

## 7. 正本への参照

- [`00_concept.md`](./00_concept.md) — ai-dev / ai-loop のアーキテクチャ・
  責務・terminal state・C-3'/Human C-3 経路の**単一正本**（恒久定義）
- [`decision-table.md`](./decision-table.md) — arbiter 裁定の decision table 正本
- [`lite-criteria.md`](./lite-criteria.md) — lite 4 軸の判定基準正本
- [`ho-paths.md`](./ho-paths.md) — touches-HO 判定の正本
- [`loopspec.md`](./loopspec.md) — LoopSpec（`scope.allowed_paths` 等）の正本
- [`arbiter-policy.md`](./arbiter-policy.md) — Arbiter L0 policy
  （lite 基準等の policy 改版は Human-owned 固定）
