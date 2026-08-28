# TEST CASES — TASK-1109 (#1109)

> 実装先: `tests/extras/ta-68-skill-spec-presence.sh`
> （`ta-67` は TASK-1093 が予約済みのため 68 を使う）
> 判定対象: `scripts/check-codex-skill-spec.sh`（**行番号ではなく関数名 `inspect` /
> `check_fields` と `--warn-only` の rc 分岐**で参照する）

## 受入基準 → テストケース マッピング

| AC | 内容 | TC | 変異 |
|----|------|----|------|
| **AC-1** | 欠落 `openai.yaml` を violation にする | **TC-03 / TC-14** | **M-1 / M-B** |
| **AC-2** | orphan `openai.yaml`（SKILL.md なし）も violation | **TC-04** | — |
| **AC-3** | 既定 target に配布物を含む | **TC-09 / TC-16** | **M-A** |
| **AC-4** | 検査対象外を理由つきで出力し件数が同値 | **TC-10** | — |
| **AC-5** | `--warn-only` は violation / target 不在でも rc=0・traceback なし | **TC-05 / TC-06 / TC-08** | **M-2 / M-3** |
| **AC-6** | `--warn-only` なしの target 不在は rc=1 | **TC-07 / TC-15** | **M-3 / M-A** |
| **AC-7** | 既定 2 root の実リポジトリ実行が rc=0 | **TC-02 / TC-12 / TC-13** | — |
| **AC-8** | 既存呼び出し元が壊れない | **TC-R1（ta-30）** | — |
| **AC-9**（v2 / R-001 R-003） | **既定経路（`explicit=False`）でも検出できる**。宣言した既定 root の不在は violation | **TC-13 / TC-14 / TC-15 / TC-16** | **M-A / M-B** |
| **AC-10**（v2 / R-004） | violation 行から root を特定できる | **TC-17** | — |
| （構造） | syntax 健全性 | **TC-01** | — |
| （構造） | 既存 field 検査が退行していない | **TC-11** | — |

## テストケース一覧

| TC | 前提 | 入力 | 期待 | 種別 |
|----|------|------|------|------|
| **TC-01** | — | `sh -n scripts/check-codex-skill-spec.sh` | rc=0 | 静的 |
| **TC-02** | 実リポジトリ | 引数なし | rc=0 | 正側 |
| **TC-03** | fixture に `SKILL.md` のみの skill | `--target <fixture>` | rc=1 かつ `no-yaml-skill: agents/openai.yaml missing` を出力 | **負側** |
| **TC-04** | fixture に `openai.yaml` のみの dir | `--target <fixture>` | rc=1 かつ `agents/openai.yaml exists but SKILL.md missing` | **負側** |
| **TC-05** | TC-03 の fixture | `--warn-only --target <fixture>` | rc=0 | 契約 |
| **TC-06** | 不在ディレクトリ | `--warn-only --target <absent>` | rc=0 | 契約 |
| **TC-07** | 不在ディレクトリ | `--target <absent>` | rc=1 かつ `target directory not found` | **負側 / fail-closed** |
| **TC-08** | TC-07 の出力 | — | `Traceback` を含まない | 契約 |
| **TC-09** | 実リポジトリ | 引数なしの出力 | `plugin/plangate/skills` を含む | 正側 |
| **TC-10** | 実リポジトリ | 引数なしの出力 | `ignored: README.md — reason:` 行が出る **かつ** summary の `ignored=<N>` 合計と `ignored:` 行数が**同値**（**絶対件数を要求しない** / R-002） | 出力契約 |
| **TC-11** | 70 文字 description の fixture | `--target <fixture>` | rc=1 かつ `short_description too long` | 退行 |
| **TC-12** | 実リポジトリ | 配布物 root の `SKILL.md` 集合 △ `openai.yaml` 集合 | **対称差が空**（絶対件数を使わない） | 同値照合 |
| **TC-13** | fixture repo（script を複製し既定 2 root を作る） | **引数なし** | rc=0 かつ `across 2 target(s)` | 正側 / **既定経路** |
| **TC-14** | TC-13 の fixture に `SKILL.md` のみの skill を追加 | **引数なし** | rc=1 かつ `beta-skill: agents/openai.yaml missing` | **負側 / 既定経路** |
| **TC-15** | TC-13 の fixture から `.codex` を削除 | **引数なし** | rc=1 かつ `target directory not found (declared default target)` と `.codex/skills` | **負側 / 既定経路** |
| **TC-16** | 実リポジトリ | 引数なしの出力 | `.codex/skills:` と `plugin/plangate/skills:` が**両方**現れる（root 名で照合） | 正側 |
| **TC-17** | 同名 basename の 2 root（`a/skills` / `b/skills`） | `--target` ×2 | rc=1 かつ violation 行が**一意に 2 行**（重複しない） | R-004 |
| **TC-R1** | 既存呼び出し元 | `ta-30-install-skills.sh` を harness 相当で実行 | 9 TC 全 PASS | 回帰 |
| **TC-R2** | extras 実行契約 | `PG_T61_NO_RECURSE=1 sh tests/extras/ta-61-extra-contract.sh` | 全 PASS（`ta-68` を含む） | 回帰 |

