# TASK-0106 EXECUTION PLAN

> Source: pbi-input.md / GitHub issue #289 / Mode: **high-risk**
> Generated: 2026-05-20

## Goal

人間が in-session で EH-3 skip を許可する一級手段（`bin/plangate maintenance` CLI）を新設し、`maintenance.json` 承認ファイルの **one-shot + パススコープ + 短 TTL** で運用性を改善する。AI 自己付与は多層 best-effort（L1-L4）+ 全試行監査で実用的に抑止する（**完全な構造保証は別 PBI 分割を明示**）。

## Constraints / Non-goals

### Constraints
- **承認境界の維持（多層 best-effort + 監査・R-001/R-012）**: 完全な構造保証は原理的困難なため、`maintenance start` は **L1 isatty / L2 env barrier (CI/CLAUDE_AGENT/CURSOR_AGENT/PLANGATE_BYPASS_HOOK 等) / L3 parent process heuristic / L4 対話 nonce (`PLANGATE_MAINT_ACK`)** の **4 層 best-effort 防御** で AI 自己付与を阻み、**全 start 試行を hook-events.log に env snapshot + ppid + isatty 結果付きで監査記録**。生成承認ファイルも env 経路で有効化しない（R-011）。完全保証は別 PBI に分割
- **承認境界実行正本（EH-3）を破壊しない**: 既存 30 分窓の動作・strict JSON 抽出（#282/TASK-0105）はそのまま流用し、新設フィールド読出にも strict 適用（R-009）
- **Hardening Override（最上位）**: **判定順序は maintenance 判定より前**（R-020）。maintenance 窓内でも以下は常時 **block**（R-003）:
  - `.claude/rules/*.md` / `.claude/settings*.json` / `.claude/commands/*.md` / `.claude/agents/*.md`
  - `scripts/hooks/*.sh` / `bin/plangate` / `schemas/*.schema.json`
  - `.github/workflows/*.yml` / `AGENTS.md` / `CLAUDE.md`
- **後方互換 vs Override 境界**: 既存 30 分窓（パス無指定）は「Override 対象パス**以外**は全パス許可」と扱い、Override 対象パスは新旧問わず常時 block（R-004）

### Non-goals
- docs-only fast path の EH-3 への無条件追加（scope 限定承認で代替）
- 既存 30 分窓そのものの仕様変更（後方互換）
- 承認境界の撤廃・緩和

## Approach Overview

