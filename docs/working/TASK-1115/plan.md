# EXECUTION PLAN — TASK-1115 (#1115)

> EH-13 の外側ゲート（`_is_token_path "$_cmd"`）に glob 語の解決可能性判定を追加し、
> ワイルドカードでファイル名リテラルを崩す bypass を全レーン同時に閉じる。

## Goal

`scripts/check-approval-token-write.sh` の Bash レーンで、
**展開後に保護トークンパスになりうる glob 語**を含むコマンドがゲートを素通りしない
ようにする。fail-closed 方針（TASK-1023 G-7）は緩めない。

## Constraints / Non-goals

- **fail-closed を緩めない**: 既存の判定不能 → block は一切変更しない。
- **真の陽性を 1 件も落とさない**: `ta-25` 既存 TC は全件 PASS のまま。
- **完全なシェル構文解析は行わない**（TASK-1045 GC-2 / TASK-1110 の方針継承）。
  本 PBI は「語の列挙 + パターン照合の方向反転」であり、`>` 判定の緩和ではない。
- **無条件 block を採らない**: 「glob を含む先は全部 block」は
  `cp schemas/*.json /tmp/` のような日常コマンドまで落とす（§誤検出の実測）。
- **行番号アンカー禁止**: 参照は関数名・アンカーコメント（`# t1115-*`）で行う。
- **絶対件数を契約値にしない**。
- Non-goals: #1101（HO 側正規化）/ `&>` 相関（#1110 据え置き）/
  `rm` 等の書き込み意図拡張 / 文字列連結回避。

## Approach Overview

現行:

```text
block ⇔ _is_token_path(cmd_string) AND _has_write_intent(cmd_string)
        ↑ ここが「リテラル照合」なので glob で崩されると素通り
```

変更後:

```text
block ⇔ _cmd_may_target_token(cmd_string) AND _has_write_intent(cmd_string)

_cmd_may_target_token(c) =
      _is_token_path(c)                                  ← 既存（不変）
   OR ∃ word ∈ split(c): _may_expand_to_token_path(word) ← 新規
```

`_has_write_intent` 側は**一切変更しない**。したがって既存の
「読み取りは block しない」「redirect 先の相関判定（#1110）」はそのまま効く。

## 判定設計: `_may_expand_to_token_path(word)`

語が glob メタ文字（`*` / `?` / `[`）を含まないなら **即 false**（従来経路に委譲）。
含む場合、次のいずれかで **true（= ゲート通過候補）**:

| ルール | 条件 | 根拠 |
|--------|------|------|
| **(A) approvals-dir** | 語が `approvals/` を含み、**basename に glob がある** | approvals/ 配下は `*/approvals/*.json` が全件保護対象。ファイル名が静的解決不能なら fail-closed |
| **(B) basename-glob** | basename が **先頭 glob でなく**、保護 basename リテラル（`maintenance.json` / `c3.json` / `parent-c3.json` / `parent-integration.json`）に**パターンとして一致**する | 照合方向を反転（`case "c3.json" in c3.jso*)` は一致）。これが #1115 の本質的是正 |

- (B) の照合は **引用符除去版の basename でも**行う（`"c3.jso"*` のような混在引用は
  shell が glob 展開するため / 保守的側）。
- **先頭 glob（`*.json` / `?x` / `[a]x`）を (B) から外す**のは誤検出抑制のため。
  `*.json` は「`c3.json` に一致しうる」ので理論上は真だが、
  `cp schemas/*.json /tmp/` のような日常コマンドを全部落とす。
  approvals 配下の `*.json` は **(A) と既存リテラル判定 `*/approvals/*.json`**
  の双方で閉じているので、外しても穴は開かない（§残存クラスに実測を記載）。
- basename は `${word##*/}`。ディレクトリ側だけの glob
  （`docs/working/*/approvals/c3.json`）は**既存リテラル判定**が拾う（実測 G4）。

### 語分割

コマンドを空白 / tab / 改行 / `;` / `&` / `|` / `(` / `)` / `<` / `>` で分割し
（`tr`）、`set -f` + `IFS=<newline>` で 1 語ずつ評価する。
分割失敗は fail-closed（true 側）。`>` を区切りに含めるのでリダイレクト先も
同じ語として評価される。

### 誤検出の実測（無条件 block を採らない根拠）

| コマンド | 無条件 block 案 | 本案 | 現行 |
|----------|-----------------|------|------|
| `cp schemas/*.json /tmp/` | **rc=2（誤）** | rc=0 | rc=0 |
| `cp docs/*.md /tmp/` | rc=0 | rc=0 | rc=0 |
| `sed -i.bak -e 's/a/b/' docs/working/*/status.md` | rc=0 | rc=0 | rc=0 |
| `sed -i '' -e 's/a/b/' docs/working/*/approvals-notes.md` | rc=0 | rc=0 | rc=0 |
| `cp /tmp/x docs/working/*/approvals/notes.md` | rc=0 | rc=0 | rc=0 |

