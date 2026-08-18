# STATUS — TASK-1115 (#1115)

## 全体構成

| PR / ブランチ | 状態 |
|---------------|------|
| `fix/1115-eh13-glob-bypass`（base: `origin/main` = `17cd044`） | push 済 / PR 未作成（C-3 前） |

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|------|---------|------|
| 2026-08-18 12:10 | A/B | Plan Package 生成 |
| 2026-08-18 12:25 | C-1 | `review-self.md` = PASS |
| 2026-08-18 12:30 | D (exec) | 初版実装（`5ccc1fe`） |
| 2026-08-18 12:45 | V-1 | `ta-25` rc=0（98 passed） |
| 2026-08-18 14:10 | **V-3** | **外部敵対レビュー = REJECT**（critical 1 / major 3 / minor 4 / info 2）。`review-external.md` 取り込み |
| 2026-08-18 15:30 | D' (re-exec) | **判定軸を「ディレクトリ条件 × basename 条件」へ統一して再設計**。fork 全廃 |
| 2026-08-18 16:10 | C-1' | `review-self-2.md` = PASS（初版 `review-self.md` は保全） |

## V-3 指摘の disposition（詳細は `review-external.md` 末尾）

| R-NNN | severity | disposition |
|-------|----------|-------------|
| R-001 | critical | **fixed**（保護ディレクトリを集合化） |
| R-002 | major | **fixed**（brace expansion を封鎖） |
| R-003 | major | **fixed 9/11 + rejected 2/11**（棄却は既存リテラル挙動との整合を実測提示） |
| R-004 | major | **fixed**（fork ゼロ化 + 走査の遅延化。800 語 14684ms → 116ms） |
| R-005 | minor | **fixed**（TC-13 + M-12） |
| R-006 | minor | **fixed**（引用/非引用で同じ幅ガード。TC-12） |
| R-007 | minor | **fixed**（TC-14 + M-13） |
| R-008 | info | **一部棄却 + 記述是正**（TC-15 + M-14 で非等価性を固定） |
| R-009 | minor | **fixed**（残存クラス表を実測ベースで全面改訂） |
| R-010 | info | **acknowledged**（既存ギャップ・範囲外） |

## モード判定結果

`high-risk`。`lite_eligible=false`・**C-3 は人間必須**（autonomous APPROVE 不可）。

## C-3 Gate

**未実施**。本ワーカーは `approvals/c3.json` を**発行しない**（Human-owned）。

## 変更ファイル

| ファイル | 変更 |
|----------|------|
| `scripts/check-approval-token-write.sh` | glob 検出を再設計（`_scan_pattern` / `_strip_quotes` / `_pin_hits_protected` / `_may_expand_to_token_path` / `_cmd_may_target_token`）。**fork ゼロ** |
| `tests/extras/ta-25-approval-token-guard.sh` | fixture 全面差し替え + T1115-TC-01〜16 + 変異 M-7〜M-16 |
| `docs/working/TASK-1115/**` | Plan Package + `review-external.md`（V-3）+ `review-self-2.md` + evidence |

## 残タスク

- [ ] **H-01 C-3 ゲート**（Human-owned / `high-risk`）
- [ ] PR 作成 → **H-02 C-4 / merge**（Human-owned）
- [ ] （follow-up）`_has_write_intent` への `rm` / `chmod` / `gzip` / `touch` 追加（V-3 R-010）
- [ ] （follow-up）読み方向（source 位置の引数）を block 対象から外す方向判定
- [ ] （follow-up）#1101 の HO 側正規化（同クラス・別実装）

## evidence

| ファイル | 内容 |
|----------|------|
| `evidence/v3-both-directions.txt` | **両方向の実測**（pre / v1 / v2 の 3 版） |
| `evidence/v3-consistency.txt` | 幅ガードで残す 2 件が既存リテラル挙動と整合することの実測 |
| `evidence/v3-perf.txt` | 性能再実測（5 / 50 / 200 / 800 語） |
| `evidence/lane-scan.txt` | `_has_write_intent` 全ルールの走査 |
| `evidence/edge-cases.txt` | 残存クラス / エッジケース |
| `evidence/shell-expansion.txt` | bash / zsh / sh / dash の実展開（中立名） |
| `evidence/ta-25.log` | `ta-25` 単体実行ログ |
| `evidence/before.txt` / `after.txt` | 初版（`5ccc1fe`）時点の実測（履歴として保全） |

## 参照

- issue #1115 / 同クラス: #1101 / 前段: #1110・#1045・#1023
- `scripts/check-approval-token-write.sh`（EH-13 / **HO 外**）
