# HANDOFF — TASK-1045（EH-13 token-guard の読み取り誤 block を塞ぐ）

> WF-05 完了資産（`hybrid-architecture.md` Rule 5）。PR マージ後も削除しない。
> Issue: [#1045](https://github.com/s977043/plangate/issues/1045) / Mode: **`critical`**
> ブランチ: `feat/1045-exec` / base: `origin/main` = `e9d384b`

## 5. 引き継ぎ文書（5 分サマリ）

`scripts/check-approval-token-write.sh` の `_has_write_intent()` は
**「コマンド文字列に `>` が 1 文字でも含まれれば書き込み意図あり」**と判定していたため、
**1 バイトも書き込まない読み取りコマンド**（`2>/dev/null` / `2>&1` / `>&2` / `3>&-` を伴うもの）が
すべて block されていた。本 PBI はこの判定を

1. **正規化**（新設 `_strip_nonwrite_redirects()`）で **fd 複製 / fd クローズ**と
   **`/dev/null` への破棄**だけを列挙的に除去し、
2. **残った `>` があればファイル宛リダイレクト**とみなす

の 2 段構成へ置き換えた。**除外は allowlist であり `>` 判定の一般的な緩和ではない**（plan GC-1 / GC-2）。
併せて block メッセージへ `rule=<id>`（6 種）を付与し、根拠を機械可読にした。

**弱体化していないことの機械的担保**は 3 重:
(a) 退行 TC 13 件がすべて `rc=2` を維持、
(b) 「弱める側の変異」（残存 `>` 判定を常時 false 化）が `T1045-TC-04` の実 FAIL で kill される、
(c) 正規化ヘルパが **fail-closed**（`sed` 不在 / `sed` 失敗のいずれでも `rc=2`）。

### 変更ファイル（3 領域に閉じている / SC-7 不発火）

| パス | 変更内容 |
|---|---|
| `scripts/check-approval-token-write.sh` | `_strip_nonwrite_redirects()` 新設 / `_has_write_intent()` の `>` 検査を 2 段化 / `command -v sed` / `rule=<id>` 6 種 / 一意アンカー 2 種 |
| `tests/extras/ta-25-approval-token-guard.sh` | `T1045-TC-01`〜`TC-22b` の **23 件**追加 / `_t25_mutate` に label prefix 引数 / 変異 2 方向追加 |
| `docs/working/TASK-1045/` | `status.md` / `current-state.md` / `handoff.md` / `decision-log.jsonl` / `evidence/` |

`plan.md` / `todo.md` / `test-cases.md` / `pbi-input.md` / `approvals/` は **1 行も編集していない**。

---

## 1. 要件適合確認結果（AC-01〜13）

| AC | 内容 | 判定 | 根拠 |
|---|---|:--:|---|
| **AC-01** | `2>/dev/null` 付き read-only が通る | **PASS** | `T1045-TC-01` rc=0 |
| **AC-02** | `2>&1` | **PASS** | `T1045-TC-02` rc=0 |
| **AC-03** | `>&2`（fd 複製）**および `N>&-`（fd クローズ）** | **PASS** | `T1045-TC-03` / `T1045-TC-20` rc=0 |
| **AC-04** | 退行: `> <TOKEN>` は block 維持 | **PASS** | `T1045-TC-04` / `TC-12` / `TC-13` / `TC-14` / `TC-15` / `TC-19` / `TC-22` / `TC-22b` すべて rc=2 |
| **AC-05** | 退行: `>> <TOKEN>` | **PASS** | `T1045-TC-05` rc=2 |
| **AC-06** | 退行: `1> <TOKEN>` / 擬似デバイス宛 | **PASS** | `T1045-TC-06` / `TC-11` rc=2 |
| **AC-07** | 併記による回避の非成立 | **PASS** | `T1045-TC-07` 4 形すべて rc=2 |
| **AC-08** | 修正前へ戻す変異で誤検知解消 TC が FAIL | **PASS** | `T1045-TC-09` → `[FAIL] T1045-TC-01` + 子 rc=1 |
| **AC-09** | 弱める側の変異で退行防止 TC が FAIL | **PASS** | `T1045-TC-10` → `[FAIL] T1045-TC-04` + 子 rc=1 |
| **AC-10** | block メッセージのルール識別子 | **PASS** | `T1045-TC-08`（`rule=file-redirect` / `rule=copy-like`） |
| **AC-11** | 既存 TC 全 PASS | **PASS** | `T1045-TC-16` / `TC-21`。standalone **70 passed / 0 failed**、`run-tests.sh` **700 passed / 0 failed** |
| **AC-12** | 起点の read-only 監査が通る | **PASS**（1 件の宣言済み例外あり） | `T1045-TC-17` 5 形 rc=0 + evidence 11 形。**`->` を含む文字列リテラルのみ block 維持**（GC-2 / 既知課題 K-2） |
| **AC-13** | syntax / 実行可能属性 | **PASS** | `sh -n` PASS / `-x` あり / `T1045-TC-18` |

**AC 13 件すべて PASS。FAIL 0 / WARN 0。**

### 検証状態の明示

| 項目 | 状態 |
|---|---|
| `ta-25` standalone（BSD / macOS） | **実行済み** — 70 passed / 0 failed / EXIT 0 |
| `tests/run-tests.sh`（source 経路 / BSD / macOS） | **実行済み** — 700 passed / 0 failed / EXIT 0 |
| GNU `sed` 4.10 での正規化等価性 | **実行済み** — 29/29 一致・出力 byte identical |
| 変異注入 2 方向の kill | **実行済み** — 実出力を evidence に保存 |
| GC-8 fail-closed の検出力 | **実行済み** — (i) 欠落 build の FAIL-OPEN を再現 |
| `bin/plangate doctor --check-settings` | **実行済み** — メイン checkout で **PASS**（worktree は `.claude/settings.json` が gitignore で不在のため FAIL する。実配線は正常） |
| **CI（ubuntu / GNU `grep` / dash）での `ta-25`** | **未実行** — PR 作成後にしか回らない（UV-1 の残り） |

---

## 2. 既知課題一覧

| ID | 内容 | 重大度 | 扱い |
|---|---|---|---|
| **K-1** | **`&>` / `&>>` 付きの読み取りコマンドは block され続ける**（`&> /dev/null` を含む）。例: `cat <TOKEN> &> /dev/null` → `rc=2` | minor（残存誤検知） | **C-3 裁定 Q-2 で「block 維持」を確定**（除外面を増やさない安全側）。固定 TC = **`T1045-TC-14 (3)`**。運用で頻度が問題化したら follow-up issue で除外を再検討する |
| **K-2** | **完全なシェル構文解析を行わないことによる取りこぼし**: 文字列リテラル中の `>`（例: `python3 -c "print('<TOKEN> -> ok')"` の `->`）、ヒアドキュメント本文中の `>`、変数展開で現れる `>` は **block 維持** | minor（残存誤検知） | plan **GC-2** の宣言どおり「誤検知として扱わない」。固定 TC = **`T1045-TC-19`**。パーサ化は新たな bypass 面を作るため採らない |
| **K-3** | **`scripts/apply-task-0123-patches.sh:67-88` の複製導線**: guard を `scripts/hooks/` へ `cp` し、**既存時はスキップして更新しない**。過去に適用した環境には**本修正が伝播しない古い fork** が残りうる | minor | `origin/main` に `scripts/hooks/check-approval-token-write.sh` は **不在**（`git ls-tree` / ディスクとも実測）＝**実害ゼロ**。`GC-7` を維持し本 PBI では触らない。**follow-up issue 起票が必要（未起票）** |
| **K-4** | **`GC-8 (ii)` による挙動変更**: `command -v sed` を追加したため、**`sed` 不在環境では token パス関連の全 Bash 呼び出しが `parse-unknown` で block** される | info | 方向は「厳格化」であり承認範囲上の危険はない。`jq` の既存契約と同型なので新規クラスでもない。C-4 / 運用が挙動差を把握できるよう明記 |
| **K-5** | **`sh tests/run-tests.sh` は実行中、実リポジトリ作業ツリーへ一時的に untracked ディレクトリを作る**: `docs/working/TASK-APPROVE-HARDEN-TEST/` / `TASK-FORCE-OVERWRITE-TEST/` / `TASK-T420/` / `TASK-T999/` | info | **本 PBI の変更とは無関係**（既存スイートの挙動）。**実行完了時に runner が cleanup し、実測で 4 件とも消滅している**（残留なし）。したがって恒久的な汚染ではない。**中断時には残りうる**点のみ留意。commit していない |
| **K-6** | **CI（Linux / GNU `grep` / dash）での実行結果が未取得** | minor | `sed` 方言差は GNU sed 4.10 で実測済み（UV-1 の主要部分は退役）。残りは `grep` / dash 差。**C-4 前の CI 実行で確認すること** |

---

## 3. V2 候補（今回の scope 外）

- **`&>` / `&>>` の `/dev/null` 宛のみを除外に加える**（K-1 の解消）。
  除外面が増えるため、`&>` 直後が `/dev/null` かつ語境界であることを厳密に要求する設計が要る。
- **`scripts/hooks/` 側の複製を廃止するか、`apply-*.sh` を「常に上書き」へ変更**（K-3 の解消）。
- **`run-tests.sh` のテスト用 TASK ディレクトリを `mktemp` サンドボックスへ隔離**（K-5 の解消）。
- **`rule=<id>` を events 化**（#230 Gate Event Normalization と連携）。
  現状は stderr 文字列のみで、構造化イベントには載っていない。
- **`_is_token_path()` の判定範囲の見直し**（本 PBI では GC-5 により一切変更していない）。

---

## 4. 妥協点（採用しなかった選択肢と理由）

| 選択肢 | 不採用の理由 |
|---|---|
| **「`>` を token path 宛のときだけ block する」** | `T1023-TC-09`（`cat <TOKEN> && echo hi > /tmp/other.txt`）は `cp`/`tee`/`mv` を含まず **`>` 検査だけが唯一の捕捉経路**のため退行する。plan **GC-3** が禁止方針として明示。実測でも `T1023-TC-09` は PASS を維持している |
| **完全なシェル構文解析（クォート / heredoc / 変数展開の解釈）** | コストに見合わず、**パーサ自体が新たな bypass 面**になる。plan **GC-2**。代わりに fail-closed のまま列挙的除去に留めた（K-2 の取りこぼしはその対価） |
| **`&>` / `&>>` を除外に含める** | 除外面（＝危険な方向）を最小化する安全側。**C-3 裁定 Q-2 で block 維持が確定**（K-1） |
| **`/dev/stdout` / `/dev/stderr` / `/dev/fd/N` を除外に含める** | リダイレクト文脈によっては実ファイルを指しうる。plan **U-1** の安全側。`T1045-TC-11` で固定 |
| **`_t25_mutate` とは別に独自の変異ドライバを書く** | anchor 一意 / sed miss / syntax / kill 判定の **4 安全チェックを複製**することになり新ドライバだけが弱くなる。plan **GC-4-B (a)**（label prefix 引数）を採用し、**既存 7 呼び出しは 4 引数のまま無変更**（`T1045-TC-21` で担保） |
| **`T1045-TC-22` だけで GC-8 を担保する** | **(i) fail-closed フォールバックが欠けた build でも `TC-22` は `rc=2` で PASS してしまう**ことを実測で確認（`evidence/verification/gc8-fail-closed.md`）。`TC-22b`（`sed` 存在するが失敗）が (i) の唯一の担保 |
| **`T1045-TC-16` をスイート内での自己再実行として書く** | 無限再帰になる。既存 `PG_T25_NO_RECURSE=1` 機構（`T1023-TC-20` の先例）を用いた子プロセス実行 + ラベル静的検査の 2 段に落とした |
| **Mode を `high-risk` へ引き下げる** | **C-3 裁定 Q-1 で `critical` 維持が確定**。V-4 と C-4 複数レビュアー推奨が適用される |

---

## 6. テスト結果サマリ

| 実行 | 結果 |
|---|---|
| `sh -n scripts/check-approval-token-write.sh` | **PASS** |
| `sh tests/extras/ta-25-approval-token-guard.sh`（standalone / BSD） | **70 passed / 0 failed / EXIT 0**（baseline 47 → +23） |
| `sh tests/run-tests.sh`（source 経路 / BSD） | **700 passed / 0 failed / EXIT 0** |
| 変異 (a) 正規化 no-op 化 | **kill**: `[FAIL] T1045-TC-01` / 子 rc=1 |
| 変異 (b) 残存 `>` 判定を常時 false 化 | **kill**: `[FAIL] T1045-TC-04` / 子 rc=1 |
| 既存 mutation 7 種（`TC-15`〜`TC-17e`） | **全 kill 継続**（ラベルは `T1023-` のまま） |
| BSD `sed` / GNU `sed` 4.10 の正規化等価性 | **29/29 一致・出力 byte identical** |
| GC-8 検出力（(i) 欠落 build） | **`sed` 失敗シムで `rc=0`（FAIL-OPEN）を再現** → `TC-22b` が唯一検出 |

### 退行がないことの直接確認

| 既存 TC | 結果 |
|---|---|
| `T1023-TC-08`（read-only `cat` → rc=0） | **PASS** |
| `T1023-TC-09`（mixed → 保守的 rc=2 / GC-3 の要） | **PASS** |
| `T1023-TC-12`（代表 write surface 6 種） | **PASS** |
| `T1023-TC-25` / `TC-26` / `TC-27`（ed/ex / git 復元系 / 負ケース） | **PASS** |
| `T1023-TC-05`（jq 不在 PATH → parse-unknown。R-010 の巻き添え検出） | **PASS** |
| `T1023-TC-24`（stdin 未 redirect の静的検査 / R-027） | **PASS** |
| `T1023-TC-15pre` / `TC-17post`（baseline / 復元） | **PASS**（RED ウィンドウは Step 3 完了で閉じた） |

---

## Stop Condition / Replan Trigger

**SC-1〜SC-9 / RT-1〜RT-5 は全件不発火。** 詳細は [`status.md`](./status.md)。

## 責務分界

| 操作 | 責務 | 状態 |
|---|---|---|
| guard / テストの実装・検証・evidence 作成 | AI-owned | 完了 |
| `approvals/c3.json` の発行 | **Human-owned** | 完了（AI は作成・編集していない） |
| `.claude/settings*.json` の適用 | **Human-owned** | 変更なし（U-5 により再適用も不要。稼働配線は `scripts/` 直下を直接呼ぶ） |
| PR 作成 / C-4 / merge | **Human-owned** | **未実施**（本 exec では PR を作成していない） |
