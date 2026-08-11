# 既存 approval artifact 監査（TC-19 / AC-09 / R-030）

- 測定日: **2026-08-10（UTC）**
- base: `origin/main` = **`5e630f9`**（exec base。plan 記載の実測は base `fac3445` 時点）
- 方法: read-only（`git log --all --diff-filter=A ... -- '*/approvals/*.json'` + tree walk）。
  実 approvals への書込・削除は一切行っていない。

## 起点（M-2 検査項目 1）

- **inventory の起点はリポジトリ初出 `2026-04-27`**（`git log --all` の追加イベント最古日を実測）。
  `2026-06-02`（ガードのファイル追加日）を起点に**していない**。
- 根拠（時間不変の性質）: 起点より前は**ガードのファイル自体が存在せず保護が 0** だった期間で
  あり、そこで作られた承認 artifact は hook の表示を根拠に真正とみなせない。保護 0 の期間を
  監査対象から外すことは「どの承認 artifact を信頼してよいか」という監査目的に対して逆行する。
  この論拠は件数にも比率にも依存しない（plan「起点変更の根拠は時間不変の性質に置く」）。

## 保護状態 3 区分の列挙（M-2 検査項目 2）

| 区分 | 期間 | 保護状態 | 追加イベント数* | distinct path 初出数* |
|---|---|---|---:|---:|
| (a) ガード不在 | 2026-04-27 〜 2026-06-01 | ガードのファイル自体が存在しない | 132 | 66 |
| (b) ガード存在・配線不在 | 2026-06-02（`a7c3805f`）〜 2026-06-11 | ファイルはあるが settings 未配線で一度も発火しない | 6 | 3 |
| (c) 配線済み・3 欠陥で無効 | 2026-06-12（`82137332`）〜 本 PBI 修正まで | 配線済みだが exit 1 / env 時 stdin bypass / parse fail-open で実効ゼロ | 25 | 19 |
| **合計** | | | **163** | **88** |

## 集計単位・測定条件（M-2 検査項目 3）

- \* **集計単位を必ず併記する**（plan の警告どおり、単位差で数値は一致しない）:
  - **追加イベント数** = `git log --all --diff-filter=A --format='C %ad' --date=short --name-only -- '*/approvals/*.json'` の commit×file 単位。同一 path が複数 ref で再出現するとその都度カウント。
  - **distinct path 初出数** = 上記出力を path で uniq し、初出日で 1 回のみカウント。
- **測定日 2026-08-10 / base `5e630f9`**。件数は契約値ではない（approvals は運用で増える
  成長ディレクトリ。plan「件数は契約値にしない」）。
- 参考: 現在 tracked の `docs/working/*/approvals/*.json` は **83 件**（git ls-files、
  distinct 88 との差は削除・リネーム済み path）。
- plan 記載スナップショット（base `fac3445`）と同値: 163（132/…）・88（66/…）→ 母集団の
  実体は base 前進後も不変であることを確認。

## (b)(c) 区分の distinct path 初出一覧（22 件）

```text
(b) 2026-06-02 docs/working/TASK-0122/approvals/c3.json
(b) 2026-06-02 docs/working/TASK-0123/approvals/c3.json
(b) 2026-06-03 docs/working/TASK-9991/approvals/c3.json
(c) 2026-06-12 docs/working/TASK-0127/approvals/c3.json
(c) 2026-06-12 docs/working/TASK-0128/approvals/c3.json
(c) 2026-06-19 docs/working/TASK-0131/approvals/c3.json
(c) 2026-06-19 docs/working/TASK-0132/approvals/c3.json
(c) 2026-06-19 docs/working/TASK-0134/approvals/c3.json
(c) 2026-06-25 docs/working/TASK-0144/approvals/c3.json
(c) 2026-06-27 docs/working/TASK-0147/approvals/c3.json
(c) 2026-07-12 docs/working/TASK-0129/approvals/c3.json
(c) 2026-07-12 docs/working/TASK-0138/approvals/c3.json
(c) 2026-07-12 docs/working/TASK-0139/approvals/c3.json
(c) 2026-07-16 docs/working/TASK-0842/approvals/c3.json
(c) 2026-07-19 docs/working/TASK-0871/approvals/c3.json
(c) 2026-07-20 docs/working/TASK-0872/approvals/c3.json
(c) 2026-07-22 docs/working/TASK-0896/approvals/c3.json
(c) 2026-07-23 docs/working/TASK-0873/approvals/c3.json
(c) 2026-07-24 docs/working/TASK-0907/approvals/c3.json
(c) 2026-07-25 docs/working/TASK-0877/approvals/c3.json
(c) 2026-07-31 docs/working/TASK-0917/approvals/c3.json
(c) 2026-08-04 docs/working/TASK-0914/approvals/c3.json
```

（(a) 区分 66 件の全列挙は `git log --all --diff-filter=A --date=short --name-only -- '*/approvals/*.json'` で再現可能。上記コマンドが単一ソース）

## provenance / 再承認判定の基準（Human H-03 への引き渡し）

どの区分の artifact も**コード差分だけでは真正性を確定できない**（plan Questions/Unknowns）。
Human は以下の基準で利用停止 / 再承認を判定する:

1. **actor / provenance**: 当該 c3.json を含む commit の author / committer が Human の
   ものか（AI の sockpuppet でないか）。発行経路（`bin/plangate approve` の TTY 経路か
   手書きか）は commit message / 監査ログ（`docs/working/_audit/`）と突合する。
2. **plan hash / source SHA**: c3.json の `plan_hash` が当該時点の plan.md 実体と一致するか
   （EH-3 相当の検算）。
3. **後続変更**: c3.json 発行 commit より後に同 TASK の plan.md が変更されていないか
   （変更があれば承認は stale）。
4. **区分別の重み**: (a) は hook 表示を根拠にできない（保護 0）。(b) は配線されておらず
   同上。(c) は「配線済みだが実効ゼロ」なので、hook が通した事実は真正性の根拠にならない。
   いずれも provenance 不明・hash 不一致は**利用停止候補**として Human に渡す（AI は
   停止処分を実行しない）。

## `$1` fallback は実行時 dead code（R-031 / #928 残存）

- `.claude/settings.example.json` の `check-approval-token-write.sh` 呼出（L72/L81 相当の
  2 箇所）はいずれも**引数なし**。適用済み `.claude/settings.json`（メイン checkout）も同様
  （実測 2026-08-10: matcher `Edit|Write` / `Bash` の 2 本、引数なし）。
- したがって本 PBI 実装後も **AC-06 の `$1` 経路は TC（T1023-TC-13a/13b）だけが緑**であり、
  実運用では `PLANGATE_HOOK_FILE` env と stdin JSON の 2 経路が実効。契約
  `docs/ai/settings-wiring-contract.md`（旧 §EH-10 → 現 §EH-13）の「引数として明示的に渡す」
  記述との drift は本 PBI では解消せず **#928 に残存**する。
