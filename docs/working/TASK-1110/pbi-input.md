# PBI INPUT PACKAGE — TASK-1110 (#1110)

## Context / Why

EH-13（承認トークン書き込みガード / `scripts/check-approval-token-write.sh`）の
Bash レーンは、`_is_token_path "$_cmd"`（コマンド文字列全体にトークンパス文字列が
含まれるか）と `_has_write_intent "$_cmd"`（コマンドに書き込み意図があるか）を
**別々に**評価し、両者の AND だけで block を決めている。

`file-redirect` ルールは「正規化後に `>` が 1 つでも残っているか」しか見ないため、
**リダイレクト先が実際にトークンパスかどうかを一切突き合わせていない**。
結果として「コミットメッセージ等にトークンパス文字列を含み、かつ無関係な
リダイレクトを伴うコマンド」が誤って block される。

実測（本 PBI 着手時 / `origin/main` = `7d91f7b`）:

| # | コマンド | 期待 | 実測 |
|---|----------|------|------|
| A | `git commit -m 'docs: <TOKEN>' > /tmp/log.txt` | rc=0 | **rc=2 BLOCK (`rule=file-redirect`)** |
| B | `git commit -m 'docs: <TOKEN> の扱い'` | rc=0 | rc=0 |
| C | `git commit -m 'docs: approval token' > /tmp/log.txt` | rc=0 | rc=0 |
| D | `echo x > <TOKEN>` | rc=2 | rc=2 |
| E | `cat <TOKEN>` | rc=0 | rc=0 |

A と B・C の対比が決定的で、**単独では block されない 2 要素が同一コマンド行に
同居した瞬間に、リダイレクト先が `/tmp/log.txt` でも block される**。

実害はドッグフーディング中に恒常的に発生している（本 PBI の調査コマンド自体が
この誤検出で block された = 実例）。

## What (Scope)

### In scope

- `file-redirect` ルールを **リダイレクト先とトークンパスの相関判定**に変更する
  （先がトークンパスに解決される場合のみ block）
- 判定不能（展開・glob・抽出失敗・空・正規化後に残った擬似デバイス）は
  **block 側**に倒す（fail-closed 維持）
- BLOCK メッセージに **どのリダイレクト先が一致したか** を出す
- `tests/extras/ta-25-approval-token-guard.sh` に負の対照（A / C / E 相当）と
  境界 TC を追加、変異注入 2 種で検出力を実証

### Out of scope

- EH-13 の fail-closed 方針（TASK-1023 G-7）の見直し
- `hook_event_name` 欠落時の parse-unknown 挙動
- `copy-like` / `git-restore` / `inplace-edit` / `lang-write` / `line-editor`
  各ルールの相関化（いずれも現状どおり保守的 OR のまま）
- `&>` / `&>>`（全出力リダイレクト）の block 維持（TASK-1045 U-2）の見直し
- `.claude/settings*.json` の配線変更（Human-owned）

## 受入基準

- **AC-1**: `git commit -m '<TOKEN を含む文言>' > /tmp/log.txt` が rc=0（誤検出解消）
- **AC-2**: `echo x > <TOKEN>` / `>> <TOKEN>` / `1> <TOKEN>` が rc=2（真の陽性維持）
- **AC-3**: リダイレクト先が静的に解決できない場合（`$(...)` / 変数 / glob / 空 /
  正規化後に残った `/dev/*`）は rc=2（fail-closed）
- **AC-4**: BLOCK メッセージが `rule=file-redirect` と一致したリダイレクト先を含む
- **AC-5**: 既存 TA-25 の全 TC が PASS（`&>` 系・`>&<file>`・`/dev/stdout` 等の
  block 維持を含む。期待値を変更する既存 TC は #1110 の是正対象であることを
  本文で明示したものに限る）
- **AC-6**: 変異注入 2 種（相関判定を OR に戻す / 相関判定を常時 false にする）が
  それぞれ実 TC の FAIL で kill される

## Notes from Refinement

- EH-13 の実体は `scripts/check-approval-token-write.sh`（`scripts/` 直下 = HO 外）。
  `scripts/hooks/*.sh` は HO 対象だが本 PBI は触らない。
- `_strip_nonwrite_redirects()`（TASK-1045）は残す。相関判定は**正規化後の
  文字列**に対して行い、正規化が load-bearing であり続けるようにする
  （既存の変異 T1045-TC-09 の kill 経路を壊さないため）。
- 既存 T1045-TC-19（文字列リテラル中の `>` を保守的 block）は本 PBI の是正対象
  クラスそのもの（ケース A と同型）なので期待値を反転する。

## Estimation Evidence

- **Risks**: 相関判定の導入で真の陽性を取りこぼす（安全側の後退）。
  シェル構文の完全解析は不可能なため、抽出不能ケースの扱いが要。
- **Unknowns**: `>&<file>` / `&>` の扱いを相関化するか（→ Out of scope とし
  現状維持で決着）。
- **Assumptions**: `_is_token_path()` のパターン集合は不変。
  BSD sed / GNU sed 双方で動く POSIX BRE のみを使う（TASK-1045 GC-6 と同じ制約）。