## エッジケース

| ケース | 扱い | TC |
|--------|------|----|
| target 直下の**ファイル**（`plugin/plangate/skills/README.md`） | skill として数えない。`ignored` に理由付きで出力 | TC-10 |
| skills root に非ディレクトリが**増える**（無関係 PR） | TC は落ちない（件数を契約値にしない） | TC-10（同値照合） |
| dotfile / dot ディレクトリ（`.system` 等） | 同上（従来の `startswith('.')` skip を踏襲、ただし出力する） | TC-10 と同経路 |
| `SKILL.md` も `openai.yaml` も無いディレクトリ | `ignored`（violation にしない） | TC-10 と同経路 |
| **1 つも target を検査できなかった** | violation（「0 件検査して All PASS」を禁止） | TC-07 の 2 件目 violation |
| **既定 target の片方が不在（#1086 後）** | **violation**（v2 で変更 / R-001）。宣言から 1 行削除する意識的なコード変更を強制する | **TC-15** |
| target パスに空白を含む | 位置パラメータ経由で渡すため壊れない | 実装（`IFS` 改行 + `set --`） |
| 同名 basename の 2 root | violation 行が root 相対パスで区別できる | TC-17 |

## 変異注入（検出力の実証）

**変異は関数ではなく call site を壊す。**

baseline: **17 passed, 0 failed / rc=0**

| 変異 | 内容（call site） | 期待 | 実測（v2） |
|------|-----------------|------|-----------|
| **M-1** | `inspect()` の走査ループに `if not has_yaml: continue` を戻す（旧 silent skip） | 負側 TC が FAIL | **TC-03 / TC-14 / TC-17 FAIL — 14 passed 3 failed**（kill） |
| **M-2** | shell 末尾の `--warn-only` rc=0 保証を削除し `exit "$_rc"` にする | TC-05 / TC-06 が FAIL | **TC-05 / TC-06 FAIL — 15 passed 2 failed**（kill） |
| **M-3** | `inspect()` の `if not os.path.isdir(target)` ガードを無効化 | 不在系 TC が FAIL | **TC-07 / TC-15 FAIL — 15 passed 2 failed**（kill） |
| **M-A**（V-3 レビューア由来） | `DEFAULT_TARGETS` の 1 行目を不在パスへ差し替え（#1086 後の状態を再現） | 既定経路の TC が FAIL | **TC-02 / TC-13 / TC-16 FAIL — 14 passed 3 failed**（kill） |
| **M-B**（V-3 レビューア由来） | `for name in missing:` → `for name in (missing if explicit else []):`（既定経路の presence 検査だけ無効化） | 既定経路の負側 TC が FAIL | **TC-14 FAIL — 16 passed 1 failed**（kill） |
| **M-C**（V-3 レビューア由来・非注入） | skills root にファイルを 1 枚追加（無関係 PR の再現） | **全 TC が PASS すべき**（時限爆弾の不在） | **17 passed 0 failed**（`ignored` summary=2 rows=2 で同値照合）|

各変異とも **適用 → FAIL 確認 → 復元 → 17 TC 全 PASS** を
`docs/working/TASK-1109/evidence/mutation/` に記録した。

### 空振りした変異（正直な記録）

| 版 | 変異 | 結果 | 原因と是正 |
|----|------|------|-----------|
| v1 初版（python と shell の両方に `--warn-only` 分岐） | **M-2** | **生存**（12 TC 全 PASS） | 「テストが弱い」のではなく **契約が二重実装**され、片方の破壊を他方が隠していた。rc 方針の実装点を shell 1 箇所へ集約して解消 |
| v1 提出版 | **M-A** | **生存**（12 TC 全 PASS） | 既定 root 不在を violation にしない設計 + 既定経路の TC 不足。v2 で「宣言した root の不在 = violation」へ変更し TC-13/15/16 を追加 |
| v1 提出版 | **M-B** | **生存**（12 TC 全 PASS） | 負側 TC がすべて `--target` 経由で、CI が通る既定経路の検出力がゼロだった。v2 で fixture repo による既定経路 TC-14 を追加 |

**自分の変異セット（M-1/M-2/M-3）が全部 kill でも、経路が偏っていれば穴は露出しない。**
M-1 は `--target` 経路で kill されており、既定経路の穴を隠していた。