（無条件 block 案 = 「redirect 先に glob があれば全部 block」を全語に拡張した場合。
`cp schemas/*.json` が落ちるため不採用。redirect 先限定にしても
`cp` / `tee` レーンの bypass が残るため、そもそも要件を満たさない。）

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S-1 | 是正前実測表を採取（本番経路 payload） | `evidence/before.txt` | agent | low | |
| S-2 | `_may_expand_to_token_path` / `_cmd_may_target_token` を実装し call site を差し替え | `scripts/check-approval-token-write.sh` | agent | med | 🚩 |
| S-3 | `ta-25` に T1115-TC-01〜07 を追加 | `tests/extras/ta-25-*.sh` | agent | low | |
| S-4 | 変異 M-7〜M-11 を追加（レーン全体 + レーン内部） | 同上 | agent | med | 🚩 |
| S-5 | 是正後実測 + `ta-25` 単体実行 + #1110 回帰確認 | `evidence/after.txt` | agent | low | 🚩 |

rollback: `git checkout origin/main -- scripts/check-approval-token-write.sh tests/extras/ta-25-approval-token-guard.sh`

## Files / Components to Touch

| ファイル | HO | 変更内容 |
|----------|----|----------|
| `scripts/check-approval-token-write.sh` | **HO 外** | 関数 2 個追加 + 外側ゲート call site 差し替え |
| `tests/extras/ta-25-approval-token-guard.sh` | **HO 外** | TC + 変異追加 |
| `docs/working/TASK-1115/**` | HO 外 | Plan Package |

`scripts/hooks/**` / `bin/plangate` / `.claude/**` / `schemas/**` / `.github/**` は
**変更しない**（HO 対象）。

## Testing Strategy

- **Unit / Integration**: `ta-25` に PreToolUse payload を stdin 供給する TC
  （= `.claude/settings.json` からの本番呼び出しと同一経路。明示引数・テスト専用
  env に偏らせない / diff-audit Phase 6 item 7）。
- **回帰**: 既存 T1023 / T1045 / T1110 TC を全件そのまま維持。
- **変異注入**（diff-audit Phase 6 item 6）:
  - **レーン全体**: M-7（`_cmd_may_target_token` を `_is_token_path` へ戻す call site 変異）
  - **レーン内部の分類**: M-8（(A) 無効化）/ M-9（(B) 無効化）/
    M-10（先頭 glob ガード除去 = **誤検出方向**）/ M-11（basename 抽出を全語に）
  - 空振りした変異は正直に記録する。
- **絶対件数を assert しない**（diff-audit Phase 6 item 8）。

## Risks & Mitigations

| Risk | 影響 | Mitigation |
|------|------|-----------|
| 誤検出増 | 開発フローが止まる | §誤検出の実測で 5 ケース測定。先頭 glob を (B) から除外 |
| `case` パターン中の `|` 誤解釈 | shell 差異で誤判定 | パターンごとに `case` を分割 |
| `set -f` の副作用 | 呼出元の glob 設定破壊 | 既存 `_redirect_writes_token` と同一方式（`set -f` … `set +f`）で統一 |
| `$(...)` 失敗で `set -e` 終了 | hook が rc≠0/2 で落ちる | すべて `|| _fallback` を付ける |
| 残存クラス（先頭 glob / 変数代入語） | 部分的な穴 | §残存クラスに明示。#1115 の報告クラスは閉じる |

## 残存クラス（本 PBI で閉じない / 明示）

| クラス | 例 | 理由 |
|--------|----|------|
| approvals 外の先頭 glob | `cp x foo/*3.json` | (B) から除外（誤検出抑制とのトレードオフ） |
| 変数代入語 | `OUT=c3.jso* cmd` | 語全体が `OUT=...` になり basename 照合が外れる |
| 文字列連結 | `open("...c3.jso"+"n","w")` | 別クラス（静的連結解析が必要） |
| `rm` 等 | `rm docs/.../approvals/*.json` | `_has_write_intent` に `rm` が無い（既存ギャップ / 本 PBI 範囲外） |

## Questions / Unknowns

- なし（Human C-3 で判断を要する既存 TC 期待値反転は **0 件**）。

## Mode 判定

**モード**: `high-risk`

**判定根拠**:

- 変更ファイル数: 2（実装 1 + テスト 1）+ Plan Package → 定量では `light`〜`standard`
- 受入基準数: 6 → `standard`
- 変更種別: **承認境界のガード（EH-13）の判定ロジック変更** → 定性で最上位
- リスク: **block を広げる方向の変更**。誤検出は開発フロー停止、
  緩めれば承認境界の bypass → 高
- 影響範囲: EH-13 の**全レーン**（redirect / copy-like / line-editor /
  git-restore / inplace-edit / lang-write）に波及
- **最終判定**: `high-risk`（安全側）

補足: `scripts/check-approval-token-write.sh` は `scripts/hooks/*.sh` ではないため
**Hardening Override 対象パスそのものではない**（オーガナイザー実測どおり HO 外）。
ただし `mode-classification.md`「承認境界周辺の変更 → 最低でも高」の趣旨
（承認トークンの保護ガード本体）に該当するため **`high-risk` に引き上げ**、
`lite_eligible=false` とする。C-3 は **人間必須**（autonomous APPROVE 不可）。
本ワーカーは **C-3 を発行しない**（`c3.json` 未作成）。
