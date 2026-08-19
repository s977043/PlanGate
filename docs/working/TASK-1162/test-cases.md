# テストケース定義 — TASK-1162 (#1162)

> **原本には書き込まない**。すべての変異は `mktemp -d` 上に複製した sandbox（以下 `$SBX`）で行い、
> 実行後に明示削除する（pbi-input A-03）。`.claude/agents/` / `.codex/agents/` /
> `scripts/ai-loop/` の原本は不変。
>
> **変異は関数ではなく呼び出し箇所（call site）を壊す**。関数本体を壊す変異は「その関数が
> 呼ばれているか」しか測れず、契約が実際に評価されているかを実証できないため。

## 受入基準 → テストケース マッピング

| AC | 内容 | 正側 TC（増えても PASS） | 負側 TC（壊すと FAIL） |
|----|------|--------------------------|------------------------|
| AC-01 | `ta-33` TC-01 が agent +1 で PASS / 期待外 tier で FAIL | **T1162-TC-01** | **T1162-TC-02**, T1162-TC-03 |
| AC-02 | `ta-33` TC-03 が toml +1 で PASS / 期待外 effort で FAIL | **T1162-TC-04** | **T1162-TC-05**, T1162-TC-06 |
| AC-03 | `ta-57` TC-15 がテスト +1 で PASS / 57 本未満で FAIL | **T1162-TC-07** | **T1162-TC-08**, T1162-TC-09 |
| AC-04 | JSON 読込が `read_json()` へ集約され挙動不変 | T1162-TC-10, T1162-TC-11 | **T1162-TC-12** |
| AC-05 | plugin 側 28 ファイルが同期され**単体で全テスト PASS** | **T1162-TC-13**, T1162-TC-14 | **T1162-TC-15** |
| AC-06 | `sh tests/run-tests.sh` が baseline 以上で exit 0 | T1162-TC-16 | — |
| AC-07 | S-3 分割要否判断が根拠付きで `handoff.md` に記録 | T1162-TC-17（doc 検査） | — |
| 全般 | 変異が実 TC の FAIL で kill される | — | **M-1〜M-7**（下表） |

---

## S-1: 件数契約の置換

### T1162-TC-01: agent を 1 体増やしても PASS（正側 / AC-01）

| 手順 | 期待 |
|------|------|
| `$SBX` へ repo を複製 → `$SBX/.claude/agents/dummy-agent.md` を `model: inherit` で追加 | — |
| `$SBX` で `ta-33` TC-01 を実行 | **PASS**（`_t33_count` が 18 になっても落ちない） |

- 意図: 現状の `-eq 17` は**この変異で FAIL する**（＝時限爆弾の実証。T-04 の RED）。
  置換後は PASS になること。
- 種別: Integration（テストスクリプト実起動）/ 自動化: 可
- 対照: 置換**前**の同一 sandbox で FAIL することを先に記録する（before/after 対比）

### T1162-TC-02: 期待外 tier の agent 混入で FAIL（負側 / AC-01）

| 変異 | 期待 |
|------|------|
| `$SBX/.claude/agents/dummy-agent.md` を `model: sonnet` で追加（sonnet 集合に**無い**名前） | **FAIL** |
| 既存 `explorer-agent.md`（sonnet 集合内）の `model:` を `inherit` へ書き換え | **FAIL** |
| 既存 `orchestrator.md`（sonnet 集合外）の `model:` を `sonnet` へ書き換え | **FAIL** |
| `model:` 行そのものを削除（空文字になる） | **FAIL** |

- 意図: 「期待集合から外れた tier を持つ agent が 1 体でもあれば FAIL」（AC-01 後半）。
  4 方向（集合外に sonnet / 集合内を inherit / 集合外を sonnet / 欠落）を網羅する。
- 種別: Integration / 自動化: 可

### T1162-TC-03: agent 削除の検知（負側 / AC-01 / 検出力の維持）

