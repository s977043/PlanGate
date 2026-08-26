# Plan Metrics Verification (#351 / TASK-0117)

> **正本**: 本 doc。`.agents/skills/ai-dev-plan/SKILL.md` の「事前メトリクス検証」
> セクションは本 doc を参照する。
>
> 関連: `mode-classification.md` /
> `working-context.md` AC-8 安全側不変条件

## 目的

PlanGate A → B 遷移 (PBI INPUT → plan 生成) で AI が **規模見積もりの実数検証なしに Mode 判定**することによる process drift を構造的に防ぐ。

実害ベース:

- PocketEitan で抽象語イラスト描き直し: Codex が「規模 M」と推奨したが、実数取得すると **17 グループ・1697 ファイル**で実態は規模 XL。推奨通り着手していれば 1 セッション完遂不能でリリース詰まりが発生する状況だった
- 本 PlanGate セッション (TASK-0108..0117): 規模見積もり 7 file → 実数 5 file 等、事前メトリクス検証が複数 PBI で軌道修正に寄与 (TASK-0117 自己適用も含む)

## B-1 → B-2 mandatory gate 位置付け

`.agents/skills/ai-dev-plan/SKILL.md` のフロー:

```text
B-1 (確認質問)
  ↓
事前メトリクス検証 (本 doc)  ← mandatory gate
  ↓
B-2 (trade-off 比較)
  ↓
B-3 (3 ファイル同時生成)
```

## 判定基準

| 実数 / AI 見積もり | 判定 | アクション |
|------------------|------|----------|
| **≥ 3 倍** | スコープ過大 | **スコープ縮小 or 別タスクへ切替**。plan を Out of scope 化 |
| **1 〜 3 倍** | 範囲内 | 採用、plan の Risks に「実数 N, 見積 M, 比率 X」を記録 |
| **< 1 倍** | スコープ過小 (or 簡素) | 採用、**Mode を 1 段下げる候補** (例: standard → light) |

### 安全側不変条件 (AC-8 一貫 / R-001/R-004)

以下のいずれかに該当する場合は **必ず Mode 引き上げ側に倒す**:

- 実数取得不能 (find / grep が範囲限定不能、対象パスが曖昧)
- Plan Health 未算出 (TASK-0213 等の自動 Plan Health 機構が未実装の場合)
- 「全件 / 全部 / 残り N 件」系の対象範囲が曖昧
- 承認境界 (Hardening Override) を含む可能性

→ `lite_eligible=false` 強制、Standard / high-risk 寄せ。

## 検証コマンド例

`.git`, `node_modules`, ビルドアーティファクト等を除外して **対象範囲を限定**:

```sh
# 文字列言及数 (ファイル数ベース、.git/node_modules 等を除外)
grep -rln --exclude-dir={.git,node_modules,dist,docs/working} <symbol> --include='*.md' --include='*.ts' -- . | wc -l

# ファイル数
find . -name <pattern> \
  -not -path './.git/*' \
  -not -path './node_modules/*' \
  -not -path './dist/*' \
  -not -path './docs/working/*' | wc -l

# 推奨: ripgrep (rg) を優先
rg --files <path> | wc -l
rg -l <pattern> --type md | wc -l

# 行数ベース (より厳格)
grep -rln <symbol> docs/ | xargs wc -l
```

### CI 等で `rg` 不在の環境

`grep -rln --exclude-dir={.git,node_modules,...}` または `find -not -path` で fallback。`--include` だけでは `node_modules` 等のディレクトリ走査自体は防げないため、必ず `--exclude-dir` を併用する。

## plan.md template (Metrics Evidence 欄 / AC-8)

`plan.md` の「Mode 判定」セクション直前 or 「Plan Health」セクション内に必須:

