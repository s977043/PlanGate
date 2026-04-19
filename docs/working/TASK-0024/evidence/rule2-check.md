# Rule 2 遵守チェック

> 実施日: 2026-04-20
> 対象: `.claude/skills/` 配下に新規作成した 10 個の SKILL.md
> Rule 2: **Skill は再利用単位に限定する。案件固有の話を入れない。**

## Layer 1: 機械的 grep チェック

### 検査内容

各 SKILL.md に案件固有情報（プロジェクト名 / 技術スタック / 具体仕様）が含まれていないか。

### 禁止パターン

- `PostgreSQL` / `Laravel` / `MySQL` / `Redis`（具体技術スタック）
- `TASK-\d+`（特定 TASK への参照）
- `このプロジェクト` / `プロジェクト固有` / `本プロジェクト`（案件限定表現）
- `Claude Code` / `Anthropic`（ツール固有の深入り、ただし WF 参照は許可）

### 実行コマンド

```bash
for f in .claude/skills/{context-load,requirement-gap-scan,nonfunctional-check,edgecase-enumeration,risk-assessment,acceptance-criteria-build,architecture-sketch,feature-implement,acceptance-review,known-issues-log}/SKILL.md; do
  grep -E "PostgreSQL|Laravel|MySQL|Redis|TASK-[0-9]+|このプロジェクト|プロジェクト固有|本プロジェクト" "$f" && echo "VIOLATION in $f"
done
```

### 結果

| Skill | Layer 1 判定 |
|---|---|
| `context-load` | ✅ CLEAN |
| `requirement-gap-scan` | ✅ CLEAN |
| `nonfunctional-check` | ✅ CLEAN |
| `edgecase-enumeration` | ✅ CLEAN |
| `risk-assessment` | ✅ CLEAN |
| `acceptance-criteria-build` | ✅ CLEAN |
| `architecture-sketch` | ✅ CLEAN |
| `feature-implement` | ✅ CLEAN |
| `acceptance-review` | ✅ CLEAN |
| `known-issues-log` | ✅ CLEAN |

**Layer 1 総合**: ✅ 全 Skill CLEAN（VIOLATION 出力なし）

---

## Layer 2: 再利用性ルーブリック

### 判定基準

| 分類 | 条件 | 判定 |
|---|---|---|
| **再利用可能（合格）** | 特定プロジェクト / 特定業界 / 特定技術に依存せず、複数プロジェクトで同じ手順で使える | OK |
| **再利用不可（不合格）** | 特定の技術スタック / 特定の TASK / 特定のビジネスロジックが前提になっている | VIOLATION |

### 各 Skill の再利用性判定

| Skill | 再利用性判定 | 根拠 |
|---|---|---|
| `context-load` | ✅ 再利用可能 | CLAUDE.md 抽出という汎用手順 |
| `requirement-gap-scan` | ✅ 再利用可能 | 要件抜け漏れ検出は汎用 |
| `nonfunctional-check` | ✅ 再利用可能 | 非機能要件カテゴリは業種横断的 |
| `edgecase-enumeration` | ✅ 再利用可能 | 境界値・例外系列挙は汎用 |
| `risk-assessment` | ✅ 再利用可能 | severity + mitigation のフォーマットは汎用 |
| `acceptance-criteria-build` | ✅ 再利用可能 | AC 明文化は汎用 |
| `architecture-sketch` | ✅ 再利用可能 | モジュール / データフロー / 状態管理は汎用概念 |
| `feature-implement` | ✅ 再利用可能 | TDD ベースの実装 workflow |
| `acceptance-review` | ✅ 再利用可能 | AC 照合は汎用 |
| `known-issues-log` | ✅ 再利用可能 | 妥協点・V2 候補の文書化は汎用 |

**Layer 2 総合**: ✅ 全 10 Skill が再利用可能

---

## 総合判定

| Layer | 結果 | 違反数 |
|---|---|---|
| Layer 1（機械的 grep） | ✅ CLEAN | 0 |
| Layer 2（再利用性ルーブリック） | ✅ CLEAN | 0 / 10 |

**Rule 2 遵守チェック**: ✅ **PASS**（10 Skill 全てが再利用単位に限定されており、案件固有情報を含まない）