`schemas/maintenance.schema.json` を **additive 拡張**（`allowed_paths`/`one_shot`/`consumed_at` を optional 追加、既存フィールド変更なし、`additionalProperties:false` 維持）。`bin/plangate maintenance start|stop` で `docs/working/_maintenance/maintenance.json` を生成/削除（start は **対話 TTY 要求**、`--force` で上書き許可）。EH-3 hook では **判定順序**: (i) Hardening Override 判定（maintenance 判定より**物理的に上の行**・R-020/R-028）→ (ii) maintenance ファイル有無・TTL check → (iii) **`fcntl.flock(LOCK_EX | LOCK_NB)` 即座取得**（hook ブロッキング回避・R-027）→ (iv) **ロック取得後にパスを再オープン**して再 read（または `fstat` と `stat(path)` で inode 不変を確認）で `consumed_at` 未消費を再確認（`os.replace` は新 inode を作るため fd ベースの flock では他者の置換を検知不能・**path 再オープン or inode 確認必須**・R-031）→ (v) python3 `os.replace(tmp, target)` で atomic 書込 → (vi) ロック解放。**ロック失敗 or 再 read で消費済み判定は fail-closed (block)**。`target_file` は判定前に `./` 除去等で正規化（R-028）。`bin/plangate doctor` に表示行 + `--json` 構造化出力（`scripts/doctor_check.py` 経由）（R-006）。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 Checkpoint |
|---|------|--------|-------|------|--------------|
| 1 | schema 拡張 (`additionalProperties:false` 維持・新フィールドは optional) | `schemas/maintenance.schema.json` v2 | AI | low | 既存 schema test PASS |
| 2 | `bin/plangate maintenance start/stop` CLI 実装 (--reason/--paths/--minutes、ハード上限 30 分、`--reason` 必須、`--force` 上書き)。**L1-L4 多層防御 + 監査ログ書込**を組み込む（R-012）: L1 isatty / L2 env barrier / L3 parent process heuristic / L4 対話 nonce (`PLANGATE_MAINT_ACK`)、全試行を hook-events.log 記録 | `bin/plangate` | AI | **high** | start で schema valid な JSON 生成、stop で削除、4 層防御の各層が unit test で reject 動作確認、監査ログ書込確認 |
| 3 | EH-3 hook 改修: target_file 正規化（R-028）→ Hardening Override 物理先頭判定（R-020）→ TTL check → **`flock(LOCK_EX|LOCK_NB)` 即座取得 → ロック後再 read 検証 → `os.replace` atomic 書込 → 解放**（R-002/R-017/R-027）、競合 fail-closed | `scripts/hooks/check-plan-hash.sh` | AI | **critical** (承認境界) | 既存 30 分窓テスト + 並行競合（TC-30）+ fail-closed + 正規化 PASS |
| 4 | Hardening Override 実装: 拡張リスト（.claude/rules/, .claude/settings*, .claude/commands/, .claude/agents/, scripts/hooks/, bin/plangate, schemas/, .github/workflows/, AGENTS.md, CLAUDE.md）は窓内でも block。新旧 maintenance.json 双方に適用（R-003/R-004） | EH-3 hook 内 | AI | **critical** | Override 対象 10 パターンの block テスト PASS |
| 5a | `bin/plangate doctor` 表示行追加: 有効窓「scope/remaining (mm:ss)/paths」 | `bin/plangate` | AI | low | doctor 出力テスト PASS |
| 5b | `scripts/doctor_check.py` の `SCOPES` に `"maintenance"` を新設し、maintenance.json 有無・残 TTL・scope/paths/one_shot/consumed_at を機械可読 JSON で出力（R-006/R-030） | `scripts/doctor_check.py` | AI | low | `bin/plangate doctor --json --scope maintenance` で全メタデータ取得 PASS（AC-13） |
| 6 | テスト追加: CLI 単体・hook 単体・E2E (start→edit→consume→re-block) | `tests/extras/ta-XX-maintenance.sh`、`tests/hooks/*` | AI | medium | 全テスト + 既存 68/78 PASS 維持 |
| 7 | docs 整備: `docs/ai/maintenance-cli.md`（運用 guide） | docs | AI | low | リンク健全 |
| 8 | handoff.md 作成 + V-1 受け入れ検査 | TASK-0106/handoff.md | AI | low | 全 AC PASS 確認 |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| `schemas/maintenance.schema.json` | 拡張 (additive) |
| `bin/plangate` | サブコマンド追加 (maintenance) + doctor 表示行 |
| `scripts/hooks/check-plan-hash.sh` | path/TTL/one-shot 判定追加・Hardening Override・python3 `os.replace` atomic 書込（R-002） |
| `scripts/doctor_check.py` | maintenance 窓の JSON 構造化出力追加（R-006） |
| `tests/extras/ta-XX-maintenance.sh` | 新規 |
| `tests/hooks/run-tests.sh` | 既存に maintenance 系追加 |
| `docs/ai/maintenance-cli.md` | 新規（運用 guide） |
| `docs/working/TASK-0106/handoff.md` | WF-05 |

## Testing Strategy

