# EXECUTION PLAN — TASK-1110 (#1110)

> EH-13 `file-redirect` ルールに「リダイレクト先 ↔ トークンパス」の相関判定を導入し、
> 誤検出（トークン名を含む文言 + 無関係なリダイレクト）を解消する。

## Goal

`scripts/check-approval-token-write.sh` の Bash レーンにおいて、
`file-redirect` ルールが **リダイレクト先が保護対象トークンパスに解決される場合にのみ**
block するようにする。判定不能は block 側（fail-closed）を維持する。

## Constraints / Non-goals

- **fail-closed を緩めない**: 抽出失敗・展開・glob・空・正規化後に残った `/dev/*` は block。
- **完全なシェル構文解析は行わない**（TASK-1045 GC-2 の方針を継承）。
  本 PBI は「列挙的な抽出 + 安全側フォールバック」であり、`>` 判定の一般的緩和ではない。
- **POSIX BRE のみ**（GNU 拡張 `\|` / `\+` / `\b` 不可、sed の RHS `\n` 不可）。
  `LC_ALL=C` 固定（TASK-1045 GC-6 / R-007 の実測理由を継承）。
- **行番号アンカー禁止**: 参照は関数名・アンカーコメント（`# t1110-*`）で行う。
- **絶対件数を契約値にしない**: TC 件数・ルール件数を assert しない。
- Non-goals: TASK-1023 G-7（fail-closed 方針）/ parse-unknown 挙動 /
  redirect 以外のルールの相関化 / `&>` の block 維持方針（TASK-1045 U-2）。

## Approach Overview

現行:

```text
block ⇔ _is_token_path(cmd_string) AND _has_write_intent(cmd_string)
        ↑ 文字列にトークン名が出るか   ↑ 残存 `>` があるか（先を見ない）
```

変更後（redirect レーンのみ）:

```text
block ⇔ _is_token_path(cmd_string) AND (
            ( 残存 `>` あり AND _redirect_writes_token(normalized) )   ← 相関判定（新規）
            OR 非 redirect ルール（copy-like / git-restore / ... 現状のまま）
        )
```

`_redirect_writes_token()` は **正規化後**（`_strip_nonwrite_redirects` 適用後）の
文字列を入力に取り、残存する各リダイレクト先を静的抽出して次で判定する:

| 抽出結果 | 判定 |
|----------|------|
| `_is_token_path` に一致 | **block**（真の陽性） |
| `/dev/*`（正規化で除去されなかった擬似デバイス） | **block**（呼出側で再束縛されうる / fail-closed） |
| 空 / `$` / バッククォート / glob (`*` `?` `[`) を含む | **block**（静的解決不能 / fail-closed） |
| **引用符 `'` `"` / バックスラッシュ `\` が残っている** | **block**（切り詰めクラス / V-3 R-001） |
| `&>` / `&>>` を含むコマンド | **block**（TASK-1045 U-2 の block 維持） |
| 抽出パイプラインの失敗（sed 失敗等） | **block**（fail-closed / TASK-1045 GC-8 (i) と同方針） |
| 上記以外の具体パス（例 `/tmp/log.txt`） | 非 block |

### 切り詰めクラスを fail-closed に数える根拠（V-3 R-001 / critical の是正）

先の語は終端文字（空白 / `;` / `&` / `|` / `(` / `)` / `<`）で打ち切る。
**POSIX sh でこれらの文字を語の一部として書くには、必ず引用かバックスラッシュ退避が要る。**
したがって打ち切りで本来の先を失った語には、打ち切り位置より前に必ず `'` / `"` / `\` が残る。
よって「打ち切り後の語に引用符・バックスラッシュが含まれる → 静的に解決できていない」
と判定すれば、構文解析（GC-2 で不採用）へ踏み込まずに当該クラスを閉じられる。

`#` は **終端文字に含めない**。`#` は語頭のみコメント開始で語中は通常文字であり、
退避なしに `dir#1/<TOKEN>` と書けてしまうため、終端に含めると取りこぼす
（語頭の `#` は「先が無い」= 空 → block へ倒す）。

初版はこのクラスを fail-closed の宣言にも実装にも数えておらず、
**引用またはバックスラッシュ退避されたトークンパスが通過していた**
（同一パスが `tee` / `cp` / `Write` では block されるのに `>` だけ通るレーン非対称）。

正規化（`/dev/null` 破棄・fd 複製 / クローズの除去）は **残す**。相関判定を
正規化後の文字列に対して行うことで、正規化が load-bearing であり続け、
既存の変異テスト T1045-TC-09（正規化 no-op 化 → T1045-TC-01 が FAIL）の
kill 経路を壊さない。

