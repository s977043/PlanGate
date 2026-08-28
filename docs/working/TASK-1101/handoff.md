---
task_id: TASK-1101
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-08-28
issued_at_commit: 82dbe8e194406f0211bb73f23574dadc1c520cf0
author: qa-reviewer
v1_release: ""
---

# Handoff — TASK-1101 / #1101（EH-3 Hardening Override のパス正規化）

## メタ情報

```yaml
task: TASK-1101
related_issue: https://github.com/s977043/plangate/issues/1101
author: qa-reviewer
issued_at: 2026-08-28
issued_at_commit: 82dbe8e194406f0211bb73f23574dadc1c520cf0
v1_release: ""
```

> 本文の測定値は **`82dbe8e` 時点**のもの。本 handoff 自身のコミットで
> commit 数 / 変更ファイル数はずれる（契約値ではない）。
> Mode = **high-risk** / `lite_eligible=false` / C-3 = APPROVED（2026-08-15T10:30:43Z）。

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| **AC-1** 直積 全件 rc=2 | **PASS** | `ta-65` TC-08: 15 パターン × 変換 13 形 = **195 件すべて rc=2 + HARDENING_OVERRIDE**。PR 前レビューで検出した root 前置部の大小文字ケースも是正済み（`evidence/test-runs/prereview-ac1-root-case.md`）|
| **AC-2** `_norm_target` 不変 | **PASS** | `ta-65` TC-10（maintenance の `allowed_paths` / doc-light 拡張子 / C-3 conversation の 3 経路）+ `ta-12` 14/0 + `ta-39` 8/0 + `ta-45` 7/0。ただし **`ta-45` は AC-2 の回帰網にならない**ことが exec で判明したため、実質の担保は TC-10 側（§2 既知課題）|
| **AC-3** 偽陽性なし | **PASS** | `ta-65` TC-06: HO 近傍の非 HO 15 件（変換適用 5 件を含む）が両文脈・両 hook で非 block |
| **AC-4** 4 シェル可搬性 | **PASS** | `ta-67` 5/0。`sh` / `dash` / `bash` / `zsh` で **32 ケース**（fail-closed 6 件 + 長さ境界 1 件を含む）が byte 一致。`LANG=ja_JP.UTF-8` でも C locale と byte 一致 |
| **AC-5** 検出力（変異注入）| **PASS** | 前セッション M1〜M10 = **10/10 kill**（`evidence/test-runs/mutation-step5.md`）。本セッションで **M11**（長さ条件の除去）と **M7 再注入**（セグメント分割後の小文字化）を追加実測し kill を確認（`evidence/test-runs/step7-performance.md` §4）。ただし AC-5 が要求する「第 8 変異で `ta-45` が FAIL」は**再現しなかった**（§2 既知課題）|
| **AC-6** `sh tests/run-tests.sh` が rc=0 | **WARN** | **通し実行は未実施**（オーケストレータの明示的な禁止指示。ローカルで 25 分超・watchdog kill の実績）。代替として S-4 が指定する既存 4 本 + 新設 1 本を個別実行し全 PASS（§6）。全体 rc=0 は **CI での確認が必要**（degrade）|
| **AC-7** 「既知の残存」の更新 | **WARN** | `docs/ai/hook-enforcement.md` を更新し (a) Edit / Write 経路に限定される旨の明示 / (b) Bash 経路 = **#1104** を追跡先として保持 / 変換クラスを 3 種から **7 種**へ訂正 / 残存脅威モデルを追記。**ただし残存 3 系統目（FS エイリアス）の追跡 issue が未起票**。AC-7 は「残存ゼロ、または残存に対する追跡 issue 番号が本文に存在」を要求するため**未充足**。起票はオーケストレータ（AI は文書化まで）|
| **AC-8** fail-closed 2 条件 | **WARN（超過充足 / plan 逸脱）** | (a) 先頭 `..` 残り・(b) セグメント数が 256 超 は `ta-65` TC-09 で rc=2 を実測。**加えて (c) 全体長が 4096 超・(d) セグメント長が 255 超 を追加した**（Step 7 の是正）。AC-8 は「2 条件」と明記しているため**逸脱**。理由と却下した代替案は `evidence/test-runs/step7-performance.md` §3 |
| **AC-9** 監査ログが生パス保持 | **PASS** | `ta-65` TC-11: `reason` と `_audit/hook-events.log` が生パス `bin/../bin/plangate` を保持 |
| **AC-10** apply の安全性 | **PASS（AI 実行分のみ）** | `scripts/apply-1101-ho-normalization.sh` が `--dry-run`（既定）/ `--apply` / `--revert` / `--emit` と、`--apply` 直後の smoke + 自動 revert を実装。**AI が実 repo に対して実行したのは `--dry-run` と `--emit` のみ**（rc=0）。`--apply` 経路の実走検証は Human-owned（H-02）|
| **AC-11** fork 増加ゼロ | **PASS** | 前セッションで 3 経路とも base = patched を実測。本セッションの変更は純シェルのままで外部コマンドを追加していない。実行時間の非線形性は別途是正（§2 / evidence step7）|

