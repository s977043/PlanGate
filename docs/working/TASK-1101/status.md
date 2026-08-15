# Status — TASK-1101

> Issue: [#1101](https://github.com/s977043/PlanGate/issues/1101)
> Mode: **high-risk**（`lite_eligible=false` / C-3 は Standard・同期固定）

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|---|---|---|
| 2026-08-15 16:55 | A | `bin/plangate init TASK-1101` で作業ディレクトリ生成 |
| 2026-08-15 17:05 | A | `pbi-input.md` 作成（#1101 の実測を根拠に PBI 化） |
| 2026-08-15 17:20 | B | `plan.md` v1 作成（**EH-3 が block したため draft → Human が `cp` で設置**） |
| 2026-08-15 17:45 | C-1 | セルフレビュー実施 → **FAIL 11 / WARN 3 / PASS 3** |
| 2026-08-15 17:45 | C-2 | 外部レビュー 3 レーン実施 → **critical 2 / major 6 / minor 4 / info 1** |
| 2026-08-15 18:10 | C-2 | `review-external.md` に **R-001〜R-013 / S-1〜S-4** を集約（追記専用・監査表つき） |
| 2026-08-15 18:30 | B' | **確定反映 1 回**: `pbi-input.md` 更新（AC 7→11）/ `plan.md` v2 / `todo.md` 新規 / `test-cases.md` 新規 |
| 2026-08-15 18:40 | C-1' | **簡易 C-1 再実行** → WARN（未解消 3 / 新規 N-1〜N-4）→ v3 へ確定反映 |
| 2026-08-15 19:10 | C-2'' | **RiverReview 実施** → **critical 1 / major 10 / minor 8 / info 1**。critical は**先行 4 レビューが全て見逃した**設計順序の欠陥 |
| 2026-08-15 19:20 | B'' | **v4 確定反映**（critical + major 10 + minor 8）。`review-self-2.md` を新規発行（M-9） |
| 2026-08-15 19:27 | C-3 | ⚠️ **v3 に対して APPROVED が発行される**（v4 未設置のまま `approve` を実行。`validate` は PASS を返した） |
| 2026-08-15 19:29 | C-3 | plan v4 設置 → **hash MISMATCH を検出**（`validate` FAIL）。承認が古い版に対するものと判明 |
| 2026-08-15 19:30 | C-3 | **`approve --force` で再承認** → 三点照合（v4 draft / c3.json / plan.md）が一致・`validate` PASS |
| 2026-08-15 19:31 | D | **exec 開始**。T-01（baseline）/ T-02（迂回面再測定）完了 |
| 2026-08-15 19:45 | D | **T-03 で中断** — `.sh` への書き込みが no-task セッションの EH-3 で block（`SKIP 拒否: SKIP_REASON 未設定`） |

## モード判定結果

**`high-risk`**

- 変更ファイル数 6 / 受入基準 11 / **承認境界そのものの判定ロジック**
- `mode-classification.md` の例外ルール「承認境界周辺の変更 → 最低でも高」に該当
- **`lite_eligible=false` 強制** / autonomous APPROVE 不可 / C-3 は同期

> critical への引き上げは不要。R-001 の Fix（`_norm_target` 据え置き）により**既存の承認契約を破壊しない**設計になったため。v1 のままなら critical 相当だった。

## 計画からの変更点（v1 → v2）

| 項目 | v1 | v2 | 理由 |
|---|---|---|---|
| 正規化の適用先 | `_norm_target` を**置き換え** | **`_ho_key` を新設**し `_norm_target` は据え置き | R-001（critical）。下流 3 経路が大小文字に感応して共有 |
| 実装方式 | `IFS=/` の for ループを想定 | **単語分割非依存**のパラメータ展開ループ | R-002（critical）。zsh で no-op になる |
| 正規化の順序 | repo root 除去 → 畳み込み | **畳み込み → repo root 除去 → 先頭 `/` 除去** | R-005。絶対パス入力で `/CLAUDE.md` が残る |
| AC 件数 | 7 | **11** | R-004 / R-007 / S-1 / S-3 の AC 昇格 |
| AC-1 の定義 | 既知 4 ケース | **9 カテゴリ 15 パターン × 変換 7 種 + 複合の直積** | R-004。狙い撃ち実装が PASS してしまう |
| AC-4 の検証方法 | `ta-65` を 4 シェルで実行 | **正規化関数を 4 シェルで直接評価** | R-003。`ta-65` は hook を常に `sh` で起動する false green |
| Step 順序 | apply スクリプトが最後（Step 7） | **Step 2 へ前倒し + sandbox 検証（Step 3）** | R-008。依存の逆行 |
| 性能基準 | `..` ループのコスト | **追加 fork 数（増加ゼロ）** | R-012。fork が支配的 |
| Questions | 3 件（未解決のまま承認要求） | **1 件**（Q1・Q3 を確定） | R-008。承認後の方式分岐は `plan_hash` を無効化する |

### 事実誤認の訂正（v1 の記述が誤っていた）

| v1 の記述 | 実測 |
|---|---|
| 「`realpath` は macOS 標準に無い」 | **誤り**。`/bin/realpath` は存在し `readlink -f` も動く。真の不採用理由は**存在しないパスで rc=1（新規 Write を正規化できず fail-open）** |
| 「末尾空白は case-insensitive FS のため実ファイルに到達」 | **誤り**。`cat "CLAUDE.md "` は `No such file`。到達するのは**大小文字だけ** |

## 残タスク

### 🤖 Agent

- [ ] T-01〜T-19（`todo.md` 参照）— **C-3 承認後に着手**

### 👤 Human

- [ ] **H-01: C-3 ゲート** ← **次はここ**
- [ ] H-02: patch 適用（`sh scripts/apply-1101-ho-normalization.sh --apply`）
- [ ] H-03: C-4 ゲート（PR レビューとマージ）

## V 系ステップ進捗

| ステップ | 状態 |
|---|---|
| L-0 / V-1 / V-2 / V-3 / V-4 | 未着手（exec 後） |

## 既知の制約

1. **`plan.md` は AI が編集できない**（EH-3）。v1 / v2 とも draft → Human が `cp` で設置した
2. **`scripts/hooks/check-plan-hash.sh` は AI が適用できない**（HO 対象パス）。patch + apply スクリプトまでが AI-owned
3. ただし **sandbox 複製 + patch により、Human 適用を待たずに検証を先行できる**（plan Step 3）

## 次セッション用プロンプト

```
TASK-1101（#1101 / EH-3 の HO 正規化）の続きです。

docs/working/TASK-1101/current-state.md と status.md を読んでください。
Plan Package（pbi-input / plan v2 / todo / test-cases / review-self / review-external）
は揃っており、C-2 の指摘 R-001〜R-013 / S-1〜S-4 は確定反映済みです。

次は C-3（人間）です。承認後、todo.md の T-01 から着手してください。
Mode = high-risk・lite_eligible=false のため autonomous APPROVE はできません。

注意:
- plan.md は EH-3 が block するため AI は編集できない（draft → Human が cp）
- scripts/hooks/check-plan-hash.sh は HO 対象パスのため AI は適用できない
- 検証は ta-65 の sandbox 複製に patch を当てて先行できる（plan Step 3）
```

## 参照ファイル一覧

- `docs/working/TASK-1101/` 配下すべて
- `scripts/hooks/check-plan-hash.sh`（対象・HO）
- `tests/extras/ta-65-eh3-ho-task-context.sh` / `ta-12` / `ta-39` / `ta-45`（回帰対象）
- `docs/ai/hook-enforcement.md`（AC-7 の更新対象）
- `scripts/apply-eh3-ho-always.sh` / `scripts/fix-eh3-doc-light-maint-guard.sh`（S-2 の stale 対処）