## Work Breakdown

### S-1: 現状の実測固定（RED の土台）

- Output: `evidence/baseline-cases.md`（A〜E + 境界計 18 ケースの修正前 rc）
- Owner: agent / Risk: 低 / 🚩 A が rc=2、D が rc=2 であることを確認

### S-2: TC 追加（RED）

- Output: `tests/extras/ta-25-approval-token-guard.sh` に `T1110-TC-*` を追加
  - 負の対照: A（トークン名 + 無関係リダイレクト）/ C / E / トークン名 + 別ファイルへの write
  - 真の陽性維持: `>` / `>>` / `1>` / 引用付き先 / `./` 前置 / `..` 混在 / 複文の後段
  - fail-closed: `$(...)` 先 / 変数先 / glob 先 / 空の先
  - メッセージ: `rule=file-redirect` と `redirect_target=` を含む
- Owner: agent / Risk: 中 / 🚩 追加 TC が **原本 guard で FAIL する**ことを確認（RED）

### S-3: 実装（GREEN）

- Output: `scripts/check-approval-token-write.sh`
  - `_redirect_writes_token()` 新設（アンカー `# t1110-redirect-correlate` で呼び出し）
  - `_has_write_intent()` の redirect レーンを相関判定に差し替え
    （`# t1045-redirect-normalize` / `# t1045-file-redirect` アンカーは維持）
  - `_block` メッセージに `redirect_target=` を追加
- Owner: agent / Risk: 高（承認境界の強制機構）/ 🚩 `sh -n` 通過 + S-2 の TC が GREEN

### S-4: 既存 TC との突合

- Output: 個別実行ログ `evidence/ta25-after.log`
- Owner: agent / Risk: 中
- 🚩 既存 TC の期待値変更は **`T1045-TC-19` と `T1023-TC-09` の 2 件のみ**
  （いずれも #1110 是正対象クラスと同型）。**うち `T1023-TC-09` は TASK-1023 の
  AC-04 を redirect レーンに限り上書きするため、Human C-3 の判断事項**
  （pbi-input §既存 TC の期待値反転を参照 / V-3 R-003 反映）。
  他の既存 TC はすべて期待値不変で PASS すること

### S-5: 変異注入（検出力の実証）

- Output: `evidence/mutation-M1.log` / `evidence/mutation-M2.log`（適用→FAIL→復元→PASS）
  + `ta-25` 内に `_t25_mutate` 呼び出しを 2 本追加（prefix `T1110`）
- Owner: agent / Risk: 中
- **レーン全体**を落とす変異（呼び出し側 = call site を破壊）
  - **M-1**: `_redirect_tok=1` 固定（= 元の OR 判定へ回帰）→ ケース A の TC が FAIL
  - **M-2**: `_redirect_tok=0` 固定（= 真の陽性を落とす）→ `T1045-TC-04` が FAIL
- **レーン内部の分類**だけを誤らせる変異（V-3 R-002 / R-005 反映。**M-1 / M-2 だけでは
  今回の穴（解決不能 → 解決済み非トークンの誤分類）は原理的に検出できない**）
  - **M-3**: 引用・退避の検出を無効化 → 切り詰めクラス TC が FAIL
  - **M-4**: 終端文字クラスへ `#` を戻す → 語中 `#` TC が FAIL
  - **M-5**: 診断値リセットの削除 → 診断値の持ち越し TC が FAIL
  - **M-6**: 改行畳み込みの無効化 → heredoc 本文の負の対照 TC が FAIL
- 🚩 空振り（適用しても PASS のまま）だった場合は TC の欠陥として正直に記録する

### S-6: Plan Package / evidence の確定

- Output: `plan.md` / `todo.md` / `test-cases.md` / `review-self.md` / `status.md` / evidence
- Owner: agent / Risk: 低

## Files / Components to Touch

| ファイル | 変更 | HO |
|----------|------|----|
| `scripts/check-approval-token-write.sh` | 相関判定の導入 | HO 外（実測 rc=0） |
| `tests/extras/ta-25-approval-token-guard.sh` | TC / 変異追加 | HO 外（実測 rc=0） |
| `docs/working/TASK-1110/**` | Plan Package / evidence | HO 外 |

**触らない**: `scripts/hooks/*.sh`（HO）/ `.claude/settings*.json`（Human-owned）/
`bin/plangate` / `schemas/*` / `.github/workflows/*`。

## Testing Strategy

