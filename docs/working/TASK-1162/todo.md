# EXECUTION TODO — TASK-1162 (#1162)

> Mode: **high-risk** → 実装タスクは `rollback:` **必須**。
> 順序制約: **S-1 → S-2 → S-3**（S-1 未完了で `test_delivery.py` にテストを足すと
> `ta-57` TC-15 が無関係に FAIL するため）。
> L-0 / V-1〜V-4 / PR 作成は `workflow-conductor` が自動制御するため本 ToDo には含めない。

## 🤖 Agent タスク

### 準備

- [ ] **T-01** 変更前 baseline を実測して `evidence/baseline/` へ固定
  - 内容: `sh tests/extras/ta-33-agent-model-tier.sh` / `ta-57-pr-convergence.sh` の rc と
    pass/fail 件数、`python3 scripts/ai-loop/test_delivery.py` の `Ran N tests`、
    `sh tests/run-tests.sh` の pass 件数（並走がない時点で 1 回）
  - 🚩 baseline は**測定日時・ホスト・HEAD SHA とセット**で記録する（U-04 / R-06）
  - depends_on: なし / Owner: agent / rollback: 不要（読取のみ）
- [ ] **T-02** JSON 読込 10 箇所の呼び出し文脈を一覧化（例外型 / メッセージ / encoding /
  後続の型検査 / fail-closed の有無）
  - 対象: `c3prime_verify.py:56` / `delivery.py:538,540` / `run_evidence_verify.py:93,285,418` /
    `run_evidence.py:243,357,411` / `discovery.py:182+186`（2 行形式）
  - 🚩 `read_json()` に**寄せられない箇所**を先に確定させる（U-01）。無理に統一しない
  - depends_on: なし / Owner: agent / rollback: 不要（読取のみ）
- [ ] **T-03** `ta-33` の期待集合（`_t33_sonnet_set` / `_t33_expect_low` /
  `_t33_expect_medium`）と現ファイル集合の突合、`ta-57` TC-15 の判定条件を把握
  - 🚩 `_t33_expect_low`(6) + `_t33_expect_medium`(11) = 17 が既にコード内にあることを確認
  - depends_on: なし / Owner: agent / rollback: 不要（読取のみ）

### 実装（S-1: 件数契約の置換 — S-2 の前提）

- [ ] **T-04**（RED）`ta-33` / `ta-57` の**変異注入ハーネス**を sandbox 上に用意し、
  現状の assert が「増加で FAIL する（＝時限爆弾である）」ことを実証
  - 🚩 agent を 1 体増やした sandbox で現状 `ta-33` TC-01 が **FAIL** すること
  - 🚩 `test_delivery.py` にテストを 1 本足した sandbox で現状 `ta-57` TC-15 が **FAIL** すること
  - ⚠️ sandbox は `mktemp -d` 複製。原本（`.claude/agents/` / `.codex/agents/` /
    `scripts/ai-loop/`）には**書き込まない**（A-03）。終了時に明示削除
  - depends_on: T-01, T-03 / Owner: agent
  - rollback: 不要（tmp のみ。原本不変）
- [ ] **T-05**（GREEN）`ta-33` TC-01 を**期待集合との双方向照合**へ置換
  - 置換内容: (a) 全 `.md`（README 除く）が期待 tier と一致 ＋ (b) `_t33_sonnet_set` の
    各名が**ファイルとして存在**（削除検知）。`-eq 17` は削除する
  - 🚩 `sh -n tests/extras/ta-33-agent-model-tier.sh` 通過 / TC-02・TC-04 の判定が不変
  - depends_on: T-04 / Owner: agent
  - rollback: `git checkout -- tests/extras/ta-33-agent-model-tier.sh`
- [ ] **T-06**（GREEN）`ta-33` TC-03 を**期待集合との双方向照合**へ置換
  - 置換内容: (a) 期待 low/medium 集合の各 toml が存在し effort 一致 ＋
    (b) **集合外の toml が存在しない**（過剰検知）。`-eq 17` は削除する
  - 🚩 集合外 toml の混入で FAIL すること（現状 `-eq 17` が担っていた検出力の維持）
  - depends_on: T-05 / Owner: agent
  - rollback: `git checkout -- tests/extras/ta-33-agent-model-tier.sh`
