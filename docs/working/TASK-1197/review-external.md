# TASK-1197 C-2 Round 1（追記専用）

- 基準: origin/main `9445df17`
- レーン: River Review（WARN）、独立検証（FAIL）。どちらも LLM で、独立性は I1 相当。Codex の I2 は未実施
- オーガナイザーの実物照合: ta-79 の `git init` 0 件、`rev-list` の履歴見落とし（側枝で追加削除、plain は空、`--full-history` は検出）、hook L816 の `exit 1` を確認。他は検証者の報告値で、再現していない
- 判定: C-3 前に是正要。下表を plan / todo / test-cases へ 1 回反映済み。**R2 は未実施**

| ID | severity | 出所 | 指摘 | status | reflected_in | notes |
|---|---|---|---|---|---|---|
| R-001 | major | RR + 検証 | 条件 3 が linked worktree の TC-11 と矛盾（`_ho_key` と `_phys_key` は一致しない） | reflected | plan 条件 3 | worktree root を出力して照合 |
| R-002 | major | RR | AC-2 の「作成して続行」が ai-loop-cycle の前提と衝突 | reflected | plan AC-2 | |
| R-003 | major | RR | T-02 は読取のみで実 payload を測れない | reflected | todo T-02、H-02、Replan | Human 適用後に 1 回測定 |
| R-004 | major | 検証 | EH-13 の前提が誤り（dir の `mv`、`cp -r`、`tar`、`rsync`、`git stash -u` は rc=0） | reflected | plan 経路表、残存脅威 | トークン存在検査は Bash 主体に無力 |
| R-005 | major | 検証 | 条件 7 の `rev-list` が stash と側枝の履歴を見落とす | reflected | plan 条件 7、TC-08b/c | `--full-history` |
| R-006 | major | 検証 | ta-79 反転の主張は誤りの可能性（`git init` なし） | reflected | plan Files、todo T-05 | 未実走。exec で確定 |
| R-007 | major | 検証 | STRICT の hash 不一致は rc=1 で、tool を止めない可能性（実 Claude は未検証） | reflected | Q-3 | 保証の実体は `bin/plangate exec` の拒否 |
| R-008 | minor | RR + 検証 | 英字 ID の大文字小文字違いで履歴検査を回避 | reflected | 条件 7、TC-17 | `:(icase)`。検証で実測 |
| R-009 | minor | RR | 変異が条件 1/4/8 と timeout を未カバー | reflected | M9〜M12 | |
| R-010 | minor | RR | 条件 4 は到達しない可能性 | reflected | Task 2 | 到達不能なら削除 |
| R-011 | minor | RR + 検証 | 監査失敗と想定外エラーが rc=1 で fail-open | reflected | 共通規則、TC-E08 | |
| R-012 | minor | RR + 検証 | prunable 例外と locked の扱い、案 B の採否 | reflected | 条件 6、Q-2 | |
| R-013 | minor | 検証 | M5 が STRICT 行のアンカーにも依存 | reflected | Task 2 | |
| R-014 | minor | 検証 | `timeout` は既存依存でない | reflected | Task 2、依存欄 | python の subprocess で実施 |
| R-015 | info | RR | ta-26 TC-39 も影響確認 | reflected | 影響確認欄 | |
| R-016 | info | 検証 | MultiEdit は settings の matcher で EH-3 に届かない | reflected | TC-04 備考 | |

## 回避クラス台帳

| クラス | 代表例 | 検出 | 是正 | 前の工程が見つけられなかった理由 |
|---|---|---|---|---|
| トークン退避 | `mv approvals /tmp/x` が rc=0 | R1 | 防げないと明記 | C-1 はファイル単位の `mv` のみ測定 |
| 履歴の簡略化 | stash、merge 済み側枝 | R1 | `--full-history` | TC が直線履歴のみ |
| worktree のキー不一致 | `.claude/worktrees/x/...` | R1 | root 照合 | sandbox に linked worktree の実測がなかった |
| FS の大文字小文字 | `TASK-aB` と `TASK-Ab` | R1 | `:(icase)` | パス検査と FS の差を未測定 |

## Human 裁定（2026-11-06）

Q-1〜Q-5 はいずれも plan の推奨どおり。Human の返信は「y」。別 issue の起票は未承認で、C-3 時に名指しで確認する。C-3 自体は未承認。

## C-2 Round 2（2026-11-07）

- 基準: origin/main `9445df17`（照合時に ls-remote で不変を確認）
- レーン: 敵対レビュー 1 体。同系 LLM で独立性は I1 相当。Codex の I2 は未実施
- 判定: **FAIL**。実装 patch は存在せず、測定は git / python の部品まで
- オーガナイザーの実測照合（git 2.52.0、sandbox）: R2-1（stash 2 回で 1→0、`--reflog` で 1、削除枝も同じ）、R2-2（cwd=sub で 0、`:(top,icase)` で 1）、Replan Trigger の文言。他はレビュアーの報告値
- 反映: **未反映**。Human の判断待ち