| 変異 | 期待 |
|------|------|
| `$SBX/.claude/agents/explorer-agent.md`（sonnet 集合内）を削除 | **FAIL** |
| `$SBX/.claude/agents/orchestrator.md`（集合外・inherit 期待）を削除 | 現行 assert 相当の検知は不能 → **既知の限界として記録** |

- 意図: 現行 `-eq 17` が実際に担っていた検出力は「tier 不一致」ではなく**削除の検知**である
  （全ファイルに `expect` を割り当てているため不一致は既に検出済み）。置換後は
  「期待集合の各名がファイルとして存在する」で削除を検知する。
- ⚠️ 2 行目は**検出力が下がる方向**。期待集合に載っていない agent の削除は検知できない。
  この限界は `handoff.md` に明記し、隠さない（Non-goal「検出力を下げる共通化」への自己申告）。
- 種別: Integration / 自動化: 可

### T1162-TC-04: toml を 1 本増やしても PASS（正側 / AC-02）

| 手順 | 期待 |
|------|------|
| `$SBX/.codex/agents/dummy_agent.toml` を追加（effort は medium 相当） | — |
| `ta-33` TC-03 を実行 | **PASS**（`_t33_toml_count` = 18 でも落ちない） |

- ⚠️ ただし TC-04（md ↔ toml の相対件数一致）は別 assert。両方が整合するよう
  `.claude/agents/` 側にも 1 体足した sandbox で確認する（TC-04 は本 PBI で変更しない）。
- 種別: Integration / 自動化: 可

### T1162-TC-05: 期待 effort と異なる toml で FAIL（負側 / AC-02）

| 変異 | 期待 |
|------|------|
| `explorer_agent.toml`（low 期待）の `model_reasoning_effort` を `"medium"` へ | **FAIL** |
| `orchestrator.toml`（medium 期待）を `"low"` へ | **FAIL** |
| `orchestrator.toml` から `model_reasoning_effort` 行を削除 | **FAIL** |
| `qa_reviewer.toml` を削除（medium 集合内） | **FAIL**（`:missing`） |

- 種別: Integration / 自動化: 可

### T1162-TC-06: 集合外 toml の混入で FAIL（負側 / AC-02 / 過剰検知）

| 変異 | 期待 |
|------|------|
| `$SBX/.codex/agents/rogue_agent.toml` を `model_reasoning_effort = "high"` で追加 | **FAIL** |
| 同上を `"low"` で追加（値は妥当だが集合外） | **FAIL** |

- 意図: 現行 `-eq 17` が間接的に担っていた「未知 agent の混入検知」を、置換後は
  **集合外 toml の明示検出**で置き換える。これがないと T1162-TC-04 の緩和で
  検出力が純減する。
- ⚠️ T1162-TC-04（+1 で PASS）と本 TC（集合外で FAIL）は**一見矛盾する**。
  正しい設計は「期待集合を更新すれば +1 が通る」であり、集合を更新せずに増やした場合は
  FAIL が正。TC-04 の手順には**期待集合への追記**を含める。
- 種別: Integration / 自動化: 可

### T1162-TC-07: テストを 1 本増やしても PASS（正側 / AC-03）

| 手順 | 期待 |
|------|------|
| `$SBX/scripts/ai-loop/test_delivery.py` に空の `test_t1162_dummy` を 1 本追加（`Ran 58 tests`） | — |
| `ta-57` TC-15 を実行 | **PASS**（`-ge 57` で通る） |
| 同様に 5 本追加（`Ran 62 tests`） | **PASS** |

- 意図: S-2 で `test_delivery.py` にテストを足しても CI が RED にならないこと
  （＝本 PBI の主目的）。
- 対照: 置換**前**は `Ran 58` で FAIL することを先に記録する。
- 種別: Integration / 自動化: 可

### T1162-TC-08: 57 本未満へ減らすと FAIL（負側 / AC-03）

