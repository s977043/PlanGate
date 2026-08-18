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

### 既存 TC の期待値反転（**2 件** / Human C-3 の判断事項）

本 PBI は「相関解析しない」ことを固定していた既存 TC を **2 件**反転する。
どちらも #1110 の是正対象クラスそのものだが、**承認済み成果物の期待値変更**なので
C-3 で明示承認を得る対象として列挙する（V-3 R-003 反映。初版では 1 件しか
宣言しておらず、宣言漏れのまま exec 中に 2 件目を反転していた）。

| 反転する TC | 変更 | 上位資料への影響 | C-3 判断事項 |
|-------------|------|------------------|--------------|
| `T1045-TC-19`（文字列リテラル中の `>`） | rc=2 → **rc=0** | TASK-1045 handoff K-2 が自ら「minor（残存誤検知）」と分類済 | 低（既知課題の解消） |
| `T1023-TC-09`（token read + 別 file write の混在） | rc=2 → **rc=0** | **TASK-1023 pbi-input AC-04**「token path と別 write を混在させた command は安全側 block を仕様とする」を **redirect レーンに限り上書き**する | **要判断**（人間が C-3 で承認した AC 本文の上書き） |

- `T1023-TC-09` の反転は **AC-04 の全面撤回ではない**。`cp` / `mv` / `tee` 等の
  非 redirect レーンは従来どおり相関解析せず安全側 block のままであり、
  上書きされるのは **redirect（`>`）レーンのみ**。
- TASK-1023 側の資料（handoff 等）への追補は **C-3 承認後の follow-up** とし、
  本 PBI では AI が単独で他 PBI の AC 記述を書き換えない。

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
  正規化後に残った `/dev/*` / **語の切り詰めで別物になりうる引用・退避済みの先**）は
  rc=2（fail-closed）。**「切り詰めクラス」は V-3 R-001 で追加**（初版はこのクラスを
  fail-closed に数え落としており、引用済みトークンパスが通過していた）
- **AC-3b**: 同一のトークンパスに対して `>` / `tee` / `cp` / `Write` の
  **どのレーンでも判定が一致する**（レーン非対称を作らない）
- **AC-4**: BLOCK メッセージが `rule=file-redirect` と一致したリダイレクト先を含む
- **AC-5**: 既存 TA-25 の全 TC が PASS（`&>` 系・`>&<file>`・`/dev/stdout` 等の
  block 維持を含む。期待値を変更する既存 TC は上表の **2 件のみ**）
- **AC-6**: 変異注入が実 TC の FAIL で kill される。**レーン全体を落とす変異だけでなく、
  レーン内部の分類だけを誤らせる変異**（引用・退避検出の無効化 / 終端文字クラスの改変 /
  診断値リセットの削除 / 改行畳み込みの無効化）を含むこと（V-3 R-002 / R-005 反映。
  レーン全体を落とす変異では今回の穴は原理的に検出できなかった）

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
