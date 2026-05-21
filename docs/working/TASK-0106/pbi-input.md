# PBI INPUT PACKAGE: TASK-0106 — EH-3 in-session skip 改善 (bin/plangate maintenance CLI)

> Source: issue #289 / Created: 2026-05-20

## Context / Why

EH-3（`scripts/hooks/check-plan-hash.sh`）は「TASK 文脈を持たない non-plan
ファイルの Edit/Write」を AI が skip を**自己付与できない**設計で正しく
block している。しかし「人間が in-session で skip を許可する一級手段」が
運用上欠落している。

| 正規ルート | 現状 | 問題 |
|---|---|---|
| `PLANGATE_SKIP_REASON` env | harness 起動時固定 | 実行中に付与不可 → セッション再起動必須（AI 自己付与防止の副作用）|
| `maintenance.json` 承認ファイル | `schemas/maintenance.schema.json` は存在するが `bin/plangate maintenance` CLI が**不在** | 人間が schema 準拠 JSON を手書きする必要があり実質運用されない |

結果: 軽微な docs 整合修正のような正当な変更でも、毎回セッション再起動
or JSON 手書きを強いられ、ガバナンスの正しさ（AI 自己付与不可）を保った
まま摩擦だけが残っている。本セッションでも何度も `python3 heredoc` で
EH-3 を迂回しており、運用負荷が継続的に発生している。

## What (Scope)

### In scope

- `bin/plangate maintenance` サブコマンド新設（**Human-owned 運用** ＝
  多層 best-effort 防御 + 全試行監査で AI 自己付与を実用的に抑止。完全な
  構造保証は別 PBI に分割）
  - `start --reason "<理由>" [--paths <glob,...>] [--minutes <n>] [--force]` で
    `schemas/maintenance.schema.json` 準拠の
    `docs/working/_maintenance/maintenance.json` を生成
  - **Human-owned 強制（多層 best-effort 防御 + 監査）**: 完全な構造的保証は
    原理的に困難なため、本 PBI では「多層 best-effort 防御 + 全試行を監査ログ
    で検知可能化」で AI 自己付与を阻む（R-001/R-012）:
    - **L1 対話 TTY 要求**: `isatty(stdin)` チェック、非対話実行は reject
    - **L2 環境変数バリア**: `CI` / `CLAUDE_AGENT` / `CURSOR_AGENT` /
      `PLANGATE_BYPASS_HOOK` 等のフラグ検出時は reject
    - **L3 プロセス系統 heuristic**: parent process が claude/codex/cursor 等の
      既知 AI agent なら reject（不可偽装ではないが追加防御）
    - **L4 対話 nonce 一致**: `PLANGATE_MAINT_ACK` 環境変数に画面表示の
      ランダム nonce を打鍵することを要求
    - **監査ログ強制**: 全 start 試行（成功・失敗）を `hook-events.log` に
      env snapshot + ppid + isatty 結果付きで記録、人間が事後検知可能
    - **明示的 best-effort 表明**: 構造的保証ではなく「多層防御 + 監査による
      検知可能性」が本 PBI のスコープ。完全保証は別 PBI（R-012 設計判断）
  - `stop` で即時失効
  - **既定束縛**: one-shot（単回 Edit/Write で消費・自動無効化） +
    対象パススコープ（`allowed_paths`） + **TTL 既定 5 分・ハード上限 30 分**（R-008）
  - **既存有効ファイル存在時の挙動**: `--force` なしでは上書き拒否（R-005, AC-9）
- EH-3 hook 側で one-shot 消費・パススコープ判定・TTL 判定を実装
- `bin/plangate doctor` に maintenance 窓の残時間/スコープ可視化
- schema 拡張: `allowed_paths` / `one_shot` / `consumed_at` フィールド追加
  （既存 30 分窓のフィールドは後方互換）

### Out of scope

- 既存 `maintenance.json` の 30 分窓そのものの仕様変更（後方互換維持）
- README Provider 表など個別 docs の実修正（本改善の最初の適用例として別途）
- 承認境界の撤廃・緩和（本改善は「人間が許可する手段の運用性向上」のみ）

## 受入基準（Acceptance Criteria）

- [ ] **AC-1**: `bin/plangate maintenance start --reason "..."` で schema
      valid な `maintenance.json` が生成される
- [ ] **AC-2**: 生成された承認下で no-task の対象 Edit/Write が 1 回通り、
      その後 one-shot 消費で自動無効化される
