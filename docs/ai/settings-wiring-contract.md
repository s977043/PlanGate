# settings wiring 契約（正本 / TASK-0080 S1）

> `.claude/settings.json` が満たすべき PreToolUse hook wiring の**正本**。
> `bin/plangate doctor --check-settings` がこの契約と実体を突合する。
> 適用は `scripts/apply-claude-settings.sh`（**ユーザー実行**。AI は
> self-mod ガードで `.claude/settings.json` を編集できないため）。

## 必須 PreToolUse hooks（matcher: Edit|Write 系）

| Hook | command（必須トークン） |
|------|------------------------|
| EH-1 plan-exists | `scripts/hooks/check-plan-exists.sh` |
| EH-2 c3-approval | `scripts/hooks/check-c3-approval.sh` |
| EH-3 plan-hash | `scripts/hooks/check-plan-hash.sh ${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}` |
| EH-6 forbidden-files | `scripts/hooks/check-forbidden-files.sh` |
| EH-9 delegation-commit-boundary | `scripts/hooks/check-delegation-commit-boundary.sh` |

### 契約ポイント

- **EH-3 は `${PLANGATE_HOOK_FILE:-}` を第2引数に含む**（P4(d) ファイルパス
  感応 SKIP / TASK-0070 AC-8。これが本セッション通底の未適用 wiring）。
- **EH-9 wiring が存在する**（委譲 commit 境界 / TASK-0073）。
- 上記トークンが `.claude/settings.json` の PreToolUse command 群に
  すべて存在すれば `doctor --check-settings` PASS。1 つでも欠落で FAIL。

## 検証・適用

- 検証: `bin/plangate doctor --check-settings`（未適用箇所を列挙し非0）
- 適用: `sh scripts/apply-claude-settings.sh`（冪等。ユーザーが実行）
- CI: settings drift check（required）が契約逸脱を fail させる

## 不変

- `.claude/settings.json` の AI 直接編集は禁止（self-mod ガード・恒久制約）。
  AI は契約定義・検証・適用 script 提供まで。適用は人間。
- 本契約の追加 hook は settings.example.json と整合させること。


## 責務分離（V-3 MJ-2/MJ-3 反映）

| 層 | 検証対象 | 手段 | 役割 |
|----|---------|------|------|
| CI `settings-drift`（required）| `.claude/settings.example.json`（契約 reference）| `check-settings-wiring.sh --target example` | 正本 reference が契約と乖離しないことを保証（example が壊れたら全員に波及するため）|
| `bin/plangate doctor --check-settings` | `.claude/settings.json`（ユーザー実体）| 構造（JSON）検証 | 実環境の wiring 未適用＝Shadow Config を検出 |
| 既存 `bin/plangate doctor` hook-wiring check | `.claude/settings.json` vs `.claude/settings.example.json` | 既存 check（TASK-0069）| settings.example.json を契約整合させた結果、未適用を**通常 doctor でも FAIL**（従来の false-PASS を是正）|

`.claude/settings.json` は gitignore（ユーザーローカル）のため **CI では検出
不可**。実体 drift の検出は doctor（ローカル / V-1・handoff DoD）が担う。
両者は役割が異なり、どちらか一方では「Shadow Config を構造的に防ぐ」根拠に
ならない（CI=reference 健全性 / doctor=実体適用）。

## タスクロックの強制経路（V-3 MJ-1 反映）

V-1/handoff 完了の DoD（[`docs/workflows/05_verify_and_handoff.md`](../workflows/05_verify_and_handoff.md)
/ [`working-context.md`](../../.claude/rules/working-context.md)）に
「`doctor --check-settings` PASS」を必須化。強制は次の二重で成立する:

1. **DoD 明文 + 通常 `doctor` の hook-wiring FAIL**: settings.example.json を
   契約整合させたため、未適用環境では `bin/plangate doctor`（通常実行）も
   FAIL する。doctor FAIL 状態での完了報告は Iron Law（検証証拠なしに完了
   扱いしない）違反。