**総合**: **8 / 11 PASS・3 WARN・0 FAIL**（AC-6 / AC-7 / AC-8 が WARN）

**WARN の扱い**:

- **AC-6**: 実行禁止指示に従った結果の degrade。**C-4 前に CI（`sh tests/run-tests.sh`）の緑を必ず確認すること**。個別 5 本は全 PASS。
- **AC-7**: FS エイリアスの追跡 issue 起票が残る。**起票してから C-4 に出すのが望ましい**（#1101 自身が「追跡先の無い KNOWN-GAP」を理由に起票された PBI であり、同じ穴を再生産しないため）。
- **AC-8**: 条件を**増やす**方向の逸脱で、対象は PATH_MAX / NAME_MAX を超え FS 上のファイルを指しえない入力に限られる。正当な書き込みは止まらない（TC-09b と両立）。**C-4 で明示承認を得ること**。

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| **FS エイリアス（macOS firmlink / シンボリックリンク）で HO を迂回できる**。`/tmp/...` が rc=2 でも `/private/tmp/...` と `/System/Volumes/Data/private/tmp/...` は rc=0（`ls -l` で同一 inode・同一タイムスタンプに到達することを確認済み）。#1101 の Non-goal（字句正規化のみ）だが**適用後も残る生きた迂回** | **major** | open（**追跡 issue 未起票**）| **Yes** |
| **Bash 経路には HO 判定が存在しない**（EH-3 は Edit / Write matcher にのみ配線）。本 PBI は Edit / Write 経路のみを扱う | major | open（**#1104** で追跡）| No（#1104）|
| **`ta-45` TC-01 は名前に反して C-3 conversation 分岐を一度も通っていない**。TASK 文脈で EH-3 を起動するため no-task 経路の内側に到達せず、判定も緩い grep。`_norm_target` を壊しても緑のまま＝ plan / test-cases が想定した AC-2 の回帰網になっていない | major | open（**追跡 issue 未起票**）| **Yes** |
| **hook 本体（`scripts/hooks/check-plan-hash.sh`）は未適用**。HO 対象パスのため AI は適用できない。適用するまで real hook の迂回は塞がっていない | major | open（**H-02 待ち**。`tests/fixtures/eh3-normalization-pending-1101.flag` が未適用を明示 opt-in で受理）| No |
| **上限内 worst case（4095 文字・全大文字）で約 0.5 秒**かかる。ハングではないが typical（約 50ms）の 1 桁上 | minor | accepted | Yes（`case` の文字クラス化）|
| **`sh tests/run-tests.sh` の通し実行が未実施**（AC-6 WARN）| major | open（**CI で確認**）| No |
| **`--apply` の実走検証が未実施**（AC-10。AI は実行禁止）| minor | open（H-02 待ち）| No |

