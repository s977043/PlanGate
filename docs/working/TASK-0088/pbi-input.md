# PBI INPUT — TASK-0088 / #226 段階的導入ガイド

## Context / Why
5 mode×10 hook×23 agent の組合せで初回導入の学習コストが高い。
ultra-light→standard 成長パスと最小セットが未文書化でチーム展開がボトルネック。

## What
- In: `docs/staged-adoption-guide.md`（新規）+ `plangate.md` から参照
- Out: settings.json 実配線変更 / hook 実装変更 / 自動化スクリプト

## 受入基準
- AC1: Phase 0-3（Day1/Week1/Week2-3/Month1+）が各々モード・エージェント・フックを明示
- AC2: 各 Phase に「使わなくてよいもの（最小セット否定形）」がある
- AC3: フック有効化推奨順序（EH-1→…→EHS）が表で示される
- AC4: エージェント最小セット（23 中の必須数）が段階別に示される
- AC5: plangate.md から本ガイドへ到達できる

## Notes
実 hook 名（check-plan-exists.sh 等）/ 実 agent 名で正確化。warning→block 昇格は
versioning-stability-policy §2.2 major と整合。

## Estimation
Risks: 実 hook/agent 名の不整合（緩和: hook-enforcement.md と突合済） / Unknowns: なし
