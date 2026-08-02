# PBI INPUT PACKAGE — TASK-0954

> Issue: [#954](https://github.com/s977043/plangate/issues/954)（bug / **priority:P2** / area:docs）
> 由来: [#943](https://github.com/s977043/plangate/issues/943)（`ai-dev-plan` 単体の報告）の横展開。#943 の修正 PR [#955](https://github.com/s977043/plangate/pull/955) は `ai-dev-plan` 1 本のみ対応し、同型の解決不能参照が他 26 skill に残存
> 作成: 2026-08-02（**main `cda229b` で実測**。`cda229b` は #955 のマージコミットそのもの＝先行修正を含む最新 main）
> 関連: [#956](https://github.com/s977043/plangate/issues/956)（`.codex/skills/` の commit 済み drift 2 件。同じ「正本 `.agents/skills/` → 派生」同期構造の隣接 PBI。**順序依存あり — Notes 参照**）

## Context / Why

skill が「正本」と宣言したファイル（`.claude/rules/*.md` / `bin/plangate` / 上流 `docs/**`）を導入先で読めないまま AI が自走すると、判定基準が skill 本文の要約だけになる。plugin（marketplace）経由の導入者からは「skill が壊れている」のか「そういう運用」なのか区別できず、切り分けコストが高い（issue #954 背景）。

issue #943 が `ai-dev-plan` で報告したこの問題は、`.agents/skills/` 全 38 skill の走査で**他 26 skill に同型で存在する**（issue 実測表）。参照は 3 クラスに分かれる:

| クラス | 内容 | `install.sh` 経由 | plugin 経由 |
|---|---|---|---|
| **A** | `.claude/rules/*.md` | 解決可 | `${CLAUDE_PLUGIN_ROOT}/rules/` に実体はあるが skill 本文に記載なし |
| **B** | `bin/plangate` / `scripts/*` | 解決不可 | 解決不可（`scripts/` は存在するが `install-plangate-skills.sh` のみ） |
| **C** | 上流 `docs/**` | 解決不可 | 解決不可 |

対象 26 skill × クラス該当の全数表は **issue #954 本文の対象表を正**とする（stale 化防止のため転記しない）。代表対象: クラス A = `ai-dev-exec` / `ai-dev-verify` / `plan-review-gate` 等 13 skill、クラス B = `bin/plangate` 参照 8 skill + `./scripts/*` 参照、クラス C = `workflows/01〜05` 参照の WF 系 skill 群ほか。exec 時は件数をハードコードせず、T-0x で現 main 基点の再走査により全数を機械確定する（TASK-0921 と同じ規律）。

### 裏取り結果（作成時点 main = `cda229b`・2026-08-02）

| # | issue の主張 | 実測（コマンド / 参照） | 結果 | 判定 |
|---|------|------|------|------|
| 1 | 「`.agents/skills/` 全 38 skill を走査」 | `find .agents/skills -mindepth 1 -maxdepth 1 -type d \| wc -l` | **38**（非 dir は `README.md` 1 件のみ、計 39 エントリ） | 一致 |
| 2 | クラス A 該当は 13 skill（+ 対応済み `ai-dev-plan`） | `grep -l '\.claude/rules/' .agents/skills/*/SKILL.md \| wc -l` | **14** = issue のクラス A 列該当 13 skill + `ai-dev-plan` | 一致 |
| 3 | `ai-dev-plan` は対応済み（Out of scope） | `.agents/skills/ai-dev-plan/SKILL.md` L15-20 付近 | 「次の順で探索する」+ `${CLAUDE_PLUGIN_ROOT}/rules/` + 解決不能時の明示、の 3 経路フォールバックが実在（base `cda229b` が #955 マージそのもの） | 一致 |
| 4 | クラス B の広がり（補助実測） | `grep -l 'bin/plangate' .agents/skills/*/SKILL.md \| wc -l` | **9** = issue のクラス B `bin/plangate` 該当 8 skill + `ai-dev-plan`（対応済み・フォールバック記述内で言及） | 一致 |
| 5 | 参考モデル: `ai-loop-cycle` は bundled resources 方式で解決済み（#771/#790） | `ls plugin/plangate/skills/ai-loop-cycle/` | plugin 側に `references/`（`00_concept.md` 等）+ `scripts/`（`arbiter.py` 等）が同梱されている。ただし**正本 `.agents/skills/ai-loop-cycle/` は `SKILL.md` のみ**で、bundled 生成は `scripts/sync-plugin-plangate.sh` の専用セクションが plugin 側に生成する（`install-plangate-skills-to-codex.sh` L99-101 のコメントでも裏付け） | 一致（補足あり: 「skill 直下に自己完結同梱」は plugin 生成物側の構造。横展開時は生成経路の設計判断が必要 — U-1） |

## What（Scope）

### In scope（issue の In scope を基点に具体化）

1. **クラス A（rules 参照）**: 対象 skill の rules 参照に「導入先相対 → `${CLAUDE_PLUGIN_ROOT}/rules/` → 解決不能なら明示」のフォールバック順を明記（#955 の `ai-dev-plan` 記述を雛形とする）
2. **クラス B（CLI / scripts 参照）**: CLI 不在時の代替手順の明記 + **「機械検証済み」と誤記しない**規律 + **C-3 を省略しない**旨の明記（同じく `ai-dev-plan` を雛形）
3. **クラス C（上流 docs/** 参照）**: `ai-loop-cycle` 方式（bundled references）で解決するか、A と同じフォールバック明記で解決するかをクラスごとに決定し、判断根拠を記録
4. **正本 `.agents/skills/` のみ手編集**。`.codex/skills/` と `plugin/plangate/skills/` は同期スクリプト経由で再生成（手編集ゼロ）
5. 導入先での実解決の実測（marketplace 経由の環境で 3 クラス各 1 件以上）

### Out of scope（issue verbatim）

- `install.sh` のコピー対象拡張（#943 の提案 3。配布物の構成変更は影響範囲が広く、別途判断）
- `docs/working/TASK-XXXX/` への参照（導入先で作る成果物なので解決不能で正しい）
- `ai-dev-plan`（#943 の修正 PR #955 で対応済み）

### Non-goals（issue verbatim）

- skill の責務・出力契約の変更（参照解決の話に限定する）
- 承認境界の緩和。CLI 不在を理由に C-3 / plan_hash ゲートを省略可能にしてはならない
- `install.sh` / 配布バンドル構成の変更

## 受入基準

> issue #954 の AC 6 項目を保持し、検証方法を付与。plan で最終確定する。

- **AC-1**: クラス A の対象 skill すべてで、rules 参照に「導入先相対 → `${CLAUDE_PLUGIN_ROOT}/rules/` → 解決不能なら明示」のフォールバック順が明記されている。検証: 対象全数を再走査（grep）し、#955 の `ai-dev-plan` と同型の探索順記述の有無を突合（件数ハードコードなし）
- **AC-2**: クラス B の対象 skill に CLI 不在時の代替手順が明記され、「機械検証済み」と誤記しない規律と C-3 を省略しない旨が含まれている（#955 における `ai-dev-plan` の記述を雛形とする）
- **AC-3**: クラス C を `ai-loop-cycle` 方式（bundled references）で解決するか、A と同じフォールバック明記で解決するかがクラスごとに決定され、その判断根拠が plan / decision-log に残っている
- **AC-4**: 正本 `.agents/skills/` のみを編集し、`.codex/skills/` と `plugin/plangate/skills/` は同期スクリプト経由で再生成されている（手編集ゼロ）。検証: PR 上で派生差分が同期スクリプトの再実行結果と一致し、再実行後の `git status` が clean
- **AC-5**: `sh tests/run-tests.sh` が baseline（issue 記載 **453 passed / 0 failed**。exec 開始時に現 main で再実測した値を正とする）を維持している
- **AC-6**: 3 クラスすべてについて「導入先で実際に解決するか」を marketplace 経由の環境で 1 件以上実測している

## Notes from Refinement

### Mode 判定案（plan で確定）

- 定量: 対象 26 skill（正本のみで 26 ファイル、派生同期 `.codex/skills/` + `plugin/plangate/skills/` を含めると実 PR の変更ファイルは最大 78+）→ 変更ファイル数 16+ で**定量は critical 帯**
- ただし変更種別は skill 本文への**参照記述の追記**（doc 寄り・クラス別の機械的同一パターン。#955 のミラー適用）で、新規設計はクラス C の方式決定（U-1）に限られる — 定性は light〜standard 相当
- mode-classification「定量と定性の高い方」の機械適用では critical。TASK-0921 と同様、**クラス別（または ≤15 skill 単位）のスライス分割で high-risk 帯へ収めるか、critical 受容（V-2/V-3/V-4 フル + 同期 C-3）で一括するか**を plan で確定する
- HO 該当性: `.agents/skills/` は Hardening Override 9 カテゴリ**対象外**（`scripts/hooks/check-plan-hash.sh` L124-134 の case 文に `.agents/` パターンなし — 実測 0 件）。doc-light は対象規模・派生（`.md` 以外の `openai.yaml` 生成物）を含むため不適用
- 安全側の初期値: **high-risk**（スライス分割時）。一括なら critical。いずれも `lite_eligible=false`・Human C-3

### #956 との順序依存（重要）

AC-4 の派生再生成（同期スクリプト素実行）は、#956 の**既存 drift 2 件**（`.codex/skills/ai-loop-cycle/SKILL.md` / `.codex/skills/plan-review-gate/SKILL.md`）を必ず巻き込む（本 pbi-input 作成時に素実行で実測済み — TASK-0956 pbi-input の裏取り参照。PR #955 でも同事象が発生しワーカーがスコープ外として除外した前例あり）。**#956 を先に解消する**か、本 PBI 側で当該 2 ファイルの stage 除外（+ handoff への明示）を計画に含める。

### 雛形（#955 = `ai-dev-plan` の実装済みパターン）

- クラス A: 「1. 導入先相対 → 2. `${CLAUDE_PLUGIN_ROOT}/rules/`（Bash で `ls` により解決確認。Read は環境変数を展開しない）→ 3. 解決不能なら skill 本文の要約を優先正本とし、正本未参照である旨を記録」
- クラス B: 「CLI 不在時のフォールバック（導入先では既定）」節 + 手動代替手順 + 誤記禁止規律
- クラス C: `docs/**` は配布対象外。#955 は要約代替 + 未参照明記で処理（= A 型）。bundled references 方式（#771/#790）は plugin 側に `references/` を同梱する — どちらを採るかがクラス C の決定事項

## Estimation Evidence

### Risks

| Risk | 影響 | 一次緩和 |
|------|------|---------|
| #956 の既存 drift を派生再生成で巻き込む | 無関係な差分が PR に混入し C-4 レビューを汚染 | 順序調整（#956 先行）or stage 除外を plan に明記（上記 Notes） |
| 26 skill への一括適用で表現が skill ごとに揺れる | 導入者の読み解きコスト・再修正 | クラス別に雛形文面を固定し、機械的に適用。C-1 で全数突合 |
| 同期スクリプトの変換仕様（description 64 文字切り詰め・`openai.yaml` 生成等）による意図しない派生差分 | AC-4 の「手編集ゼロ」検証が濁る | 再生成後に `git status` / diff を全件確認し、想定内差分のみである根拠を evidence 化 |
| `ai-loop-cycle` の bundled 生成が専用セクション実装（skill 固有）で、横展開が単純コピーで済まない | クラス C の工数増・生成経路の複雑化 | U-1 を plan の最初の設計判断とし、bundled 方式を選ぶ場合は生成の一般化コストを見積もってから確定 |
| marketplace 経由の実測（AC-6）が環境準備で詰まる | AC-6 未充足 | 実測環境の手段を plan の Unknown として先に確定（`/plugin add` 済み環境 or 一時環境構築） |

### Unknowns

- **U-1**: クラス C の方式選択 — bundled references（#771/#790 方式）の横展開か、A 型フォールバック明記か。bundled は `sync-plugin-plangate.sh` の ai-loop-cycle 専用セクションの一般化が必要になる可能性（裏取り #5 の補足）。判断根拠の記録が AC-3
- **U-2**: AC-6 の marketplace 実測の具体手段（実導入環境の用意・検証手順）
- **U-3**: 派生再生成の正確なコマンド列 — `install-plangate-skills-to-codex.sh`（`.codex/skills/`）と `sync-plugin-plangate.sh`（`plugin/plangate/`）の役割分担、および `.claude/skills/`（28 skill・正本と非同一の別系統 — 実測で `ai-loop-cycle/SKILL.md` が正本と differ）を本 PBI の派生対象に**含めない**ことの確認
- **U-4**: スライス分割の単位（クラス別 A/B/C か、skill 数 ≤15 の均等割か）と、その場合の PR 本数

### Assumptions

- issue #954 の対象表（26 skill × 3 クラス）が現 main で有効であること（base `cda229b` は #955 マージそのもので、それ以降 `.agents/skills/` への変更なし）
- `sh tests/run-tests.sh` baseline = 453 passed / 0 failed（issue 記載。exec 開始時に再実測して正とする）
- #956 との順序調整（先行解消 or stage 除外）が可能であること
- #955 の `ai-dev-plan` 記述が雛形として引き続き正であること（変更されないこと）
