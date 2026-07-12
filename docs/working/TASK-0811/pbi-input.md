---
task_id: TASK-0811
artifact_type: pbi-input
schema_version: 1
status: draft
related_issue:
  - https://github.com/s977043/plangate/issues/811
created_by: orchestrator
---

# TASK-0811 PBI INPUT PACKAGE

> issue #811（Memory Promotion Gate — 経験のルール・Skill・Hook化を審査する）を
> PBI 化する。2026-07-12 に Human 判断が issue コメントで確定しており、本
> pbi-input はその判断（中量案採用）をスコープ確定の正とする。

## Context / Why

- セッション履歴から繰り返された失敗・成功を抽出し、
  `short-term → long-term → CLAUDE.md / Skill / Hook` へ昇格させる運用が
  ai-second-brain 等で公開されている（issue 本文参照:
  https://zenn.dev/nexta_/articles/858e92ee22b4a4 ）。
- `pain_count >= 3` のような固定回数だけで実行可能なルールへ昇格させると、
  偶発的失敗・成功の誤採用、プロジェクト固有知識のグローバル拡大、
  CLAUDE.md 肥大化、lint/test/CI で防ぐべき問題の自然言語ルール化、
  陳腐化ルールの降格不能、Skill/Hook が権限・外部送信・破壊的操作へ
  影響するリスクがある（issue 本文「背景 / Why」より）。
- PlanGate には、ai-second-brain 等が生成した学習候補を審査し、実行可能な
  振る舞いへ安全に昇格させる **Memory Promotion Gate** が適している。
- 2026-07-12 の Human 判断（issue #811 コメント、verbatim）:

  > **中量案を採用**: 正本 `docs/ai/memory-promotion-gate.md` + 候補テンプレ +
  > `docs/working/_audit/memory-promotion-log.jsonl`（append-only・decision-log
  > 同型）。CLI/機械化は非実装（DoD どおり文書化まで）。
  >
  > knowledge-capture との責務分界: **即時反映 = 低リスク・単発 / 審査昇格
  > （本 Gate）= 高リスク or 恒久ルール化**の境界で確定。
  >
  > responsibility-classes.md への 1 行追記が HO 接触のため
  > mode=high-risk・同期 C-3 必須。plan 正式化は次セッションで TASK 化
  > （起草済み plan 草案はオーガナイザーが保持）。

  この判断により、実装範囲は **文書化（正本 + テンプレ + 監査ログ形式定義）まで**
  であり、CLI/自動判定/Hook 実装は本 PBI の非目標である。

## What（Scope）

### In Scope

