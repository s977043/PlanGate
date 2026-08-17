# TEST CASES — TASK-1109 (#1109)

> 実装先: `tests/extras/ta-68-skill-spec-presence.sh`
> （`ta-67` は TASK-1093 が予約済みのため 68 を使う）
> 判定対象: `scripts/check-codex-skill-spec.sh`（**行番号ではなく関数名 `inspect` /
> `check_fields` と `--warn-only` の rc 分岐**で参照する）

## 受入基準 → テストケース マッピング

| AC | 内容 | TC | 変異 |
|----|------|----|------|
| **AC-1** | 欠落 `openai.yaml` を violation にする | **TC-03** | **M-1** |
| **AC-2** | orphan `openai.yaml`（SKILL.md なし）も violation | **TC-04** | — |
| **AC-3** | 既定 target に配布物を含む | **TC-09** | — |
| **AC-4** | 検査対象外を件数 + 理由つきで出力 | **TC-10** | — |
| **AC-5** | `--warn-only` は violation / target 不在でも rc=0・traceback なし | **TC-05 / TC-06 / TC-08** | **M-2 / M-3** |
| **AC-6** | `--warn-only` なしの target 不在は rc=1 | **TC-07** | **M-3** |
| **AC-7** | 既定 2 root の実リポジトリ実行が rc=0 | **TC-02 / TC-12** | — |
| **AC-8** | 既存呼び出し元が壊れない | **TC-R1（ta-30）** | — |
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
| **TC-10** | 実リポジトリ | 引数なしの出力 | `ignored=1` と `ignored: README.md — reason:` を含む | 出力契約 |
| **TC-11** | 70 文字 description の fixture | `--target <fixture>` | rc=1 かつ `short_description too long` | 退行 |
| **TC-12** | 実リポジトリ | 配布物 root の `SKILL.md` 集合 △ `openai.yaml` 集合 | **対称差が空**（絶対件数を使わない） | 同値照合 |
| **TC-R1** | 既存呼び出し元 | `ta-30-install-skills.sh` を harness 相当で実行 | 9 TC 全 PASS | 回帰 |

## エッジケース

| ケース | 扱い | TC |
|--------|------|----|
| target 直下の**ファイル**（`plugin/plangate/skills/README.md`） | skill として数えない。`ignored` に理由付きで出力 | TC-10 |
| dotfile / dot ディレクトリ（`.system` 等） | 同上（従来の `startswith('.')` skip を踏襲、ただし出力する） | TC-10 と同経路 |
| `SKILL.md` も `openai.yaml` も無いディレクトリ | `ignored`（violation にしない） | TC-10 と同経路 |
| **1 つも target を検査できなかった** | violation（「0 件検査して All PASS」を禁止） | TC-07 の 2 件目 violation |
| 既定 target の片方が不在（#1086 後） | 理由付き SKIPPED。もう片方を検査して判定する | 設計（TC 化は #1086 側） |
| target パスに空白を含む | 位置パラメータ経由で渡すため壊れない | 実装（`IFS` 改行 + `set --`） |

## 変異注入（検出力の実証）

**変異は関数ではなく call site を壊す。**

| 変異 | 内容（call site） | 期待 | 実測 |
|------|-----------------|------|------|
| **M-1** | `inspect()` の走査ループに `if not has_yaml: continue` を戻す（旧 silent skip） | TC-03 が FAIL | **TC-03 FAIL / 11 passed 1 failed**（kill） |
| **M-2** | shell 末尾の `--warn-only` rc=0 保証を削除し `exit "$_rc"` にする | TC-05 / TC-06 が FAIL | **TC-05・TC-06 FAIL / 10 passed 2 failed**（kill） |
| **M-3** | `inspect()` の `if not os.path.isdir(target)` ガードを無効化 | TC-07 が FAIL | **TC-07 FAIL / 11 passed 1 failed**（kill） |

各変異とも **適用 → FAIL 確認 → 復元 → 12 TC 全 PASS** を
`docs/working/TASK-1109/evidence/mutation/` に記録した。

### 空振りした変異（正直な記録）

初版実装（python と shell の両方に `--warn-only` 分岐がある版）に対する **M-2 は生き残った**
（12 TC 全 PASS）。python 側の `if not warn_only:` が shell 側の破壊を吸収したため。
これは「テストが弱い」のではなく **契約が二重実装されていた**ことが原因であり、
rc 方針の実装点を shell 1 箇所に集約する設計変更で解消した（`evidence/mutation/README.md`）。
