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

## 判定設計（V-3 REJECT を受けた再設計）

初版は **(A) をディレクトリで括り (B) を *形*（先頭に glob があるか）で除外**して
おり、**軸が混在**していた。その結果、片方の軸で漏れ（保護ディレクトリを 1 つしか
見ていない）、もう片方の軸で止めすぎた（保護対象でない拡張子まで block）。
V-3 R-001 / R-003 は同じ根から出ている。

**保護対象を「ディレクトリ条件 × basename 条件」の組で定義し直し、除外は
*形* ではなく *幅*（保護名をどれだけ pin するか）で行う。**

| 組 | ディレクトリ条件 | basename 条件 | 目的 |
|----|------------------|---------------|------|
| **P1** | 承認トークン置き場（**2 箇所**）配下 | **`.json` で終わりうる** | 当該 dir で実際に保護されているのは `.json` のみ。他の拡張子は止めない |
| **P2** | 任意 | 保護名リテラルに一致しうる **かつ 1 文字を除いて pin する** | 「1 文字だけ譲る狙い撃ち」を捕らえ、「一致はしうるが狙っていない広い語」は通す |

### 幅（pin）の定義

候補語を **パターン**、保護名を **subject** に置いて照合し（照合方向の反転）、
一致したときに候補語が pin する文字数を数える:

- リテラル文字 … 1
- `[...]` … 1（1 文字にしか一致しないため）
- `*` / `?` … 0

`pin >= len(保護名) - 1` を要求する = **1 文字を除いて pin していなければ通す**。

### 「`.json` で終わりうる」の判定

最後のメタ文字より後ろのリテラル部分（tail）が `.json` の suffix であるか、
tail 自体が `.json` で終わるかを見る。`*.pdf` / `*.md` は tail が `.pdf` / `.md`
なので **`.json` になりえない** → P1 に該当しない。

### brace expansion（V-3 R-002）

`{` をメタ文字集合に加え、`{` 以降を `*` へ正規化する。`*` は brace の展開結果を
包含するので安全側。**brace は存在しないファイルを新規作成できる**ため、
既存ファイルの上書きしかできない glob より危険であり、残存クラス化ではなく封鎖した。

### fork ゼロ（V-3 R-004）

PreToolUse は**全 Bash 実行のたび**に走るため、サブシェル・外部コマンドを使わず
パラメータ展開と `case` のみで実装する。さらに文字走査は
**保護ディレクトリ配下か、保護名にパターン一致した語だけ**で行う（遅延化）。

## 誤検出の探索方法（V-3 R-003 の方法論指摘への対応）

初版の FP 実測 5 ケースは「除外条件に当たるサンプル」に偏っていた。再設計では
**block 条件の補集合を体系的に列挙**する方針に変更した:

1. **P1 の補集合**: 保護ディレクトリ配下 × `.json` にならない拡張子（`*.md` / `*.pdf`）
2. **P2 の補集合**: 保護名に一致しうるが幅が足りない語
   （先頭 1 文字のみ pin / 拡張子のみ pin）
3. **保護ディレクトリに似て非なる語**（`approvals-notes` 等）
4. **引用の有無での対称性**（V-3 R-006）
5. **書き込み意図が無い経路**（読み取り・メッセージ文字列）

実測は 3 版（`pre` = `origin/main` / `v1` = REJECT 版 / `v2` = 本是正）で採り、
`evidence/v3-both-directions.txt` に **両方向**（塞ぐべきもの / 誤検出であっては
ならないもの）を 1 表で残す。

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

## 残存クラス（本 PBI で閉じない / 実測ベース・V-3 R-009 反映）

初版の表は「到達先を過小に見せている」と指摘されたため、**実測した rc とともに**
再掲する（`evidence/v3-both-directions.txt` / `evidence/edge-cases.txt`）。

| クラス | 例 | v2 実測 | 理由 |
|--------|----|---------|------|
| 幅が足りない語（保護ディレクトリ**外**） | `cp src/c* /tmp/` | rc=0 | **意図的**。幅ガードで通す（V-3 R-003）。保護ディレクトリ配下なら P1 が捕らえる |
| 拡張子のみ pin する語（保護ディレクトリ外） | `cp schemas/*.json /tmp/` | rc=0 | 同上 |
| 変数代入語 | `OUT=<name> cmd` | rc=0 | 語全体が `OUT=…` になり basename 照合が外れる |
| 文字列連結 | 言語ランタイム内で名前を組み立てる形 | rc=0 | 静的連結解析が必要（別クラス） |
| `rm` / `chmod` / `gzip` / `touch` | `rm <protected-dir>/*.json` | rc=0 | **`_has_write_intent` 側の既存ギャップ**（V-3 R-010）。#1115 で新規に生じたものではない |
| 読み方向の区別なし | `cp <protected-name> /tmp/` | rc=2 | **既存設計**。`_has_write_intent` に方向判定が無く、リテラル形も `origin/main` で rc=2。V-3 R-003 #5/#11 の棄却根拠 |
| ディレクトリ名自体を glob で崩す | 保護ディレクトリ名の一部を `*` にする形 | 一部 rc=0 | basename が literal なら `_is_token_path` が捕らえるが、両方を崩すと漏れる |

**follow-up 候補**（本 PBI 範囲外・issue 化を推奨）:

- `_has_write_intent` への `rm` / `chmod` / `gzip` / `touch` 追加（V-3 R-010）
- 読み方向（source 位置の引数）を block 対象から外す方向判定
- #1101（HO 側 `scripts/hooks/check-plan-hash.sh` の正規化。同クラス・別実装）

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