| 変異 | 期待 | 観点 |
|------|------|------|
| `test_delivery.py` からテストを 1 本削除（`Ran 56 tests`） | **FAIL** | 境界の直下 |
| 10 本削除（`Ran 47 tests`） | **FAIL** | 明白な消失 |
| ちょうど 57 本（変異なし） | **PASS** | 境界そのもの（`-ge` の等号側） |

- 意図: 「テスト消失を検知できなくなる」ことを防ぐ（Non-goal に明記された最悪ケース）。
  境界値 56 / 57 / 58 の 3 点を必ず測る。
- 種別: Integration / 自動化: 可

### T1162-TC-09: 件数以外の 2 条件が独立に効く（負側 / AC-03）

| 変異 | 期待 | 落ちる条件 |
|------|------|-----------|
| テストを 60 本にした上で 1 本を意図的に失敗させる（`Ran 60 tests` / `FAILED` / rc≠0） | **FAIL** | rc=0 と `^OK` |
| `test_delivery.py` を import エラーにする（`Ran` 行が出ない → `_t57_n=0`） | **FAIL** | 3 条件すべて |
| 出力に `OK` が出ず rc=0 のみ（skip 全件等） | **FAIL** | `grep -q '^OK'` |

- 意図: `-ge 57` へ緩めた分、**rc=0 と `OK` の 2 条件が実際に評価されている**ことを実証する。
  「件数だけ満たすが失敗している」状態を通さない。
- 種別: Integration / 自動化: 可

---

## S-2: JSON 読込の単一定義化

### T1162-TC-10: `read_json()` 単体（AC-04）

| 入力 | 期待 |
|------|------|
| 妥当な JSON ファイル | dict / list を返す |
| 不正 JSON（`{`） | T-02 で確定した例外型（`ValueError` 系）を送出 |
| 不存在パス | `OSError`（または `ValueError` へ包む — T-02 の決定に従う） |
| 読み取り権限なし | 同上 |
| 非 UTF-8 バイト列 | `UnicodeDecodeError`（`ValueError` サブクラス）が fail-closed で扱われる |
| 空ファイル | 不正 JSON と同じ扱い |

- 種別: Unit（`test_c3_contract.py`）/ 自動化: 可
- 🚩 例外の**型とメッセージ**まで assert する（メッセージが変わると呼び出し側の
  エラー表示が変わり、実質的な振る舞い変更になるため）

### T1162-TC-11: 呼び出し 10 箇所の挙動不変（AC-04）

各呼び出し箇所について、**リファクタ前後で同一入力に対する (例外型, メッセージ, プロセス rc)
の 3 つ組が一致**することを対比表で確認する。

| # | 箇所 | 特記事項 |
|---|------|----------|
| 1 | `run_evidence.py:243` | — |
| 2 | `run_evidence.py:357` | ループ内。1 件失敗時に継続するか停止するかを確認 |
| 3 | `run_evidence.py:411` | 同上 |
| 4 | `run_evidence_verify.py:93` | **schema 読込**。失敗＝受理器が起動不能（fail-closed 必須） |
| 5 | `run_evidence_verify.py:285` | `c3.json` 読込 |
| 6 | `run_evidence_verify.py:418` | evidence 読込 |
| 7 | `delivery.py:538` | `approvals/c3.json`。例外を握らず素通し |
| 8 | `delivery.py:540` | `--snapshot` 引数由来のパス |
| 9 | `c3prime_verify.py:56` | — |
| 10 | `discovery.py:182+186` | **2 行形式**。`OSError` と `JSONDecodeError` を**別メッセージ**で `ValueError` に包み直す。差異を吸収できなければ**据え置き**（理由を記録） |

- 入力セット（各箇所共通）: 妥当 JSON / 不正 JSON / 不存在 / 権限なし / 非 UTF-8 / 空
- 種別: Unit + Integration / 自動化: 可
- 🚩 「寄せられなかった箇所」は件数と理由を `handoff.md` に明記（隠して「10/10 集約」と
  書かない）

