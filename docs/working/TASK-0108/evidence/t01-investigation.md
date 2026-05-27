# TASK-0108 T-01 investigation (read-only)

> 実施: 2026-05-27 / Mode: read-only / C-3 前可
> 目的: #310 残作業の実数確認、#356 (merged) 後の重複整理、c3.json 発行前の scope 確定

## 1. #310 7 項目 vs #356 (merged) 実装状態

| # | 改善案 | 優先 | #356 実装 | TASK-0108 残作業 |
|---|--------|------|----------|----------------|
| 1 | 「最初に読む 3 ページ」順序明示 | HIGH | ✅ README L21-25 + docs/index.md L9-17 | **完了** (out of scope) |
| 2 | Requirements 明文化 | HIGH | ✅ README + docs/index.md 両方 | **完了** (out of scope) |
| 3 | 30-minute first run 単一化 | HIGH | ⏳ 部分 (README/docs/index に順序提示済、ただし「正本」明示なし) | **残: T-02 で対応** |
| 4 | `doctor --fix` 必須度強調 | MEDIUM | ✅ README L143-155 (`### 導入後: hook 強制 🚨 必須` + ⚠️ 重要 box) | **完了** (out of scope) |
| 5 | When NOT to use | MEDIUM | ✅ `docs/when-not-to-use.md` 新規 | **完了** (out of scope) |
| 6 | 用語 Glossary | MEDIUM | ✅ `docs/glossary.md` 新規 | **完了** (out of scope) |
| 7 | ABCD ↔ WF-01..05 呼称統合 | LOW | ⏳ 部分 (docs/glossary.md L23-31 に対応表あり、ただし docs/workflows/README.md L61-69 にも重複対応表あり) | **残: T-07 で対応** |

→ **TASK-0108 plan の T-02..T-07 のうち、#356 で 5 項目が既に完了**。残作業は **2 項目** (#3 と #7) のみ。

## 2. #3 30-min first run 単一化 (T-02 残作業)

### 現状

- **README.md L21-25** に「最初に読む 3 ページ」セクション存在
  - 順序: PlanGate ガイド → 段階的導入ガイド → 10 分チュートリアル
- **docs/index.md L9-17** に同等セクション存在
  - 順序: 同上
- **staged-adoption-guide.md Phase 0** (L27-) で「体験 Day 1」を ultra-light として記述

### 残作業

- **「staged-adoption-guide.md Phase 0 を正本」と明示** (現状は単に list の一項目)
- README は「短縮版」、docs/index.md は「導線」と役割明示
- README_en.md にも英訳同期 (現状未確認)
- アンカー link `#phase-0-体験day-1` 化

### Plan T-02 反映済要素

```
T-02: README + README_en + docs/index.md の 3 箇所で staged-adoption-guide.md Phase 0 を正本として明示、
README は短縮版・docs/index.md は導線。アンカー [Phase 0](./docs/staged-adoption-guide.md#phase-0-体験day-1) まで具体化
```

→ Plan に既に明記済、実装は exec 時。

## 3. #7 ABCD ↔ WF-01..05 呼称統合 (T-07 残作業)

### 現状

| File | 内容 |
|------|------|
| `docs/glossary.md` L23-31 | ABCD↔WF 対応表 (PR #356 で新設) |
| `docs/workflows/README.md` L61-69 | 同等対応表 (既存) |
| `docs/plangate.md` | `## [A-D]` 見出しなし (実体確認) |
| `docs/ai/project-rules.md` | 呼称方針なし |

→ **重複対応表が 2 ファイルに存在** (glossary + workflows/README)、片方を正本に確定する必要あり。

### 残作業

- **glossary.md を正本** とし、workflows/README.md は glossary.md 参照に切替 (重複解消)
- docs/plangate.md 見出しは「`## A: PBI INPUT (WF-01/02)`」併記 (アンカー ID 維持) — ただし現状 `## A` 見出し不在のため、新規追加か別アプローチが必要
- docs/ai/project-rules.md に方針追記「新規 doc は WF-XX 優先、既存 ABCD は対応表で吸収」

### Plan T-07 反映済要素

```
T-07: ABCD ↔ WF-01..05 対応表を docs/glossary.md 末尾に正本配置、
docs/workflows/README.md の既存対応表は glossary.md 参照に切替 (重複解消)。
docs/plangate.md の見出しは ## A: PBI INPUT (WF-01/02) のように併記でアンカー ID 維持。
docs/ai/project-rules.md に呼称方針追記
```

→ Plan に詳細記載済。**docs/plangate.md の見出し追加は新規作業** (現状不在)。

## 4. 規模メトリクス検証 (#351 TASK-0117 先行適用)

| 項目 | plan 見積もり | 実数 (T-01 確認) | 比率 |
|------|--------------|----------------|------|
| 変更ファイル数 | 7 | T-02 (3 file) + T-07 (4 file) = **7 file** | **1.0 倍** |
| 受入基準数 | 7 | 7 (一部 #356 で先取り済) | 1.0 倍 |
| Mode | standard | standard 維持 | — |

TASK-0117 判定基準「1〜3 倍」→ 採用、Mode 降格不要。

## 5. #356 既実装との衝突確認

- README「最初に読む 3 ページ」L21-25 を再編集 (順序自体は変更なし、「正本」表現追加)
- docs/index.md L9-17 同様
- docs/glossary.md は既存、L23-31 対応表を「正本」と明示する文言追加
- docs/workflows/README.md L61-69 対応表を glossary.md 参照に切替

衝突懸念: なし (additive change で既存 #356 を破壊しない)。

## 6. T-01 結論

### 確定事項

1. **TASK-0108 残作業は実質 2 項目** (#3 30-min 統一 + #7 呼称統合)
2. **#1/#2/#4/#5/#6 は #356 で完了済** (out of scope に明確化要)
3. 規模メトリクス 1.0 倍で Mode standard 維持
4. docs/plangate.md の ABCD 見出し追加は新規作業 (現状不在)
5. README_en.md の英訳同期は要 (未確認状態)

### plan 補足 (T-02 以降で対応)

- plan の Out of scope に「#1/#2/#4/#5/#6 は #356 で完了済」を追記
- T-04..T-06 を削除 (#356 で完了)
- T-02 (#3) と T-07 (#7) のみ残す簡素化
- docs/plangate.md の ABCD 見出し追加方針確定

### 残作業 (c3.json APPROVED 後)

T-02 (30-min 統一) → T-07 (ABCD↔WF 呼称統合) → T-08 (任意 C-2 再実施) → T-09 (handoff + V-1)。

### AC-1..AC-7 充足見込み

| AC | 状態 |
|----|------|
| AC-1 公開トップ + README + staged-adoption 統一 | #356 で 1/2 達成、T-02 で完成 |
| AC-2 Required/Optional 一貫 | #356 で完了、追加対応不要 |
| AC-3 30-min single 導線 | T-02 で完成 |
| AC-4 doctor --fix 必須度 | #356 で完了 |
| AC-5 When NOT to use 存在 | #356 で完了 |
| AC-6 用語 Glossary 存在 | #356 で完了 |
| AC-7 ABCD ↔ WF 統合 or 対応表 | T-07 で完成 |
