# TEST CASES — TASK-0907

> 論理コード変更ゼロ（docs / command md のみ）→ doc 整合・sync 冪等・承認境界不変が検証軸。
> C-2 確定反映済み（`Refs: R-NNN`）。判定は実行結果のみ。

## 受入基準 → テストケース マッピング

| AC | 内容 | テストケース |
|----|------|-------------|
| AC-1 | §2 で plangate 本体の lite/clean/reversible な本番変更が eligible（grep 機械化） | TC-1 |
| AC-2 | §5 diff ゼロ + §4/§6 escalate 条件 additive-only | TC-2 |
| AC-3 | Human 決定 verbatim が §2 に記録 | TC-3 |
| AC-4 | command 実行前チェック3 整合 + ガード非後退 | TC-4 |
| AC-5 | rollout-policy sync 冪等 / command cmp 一致 | TC-5 |
| AC-6 | carve-out（engine `scripts/ai-loop/**` + ai-loop policy/spec corpus glob）が §2 注記に存在 | TC-6 |
| AC-7 | 新規 auto-approve 可能化する承認境界相当パスが無い | TC-7 |
| AC-8 | #780 未導入下で実機能は決定論的 escalate | TC-8 |

## テストケース一覧

### TC-1（AC-1・R-005）§2 eligible 域拡張（grep 機械化）
- 入力: §2 適用ドメイン表 plangate 本体行
- 期待: `lite=true`・`boundary=clean`・`reversible` の 3 語 + 「本番フロー変更が適用可」明示文が存在
- 種別: grep 完全一致

### TC-2（AC-2・R-002）§5 diff ゼロ + §4/§6 additive-only
- 前提: base=main `3b987a1`
- 入力: `git diff main -- docs/workflows/ai-loop/rollout-policy.md`
- 期待:
  - §5「不変条件」節に変更行ゼロ
  - §4/§6 の escalate 条件（touches-HO 無条件 / lite=false / 判定不能→false / NO MERGE BY AI / 上限 3）に **削除・条件緩和ゼロ**（additive のみ）
- 種別: diff 実測（節範囲の `-` 行が escalate 条件に無いこと）

### TC-3（AC-3）Human verbatim
- 期待: 「適用ドメインを拡張し ai-loop で開発」「基本的に開発は ai-loop-workflow を使って開発をして欲しい 改善をすすめたいため」が verbatim
- 種別: grep 完全一致

### TC-4（AC-4・R-004）command 整合 + ガード非後退
- 入力: `.claude` / plugin 両版の実行前チェック3
- 期待:
  - §2 拡張と整合（lite/clean な本番変更は ai-loop 可・承認境界/HO 接触は通常フロー）
  - HO 接触無条件 escalate / NO MERGE BY AI / touches-HO 停止規則の文言が**削除・緩和されていない**
- 種別: doc 突合 + 非後退 diff

### TC-5（AC-5・R-101）sync drift（機構別）
- 前提: T2〜T5 完了（command は H2 適用済み）
- 期待:
  - **rollout-policy**: `sh scripts/sync-plugin-plangate.sh --dry-run` が rollout-policy 行に **変更なし**（冪等・byte 一致は期待しない）
  - **command**: `cmp .claude/commands/ai-loop-workflow.md plugin/plangate/commands/ai-loop-workflow.md` = exit 0
- 種別: sync 冪等（dry-run）+ byte 照合

### TC-6（AC-6・R-001/R-107）carve-out 存在（判定基盤 2 系統）
- 入力: §2 注記節
- 期待:
  - ①エンジンコード `scripts/ai-loop/**`（+ 配布版 `plugin/plangate/skills/ai-loop-cycle/scripts/**`）が除外・escalate 固定
  - ②ai-loop policy/spec 文書 corpus 全体（`docs/workflows/ai-loop/**` + `docs/ai/ai-loop/**`）が除外・escalate 固定
  - ③実行手順スキル（`.agents/skills/ai-loop-cycle/**` + `.claude/skills/ai-loop-cycle/**`）が除外・escalate 固定（River M-1）
- 種別: grep 突合（①②両方の言及を確認）

### TC-7（AC-7・R-002）承認境界相当パスの非増加
- 入力: §2 拡張後の clean 判定で新規 auto-approve 可能化するパス集合
- 期待: 承認境界相当（HO パス・強制エンジン・承認トークン）が新規に auto-approve 対象化していないことを列挙確認
- 種別: パス集合の点検（ho-paths HO 一覧 + carve-out との突合）

### TC-8（AC-8・R-003）#780 未導入下の決定論的 escalate
- 入力: §2 注記の #780 順序制約文言
- 期待: 「#780 slice C 未導入下では plangate 本体の実機能 auto-approve は escalate」と決定論的に読める（「寄り」等の非決定論表現が無い）
- 種別: grep（否定含む・「寄り」不在）

## エッジケース

- **EC-1**: HO command patch 未適用の中間状態 → `.claude`≠`plugin`（文言のみ差・機能差なし・fail-closed 影響なし）。handoff に「未適用でも安全」明記
- **EC-2**: §2 注記が §4 auto-approve 方針を**再定義せず参照**（§4 の数値・条件を複製していないことを grep 確認）
- **EC-3**: §2 注記が参照する `#780`/`lite-criteria.md §2`/`decision-table.md §2`/`ho-paths.md` のアンカー・相対パスが実在（リンク切れなし）
- **EC-4**: carve-out の配布版パス `plugin/plangate/skills/ai-loop-cycle/scripts/**` が実在または将来配置想定として正しい（存在確認）
