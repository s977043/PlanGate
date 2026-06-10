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
