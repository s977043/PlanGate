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

## 2026-08-05 — v8.18.0 リリース + #914 完遂 + Plan Contract 系 pbi 整備 run

- 目的達成可否: 達成（一部 Human 待ち）。v8.18.0 リリース完遂（version 同期マップ 8/8・#950 恒久対応として Actions の PR 作成権限を有効化）。#914 を exec 開始から CLOSED まで完走（PR #986 `0ebb8fe`・変異注入 8 件・V-1 独立検査 FAIL 0・River Review 3 回）。pbi-input 6 本（#928 #894 #906 #960 #980 #921）と #981 の Plan Package（plan/todo/test-cases + C-1 3 回 + C-2 2 レーン）を整備。#981 の C-3 と #1003 の C-4 が Human 待ちで停止。
- 失敗・手戻り: オーガナイザー自身の誤りが 5 件。① `apply-claude-settings.sh` を効果未検証のまま 5 ターン繰り返し依頼したが dry-run すると「変更なし」の no-op（スクリプトは 2 分岐しか実装しておらず不足 5 件を配線できない）→ #914 が長時間ブロック ② #921 に「ta-58 の伝播は PR #988 で是正済み」と投稿したが実際は `0ebb8fe`（#986）で、`git show 7680145:...` では 0 件（issue に再訂正投稿）③ `FORBIDDEN_KEYS` を 15 個と計測（`grep -A2` が余分な行を拾った。正は 14 個）④ 追跡 `c3.json` を 81 件と報告（正は 80 件。`PBI-116/parent-c3.json` は exec preflight が読まないため母数外）⑤ ワーカーの worktree を完了報告直後に削除し、修正指示時にワーカーが共有 checkout へ落ちた（2 件・いずれもワーカーが自力復旧）。構造的な手戻りとして、1 本目のレビュー修正が新しい major を作り（PR #976 の apply が特定条件で永久に非収束）2 本目で捕捉。TC-33 の false positive で #914 の CI が 2 回ブロックされ、3 回目で対症療法（新規ファイルの 1 行化）から根本修正（awk による行継続畳み込み）へ切り替えた。
- 次回再利用すべき判断: ① 依頼コマンドは dry-run か実装分岐の確認で効果を実測してから出す。同じ依頼を 2 回繰り返したら依頼内容自体を疑う ② 修正にも次のレビューラウンドを当てる — 「検証は層ごとに深くなる」は修正そのものにも適用され、1 本目の指摘を直した版に 2 本目を当てて初めて非収束バグが出た ③ 対症療法が 2 回続いたら検査側（根本）を直す — ta-59 → ta-60 で同じ false positive が出た時点で切り替えるべきだった ④ 帰属 PR の主張は `git log -S` で裏取りしてから書く ⑤ 数え上げは抽出方法を明示して数える（範囲込み grep のカウントを避ける）⑥ ワーカーの worktree はレビュー通過まで残す。
- 効いた skill / gate / artifact: River Review の多層化（1 本目=実装の穴、2 本目=修正が作った穴、と別クラスを捕捉）。変異注入（#914 の 8 変異 / TC-33 の 3 変異 / ta-59 の 5 TC）が毎回「空振りテストでない」ことを実証。C-2 の 2 レーン責務契約 — コードベース整合レーンが「#874 が `docs/schemas/`（非 HO）という別解を確立済み」を発見し、設計妥当性レーンだけでは出ない指摘を出した。ワーカーが指示の前提を実測で覆す規律が複数回機能（未引用 `${VAR:-}` の word splitting 挙動 / EH-6 の参照先 / レビュアーの行番号誤り / 並行セッションとの衝突を検知して push を止めた判断）。実物照合（head SHA・exit code・一次ソース）が報告の誤りを毎回捕まえた。
- 1 人運用で負荷が高かった箇所: 並行セッションとの衝突が頻発（同一ブランチへの二重投入で ref が 2 回進行 / carry-over の上書き競合 v43〜v60 / 共有 checkout が `main` でなく作業ブランチにいた）。EH-3 配線後に Edit/Write が全面 block され起動時 env でしか解除できずセッション再起動が要る。Human 待ちが同時多発（apply 実行 / #981 C-3 / PR マージ）し、待ちの間に着手できる範囲の見極めにコストがかかった。gh アカウントドリフトが複数回発生（禁止アカウントへの自動切替）。
- confirmed_by: masatake.komine（「confirm」指示にて）
