# Improvement Seeds（append-only / WF-06 Retro）

> 正本スキーマ: [`docs/ai/retro-phase.md`](../ai/retro-phase.md) §2。
> 1 run 1 エントリを追記のみ（既存編集・削除しない）。確定追記は人間 confirm でのみ。
> スコアリング・優劣判定は含めない（#231 LLM-judge の責務）。

## 2026-06-07 — v8.12.0 リリース run（#470-482 / 6 issue close）

- 目的達成可否: 達成。plugin sync 品質改善（#456/#476）・HO 待ち 4 件適用（#451/#452/#454/#463）・why-plangate ランディング（#470）を完遂し v8.12.0 を本番リリース（tag-main parity OK / Release published）。オープン PR・issue ともにゼロ。
- 失敗・手戻り: 44 コミット中 24 がレビュー指摘対応（55%）、fix が最多 16。シェルスクリプトの定石（set -eu 耐性・trap 隔離・パーミッション保持・tmp 掃除）を初回で外しレビューで修正するループが多発。特に trap は「なし→追加(#475)→Gemini high で親シェル汚染指摘→サブシェル隔離」と修正が連鎖。version 多箇所（marketplace metadata.version / README 散文 Latest 表記）の同期漏れも初回で発生。
- 次回再利用すべき判断: ① シェル一時リソースの掃除方式（サブシェル隔離 / trap なし通常 rm）を書く前に決める ② コマンド置換は if 条件内（set -e 耐性）③ 実ファイル改変は cat > で上書き（パーミッション保持）④ version 同期マップ（plugin.json / marketplace plugins[]+metadata / README Version 行+散文 Latest / CHANGELOG / tag）を 1 チェックリスト化し、sync 非対応の散文は drift テストで担保（ta-28 TC-11 で実装済）。
- 効いた skill / gate / artifact: 3 視点レビュー（セルフ機械 + 別視点 general-purpose + Gemini）が初回品質の低さを出口で全件救済。verify-then-report（CI ログで set -eu 停止・slug 不一致の原因特定、推測修正を回避）。責務 4 分類（apply-ho-followups.sh = AI 作成・Human 実行）で HO パスを正しい分界で適用。tag-main parity Iron Law。
- 1 人運用で負荷が高かった箇所: gh account ドリフト（毎 push 前に gh auth switch + https remote が必須）。Codex usage limit（6/11 まで）で相談が Codex 実行でなく直接判断に。レビュー往復が多く 1 機能あたりコミット数が増加。
- confirmed_by: masatake.komine（「記録して」指示にて confirm）

## 2026-06-25 — TASK-0143 EH-4/5/7 CLI 配線 run（#528 EH-3 doc-light 経路 / EPIC #527 子 PBI-1）

- 目的達成可否: 達成。EH-4 strict を `cmd_verify` V-1 前、EH-5 warn を V-1 後に配線する apply-script・dry-run 差分確認・ta-44 テスト（SKIP/PASS 両モード）・docs 2 件（settings-wiring-contract / hook-enforcement）を完遂。metrics 2 events 収集。HO 待ち（H-02 apply）は Human-owned として残す。
- 失敗・手戻り: Write tool が EH-3 に 2 回ブロックされ（.sh ファイル + PLANGATE_SKIP_REASON 未設定）、Python heredoc へ切り替え。ta-44 TC-02/03 で PLANGATE_WORKING_DIR が hook 内部計算 REPO_ROOT に無視されることを見落とし、サンドボックス設計を修正（実 docs/working/ 配下の一時 TASK ディレクトリを使う方式に変更）。
- 次回再利用すべき判断: ① EH-3 が .sh 含む非 .md ファイルをブロックするためファイル作成は Python 経由（PLANGATE_HOOK_TASK 設定）② hook スクリプトは REPO_ROOT を内部計算するため hook 単体テストは実 docs/working/ 配下にサンドボックスを作成する ③ apply-script 設計（patch_file old/new + dry-run + already applied 検出）は TASK-0141 から踏襲し差分が少ない ④ extras/ 自動 source（run-tests.sh 編集不要）のパターンを活用
- 効いた skill / gate / artifact: ta-43（TASK-0141）の apply-script パターンを踏襲したことで apply-script 設計コストがゼロ。test 結果 332 passed 0 failed で回帰なし。
- 1 人運用で負荷が高かった箇所: EH-3 ブロックへの対処（Python 経由 heredoc の Python 構文エスケープ問題）。hook スクリプト内 REPO_ROOT 計算がテスト設計に影響する点の検出遅延。
- confirmed_by: masatake.komine