- [ ] **T-07**（GREEN）`ta-57` TC-15 を **`-ge 57` ＋ `OK` ＋ rc=0** の 3 条件へ置換
  - ⚠️ 下限方針は**人間承認済み**（A-02）。等値へ戻したり `OK` / rc 条件を落としたりしない
  - 🚩 FAIL メッセージに実測 `ran=` を残す（デバッグ可能性の維持）
  - depends_on: T-06 / Owner: agent
  - rollback: `git checkout -- tests/extras/ta-57-pr-convergence.sh`
- [ ] **T-08**（変異）S-1 の変異注入を**呼び出し箇所（call site）**に適用し kill を実証
  - 正側: agent +1 / toml +1 / テスト +1 → **PASS**（時限爆弾が消えたこと）
  - 負側: 期待外 tier の agent 混入 / 期待外 effort の toml 混入 / テスト 57 本未満 → **FAIL**
  - 🚩 空振り（PASS のまま）なら TC の欠陥として**正直に記録**する（R-02）
  - depends_on: T-05, T-06, T-07 / Owner: agent
  - rollback: 不要（sandbox コピーのみ。原本不変）

### 実装（S-2: JSON 読込の単一定義化）

- [ ] **T-09** `scripts/ai-loop/c3_contract.py` に `read_json(path)` を追加
  - ⚠️ **新規ファイルを作らない**（`sync-plugin-plangate.sh:428/440` の二重 allowlist に
    載らず plugin 側だけ import エラーになるため）
  - 🚩 シグネチャは T-02 の一覧から**最大公約数**を採る（U-02）。fail-closed を壊さない
  - depends_on: T-02, T-08 / Owner: agent
  - rollback: `git checkout -- scripts/ai-loop/c3_contract.py`
- [ ] **T-10** `test_c3_contract.py` に `read_json()` の単体テストを追加
  （正常 / 不正 JSON / 不存在 / 権限不可 / 非 UTF-8）
  - 🚩 例外の**型とメッセージ**まで assert する（R-03）
  - depends_on: T-09 / Owner: agent
  - rollback: `git checkout -- scripts/ai-loop/test_c3_contract.py`
- [ ] **T-11** 10 箇所の呼び出しを**1 箇所ずつ**置換し、そのつど挙動不変を確認
  - 順序: `run_evidence.py`(3) → `run_evidence_verify.py`(3) → `delivery.py`(2) →
    `c3prime_verify.py`(1) → `discovery.py`(1, 2 行形式)
  - 🚩 各置換後に当該ファイルのテストを実行し rc=0。例外型・メッセージ・rc の対比表を
    `evidence/s2-behavior-parity/` へ
  - ⚠️ `discovery.py:182-188` は `OSError` と `JSONDecodeError` を**別メッセージ**で
    `ValueError` に包み直しているため最後に扱い、差異が吸収できなければ**据え置く**（U-01）
  - depends_on: T-10 / Owner: agent
  - rollback: `git checkout -- scripts/ai-loop/<該当ファイル>`（1 ファイル単位で戻せる）
- [ ] **T-12**（変異）`read_json()` の**呼び出し箇所**に変異を注入し、既存テストが kill する
  ことを実証（例: 例外を握り潰す / パスを別引数に差し替える）
  - 🚩 kill されない変異があれば「その挙動は未検証」と正直に記録し、TC を足すか据え置きを判断
  - depends_on: T-11 / Owner: agent
  - rollback: 不要（sandbox コピーのみ）

### 検証

- [ ] **T-13** plugin 同期と **plugin 側コピー単体でのテスト実行**（AC-05）
  - 手順: `sh scripts/sync-plugin-plangate.sh --dry-run` で差分確認 → 同期 →
    `ls plugin/plangate/skills/ai-loop-cycle/scripts/ | wc -l` が **28** →
    `plugin/plangate/skills/ai-loop-cycle/scripts/` 配下で `test_*.py` を実行し全 PASS
  - ⚠️ plugin 側は同期生成物。**直接編集しない**（A-05）
  - 🚩 新規ファイルを作った場合のみ `sync-plugin-plangate.sh:428` と `:440` の**両方**を更新
  - depends_on: T-12 / Owner: agent
  - rollback: `git checkout -- plugin/plangate/skills/ai-loop-cycle/scripts/`