1. **正本ドキュメント** `docs/ai/memory-promotion-gate.md` の新規作成
   - 責務と既存 Gate（C-3 / C-4 / Hardening Override 等）との差分を明文化
   - `candidate_id / kind / summary / evidence / pain_count / success_count /
     failure_count / severity / confidence / scope / proposed_target /
     constraints / risks` を持つ candidate 入力スキーマ（issue 本文の
     「1. 入力契約」を踏襲）
   - `approve / approve_with_conditions / needs_evidence / needs_human_review /
     reject / duplicate / prefer_automation / deprecate` の decision 出力語彙
     （issue 本文「5. Gate結果」を踏襲）
   - 固定回数ではなくリスクベースで判定する方針（重大度・再現性・信頼度・
     スコープ・blast radius。issue 本文「2. 固定回数ではなくリスクベースで
     判定」を踏襲。`promotion_score` 数式は参考案として明記し、最終判定は
     説明可能な判定規則を優先する旨を明記）
   - 昇格先（memory / wiki, CLAUDE.md 等常設ルール, Skill, Hook, lint/test/CI,
     Runbook, 対応不要/archive）の選択基準（issue 本文「3. 昇格先の選択基準」）
   - 証拠検証観点（同一根本原因の重複カウント防止、成功と手順の因果関係が
     弱い場合の保留、外部記事のみを根拠にしない等。issue 本文「4. 証拠検証」）
   - Canary・ロールバック・再検証の手順（issue 本文「6. Canaryとロールバック」）
   - 高リスク変更（Hook 追加・権限変更・外部送信・破壊的操作・CLAUDE.md 変更）
     の承認境界（issue 本文「8. 自動化レベル」を踏襲し、責務4分類
     [`responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
     と整合させる）
2. **候補テンプレート**の新規作成（配置は `docs/working/templates/` 配下を
   想定。plan 段階で確定）
   - candidate 入力スキーマに沿った記入例
   - decision 出力（Gate 結果 + 理由コード）の記入例
3. **`docs/working/_audit/memory-promotion-log.jsonl` の形式定義**
   - 既存 `decision-log.jsonl` 同型の append-only 形式（新規ログファイル自体の
     作成は任意、スキーマ定義のみでも可。plan 段階で決定）
   - Trust Ledger 記録項目（`candidate_id / decision / promoted_to / model /
     reason / evidence_count / human_intervention / canary_scope / before /
     after / rollback_count / revalidate_at`。issue 本文「7. Trust Ledger連携」
     を踏襲）
4. **knowledge-capture との責務分界の明文化**（Human 判断 verbatim を正本に
   反映）: 即時反映（`growth-core:knowledge-capture` 相当）= 低リスク・単発、
   審査昇格（本 Gate）= 高リスク or 恒久ルール化
5. **`.claude/rules/responsibility-classes.md` への 1 行追記の差分提案**
   （HO 対象パスのため AI は提案まで。実適用は Human）
   - Memory Promotion Gate の昇格判断（CLAUDE.md / Skill / Hook 昇格）を
     責務4分類のどこに位置づけるかの 1 行追記案
6. **代表的な candidate 判定例を 3 種類以上作成**（issue DoD 準拠。低リスク
   memory 候補 / Skill 昇格候補 / Hook・権限変更を伴う高リスク候補、を想定）
7. **既存 PlanGate / ai-loop との統合案**（issue「他リポジトリとの責務分担」
   節を踏まえ、ai-second-brain / river-review / hermes-agent-ops との入出力
   境界を明記。ただし他リポジトリ実装は非目標）
8. **導入判断（採用 / 部分採用 / 見送り）を ADR または同等文書に残す**
   （issue DoD 準拠。配置は `docs/ai/memory-promotion-gate.md` 内の節、または
   別 ADR ファイルか、plan 段階で確定）

### Out of Scope

- candidate 受領・スキーマ検証・類似候補検索・リスク分類の **CLI/機械化**
  （Human 判断で「DoD どおり文書化まで」と明示）
- Hook 実装（審査結果を強制する Hook 自体の実装）
- `.claude/rules/responsibility-classes.md` を含む HO 対象ファイルへの
  **実適用**（差分提案までとし、適用は Human が別途ワンアクションで実施）
- ai-second-brain / river-review / hermes-agent-ops 側の実装変更
- 固定回数昇格ルール（`pain_count >= 3` 等）の実装（issue 非目標と一致）
- 昇格後の効果測定を自動集計する仕組み（成功指標の定義までとし、集計自動化は
  別 PBI）

## 受入基準

1. `docs/ai/memory-promotion-gate.md` が新規作成され、Memory Promotion Gate の
   責務と既存 Gate（C-3 / C-4 / Hardening Override / knowledge-capture）との
   差分が明文化されている
2. candidate 入力スキーマ（`candidate_id` 等 issue 本文「1. 入力契約」の全
   フィールド）が正本に定義されている
3. decision 出力語彙（`approve` 等 issue 本文「5. Gate結果」の 8 種）が
   正本に定義されている
4. 重大度・再現性・信頼度・スコープ・blast radius を用いたリスクベース判定
   方針が定義され、固定回数ルールを採用しない旨が明記されている
5. 昇格先（memory/wiki, CLAUDE.md, Skill, Hook, lint/test/CI, Runbook,
   対応不要/archive）の選択基準が定義されている
6. Gate 結果と理由コードが定義されている
7. 高リスク変更（Hook 追加・権限変更・外部送信・破壊的操作・CLAUDE.md 変更）
   の承認境界が、責務4分類（AI-owned / Human-owned / CI-owned /
   Workflow-owned）と整合する形で定義されている
8. Canary・効果測定・ロールバック・再検証の手順が定義されている
9. `docs/working/_audit/memory-promotion-log.jsonl` の Trust Ledger 記録項目
   （`candidate_id / decision / promoted_to / model / reason /
   evidence_count / human_intervention / canary_scope / before / after /
   rollback_count / revalidate_at`）がスキーマとして定義されている
10. 代表的な candidate 判定例が 3 種類以上作成されている（低リスク memory
    候補 / Skill 昇格候補 / 高リスク Hook・権限変更候補を最低限含む）
11. 既存 PlanGate / ai-loop との統合案が作成されている
12. knowledge-capture（即時反映）と Memory Promotion Gate（審査昇格）の
    責務分界が、2026-07-12 Human 判断の文言（低リスク・単発 / 高リスク・
    恒久ルール化）に沿って正本に明記されている
13. `.claude/rules/responsibility-classes.md` への 1 行追記の差分案が
    plan.md または handoff.md に明示され、Human 適用手順が示されている
    （実ファイルへの適用は行わない）
14. 導入判断（採用 / 部分採用 / 見送り）が ADR または同等文書として記録
    されている
15. C-1 セルフレビュー（17 項目）が実施され `review-self.md` に PASS/WARN/FAIL
    判定が記録されている
16. Mode 判定が high-risk であり、その根拠（承認境界周辺の変更＝
    `responsibility-classes.md` 追記が HO 接触のため。
    [`mode-classification.md`](../../.claude/rules/mode-classification.md)
    の「承認境界周辺の変更 → 最低でも高」の例外ルールに該当）が明記されている

## Human Decisions Required / Unknowns

以下は issue およびコメントから判断できず、plan 作成時に Human 確認または
Repository-Resolvable Question として扱う:

- **候補テンプレートの正確な配置**: `docs/working/templates/` 配下か
  `docs/ai/` 配下か（`docs/ai/memory-promotion-gate.md` に埋め込むか別
  ファイルにするか）は Human 判断コメントに明記がなく、plan 段階で確定が
  必要
- **ADR の配置形式**: 本リポジトリに ADR 専用ディレクトリが存在するか未確認
  （plan 作成時に `find` で実測確認する Repository-Resolvable Question）
- **`memory-promotion-log.jsonl` の実ファイル作成要否**: Human 判断コメントは
  「正本 + 候補テンプレ + `docs/working/_audit/memory-promotion-log.jsonl`」と
  記載し実体作成を示唆する一方、DoD は「Trust Ledgerへの記録項目を追加・
  整理する」（スキーマ定義）にとどまる。空ファイル（0 件）を作成するか、
  スキーマ定義のみで実体ファイルは作成しないかは plan 段階で Human 確認が
  望ましい
- **`.claude/rules/responsibility-classes.md` 追記の具体文言**: Human 判断は
  「1 行追記」とのみ指定し、文言自体は確定していない。plan 作成時に草案を
  提示し、C-3 で承認を得る
- **既存 PlanGate 6 段階ループとの対応関係の反映粒度**: issue「想定フロー」
  節は Triage/Conductor/Worker/Verifier/Gate/Trust Ledger の既存ループとの
  対応案を示すが、これを正本にそのまま転記するか、PlanGate 側の C-1〜C-4/
  V-1〜V-4 用語に翻訳するかは plan 段階の設計判断
- **ai-loop-workflow との関係**: 本 PBI は本番 PlanGate WF-00〜07 側の正本
  整備であり、ai-loop-workflow（PoC）への適用要否は issue に明記がない。
  plan 段階で「本 PBI は対象外、統合案の記述に留める」ことを明示する想定

## Notes from Refinement（2026-07-12 決定事項・issue コメント verbatim 反映）

- **中量案採用**: 正本 `docs/ai/memory-promotion-gate.md` + 候補テンプレ +
  `docs/working/_audit/memory-promotion-log.jsonl`（append-only・decision-log
  同型）。CLI/機械化は非実装（DoD どおり文書化まで）
- **knowledge-capture との責務分界**: 即時反映 = 低リスク・単発 / 審査昇格
  （本 Gate）= 高リスク or 恒久ルール化 の境界で確定
- **Mode 判定**: `responsibility-classes.md` への 1 行追記が HO 接触のため
  mode=high-risk・同期 C-3 必須
- **次アクション**: plan 正式化は次セッションで TASK 化する（起草済み plan
  草案はオーガナイザーが保持。本 pbi-input はその TASK 化の入力として作成）

## Estimation Evidence

### Risks

- 正本ドキュメントが issue 本文の設計案（スコアリング式・フロー等）を
  そのまま転記するだけになり、PlanGate 既存機構（C-3/C-4/Hardening
  Override/knowledge-capture）との**差分**が曖昧になるリスク。受入基準 1
  で差分明文化を必須化して緩和する
- `.claude/rules/responsibility-classes.md` への追記案が、既存の 4 分類
  表・境界の原則と矛盾する文言になるリスク（例: AI-owned に不可能操作を
  含めてしまう）。plan 段階で既存正本の原則（「AI が物理的に不可能な操作を
  AI-owned にしない」）との整合レビューを必須とする
- DoD 11 項目のうち「代表的な候補3種類以上で判定例」「導入判断ADR」は
  文書化タスクとしては分量が大きく、high-risk 判定のタスク数閾値
  （11-20 相当）に近づく可能性がある。plan 作成時に Work Breakdown で
  タスク数を精査する

### Unknowns

- `docs/ai/` 配下の既存正本ドキュメント（`hook-enforcement.md` 等）の
  フォーマット・見出し構成（plan 作成時に読み込み、テンプレート踏襲の要否を
  確認する）
- 本リポジトリに ADR 専用の配置慣習（`docs/adr/` 等）が既に存在するか
  （plan 作成時に `find`/`grep` で実測確認する）

### Assumptions

- issue #811 本文の「入力契約」「Gate結果」「Trust Ledger連携」節の項目名は
  そのまま正本のスキーマ定義に踏襲してよい（Human コメントで変更指示なし。
  本エージェントの読み取りで issue 本文を実測確認済み: 2026-07-12 時点で
  上記節が存在することを確認）
- 本 PBI は文書化（正本 + テンプレ + ログスキーマ）のみを実装範囲とし、
  Hook 化・CLI 化は将来 PBI として明示的に分離する（Human 判断「CLI/機械化は
  非実装」と一致）