| ID | severity | 指摘 | status | reflected_in | notes |
|---|---|---|---|---|---|
| R2-1 | major | stash@{1} と削除した未 merge 枝を条件 7 が見落とす | open | | 実測済み。`--reflog` は reflog 失効後を救えない |
| R2-2 | major | `:(icase)` が cwd 相対で、サブディレクトリから allow に倒れる | open | | 実測済み。`:(top,icase)` と cwd=root |
| R2-3 | major | T-02 に後続依存がなく、実 payload 未測定のまま C-4 に進める | open | | H-03 に依存を追加、適用先と再起動を T-15 に明記 |
| R2-4 | minor | 条件 3 の字句一致が祖先 symlink で block する | open | | worktree root より下を lstat で検査 |
| R2-5 | minor | TC-E08 は既存 helper で実現できない | open | | allow 専用 writer |
| R2-6 | minor | 変異の対応不足（M13、E07〜E09、TC-13） | open | | |
| R2-7 | minor | timeout の数値が未定義、handoff タスクがない | open | | C-3 前に数値を決める |
| R2-8 | info | 移動した worktree の prunable skip、パスの改行 | open | | 残存脅威に追記、`-z` で解析 |

### 回避クラス台帳（R2 追記）

| クラス | 代表例 | 検出 | 是正 | 前の工程が見つけられなかった理由 |
|---|---|---|---|---|
| ref 到達性の死角 | stash@{1}、削除枝 | R2 | 未反映 | R1 は履歴の簡略化だけを見て、参照の集合を疑わなかった |
| 実行文脈依存の pathspec | cwd=サブディレクトリ | R2 | 未反映 | TC が常に root で実行される想定だった |
| 検証の順序外れ | T-02 が gate に未接続 | R2 | 未反映 | タスクの移動だけを見て、後続の依存を確認しなかった |

### 収束判定

未収束。新クラスが 2 ラウンド連続で出たので、plan の Replan Trigger「判定モデル自体を見直す」に該当する。扱いは Human に諮る。

### 反映記録（2026-11-07）

Human の「ｙ」を受け、案 B 維持を確定し、R2-1〜R2-8 を plan / todo / test-cases へ反映した（上表の status は記録時点の値として残す）。R2-5 は allow 専用 writer、R2-7 の数値は git 呼び出しごと 10 秒、許可経路合計 15 秒を案とした。

## C-2 Round 3（2026-11-07）

- レーン: Codex 敵対レビュー（I2、read-only、静的照合のみ）。rollout: `~/.codex/sessions/2026/11/07/rollout-2026-11-07T09-37-15-01a1b370-2994-7d53-a5bb-06cb4e629bcf.jsonl`
- 判定: **FAIL**。オーガナイザー照合: R3-1 は sandbox で再現（完全履歴 1 件、`--depth 1` の clone は rc=0 で 0 件）。R3-2 は hook L411 の `realpath` 後に `_phys_target` が作られることを確認。実装 patch がないので検査の失敗自体は未測定
- 反映: **未反映**。新クラスが出たので停止し、Human に報告する

| ID | severity | 指摘 | status | notes |
|---|---|---|---|---|
| R3-1 | major | shallow clone など履歴が欠けると、条件 7 が空のまま allow に倒れる | open | 新クラス |
| R3-2 | major | `_phys_target` は realpath 後の値で、これを `lstat` しても祖先 symlink を検出できない | open | 新クラス。R2-4 の是正が生んだ穴 |
| R3-3 | minor | T-02 は成功時の 1 回のみで、実環境の block とエラー処理を測らない | open | 検証の順序外れと同型 |

### 回避クラス台帳（R3 追記）

| クラス | 代表例 | 検出 | 是正 | 前の工程が見つけられなかった理由 |
|---|---|---|---|---|
| 履歴の完全性 | shallow clone | R3 | 未反映 | R2 は ref の到達性を見たが、履歴自体の欠落を見なかった |
| 検査入力の喪失 | 解決後パスへの lstat | R3 | 未反映 | R2 の是正案を既存の変数の出所と照合しなかった |

未収束（新クラス 3 ラウンド連続）。

### 反映記録（2026-11-07）

Human の「ｙ」を受け、案 B 縮小を確定し、R3-1〜R3-3 を反映した（上表の status は記録時点の値）。R4 は行わず、未収束のまま打ち切る可否を C-3 に諮る。反映後のレビューは未実施。

## C-3（2026-11-07）

Human 判定: **CONDITIONAL**（選択式の回答）。未収束のまま計画レビューを打ち切り、pbi-input を確定した。別 issue は名指し承認のうえ #1641、#1642 として起票し、番号とタイトルを照合した。C-3 の確定反映は完了。残りは Human の c3.json 発行（確定後の plan_hash）。