**Critical 課題**: open な critical は 0。ただし上記 major が 5 件 open であり、本 PBI が塞ぐのは
「EH-3 の HO が Edit / Write 経路の**字句上の**表記揺れに対して塞がる」ところまで。
**「HO は常時 block される」と読んではならない**（`docs/ai/hook-enforcement.md` の残存脅威モデル参照）。

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|-----------|
| FS エイリアス / シンボリックリンクによる HO 迂回の封鎖 | 字句正規化では原理的に届かない。inode 比較など FS に触れる設計が要り、`realpath` 系は存在しないパスで fail-open する（本 PBI で不採用）| **High** | 未起票 |
| `ta-45` TC-01 を C-3 conversation 分岐に実際に到達させ、判定を厳格化する | 現状は「壊しても緑」のテストであり回帰網として機能していない | **High** | 未起票 |
| HO の `case` を `[Cc][Ll]...` の文字クラスに置き換え、小文字化写像そのものをやめる | 上限内 worst case の約 0.5 秒を消せる。root 除去の大小文字非依存比較を root 長に限定できる。ただし 195 件の直積 TC と変異 M1〜M10 の作り直しを伴う | Medium | 未起票 |
| Bash matcher への EH-3 配線 | 経路の欠落そのもの。settings 変更を伴うため Human-owned | High | **#1104** |
| EH-3 への `timeout` 導入 | 本 PBI は入力長で切ったが、hook 全体が暴走したときの一般的な保険が無い | Medium | 未起票 |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| `_ho_key` を**新設**し `_norm_target` は据え置き | `_norm_target` 自体を正規化する（v1 設計）| 下流 3 経路（maintenance の `fnmatchcase` / C-3 conversation / doc-light）が大小文字に感応して共有しており、破壊すると **maintenance 窓が全滅し C-3 conversation が silent に死ぬ**（R-001 / critical）|
| 単語分割非依存のパラメータ展開ループ | `IFS=/` の for ループ | zsh では単語分割が既定で起きず **no-op になる**。`ta-65` は hook を常に `sh` で起動するため**検出できない**（R-002 / critical）|
| 純シェルの字句正規化 | `realpath` / `readlink -f` | BSD 実装は**存在しないパスで rc=1**（新規 Write を正規化できず fail-open）。かつシンボリックリンクを解決して意味論が変わる |
| **長さ由来の fail-closed 2 条件を追加**（plan 逸脱）| 性能問題を受容する / セグメント分割のみ | 受容は EH-3 に timeout が無く**ハング＝全 Edit / Write 停止**を残す。セグメント分割だけでは 1 セグメント × 20,000 文字に効かない（実測）。詳細: `evidence/test-runs/step7-performance.md` §3 |
| TC-07 を「既定 fixed + PENDING-APPLY flag」方式 | TC-07 の単純反転 | 単純反転だと Human が `--apply` するまで CI が RED になり PR がマージ不能。#1089 の KNOWN-GAP flag と同一機構 |
| patch + apply スクリプト方式 | AI が `check-plan-hash.sh` を直接編集 | **HO 対象パスは AI 編集不可**（責務 4 分類 / Human-owned）|

## 5. 引き継ぎ文書

### 概要

EH-3 の Hardening Override（HO）判定が**生のパス文字列を `case` で突き合わせていた**ため、
`./` 前置 / `//` / `/./` / `..` 往復 / repo root 跨ぎ / 大小文字 / 末尾空白（**7 変換クラス**）
とその複合で **HO 9 カテゴリ 15 パターンすべて**を迂回できた。本 PBI は
**HO 判定専用キー `_ho_key` を新設**して字句正規化（`_pg_fold_path`）を通し、
`_norm_target` は据え置いた（下流 3 経路の意味論を壊さないため）。

**現状**: 正規化関数（`tests/fixtures/pg-fold-path.sh` が正本）・patch 適用スクリプト・
回帰テストは揃っており、sandbox 複製に対して **195 件の直積が rc=2** を実測している。
**`scripts/hooks/check-plan-hash.sh` 本体への適用（H-02）は Human-owned で未実施**。
適用するまで real hook の迂回は塞がっていない。

**本セッションでやったこと**: 13 日前の中断原因だった Step 7 の性能問題に**判定を下した（受容ではなく是正）**。
小文字化を `/` セグメント単位に分割し、**全体長 4096 / セグメント長 255 の fail-closed** を追加。
`len=2749` が 10.8 秒から 0.2 秒へ、1 セグメント × 20,000 文字（従来は 10 分の枠内で未完＝ハング）が
58ms で block になった。Step 8（回帰）/ Step 9（文書）/ handoff まで完了。

### 触れないでほしいファイル

- **`docs/working/TASK-1101/plan.md`**: C-3 APPROVED 済みで `approvals/` 配下の承認記録の
  `plan_hash` と一致している。1 バイト変えると MISMATCH で exec が block される。
  本 PBI では過去に「v3 に対して承認が発行されていた」事故があり `approve --force` で
  是正した経緯がある（`current-state.md`）。計画の不備は**手を出さず報告**すること。