- [ ] **T-14** 個別スイート → フルスイートの順で実行し AC-06 を確認
  - 個別: `sh tests/extras/ta-33-agent-model-tier.sh` / `ta-57-pr-convergence.sh` rc=0
  - フル: `sh tests/run-tests.sh` が **T-01 baseline の pass 件数以上**で exit 0
  - ⚠️ フルスイートは**並走がない時点で 1 回**（R-05）。件数は**下限比較**（絶対値契約にしない）
  - depends_on: T-13 / Owner: agent
  - rollback: 不要（検証のみ）

### S-3（判断のみ）

- [ ] **T-15** `tests/hooks/run-tests.sh`（754 行 / EH ブロック 13 個）の分割**要否判断**
  - 調査: 共有変数・fixture・順序依存の有無を実測（U-03）
  - 🚩 「実施する / しない」いずれでも可。**根拠を必ず残す**（AC-07）
  - ⚠️ 本 PBI では分割を**着手しない**。実施判断でも別 PBI へ送る
  - depends_on: T-14 / Owner: agent / rollback: 不要（調査のみ）

### 完了

- [ ] **T-16** `handoff.md` に S-3 判断（AC-07）と `-ge 57` 下限の**運用注記**（R-06）を記録
  - 記載必須: 必須 6 要素 ＋ S-3 判断根拠 ＋ 下限 baseline の測定条件 ＋
    据え置いた JSON 読込箇所とその理由（U-01）
  - depends_on: T-15 / Owner: agent / rollback: 不要
- [ ] **T-17** Plan Package（plan / todo / test-cases / review-self）と `status.md` を確定
  - depends_on: T-16 / Owner: agent / rollback: 不要
- [ ] **T-18** commit + push（`refactor/1162-count-contracts-and-read-json`）
  - ⚠️ ブランチは **`origin/main` から分岐**し、作成直後に `git diff main --stat` で
    混入がないことを検証する
  - ⚠️ commit 前に `git diff --cached` で staged 内容を確認する
  - depends_on: T-17 / Owner: agent
  - rollback: `git reset --hard <前の SHA>`（push 前）

## 👤 Human タスク

- [ ] **H-01**（C-3 ゲート / exec 前）plan / todo / test-cases をレビューし三値判断
  - ⚠️ Mode = **high-risk** のため **autonomous APPROVE 不可**。人間の C-3 が必須
  - 承認時は `approvals/c3.json`（`c3_status=APPROVED` ＋ 確定後 plan の `plan_hash`）を発行
  - depends_on: T-17（の前段として plan 確定）/ Owner: human
- [ ] **H-02**（C-4 ゲート / PR レビュー）GitHub 上で APPROVE / REQUEST CHANGES / REJECT
  - ⚠️ **merge は Human-owned 固定**（AI は merge しない）
  - depends_on: T-18 / Owner: human

## ⚠️ 依存関係

| 依存 | 内容 |
|------|------|
| **S-1 → S-2** | T-05〜T-08（S-1）完了前に T-09〜T-12（S-2）へ進まない。`test_delivery.py` へのテスト追加が `ta-57` TC-15 を FAIL させるため |
| **Agent → Human（C-3）** | H-01 APPROVED 前に実装タスク（T-05 以降）を開始しない |
| **Agent → Human（C-4）** | T-18 push 後、H-02 の APPROVE なしに merge しない |
| **T-01 → T-14** | AC-06 の「同じ pass 件数以上」は T-01 の baseline がないと判定不能 |
| **T-02 → T-09** | `read_json()` のシグネチャは 10 箇所の文脈一覧なしに決めない |
| **T-12 → T-13** | plugin 同期は本体側の変更が確定してから |

## 即停止条件

- HO 対象パス（`.claude/**` / `scripts/hooks/**` / `bin/plangate` / `schemas/**` /
  `.github/workflows/**` / `CLAUDE.md` / `AGENTS.md`）の編集が必要になった → **即停止**
- 外部振る舞い（CLI IF / exit code 契約 / hook 挙動）を変える必要が生じた → **即停止**（A-06）
- 変異注入が空振りし、検出力を実証できない → **即停止して人間判断**（R-02）
- hook（EH-3 等）に block された → **迂回せず報告して停止**