2. **`doctor --check-settings`**: 構造検証で未適用箇所を決定論的に列挙。

> ~~既知の限界（V2 候補）~~: ~~完全な PreToolUse-hook レベルの機械 block~~ — **解消済 (PR #347)**。`.codex/hooks.json` + `.codex/hooks/eh-bridge.sh` で Codex CLI 側にも EH-1/2/3/6/9 が物理 PreToolUse block として配線済。Claude Code 側は従来通り `.claude/settings.json` で配線。詳細は本ファイル後段の §Codex CLI parity 参照。


## Codex CLI parity (#336 / Gap 4) — 達成済

**判明事項** (2026-05-25 PR #347): OpenAI Codex CLI は `PreToolUse` / `PostToolUse` hook API を公式提供しており、Claude Code の hook 仕様と直接互換 (matcher / stdin JSON / exit 2 で deny / `hookSpecificOutput.permissionDecision`)。公式仕様: https://developers.openai.com/codex/hooks

### 三層の強制機構

| 層 | 機構 | カバー範囲 |
|----|------|----------|
| 1. Session 前 | `scripts/codex-guarded.sh` (PR #343) | validate / doctor / EH-8 privacy / plan.md hash snapshot |
| 2. **Session 中 (物理 pre-Write block)** | **`.codex/hooks.json` + `.codex/hooks/eh-bridge.sh` (PR #347)** | **EH-1 / EH-2 / EH-3 / EH-6 / EH-9 を Codex 側でも発火** |
| 3. Session 後 | `scripts/codex-guarded.sh` post-flight | plan.md hash drift 検知 + validate 再実行 |

### 等価強制マトリクス

| 強制 | Claude Code | Codex CLI |
|------|-------------|-----------|
| EH-1 plan-exists | ✅ `.claude/settings.json` PreToolUse | ✅ `.codex/hooks.json` PreToolUse |
| EH-2 c3-approval | ✅ 同上 | ✅ 同上 |
| EH-3 plan_hash | ✅ 同上 | ✅ 同上 |
| EH-6 forbidden_files | ✅ 同上 | ✅ 同上 |
| EH-9 delegation-commit-boundary | ✅ PreToolUse Bash | ✅ PreToolUse Bash |

### Codex bridge の動作

1. Codex CLI が `apply_patch` / `Edit` / `Write` / `Bash` 呼び出し前に `.codex/hooks.json` を参照
2. 該当 matcher の `command` (= `.codex/hooks/eh-bridge.sh <HOOK_NAME>`) が起動
3. eh-bridge.sh が stdin JSON から file path (Edit/Write.file_path or apply_patch.command の `*** Update/Add/Delete File:`) を抽出
4. `PLANGATE_HOOK_FILE` / `PLANGATE_HOOK_TASK` を設定し `scripts/hooks/<HOOK_NAME>` を起動
5. exit code を Codex の `hookSpecificOutput.permissionDecision` (`allow` / `deny`) に翻訳
6. Codex CLI が deny 時は write を物理 block

### 責務分界 (継続)

- `.claude/settings.json` / `bin/plangate` / `scripts/hooks/*.sh` 等の Hardening Override 領域を改変するのは依然として **AI 改変不可** (Human-owned)
- 新規 hook 追加 (`.codex/hooks.json` / `.codex/hooks/*.sh`) は AI-owned (Override 対象外)
- 既存 hook 改変は Human-owned

## Wiring Integrity Enforcement（#500 / 配線整合性の強制・Specification）

> Status: Specification（方針確定。実装は HO パス絡みのため受け入れ条件ごとに段階 PBI へ分解）
> 出自: river 3 相レビュー（2026-06-08、Gemini + コードベース調査で代替実行 /
> external-reviewer-interface §10 unavailable 準拠）で検出した「規範↔実装」乖離
> （Shadow Config）への是正方針。

### 強制モード方針（example=warning / 本番=strict）

- `settings.example.json` は配布テンプレートのため **warning モード**（`PLANGATE_HOOK_STRICT`
  未設定）を既定とし、導入直後の破壊を避ける。
- **本番運用（承認境界を信頼する運用）では strict 必須**。`PLANGATE_HOOK_STRICT=1` を
  設定し EH-2 / EH-3 / EH-6 等を block モードで動かす。
- この warning↔strict の差は「設定の罠（Shadow Config）」になりうるため、後述の doctor
  検証で乖離を物理ブロックする。

### doctor によるモード別必須 strict 配線検証

- `bin/plangate doctor --check-settings` は、コード整合性に加えて **現在のモードで必須
  フックが strict 配線・有効化されているか** を検証する。
- Governance Contract（モード → 必須 strict フック集合）を定義する。
- **モード別 exit code**: **strict モード**では乖離があれば **exit 1 で物理ブロック**する。
  一方 **warning モード（example 既定）** では「導入直後の破壊を避ける」方針（上節）と
  整合させ、未配線・非 strict 配線に対して **warning を出力したうえで exit 0 で通過**させる
  （block しない）。モードごとの exit code 挙動を doctor 実装時に明示する。
- これにより「スクリプトは存在するが settings に配線されておらず動かない幽霊ガバナンス」を
  構造的に排除する。

### EH-10: 承認トークン書込みガードの採番・配線

- `scripts/check-approval-token-write.sh`（c3.json / maintenance.json 等の承認トークンへの
  AI 書込みガード）を **EH-10** として正規採番し、`PreToolUse(Edit|Write)` に配線する。
- #420（maintenance.json 発行元検証ギャップ / R-012）と直結。provenance 検証はそちらと協調。
- **配線方式（重要）**: Claude Code のフック実行環境は env `PLANGATE_HOOK_FILE` を自動 export しないため、`.claude/settings.json` の配線で `${PLANGATE_HOOK_FILE:-}` を **引数として明示的に渡す**（EH-3 と同様）。`check-approval-token-write.sh` は引数 `$1` をターゲットファイルパスの fallback として受け取れるよう実装する（env のみ参照だと Claude Code 環境下でガードがスルーされる）。

### 検証ロジックの対称化・テスト空白の解消（実装方針）

| 受け入れ条件 | 実装方針 | 主パス（HO） |
|------------|---------|-----------|
| EH-2（c3_status）strict 化 | EH-3 と同じ python3 strict JSON 解析へ置換（permissive な grep/sed 抽出を廃止し EH-3 と対称化） | `scripts/hooks/check-c3-approval.sh` |
| EH-1/EH-2 stdin fallback | env 未注入時に stdin `tool_input.file_path` から解決し SKIP(allow) を解消 | `scripts/hooks/*.sh` |
| maintenance verdict テスト | VALID / CONSUMED / OUT_OF_SCOPE / HARDENING_OVERRIDE の fixture + assert を追加 | `tests/hooks/` |
| ta-06 ログ握りつぶし解消 | `>/dev/null 2>&1` 圧縮をやめ、どの EH が落ちたかをログに残す | `tests/.../ta-06-hooks.sh` |

### 段階 PBI 分解（HO 実適用は Human）

本仕様の HO 実装は以下の順で段階 PBI に分解する（各々 plan → C-3 承認 👤 → exec、
HO 適用は Human）:

1. **EH-2 strict 化 + EH-1/EH-2 stdin fallback**（hooks 堅牢化・最小単位・回帰リスク低）
2. **EH-10 採番・配線 + check-approval-token-write 統合**（#420 と協調）。配線時は既存の契約検証スクリプト `scripts/check-settings-wiring.sh` の `checks` リストにも EH-10（`check-approval-token-write.sh`）を追加し、CI / ローカルの契約ドリフト検知（`--target example`）に組み込んで配線漏れを防ぐ
3. **doctor Wiring Integrity Enforcement**（Governance Contract 定義 + exit 1）
4. **hooks 回帰テスト拡充**（maintenance verdict fixture + ta-06 ログ解消）

各段階は承認境界（HO）の変更を含むため `mode-classification.md` により最低 high・
Standard C-3 同期固定（autonomous APPROVE 無効）とする。
