# TASK-0877 HANDOFF

> Issue: [#877](https://github.com/s977043/plangate/issues/877)（P1 / bug / area:workflow）
> Mode: `high-risk` / `lite_eligible=false` / HO 非該当
> 発行: 2026-07-25 / plan_hash `sha256:a49aca66b085c8cc77522b736c649c16bc252d15871da955f8040af82811dc10`
> 実行方式: **ai-loop（C-3' 裁定）→ HUMAN_ESCALATED → Human C-3 APPROVED → exec**

## 1. 要件適合確認結果（V-1）

`acceptance-tester` による機械突合（実行コマンドと exit code を根拠に判定）。

| AC | 内容 | 判定 | 根拠 |
|----|------|------|------|
| AC-1 | guard 発火で exit 3（複数 label でも 1 回） | **PASS** | 独立 sandbox で `rc=3` 実測 / TC-10・TC-16 PASS |
| AC-2 | `PLANGATE_ALLOW_MASS_DELETE=1` で override + 解除ログ + CI env 不使用 | **PASS** | override で `rc=0`・stale 4 件削除・解除ログ出力 / `grep -rn PLANGATE_ALLOW_MASS_DELETE .github/` = 0 件 |
| AC-3 | stale カウントが dry-run と実行で一致 | **PASS** | 乖離帯 src=3/stale=4 で両モードとも guard 発火（旧実装は dry-run 非発火） |
| AC-4 | `PG_HARNESS_SOURCED`（非 export・`FIXTURES_DIR` との AND） | **PASS** | `export PG_HARNESS_SOURCED` = 0 件 / TC-13 PASS（`FIXTURES_DIR` 汚染にも耐える） |
| AC-5 | DELETE 正常系（src=2 / stale=1）固定 | **PASS** | TC-09 PASS |
| AC-6 | F5 の別 issue 分離を明示記録 | **PASS**（V-1 時点は未起票で FAIL → 本 handoff 発行で充足） | plan Q2 + 本 handoff §3 + **[#914](https://github.com/s977043/plangate/issues/914)** |
| AC-7 | `.github/workflows/*.yml` を touch しない | **PASS** | `git status --short` の .github 変更 0 件 |
| AC-8 | TC-03 が rc 捕捉 + AND 判定 | **PASS** | `_t26_rc=0; ... || _t26_rc=$?` + `[ rc -eq 0 ] && grep -q` |
| AC-9 | guard メッセージが stderr + label + override 手順 | **PASS** | stdout 側の `safety guard` 出現数 0・stderr に 2 行（label `agents` + override 手順を含む） |

**V-1 判定: 9/9 PASS**（V-1 実行時点では AC-6 のみ FAIL。follow-up issue #914 の起票と本 handoff の発行で解消）

## 2. テスト結果サマリ

| 項目 | ベースライン（main ee9a1b5） | 実装後 |
|------|------------------------------|--------|
| `sh tests/run-tests.sh` | 422 passed / 0 failed（exit 0） | **428 passed / 0 failed（exit 0）** |
| `sh tests/extras/ta-26-plugin-sync.sh`（standalone） | 8 passed / 0 failed | **14 passed / 0 failed** |
| Verification Automation（`run-tests && ta-26`） | — | **exit 0** |
| ta-26 実行時間 | 約 15 秒 | 約 30 秒（TC-13 の子プロセス 2 回ぶん。子では TC-03/04 を省略して 48 秒→30 秒に短縮） |

**回帰検出力の実証**: 新しい ta-26 を `origin/main` の worktree（旧実装）に対して実行すると
**TC-10 / TC-11 / TC-12 / TC-13 / TC-16 が FAIL**（9 passed / 5 failed・exit 1）。
TC-09 は正常系ガードのため旧実装でも PASS。すなわち新規 TC は空振りしていない。

旧実装での TC-12 の診断出力（F2 の乖離そのもの）:

```
[FAIL] TC-12 失敗 (dry: fired=no rc=0 dst=4 期待 yes/0/4 / run: fired=yes rc=0 dst=7 期待 yes/3/7)
```

## 3. 既知課題 / V2 候補（follow-up: #914）

| # | 内容 | 状態 |
|---|------|------|
| KI-1 | **src 駆動の無ガード削除が 2 経路残る**（`sync-plugin-plangate.sh` L140-150 = skills references / L283-296 = ai-loop-cycle references）。特に後者は正本 2 ディレクトリが空化すると期待集合が空になり全 `.md` 削除に至る真の hazard。L317-330 は allowlist 駆動のため対象外 | **#914 へ分離**（C-3 Q2 で確定） |
| KI-2 | **harness/standalone 判別が二機構併存**。`${FIXTURES_DIR:-}` 単独判定を使う既存 11 extras（ta-39/43/44/45/46/47/49/50/51/52/53）と、本 PBI で導入した `PG_HARNESS_SOURCED` 方式が並存する。`tests/extras/README.md` の規約追記も未実施 | **#914 へ分離**（C-2 R-204 の部分採用） |
| KI-3 | ta-26 の実行時間が 15 秒 → 30 秒に増加（TC-13 の子プロセス 2 回）。子では最も重い TC-03/TC-04 を省略済みだが、さらに削るなら ① を落として ②（`FIXTURES_DIR` 汚染ケース）のみに絞る余地がある | V2 候補 |
| KI-4 | 判定式は README.md の対称化により旧式と**厳密等価ではない**（`stale > S_old − R` vs 旧 `stale > S_old + R`）。実 repo では **安全側へ最大 2 件早く発火**する。#861 の意図と同方向のため許容 | 仕様として plan 論点 B に記録 |

## 4. 妥協点（採用しなかった選択肢と理由）

| 選択肢 | 不採用の理由 |
|--------|-------------|
| 発火箇所で即 `exit 3`（論点 A の A-2 案） | 後続 label のコピーが行われず CI 自動 PR の内容が発火位置依存で非決定になる。既存 guard の「削除ループのみスキップ・コピーは阻害しない」契約も壊れる |
| dry-run でも `exit 3` にする | CI 2 job はいずれも `--dry-run` を使わない生実行のため AC-1 の成立に不要。dry-run は副作用のない予告に徹する（B-1 既決 / C-3 論点 3 で再確認） |
| `_dst_count` を dry-run 時のみ補正（論点 B の B-2 案） | モード分岐が判定式に混入し、以後の変更で再び乖離する |
| `.github/workflows/sync-plugin-plangate.yml` の変更 | 不要（exit 3 で job は自動 fail）。HO 回避のため AC-7 で明示的に禁止 |
| F5（無ガード削除 2 経路）を本 PBI に含める | scope 肥大。#914 へ分離（AC-6） |
| `tests/extras/README.md` の規約追記 | Files to Touch 3 件を維持するため #914 へ分離。代わりに ta-26 冒頭コメントで方針を明記 |

## 5. 引き継ぎ文書（5 分で状況把握）

**やったこと**: `scripts/sync-plugin-plangate.sh` の mass-delete safety guard（#861 由来）が
WARN を出して `return 0` する silent 実装だったため、CI が「削除が永久に保留されたまま毎 run
発火し続ける」恒久 drift を検知できなかった。これを **fail-closed（終端 exit 3）** へ変更し、
`PLANGATE_ALLOW_MASS_DELETE=1` の明示 override と、dry-run/実行で判定が食い違わない
**stale 件数ベースの判定式**へ差し替えた。あわせてテスト側の空振り（TC-03 の `$?` 未検証）を
是正し、DELETE 正常系・exit 3・override・モード一致・harness 判別・複数 label 発火の
6 TC を追加した。

**触ったファイル（3 件・すべて非 HO）**:

1. `scripts/sync-plugin-plangate.sh` — `_warn()` 追加 / `guard_fired` 集約 / 判定式を
   `_stale_count > _src_count` へ（README.md を src/dst 対称に除外）/ override 分岐 /
   終端 exit 3（dry-run は exit 0 維持）
2. `tests/extras/ta-26-plugin-sync.sh` — standalone 判別を `PG_HARNESS_SOURCED` AND
   `FIXTURES_DIR` へ / TC-03 是正 / TC-09〜TC-13・TC-16 追加 / 子プロセス再帰防止
   （`PG_T26_NO_RECURSE`）
3. `tests/run-tests.sh` — unset リストに `PG_HARNESS_SOURCED` / `PLANGATE_ALLOW_MASS_DELETE`
   を追加 / extras source 直前に `PG_HARNESS_SOURCED=1`（非 export）

**次の担当者が知っておくべき勘所**:

- guard の判定は **stale（dst にあって src に無い件数）と src 残存件数**の比較。`_dst_count` は
  廃止した（コピー後に数えるため dry-run と実行で値が変わり判定が食い違っていた）
- `guard_fired` は POSIX sh の global。`sync_dir` がサブシェル経由で呼ばれるように変更すると
  集約が壊れる（現状は L96 の 1 箇所のみからの直接呼び出し）
- exit code の優先順位は **先行 fatal（marketplace.json 失敗の exit 1）> guard（exit 3）**
- CI drift-check job は `run:` の 1 行目で sync を実行するため、exit 3 だと yml 側の
  `::error::` 説明行に到達しない。**失敗理由はスクリプトの stderr だけが伝達手段**（AC-9）
- ta-26 に新 TC を足すときは **TC-08 と同じ最小 sandbox**（`CHANGELOG.md` /
  `.claude-plugin/marketplace.json` を置かない）を使う。フル sandbox にすると
  marketplace 経路の `exit 1` が guard の exit 3 判定を汚染する
- extras から `run-tests.sh` や自身を無条件に再実行してはならない（スイート再入ループ）

## 6. プロセス記録（ai-loop C-3'）

| フェーズ | 結果 |
|---------|------|
| C-1（25 項目） | PASS（critical/major/minor = 0） |
| C-2（2 レーン） | conditional ×2 — **critical 1 / major 8 / minor 10 / info 6** → 24 件全採用（R-204 部分採用・不採用 0） |
| 簡易 C-1 | PASS |
| **C-3' ai-loop run-027** | **`HUMAN_ESCALATED`（exit 2）** — `boundary=clean` / `lite=false`（3 ファイル > `SIZE_OK_MAX_FILES=2`）/ W チェック `model_a=approve, model_b=approve` |
| C-3（Human） | **APPROVED**（論点 6 件すべて推奨どおり） |

C-2 / W チェックが検出した主な穴（いずれも実装前に解消）:

- **critical**: TC-13 を素直に書くと ta-26 から `run-tests.sh` を再実行して全スイートが再入ループ
- **major**: TC-12 の fixture（src=1/stale=4）が現行実装でも両モード発火する**空振り**（乖離帯は `src < stale ≤ 2*src`）
- **major**: TC-13 が `FIXTURES_DIR` 汚染ケースを含まず AC-4 を検証できない
- **major**: plan の guard 行番号が誤り（実測 L64-82 / 判定式 L79）
- **major**: exit 3 は drift-check の説明メッセージに到達しない → AC-9 新設
- **W-B**: 「実行時は厳密に等価」は README 対称化を入れると成立しない（安全側へ 2 件ずれる）

record: `ai-loop-runs/20260724T220125Z-ee9a1b5.json`
