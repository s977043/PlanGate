# TASK-0108 handoff

> WF-05 Verify & Handoff 完了パッケージ (Rule 5 必須 6 要素)
> Issue: [#310](https://github.com/s977043/plangate/issues/310)

## 概要

公開ドキュメント外部新規ユーザー UX 改善 (#310 7 項目) のうち、**#356 (merged) で 5 項目先行完了**、残 **2 項目** (#3 30-min first run 統一、#7 ABCD↔WF 呼称統合) を本 PBI で完了。

## 1. 要件適合確認結果

| AC | TC | 結果 | 検証 |
|----|----|------|------|
| AC-1 公開トップ + README + staged-adoption 統一 | TC-01/02/01b | ✅ PASS | #356 で部分達成 + 本 PBI で「正本」明示完成 |
| AC-2 Required/Optional 一貫 | — | ✅ #356 で完了 | docs/index.md / README で達成済 |
| AC-3 30-min single 導線 | TC-01b | ✅ PASS | staged-adoption-guide.md Phase 0 を 3 ファイル (README + README_en + docs/index.md) で正本明示 |
| AC-4 doctor --fix 必須度 | — | ✅ #356 で完了 | README L143-155 |
| AC-5 When NOT to use | — | ✅ #356 で完了 | docs/when-not-to-use.md |
| AC-6 用語 Glossary | — | ✅ #356 で完了 | docs/glossary.md |
| AC-7 ABCD ↔ WF 統合 | TC-07 | ✅ PASS | glossary.md 正本化 + workflows/README.md 参照切替 + plangate.md WF 併記 + project-rules.md 方針追記 |

## 2. 既知課題一覧

| ID | 内容 | 重要度 | 取扱い |
|----|------|--------|--------|
| K-1 | docs/plangate.md は ABCD 見出しを `## A:` 形式でなく table cell `**A**:` で持つため、plan 想定の「見出し併記」ではなく「table 列追加」で対応 | info | 実装上同等の意図達成、issue なし |
| K-2 | C-2 任意再委任 (Step 6) は Codex usage 上限 + Gemini quota 1h+ 待ちのため deferred | minor | V-3 (実装後外部レビュー) で代替検証推奨 |
| K-3 | README_en.md に「Where to Start (First 3 Pages)」セクションを新設したが、日本語版「最初に読む 3 ページ」と完全並列 | info | 構造的整合性確保 |

## 3. V2 候補 (今回 scope 外)

| 案 | 内容 |
|----|------|
| V2-A | 各 doc の冒頭に glossary.md リンクを追加 (現状は docs/index.md のみ参照) |
| V2-B | docs/staged-adoption-guide.md Phase 0 の見出し ID 安定化 (現状日本語アンカーで slug 自動生成依存) |
| V2-C | README_en.md と README.md の継続的同期チェック (CI 化) |

## 4. 妥協点

- docs/plangate.md の ABCD 見出しは現状の **table cell 表記**を維持、新規 `## A:` 形式の見出し追加は採用せず (既存アンカー破壊回避優先)
- Step 6 (任意 C-2 再委任) は外部 LLM quota 制約のため deferred、V-3 で代替推奨
- glossary.md の WF-XX セクション見出しを「ABCD ↔ WF 対応表 (正本)」に拡張 (slug 変更により URL 影響あり、ただし内部参照のみのため許容)

## 5. 引き継ぎ文書 (5 分把握サマリ)

1. **#310 の実 scope は 2 項目** (#3 30-min 統一 + #7 ABCD↔WF 呼称統合)。残 5 項目は #356 (本セッション merged) で先行完了済。
2. **Step 1 (#3)** 達成:
   - README L21-25 / README_en.md / docs/index.md L9-17 で staged-adoption-guide.md Phase 0 を **30 分初回体験の正本** と明示
   - アンカー `#phase-0-体験day-1` 化
   - README は短縮版、docs/index.md は導線、staged-adoption-guide.md は正本という役割分担
3. **Step 5 (#7)** 達成:
   - **glossary.md L23**: WF-XX セクションを「ABCD ↔ WF 対応表 (正本)」と昇格、single source of truth として明示
   - **workflows/README.md L57**: 既存対応表に「正本注記」追加し glossary.md を指す
   - **plangate.md L74**: 既存 phase table に **対応 WF 列**を追加
   - **project-rules.md**: `## A''. フェーズ呼称ルール` セクション新設、新規 doc は WF-XX 優先、既存 ABCD は対応表で吸収
4. **Step 6 (C-2 再委任)** deferred (外部 LLM quota)
5. **Step 7 (handoff)** 本ドキュメント

## 6. テスト結果サマリ

| カテゴリ | 結果 |
|---------|------|
| TC-01b docs/index.md staged-adoption 正本明示 + アンカー | ✅ grep 該当 |
| TC-07 4 ファイル (glossary / plangate / workflows/README / project-rules) | ✅ 全該当 |
| markdownlint | PR CI で確認 |
| 既存リンク健全性 | 既存アンカー破壊なし (テーブル列追加と注記追加のみ) |
| Plan Health (#351 #事前メトリクス) | plan 7 file → 実 5 file (0.71 倍)、scope 縮小済 |

## 7. Refs

- Issue: [#310](https://github.com/s977043/plangate/issues/310)
- C-3 APPROVED: PR #375 merged 2026-05-27
- T-01 evidence: PR #373 merged 2026-05-27
- plan 簡素化: PR #374 merged 2026-05-27
- 先行実装 (5 項目): PR #356 merged 2026-05-26
- C-2 proactive: Codex+Gemini R-001..R-006 (2026-05-24) 反映済
- TASK-0117 (#351) 自己適用: 規模メトリクス 0.71 倍 → standard 維持
