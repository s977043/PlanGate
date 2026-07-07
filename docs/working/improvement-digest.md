# Improvement Digest #001（seeds-hygiene 統合サンプル）

> 生成日: 2026-07-07
> 出典: `docs/working/improvement-seeds.md`（エントリ 2 件・元ファイル不変）
> 処理仕様: [`docs/ai/seeds-hygiene.md`](../ai/seeds-hygiene.md)
> 採用状態: 本 digest は仕様（#754）に基づくサンプル生成物であり、内容の
> 正式採用は本 PR の C-4 レビューが兼ねる（[`seeds-hygiene.md`](../ai/seeds-hygiene.md)
> 「責務分類」節に準拠。digest 採用 = Human-owned）。

## 対象エントリ

- 2026-06-07 — v8.12.0 リリース run（#470-482 / 6 issue close）
- 2026-06-25 — TASK-0143 EH-4/5/7 CLI 配線 run（#528 EH-3 doc-light 経路 / EPIC #527 子 PBI-1）

## 統合知見（重複統合）

- **EH-3 ブロック時の Python heredoc 対処**: v8.12.0 エントリの「効いた
  skill / gate / artifact」に記録された `apply-ho-followups.sh`（HO パス
  = AI 作成・Human 実行の分界）と、TASK-0143 エントリの「失敗・手戻り」に
  記録された「Write tool が EH-3 に 2 回ブロックされ、Python heredoc へ
  切り替え」は、**同一の技術的原因**（EH-3 が非 `.md` ファイルの Write を
  ブロックし、迂回に Python 経由の書き込みが必要）に言及している。2 エン
  トリで独立に発生していることから、1 項目に統合し **恒常運用へ昇格すべ
  き候補**とする: 「EH-3 対象ファイルへの書き込みは、Edit/Write が
  `PLANGATE_SKIP_REASON` 未設定でブロックされる前提で、Python 経由（また
  は明示 `PLANGATE_HOOK_TASK` + skip reason 設定）を初手の手順として選ぶ」。

## 陳腐化判定（resolved マーク）

- **gh account ドリフト**: v8.12.0 エントリの「1 人運用で負荷が高かった
  箇所」に「gh account ドリフト（毎 push 前に gh auth switch + https
  remote が必須）」と記録されている。判定基準 (a) 摩擦点の原因となった
  仕組み: `.claude/settings.example.json` の `SessionStart` hook に
  `sh ${CLAUDE_PROJECT_DIR}/scripts/gh-pin-account.sh` が実在することを
  確認済み（2026-07-07 時点）。(b) 裏付け: 本 hook 配線はエントリ記録日
  （2026-06-07）以降に SessionStart へ組み込まれたものであり、セッション
  開始時に account pin を自動実行する経路が存在する。よって本摩擦点は
  **resolved（解消済み）** としてマークする。

## 現役知見（未解消・resolved マークなし）

- **version 同期マップ**（v8.12.0 エントリ）: `plugin.json` / marketplace
  `plugins[]`+metadata / README Version 行+散文 Latest 表記 / CHANGELOG /
  tag の 5 箇所同期チェックリスト化は、drift テスト（ta-28 TC-11）でカ
  バーされているとエントリに明記されているが、恒常的な version bump 作業
  自体は今後も発生するため「現役」の判断・チェックリストとして残す
  （resolved マークは付与しない＝解消済みなのは検出手段であって作業その
  ものではないため）。
- **apply-script パターン**（TASK-0143 エントリ）: `patch_file old/new + dry-run + already applied 検出` の設計を TASK-0141 から踏襲し、コスト
  ゼロで再利用できたと記録されている。今後も HO 待ち follow-up が発生す
  る限り現役の判断として扱う。
- **hook スクリプト内 REPO_ROOT 計算とテスト設計の相互作用**（TASK-0143
  エントリ）: `PLANGATE_WORKING_DIR` が hook 内部計算の `REPO_ROOT` に無視
  される点は、hook 単体テストのサンドボックス設計（実 `docs/working/` 配
  下に一時 TASK ディレクトリを作る方式）として今後も踏襲すべき現役知見。

## 矛盾検出

- 2 エントリ間で相反する「次回再利用すべき判断」は検出されなかった
  （両エントリとも独立した run のため、同一論点に対する対立記述はなし）。

## 還流先

本 digest は [`docs/ai/seeds-hygiene.md`](../ai/seeds-hygiene.md) の「還流」
節に定義されたとおり、以下へ参照入力として位置づける:

- WF-01 context bootstrap（セッション開始時の Progressive Disclosure）
- plan 生成時（フェーズ B）の Work Breakdown / Risks & Mitigations 参考情報

digest の記述を根拠に plan 生成や C-3 承認の自動判断を行わない
（[`seeds-hygiene.md`](../ai/seeds-hygiene.md) 「還流」節と同じ制約）。
