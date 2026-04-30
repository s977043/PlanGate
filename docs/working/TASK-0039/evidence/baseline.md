# Baseline — TASK-0039

> 削減目標の合否判定用 baseline。
> 本 PR の base branch (`main` / `7cecb43`) 時点の値を記録。

## 行数 baseline (`wc -l`)

| ファイル | baseline 行数 | 50% 目標（合否上限） |
|---------|--------------|------------------|
| `CLAUDE.md` | **43** | **22** 行以下 |
| `AGENTS.md` | **61** | **30** 行以下 |
| 合計 | 104 | — |

## 計測コマンド（再現用）

```bash
git checkout main && wc -l CLAUDE.md AGENTS.md
# 期待出力（2026-04-30 時点）:
#       43 CLAUDE.md
#       61 AGENTS.md
#      104 total
```

## 合否判定（Step 7 検証時）

各ファイルが個別に baseline の 50% 以下であること:

- CLAUDE.md: `wc -l CLAUDE.md` が 22 行以下
- AGENTS.md: `wc -l AGENTS.md` が 30 行以下

合計ではなく **両ファイル単独評価**（C-2 EX-03 / 同 PR 修正済の方針）。

## 記録メタ

| 項目 | 値 |
|------|---|
| baseline 取得日時 | 2026-04-30T05:18:23Z（Child C-3 APPROVED と同時刻） |
| baseline コミット | `7cecb43`（PR #131 マージ後の main） |
| 取得者 | s977043 (mine_take) |