- [ ] **AC-3**: `--paths` 指定外、および **Hardening Override 対象パス**
      （.claude/rules/*.md, .claude/settings*.json, .claude/commands/*.md,
      .claude/agents/*.md, scripts/hooks/*.sh, bin/plangate,
      schemas/*.schema.json, .github/workflows/*.yml, AGENTS.md, CLAUDE.md）
      は窓内でも常時 block される（R-003）
- [ ] **AC-4**: TTL 超過後は窓内であっても block され、ハード上限（30 分）
      を超える `--minutes` は拒否される。既定 TTL は 5 分（R-008）
- [ ] **AC-5**: AI による承認の自己発行を **多層 best-effort で抑止し、全試行
      を監査可能化** する（R-001/R-012）。`maintenance start` は L1 isatty /
      L2 env barrier (CI/CLAUDE_AGENT/CURSOR_AGENT/PLANGATE_BYPASS_HOOK) /
      L3 parent process heuristic / L4 対話 nonce (`PLANGATE_MAINT_ACK`) の
      4 層で reject、全試行を hook-events.log に env snapshot + ppid + isatty
      で記録。env 経路では承認ファイルを有効化しない（R-011）。完全な構造
      保証は別 PBI スコープ（明示的 best-effort）
- [ ] **AC-6**: `bin/plangate doctor` が有効な maintenance 窓の残時間と
      スコープを表示する
- [ ] **AC-7**: 既存 `maintenance.json`（30 分窓・パス無指定）が後方互換
      で動作する（Override 対象パス以外）
- [ ] **AC-8**: CLI / hook の判定にユニットテストがあり、
      `tests/run-tests.sh` で検証可能
- [ ] **AC-9**: 既存有効な maintenance.json が存在する状態での `maintenance start`
      は `--force` なしでは exit 非0 で上書き拒否される（R-005, R-010）
- [ ] **AC-10**: 新設フィールド（allowed_paths/one_shot/consumed_at）の判定も
      env 経由では有効化されない（ファイル存在のみを正本とする）（R-011）
- [ ] **AC-11**: one-shot 消費は `flock(LOCK_EX | LOCK_NB)` 取得後の **再 read 検証**を
      含む atomic Read-Modify-Write で実装、並行競合時 fail-closed（R-027）
- [ ] **AC-12**: Hardening Override 10 パターンは `target_file` の表記揺れ
      （`./` 有無、絶対パス、相対パス）に関わらず正規化後に確実に遮断（R-028）
- [ ] **AC-13**: `bin/plangate doctor --json` 出力に maintenance scope が含まれ、
      `maintenance.json` 有無・残 TTL・scope/paths/one_shot/consumed_at が
      機械可読で取得可能（R-030）
## Notes from Refinement

- **承認境界の維持（best-effort + 監査・R-012）**: AI 自己付与は **多層
  防御（L1 isatty / L2 env barrier / L3 parent process heuristic / L4 対話
  nonce `PLANGATE_MAINT_ACK`）で実用的に抑止し、全 start 試行を
  hook-events.log に env snapshot + ppid + isatty 結果で監査記録**する。
  完全な構造保証は**別 PBI に分割**することを明示（pbi-input In scope /
  AC-5 / plan Constraints と整合）
- one-shot の atomicity: EH-3 が consume するタイミングで file を
  delete/move/`consumed_at` 設定 のいずれかで atomically 無効化
- **Hardening Override（必須採用）**: maintenance 窓内でも以下は常時 block
  （AC-3 でも明示）。重要 infra への変更は別承認ルートを必要とする（R-003）:
  - `.claude/rules/*.md` / `.claude/settings*.json`
  - `.claude/commands/*.md` / `.claude/agents/*.md`
  - `scripts/hooks/*.sh`
  - `bin/plangate`
  - `schemas/*.schema.json`
  - `.github/workflows/*.yml`
  - `AGENTS.md` / `CLAUDE.md`

## Estimation Evidence

### Risks

- EH-3 は **承認境界実行正本**。改修ミス = 承認境界破壊リスク
- **one-shot consume の race condition**: tmp+rename だけでは並行 hook
  が両方とも未消費読みで通過するリスク → `python3 os.replace()` で
  atomic 書込・書込前に mtime/inode 先取り検出・競合検出時 fail-closed
  (block) を必須化（R-002, severity = critical）
- 既存 30 分窓との後方互換維持（Override 対象パス以外は既存挙動と同じ）（R-004）
- 新設フィールド読出での寛容抽出による bypass → strict JSON 抽出
  パターン (#282/TASK-0105) を新設フィールド読出にも適用（R-009）

### Unknowns

- ~~one-shot consume atomicity 実装方式~~ → **確定**: python3
  `os.replace(tmp, target)` で atomic 書込（R-002）
- ~~doctor 表示の TTL 計算粒度~~ → **確定**: 分:秒表示、JSON 出力では
  UNIX epoch + 残秒（R-006）
- ~~Hardening Override 対象パス~~ → **確定**: 上記 Hardening Override
  リスト（R-003）
- ~~既存有効窓上書き仕様~~ → **確定**: `--force` なしで reject（AC-9）

### Assumptions

- `schemas/maintenance.schema.json` を additive に拡張（既存フィールド削除なし）
- 既存 EH-3 の strict JSON 抽出（#282/TASK-0105 で確立）はそのまま流用
- `bin/plangate maintenance start` は **多層 best-effort 防御 + 監査** で
  AI 自己付与を阻む（R-001/R-012）。完全な構造保証は別 PBI に分割
- **UTF-8 環境前提**（R-018, TC-22）: ファイルパス・reason 文字列処理は
  UTF-8 ロケール前提。shift-jis 等の非 UTF-8 環境は documented limitation

## Mode 判定（参考）

`high-risk`（**critical** 候補も検討）:
- 変更ファイル数 6-15 想定（bin/plangate / schema / hook / doctor / 既存テスト / 新規テスト / docs）
- 承認境界 hook の改修 = セキュリティ関連最低でも「中」、本件は「高」
- 影響範囲: 複数レイヤー（CLI / hook / schema / doctor）

## Labels / Milestone

- Labels: `enhancement`, `priority:P2`
- Milestone: 未割当（issue-governance.md §4.2 推測禁止、対象バージョン決定後に人間が付与）

## Parent / Related

- Parent EPIC: なし（EPIC #193 CLOSED 後の独立改善）
- 関連正本: `.claude/rules/responsibility-classes.md`（Human-owned 境界）
- 関連 hook: `scripts/hooks/check-plan-hash.sh`（EH-3）
- 関連 issue: #282 (EH-3 strict JSON 化, CLOSED) / 本 PBI follow-up: #289