### T1162-TC-12: `read_json()` 呼び出し箇所の変異が kill される（負側 / AC-04）

- **call site を壊す**変異のみ（関数本体は壊さない）:

| 変異 | 期待 |
|------|------|
| 呼び出しを `try/except: pass` で囲み例外を握り潰す | 既存テストが **FAIL** |
| 引数のパスを別の実在ファイルへ差し替える | **FAIL** |
| 呼び出しを除去して固定 dict `{}` を返す | **FAIL** |
| `discovery.py` の包み直しメッセージ文字列を変更 | **FAIL**（メッセージを assert していれば） |

- 🚩 kill されない変異があれば「その挙動は未検証」と正直に記録し、TC 追加か据え置きを判断する
- 種別: Mutation / 自動化: 可

---

## S-2 の配布検証（plugin）

### T1162-TC-13: plugin 側コピー単体で全テスト PASS（AC-05）

| 手順 | 期待 |
|------|------|
| `sh scripts/sync-plugin-plangate.sh --dry-run` | 差分 0（同期後） |
| `ls plugin/plangate/skills/ai-loop-cycle/scripts/ \| wc -l` | **28** |
| `plugin/plangate/skills/ai-loop-cycle/scripts/` を `$SBX` へ**単独コピー**し、その中で `python3 test_*.py` を全実行 | **全 PASS**（rc=0） |

- ⚠️ 「`scripts/ai-loop/` で通る」ことは AC-05 の証拠にならない。**plugin 側コピーだけを
  切り出した状態**（repo root なし）で実行し、import 解決が閉じていることを実証する。
- 種別: Integration / 自動化: 可

### T1162-TC-14: 同期の双方向一致（AC-05）

| 検査 | 期待 |
|------|------|
| `scripts/ai-loop/*.py`（28 対象）と plugin 側の内容 `diff` | **差分 0** |
| `sync-plugin-plangate.sh:428` の `for` 列挙と `:440` の `case` allowlist が**同一集合** | 一致 |

- 種別: Integration / 自動化: 可

### T1162-TC-15: allowlist 欠落の検知（負側 / AC-05）

| 変異 | 期待 |
|------|------|
| `$SBX` で新規 `scripts/ai-loop/foo.py` を作り、`c3_contract.py` から import させ、**allowlist に足さずに**同期 → plugin 側コピー単体でテスト実行 | **FAIL**（import エラー） |
| 同上で `:428` のみ更新（`:440` 未更新）→ 同期 | plugin 側で `foo.py` が **削除される**ことを確認 |

- 意図: 「新規ファイルを作らない」という S-2 の設計制約が**実在する制約であること**の実証。
  この TC が FAIL しない（＝新規ファイルを作っても問題ない）なら S-2 の前提を見直す。
- 種別: Integration / 自動化: 可

---

## 全体回帰・記録

### T1162-TC-16: フルスイート回帰（AC-06）

| 検査 | 期待 |
|------|------|
| `sh tests/run-tests.sh` | exit **0** |
| pass 件数 | T-01 baseline の pass 件数 **以上** |

- ⚠️ 件数は**下限比較**。絶対件数を新たな契約にしない（本 PBI が除去している時限爆弾を
  自分で再導入しないため）。
- ⚠️ 並走がない時点で 1 回だけ実行（ta-61 入れ子等の相互干渉を避ける）。baseline は
  **測定日時・ホスト・HEAD SHA とセット**で記録する。
- 種別: Integration / 自動化: 可（ただし手動タイミング制御）

### T1162-TC-17: S-3 判断の記録（AC-07 / doc 検査）

| 検査 | 期待 |
|------|------|
| `docs/working/TASK-1162/handoff.md` に S-3 の分割要否判断が存在 | あり |
| 判断に**根拠**（EH ブロック 13 個の共有変数 / 順序依存の実測）が併記 | あり |
| 「実施する / しない」が明示 | いずれか |