- **Unit (CLI)**: `maintenance start` で schema valid な JSON 生成 / `stop` で削除 / `--minutes` ハード上限拒否 / `--reason` 必須エラー
- **Unit (CLI 自己付与防止)**: 非対話実行 / CI 環境変数 / agent 実行 / TTY 偽装で `start` reject（R-001/R-011）
- **Unit (hook)**: path glob match / TTL 内/外 / one-shot consumed_at が未設定で通過・設定後 block / Hardening Override 拡張リスト 10 パターンすべて窓内でも block / 並行競合で fail-closed
- **Integration (E2E)**: `maintenance start --paths "README.md" --minutes 5` → no-task で README.md Edit 通過 (consumed_at 書込) → 同じ承認で 2 回目 Edit が block → stop で完全失効
- **Backward compat**: 既存 30 分窓・パス無指定 maintenance.json が「Override 対象パス以外は許可」で動作（R-004）
- **TTL 既定 5 分 / ハード上限 30 分**（R-013）: 新規 `start` は既定 5 分、`--minutes` 指定で上限 30 分まで延長、超過は reject
- **Runner 統合 (TC-23)**: `tests/run-tests.sh` 実行で新規 ta-XX-maintenance.sh と既存 hook テストが呼び出され全 PASS する（R-007）
- **回帰**: 既存 `tests/run-tests.sh` 68 PASS + `tests/hooks/run-tests.sh` 78+ PASS 維持

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| 承認境界の意図せぬ緩和（hook 改修ミスで env 経路で有効化される 等） | **critical** | env 経路での無効化を unit test で固定、Hardening Override をデフォルト ON、`start` の TTY 要求を unit test で固定（R-001/R-011） |
| one-shot consume の race condition (2 並行 Edit) | **critical** | **`fcntl.flock(LOCK_EX)` 必須**（R-017）→ ロック取得後に再度 `consumed_at` を strict 読出 → 未消費なら python3 `os.replace(tmp, target)` で atomic 書込 → ロック解放。ロック取得失敗 or 再検証で消費済み判定なら **fail-closed (block)**。Read-Modify-Write race を構造的に排除（R-002/R-017） |
| path glob の解釈差異 (sh case vs python fnmatch) | medium | EH-3 が sh なので sh case パターンで統一・テストで多パターン検証 |
| 既存 30 分窓との後方互換破壊 | high | 既存テストを必ず維持 + 新フィールド unknown 時のデフォルト動作を「Override 対象パス以外は既存挙動と同じ」に固定（R-004） |
| Hardening Override と後方互換の衝突 | **major** | 既存 30 分窓「任意 path PASS」は **Override 対象パス以外**に限定する旨を明文化（R-004） |
| 新設フィールド読出での寛容な抽出による bypass | **major** | strict JSON 抽出パターン (#282/TASK-0105) を新設 `allowed_paths`/`one_shot`/`consumed_at` 読出にも適用（R-009） |
| **flock の Read-Modify-Write race** | **major** | flock 取得**前**に読んだ「未消費」を信じると race が崩壊。**ロック後の再 read 検証**を必須化、競合 fail-closed（R-027） |
| **`os.replace` による inode 入れ替えと flock の整合** | **major** | `os.replace` は新 inode を作るため fd ベース flock で他者の置換を検知不能。**ロック後にパスを再オープンするか `fstat` vs `stat(path)` で inode 不変を確認**してから書込（R-031） |
| Hardening Override の表記揺れ bypass | **major** | `target_file` が `./` 付き・絶対・相対で来る可能性 → 判定前に正規化 + `*/path|path` glob（R-028） |
| macOS BSD ps と Linux GNU ps の差異 | minor | L3 parent heuristic で `ps -p $PPID -o comm=` のフルパス返却対応 → `grep -iqE 'claude|codex|cursor'` 部分一致（R-029） |

## Questions / Unknowns

全 Unknowns は外部レビュー (review-external.md) を経て確定済:

- one-shot consume granularity → **単一 Edit/Write 操作で 1 回** 確定
- doctor 表示の TTL 粒度 → **分:秒表示** + `--json` で UNIX epoch+残秒（R-006）確定
- `--paths` 未指定時の動作 → **Override 対象パス以外は許可（後方互換維持）**（R-004）確定
- `maintenance start` 実行主体 → **AI 起動不可（対話 TTY 要求）**（R-001）確定
- 既存有効窓上書き → **`--force` なしで reject（AC-9）**（R-005）確定

## Mode 判定

**high-risk**（critical 寄り）

判定根拠:
- 変更ファイル数: 6-8 → high-risk
- セキュリティ関連（承認境界実行 hook 改修）→ 最低でも中、本件は高
- リスク: 高（承認境界破壊の可能性）
- ロールバック: 計画的に必要（schema/hook の互換性保持で対応）
- **最終判定**: high-risk（critical 候補は exec フェーズで再評価）