```markdown
## Metrics Evidence (#351 事前メトリクス検証)

| 項目 | AI 見積もり | 実数 | 比率 | 判定 |
|------|------------|------|------|------|
| 変更ファイル数 | N | M | M/N | 採用 / 縮小 / Mode 1 段下げ |
| AC 件数 | N' | M' | M'/N' | 採用 / 縮小 / — |
| (該当範囲がある場合) 言及箇所数 | ... | ... | ... | ... |

**取得コマンド**: `find ... | wc -l` / `grep -rln ... | wc -l` (具体コマンドを 1 行記載)

**判定理由**: (Mode 維持 or 変更の根拠を 1-2 文)
```

## 既存実例

### 1. PocketEitan 抽象語イラスト描き直し (2026-05-26 セッション)

- AI 当初見積もり: **規模 M** (推定 1 グループ程度)
- 実数: `find pages -name '*.png' | wc -l` で **17 グループ・1697 ファイル**
- 比率: **約 17 倍** (≥ 3 倍 → スコープ縮小)
- 結果: 当該タスクを別 PBI に切替、リリース詰まり回避
- 参考: PocketEitan PR #371 / memory `feedback_size_estimate_verify_before_adopt.md`

### 2. PlanGate TASK-0111 (#295 pages → docs/pages 移設、2026-05-27)

- plan 見積もり: 10-20 file
- 実数 (T-01 evidence): 9 file (pages/) + 4 file (docs/**/*.md 置換) + 1 file (sidebars.js) = **14 file**
- 比率: **0.7〜1.4 倍** (1〜3 倍範囲) → Mode standard 維持で妥当
- 結果: scope 適切、軌道修正不要

### 3. PlanGate TASK-0117 (#351 本 PBI、自己適用 / 2026-05-27)

- plan 見積もり: 4-5 file
- 実数 (T-01 evidence): SKILL.md (1 追記) + plan-metrics-verification.md (新規) + ta-19 (新規) + handoff = **4 file**
- 比率: **0.8〜1.0 倍** (1〜3 倍範囲、< 1 寄り) → Mode standard 維持で妥当
- 結果: 本 PBI 自身を本 PBI 手法で評価 = 妥当な mode (meta 達成)

### 4. PlanGate TASK-0108 (#310 UX 7 項目 / 2026-05-27)

- plan 当初: 7 step (#1..#7 全項目)
- 実数 (T-01 evidence + #356 既達状況): 7 step → 実 2 step (#3, #7 のみ残、5 項目は #356 で先行完了)
- 比率: **0.29 倍** (< 1 倍、scope 縮小済) → Mode standard 維持 + Out of scope 明示で対応
- 結果: scope 縮小の正規化、過剰 work 回避

## TASK-0112 (mode 例外ルール) との境界

| PBI | 役割 |
|-----|------|
| **本 doc (TASK-0117 #351)** | A → B 遷移時の **plan 前 メトリクス検証** (AI 行動規範) |
| **TASK-0112 (#193 mode-classification 例外ルール)** | mode 自動補正の例外条件 (承認境界周辺は最低 high-risk) |

**相互参照のみ、重複定義なし**:

- 本 doc は「実数を取って Mode を判定する手順」
- TASK-0112 は「特定パスに touch する場合は強制 high-risk」

両者は **AND 関係** で適用される。

### TASK-0112 plan の状態 (現時点)

TASK-0112 plan は merged だが exec 未実施 (c3.json 待ち)。本 doc 適用時点で TASK-0112 の例外ルール本体 (`.claude/rules/mode-classification.md` 改修) が未適用の可能性。安全側 (`lite_eligible=false` を本 doc 適用側で明示扱い) で進む (R-006)。

## CLI 化 (V2 候補、本 PBI scope 外)

将来的に `bin/plangate validate --metrics` 等の機械検証 CLI を導入する場合は別 PBI (#352 codex-mvp-split に類似の構造)。

## References

- Issue: [#351](https://github.com/s977043/plangate/issues/351)
- TASK-0117 plan: `plan.md`
- T-01 evidence: `t01-investigation.md`
- 参考実装: PocketEitan PR #371
- memory: `feedback_size_estimate_verify_before_adopt.md`