- **`scripts/hooks/check-plan-hash.sh`**: HO 対象パス。AI は編集も適用もできない。
  **patch 経由（apply スクリプト）という設計を壊さないこと。**
- **`tests/fixtures/pg-fold-path.sh` の BEGIN / END マーカー**: apply スクリプトが
  ここを byte 一致で inline し、`ta-65` TC-12 が照合している。マーカーを消さないこと。

### 次に手を入れるなら

1. **H-02（Human）**: `sh scripts/apply-1101-ho-normalization.sh --apply` を実行し、
   **成功したら `tests/fixtures/eh3-normalization-pending-1101.flag` を削除する**
   （適用済みで flag が残ると `ta-65` TC-07 が stale 宣言として FAIL する）。
2. **オーケストレータ**: §2 の「追跡 issue 未起票」2 件（FS エイリアス / `ta-45` TC-01）を起票し、
   `docs/ai/hook-enforcement.md` の残存 3 系統目に issue 番号を書き込む。これで **AC-7 が PASS になる**。
3. **CI**: `sh tests/run-tests.sh` の緑を確認する（AC-6 の degrade 解消）。

**避けるべきアンチパターン**:

- `_norm_target` に `_ho_key` の正規化（特に小文字化）を適用すること（R-001 / critical）。
- `ta-65` 経由で 4 シェル可搬性を確認したつもりになること（hook を常に `sh` で起動する false green / R-003）。
- 実測を添えずに「fail-closed にした」「塞いだ」と書くこと。

### 参照リンク

- Issue: <https://github.com/s977043/plangate/issues/1101>
- [`status.md`](./status.md) / [`current-state.md`](./current-state.md) / [`plan.md`](./plan.md)（v4）/ [`test-cases.md`](./test-cases.md)
- [`evidence/test-runs/step7-performance.md`](./evidence/test-runs/step7-performance.md)（本セッションの主成果）
- [`evidence/test-runs/mutation-step5.md`](./evidence/test-runs/mutation-step5.md)（M1〜M10）
- [`docs/ai/hook-enforcement.md`](../../ai/hook-enforcement.md)（残存脅威モデル）

## 6. テスト結果サマリ

> **絶対件数を契約値にしない**。以下は `82dbe8e` 時点の測定値。

| テスト | 実行方法 | PASS | FAIL | rc |
|---|---|---|---|---|
| `tests/extras/ta-65-eh3-ho-task-context.sh` | standalone | **17** | 0 | 0 |
| `tests/extras/ta-67-pg-fold-path-portability.sh` | standalone | **5** | 0 | 0 |
| `tests/extras/ta-12-maintenance.sh` | `extras-mini-harness.sh` | **14** | 0 | 0 |
| `tests/extras/ta-39-eh3-doc-light.sh` | `extras-mini-harness.sh` | **8** | 0 | 0 |
| `tests/extras/ta-45-c3-mode-config.sh` | `extras-mini-harness.sh` | **7** | 0 | 0 |
| `scripts/lint-shell.sh`（L-0）| gate / severity=error | — | 0 findings | 0 |
| `scripts/apply-1101-ho-normalization.sh --dry-run` | AI 実行可の範囲 | — | — | 0 |
| **`sh tests/run-tests.sh`（AC-6）** | **未実施（禁止指示）** | — | — | **未測定** |

**変異注入（検出力）**

| 変異 | kill | 検出 TC |
|---|---|---|
| M1〜M10（前セッション）| **10 / 10** | TC-01b / TC-02 / TC-07 / TC-08 / TC-09 / TC-11 / TC-12 |
| **M11**（長さ由来の fail-closed 2 条件を除去）| **1 / 1** | **TC-09c**（len=20000 が rc=124 = timeout / seg=300 が rc=0）|
| **M7 再注入**（小文字化を no-op 化 / セグメント分割後の実装に対して）| **1 / 1** | **TC-08（195 件中 78 件が block されず）**|

**FAIL / SKIP の詳細**:

- FAIL は 0。**未測定が 1 件**（`sh tests/run-tests.sh`）— 実行禁止指示による degrade。CI で確認する。
- `ta-65` TC-07 は `eh3-normalization-pending-1101.flag` により **PENDING-APPLY として受理**されている
  （real hook 未適用を明示 opt-in で許容している状態。適用後は flag 削除が必須）。

## 7. Metrics summary

該当なし（本 PBI では `bin/plangate metrics` を収集していない）。