- 種別: 手動レビュー / 自動化: 不可（存在検査のみ機械化可）

---

## 変異一覧（kill 実証）

> すべて `$SBX` 上で適用 → 対象 TC が **FAIL** することを確認 → 復元 → **PASS** に戻ることを確認。
> **call site を壊す**変異に統一する。

| ID | 変異（call site） | kill する TC | 対応 AC |
|----|-------------------|--------------|---------|
| M-1 | `.claude/agents/` に sonnet 集合外の `model: sonnet` agent を 1 体追加 | T1162-TC-02 | AC-01 |
| M-2 | sonnet 集合内 agent の `model:` を `inherit` へ書換 | T1162-TC-02 | AC-01 |
| M-3 | sonnet 集合内 agent のファイルを削除 | T1162-TC-03 | AC-01 |
| M-4 | `.codex/agents/` の low 期待 toml の effort を `"medium"` へ書換 | T1162-TC-05 | AC-02 |
| M-5 | `.codex/agents/` に集合外 toml を 1 本追加 | T1162-TC-06 | AC-02 |
| M-6 | `test_delivery.py` からテストを 1 本削除（`Ran 56`） | T1162-TC-08 | AC-03 |
| M-7 | `read_json()` の**呼び出しを** `try/except: pass` で囲む | T1162-TC-12 | AC-04 |

### 空振り時の扱い

変異を入れても対象 TC が PASS のままだった場合、**「検出できた」と書かない**。
「変異 M-x は kill されなかった」を `handoff.md` の既知課題へ記録し、TC を足すか
「その挙動は未検証」と明記するかを人間判断に上げる。

## エッジケース

| ID | ケース | 扱い |
|----|--------|------|
| E-01 | `.claude/agents/README.md` | `ta-33` TC-01 は `case ... README) continue` で除外済み。置換後も除外を維持する |
| E-02 | `.codex/agents/` に toml が 0 本（glob 不展開） | `ls` が空 → 期待集合の全件 `:missing` で **FAIL**（fail-closed）。sh の glob 不展開で `wc -l` が 0 になる経路を明示的に検査する |
| E-03 | `ta-57` の `Ran` 行が複数出る（サブプロセス実行） | `head -1` で先頭のみ採用（現行踏襲）。複数出る条件が生じたら停止して設計見直し |
| E-04 | `Ran 1 test in ...`（単数形） | 現行 `sed` は `tests*` で単数形も拾う。置換後も維持する |
| E-05 | `test_delivery.py` が import エラーで `Ran` 行を出さない | `_t57_n=0` → `-ge 57` で **FAIL**（fail-closed 維持） |
| E-06 | JSON ファイルが**シンボリックリンク**／ディレクトリ | `read_json()` は `OSError`（`IsADirectoryError` 含む）で fail-closed |
| E-07 | JSON が BOM 付き UTF-8 | 現行 `encoding="utf-8"` の挙動を**変えない**（BOM で失敗するなら失敗のまま） |
| E-08 | plugin 側に**余分な** `.py` が残る | `sync-plugin-plangate.sh` の `case` 既定枝で削除される。T1162-TC-15 の 2 行目で確認 |
| E-09 | 期待集合を更新して agent を正式に増やす運用 | T1162-TC-04 の手順に「期待集合への追記」を含める（集合更新すれば +1 が通る、が正しい設計） |

## 自動化可否サマリ

| 種別 | TC | 自動化 |
|------|----|--------|
| Unit | T1162-TC-10 | 可（`test_c3_contract.py`） |
| Integration | T1162-TC-01〜09, 11〜16 | 可（sandbox 複製 + スクリプト実起動） |
| Mutation | M-1〜M-7 | 可（sandbox 上で適用 / 復元） |
| 手動レビュー | T1162-TC-17 | 存在検査のみ機械化可 |