- **Unit / Integration**: `tests/extras/ta-25-approval-token-guard.sh` を
  **個別実行**（`sh tests/extras/ta-25-approval-token-guard.sh`）で検証。
  フルスイート（`tests/run-tests.sh`）は ta-61 が入れ子で full-suite を再実行する
  構造のため、並走ワーカーの相互妨害を避けて**本 PBI では実行しない**
  （オーケストレータが最後に 1 本走らせる）。
- **Verification Automation**: A〜E を含む 18 ケースを payload 生成スクリプトで
  一括実行し、修正前後の rc 表を evidence に残す。
- **Mutation**: 既存 `_t25_mutate` ハーネスを再利用し、**call site を壊す**変異で
  kill を実証する（関数本体だけを壊す変異は検出力の証明にならない）。

## Risks & Mitigations

| Risk | 影響 | Mitigation |
|------|------|-----------|
| 相関判定で真の陽性を取りこぼす | 承認境界の穴（critical） | 判定不能は全て block 側。**「判定不能」の定義に切り詰めクラスを含める**（V-3 R-001 で顕在化。初版は数え落としていた）。既存 block 系 TC を期待値不変で維持し、M-2 に加え **レーン内部の分類を壊す M-3〜M-6** で緩和を機械検出 |
| quote / 変数 / パス正規化の抜け（#1101 同型） | bypass | `./` `..` は `_is_token_path` のパターンが `*` 前置のため影響なし。**引用符は剥がさず「残っていること自体を解決不能の証拠」として block 側へ倒す**。展開・glob も block 側 |
| レーン間で判定が食い違う（`>` だけ通る等） | 承認境界の穴 | 同一パスに対する `>` / `tee` / `cp` / `Write` の一致を TC で固定（AC-3b） |
| sed の GNU/BSD 差異 | 実行環境で誤動作 | POSIX BRE のみ・RHS `\n` 不使用（分割は `tr` で行う）・`LC_ALL=C` 固定 |
| 既存変異テストの kill 経路破壊 | 検出力の silent 低下 | 正規化を残し相関判定を正規化後文字列に適用。`# t1045-*` アンカーを維持し、変異ハーネスを流用 |
| 複数行コマンド（heredoc）での抽出崩れ | 誤判定 | 抽出前に改行を空白へ畳む |

## Questions / Unknowns

- Q1: `&> <file>` / `>& <file>` を相関化するか → **しない**（TASK-1045 U-2 を維持。
  本 PBI 範囲外。既知の残存誤検出として handoff に記録）
- Q2: `> /dev/stdout` 等の擬似デバイスを許すか → **許さない**（呼出側で
  token file へ再束縛されうるため fail-closed。既存 T1045-TC-11 を維持）

## Mode判定

**モード**: `high-risk`

**判定根拠**:

- 変更ファイル数: 2（コード / テスト）+ Plan Package → 定量では `standard` 相当
- 受入基準数: 6 → `high-risk`（6-10）
- 変更種別: **code**（セキュリティガードのロジック変更）
- リスク: **高** — EH-13 は承認トークン（`approvals/*.json` / `maintenance.json`）への
  AI 直接書き込みを止める**承認境界の強制機構**。本変更は block 条件を
  **狭める方向**であり、誤ると承認境界に穴が空く
- 影響範囲: EH-13 が配線された全 Bash ツール呼び出し（複数レイヤーに波及）
- ロールバック: 計画的に必要（`git revert` 1 コミットで戻せるが、
  戻すと #1110 の誤検出が再発する）

**例外ルールの適用判断**:

- 「セキュリティ関連の変更 → 最低でも中」: **該当**（承認トークン保護ガード）
- 「承認境界周辺の変更 → 最低でも高」: 対象パス（Hardening Override 9 カテゴリ）に
  `scripts/check-approval-token-write.sh` は**含まれない**（HO は `scripts/hooks/*.sh`。
  本ファイルは `scripts/` 直下で、実測でも `rc=0` = HO 外）。
  したがって**文言上の完全一致では非該当**。
  しかし本ファイルは**承認境界そのものを強制する hook 実体**であり、
  「承認境界周辺」に実質該当するかは判定が割れうる。
  mode-classification の **「自動推定の安全側: 該当不確実なら該当扱い（Mode を
  引き上げる側）」** に従い、**該当扱い**として最低 `high-risk` を採用する。
- **最終判定**: `high-risk`
- `lite_eligible`: **false**（安全側。承認境界の強制機構に対する block 条件の緩和）
- **C-3**: 人間 C-3 必須（autonomous APPROVE 不可 = mode high-risk かつ
  セキュリティ関連）。本ワーカーは **`c3.json` を発行しない**。
