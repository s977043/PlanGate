# W-6（C-3 Autonomous APPROVE マトリクス）downstream 導入経路

> Status: Specification（v1）
> 対象: issue [#688](https://github.com/s977043/plangate/issues/688)
> 正本: [`working-context.md`](../../.claude/rules/working-context.md) 「C-3 Autonomous
> APPROVE（ユーザー自律実行委任時 / #353）」節（本 doc は**人間著者による導入手順** +
> **未導入リポジトリでの暫定運用規定** を扱う付随ドキュメントであり、判定マトリクス
> そのものの正本ではない）。関連: [#353](https://github.com/s977043/plangate/issues/353)
> （C-3 Autonomous APPROVE 初出）/ [#626](https://github.com/s977043/plangate/issues/626)
> （C-3 承認モード切替、本 issue とは論点が異なる — #626 は承認モードの選択、本 issue
> は導入経路とセーフティ分類器の衝突）。

## 0. 用語

本 doc では `.claude/rules/working-context.md` の「C-3 Autonomous APPROVE（ユーザー
自律実行委任時 / #353）」節（判定マトリクス + 必須記録 + 即停止条件 + AC-10 Hardening
Override 優先）を **W-6** と呼ぶ。W-6 自体は `.claude/rules/*.md` 配下にあるため
Hardening Override（HO）対象パスであり、本 doc は HO 対象パスを一切変更しない。

## 1. 背景（issue #688 より）

下流リポジトリ（PocketEitan）で W-6 を AI エージェント経由で同期しようとしたところ、
Claude Code のセーフティ分類器が「AI 自身の承認権限拡大（Self-Modification /
Instruction Poisoning）」として拒否した（2026-06-18 実例）。このガード自体は妥当だが、
結果として下流で「ルール未整備のまま autonomous APPROVE 運用だけが先行する」逆転が
発生した（翌日 2026-06-19 のタスクで `C-3 Gate: AUTONOMOUS APPROVED` が判定基準の
明文化なしに記録された）。

この逆転を解消するため、本 doc は次の 3 点を提供する:

1. W-6 を **人間が著者となって導入する手順**（コピペ用スニペット + 導入チェックリスト）
2. W-6 **未導入**リポジトリで autonomous APPROVE が行われた場合の**暫定記録フォーマット**
3. `plangate doctor` での W-6 導入状態の**検知仕様**（未導入 + autonomous APPROVE
   記録あり → WARN。実装は別 PBI の follow-up）

## 2. なぜ apply スクリプトを用意しないか

`.claude/rules/*.md` は Hardening Override 対象パスであり、`mode-classification.md`
の例外ルールにより「承認境界周辺の変更 → 最低でも高（high-risk）」+ Standard・同期
C-3 が強制される。加えて、AI が生成した apply スクリプト（`sh apply-xxx.sh --apply`
形式）を人間が実行する経路であっても、**スクリプトの中身が AI 生成**である以上
「AI 由来の承認権限拡大」という同じ懸念にセーフティ分類器が反応しうる（#688 の実例が
示すとおり、AI が W-6 の *内容そのもの* を down-stream に運ぶ操作は、実行主体が
人間であっても "AI が承認緩和ルールを増幅させている" という構造は変わらない）。

したがって本 doc は **apply スクリプトを提供しない**。導入は §3 のコピペ用スニペットを
**人間が自分のエディタ / commit で著者として持ち込む**ことを正とする。AI（Claude
Code / Codex 等）はこの節を「実行してよいコマンド」として扱ってはならず、人間への
提示・説明にとどめる。

## 3. 人間著者による導入手順

### 3.1 前提

- 導入は **人間が** 対象リポジトリの `.claude/rules/working-context.md`（または同等の
  正本ファイル）に、以下のスニペットを**自分の commit として**貼り付けることで行う。
- AI エージェントに「このスニペットをファイルに書き込んで」と指示することは、
  形式的に人間が指示していても実質 AI 生成物の HO 領域への書き込みであり、
  Hardening Override（`.claude/rules/*.md` は最低 high-risk・同期 C-3 必須）および
  自己承認権限拡大ガードの精神に反する。**エディタで人間が直接貼り付ける**、または
  人間が commit 内容を一字一句確認した上で `git commit` する運用を徹底する。

### 3.2 コピペ用スニペット

以下は `.claude/rules/working-context.md`（または同等ファイル）の C-3 ゲート条件
セクション配下に、人間が直接貼り付けるための断片。plangate 本体 v8.13.0 時点の
`working-context.md` L333-360 の内容と同一。

```markdown
#### C-3 Autonomous APPROVE（ユーザー自律実行委任時 / #353）

ユーザーが「自律的に進めて」「残タスクを進めて」等の**自律実行指示**を明示した場合、
以下の条件をすべて満たすときは AI が C-3 を autonomous APPROVE できる。

**autonomous APPROVE 判定マトリクス**:

| 条件 | autonomous APPROVE 可否 |
|------|------------------------|
| Mode = ultra-light / light | ✅ 可（C-1 PASS のみ） |
| Mode = standard + 受入基準 ≤ 5 + 影響範囲が plan Files に閉じる | ✅ 可（C-1 PASS のみ） |
| Mode = standard + 受入基準 > 5 または影響範囲が plan Files を超える | ⚠️ 条件付き（C-2 必須、重大指摘なし） |
| Mode = high-risk / critical | ❌ 不可（人間 C-3 必須） |
| Hardening Override 対象パスを含む | ❌ 不可（Mode に関わらず人間 C-3 必須） |
| スキーマ変更 / 破壊的変更 / セキュリティ関連 | ❌ 不可（人間 C-3 必須） |

**autonomous APPROVE 時の必須記録**:
- `status.md` に `## C-3 Gate: AUTONOMOUS APPROVED` を記録
- ユーザーの自律実行指示を verbatim で引用
- C-1 結果（PASS or 軽微 WARN のみであること）

**即停止条件（autonomous 実行中）**:
- 想定外の規模・影響範囲の拡大が判明した時点で即停止 → 人間判断を仰ぐ
- C-2 必須条件で重大指摘が出た場合は即停止

**AC-10 Hardening Override 優先**（mode-classification.md AC-10 と一致）:
HO 対象パスを含む変更は `autonomous APPROVE` および `lite_eligible` を**無効化**し
Standard・同期 C-3 を強制。
```

> 対象リポジトリの Hardening Override 対象パス一覧（`mode-classification.md` の
> 9 カテゴリ）が plangate 本体と異なる場合は、貼り付け前に「HO 対象パスを含む変更」
> の判定基準を対象リポジトリの実際のパス構成に合わせて調整すること（機械的なコピペ
> だけで終わらせない）。

### 3.3 導入チェックリスト（人間用）

- [ ] このスニペットを **人間が** 対象ファイルにペーストした（AI に書き込みを
      代行させていない）
- [ ] 対象リポジトリに `mode-classification.md`（5 段階モード分類 + AC-10 Hardening
      Override）が既に導入済み、またはこのタイミングで併せて導入した
      （W-6 は `mode-classification.md` の AC-10 / lite_eligible を前提として
      いるため、W-6 単体では機能しない）
- [ ] 対象リポジトリの Hardening Override 対象パス一覧を確認し、W-6 内の
      「Hardening Override 対象パスを含む」判定が対象リポジトリの実態と一致する
      ことを確認した
- [ ] commit は人間の GitHub アカウントで行い、コミットメッセージに
      `Refs #688`（本 issue）または対象リポジトリの追跡 issue を記載した
- [ ] 導入後、`status.md` の `## C-3 Gate: AUTONOMOUS APPROVED` 記録例を
      チームに周知した（§4 の記録フォーマットと整合させる）
- [ ] `plangate doctor` を実行し、W-6 検知（§5、実装後）が導入済みとして
      認識されることを確認した（doctor 未実装期間は目視確認で代替）

## 4. W-6 未導入リポジトリでの暫定記録フォーマット

W-6（判定マトリクス）が未導入のリポジトリでも、AI が実質的に autonomous APPROVE
相当の判断（人間の明示的な逐次承認なしに C-3 を通過したとみなせる判断）を行う場面が
ありうる。issue #688 の実例（2026-06-19、判定基準の明文化なしに
`C-3 Gate: AUTONOMOUS APPROVED` が記録された）を踏まえ、W-6 未導入の期間に限り
以下の**暫定記録フォーマット**を必須とする。

### 4.1 必須記録項目

`status.md`（または相当のフェーズ履歴ファイル）に、以下を **verbatim 必須**で記録する:

| 項目 | 内容 | verbatim 必須 |
|------|------|:---:|
| `w6_status` | `not_introduced`（W-6 未導入である旨を明示） | - |
| `user_instruction` | ユーザーの自律実行指示の原文 | ✅ |
| `mode` | 適用した規模モード（ultra-light 〜 critical） + 判定根拠 | - |
| `ho_path_touched` | Hardening Override 対象パスへの touch 有無（true/false）+ 該当パス一覧 | - |
| `judgment_basis` | なぜ autonomous 相当と判断したか（W-6 の判定マトリクス相当の軸を人間可読な文章で記述。マトリクスが無いため機械判定はできない前提を明記） | - |
| `c1_result` | C-1 セルフレビュー結果（PASS / WARN 内容） | - |

### 4.2 記録テンプレート例

```markdown
## C-3 Gate: AUTONOMOUS APPROVED（暫定・W-6 未導入）

- w6_status: not_introduced
- user_instruction: "<ユーザー指示の原文をそのまま引用>"
- mode: light（変更ファイル数1、受入基準2、影響範囲は当該機能のみ）
- ho_path_touched: false（該当パスなし）
- judgment_basis: |
    W-6（working-context.md の autonomous APPROVE 判定マトリクス）が本リポジトリに
    未導入のため、plangate 本体の判定マトリクス相当の軸（Mode / 受入基準数 /
    影響範囲 / HO 対象パス有無 / スキーマ変更有無）を目視で確認し、
    「Mode=light かつ HO 対象パスなし」で machine-checkable 相当と判断した。
- c1_result: PASS（C-1 全25項目チェック、指摘なし）
```

### 4.3 位置づけ

本フォーマットは W-6 の**代替**ではない。W-6 未導入の間に監査証跡を最低限確保する
ための**橋渡し**であり、W-6 導入後は §3 のマトリクスによる正式な記録
（working-context.md 既定の必須記録項目）に切り替える。

## 5. `plangate doctor` での検知仕様（Specification のみ・実装は follow-up）

> 実装は `bin/plangate`（Hardening Override 対象パス）への変更を要するため、
> **本 doc では仕様のみを定義し、実装は別 PBI（follow-up）とする**。本 doc 自体は
> `bin/plangate` を変更しない。

### 5.1 検知条件

```text
W6IntroductionGapDetected =
  W6NotIntroduced
  AND AutonomousApproveRecordExists
```

| 項目 | 判定方法（仕様） |
|------|-----------------|
| `W6NotIntroduced` | `.claude/rules/working-context.md`（または相当ファイル）に「C-3 Autonomous APPROVE」見出し文字列が存在しない |
| `AutonomousApproveRecordExists` | `docs/working/TASK-*/status.md` のいずれかに `C-3 Gate: AUTONOMOUS APPROVED` 文字列が存在する（§4 の暫定記録フォーマットの有無に関わらず、見出し文字列自体の存在で判定） |

### 5.2 doctor 出力仕様（案）

```text
  [WARN] W-6（C-3 Autonomous APPROVE マトリクス）未導入だが
         AUTONOMOUS APPROVED 記録が N 件検出されました。
         導入手順: docs/ai/w6-autonomous-approve-introduction.md
```

- Severity は **WARN**（block しない）。W-6 は Hardening Override 対象のため
  doctor による自動導入・自動修正（`--fix`）は行わない（人間著者導入が正のため）。
- 検知対象ファイル数・該当 TASK ディレクトリ一覧をメッセージに含め、
  トレーサビリティを確保する（`orchestrator-mode.md` の「検証可能性」原則
  ＝明示的失敗・トレーサビリティ・冪等性 に整合させる）。

### 5.3 follow-up スコープ

- `bin/plangate doctor` への実装（新規チェック項目の追加）
- 既存の doctor 検査項目一覧（12 項目 / v8.6.0 セクション）への追加登録
- CI ワークフローでの定期実行の要否検討

これらは本 doc の範囲外とし、別 issue（本 doc への `Refs #688` を継承する）で
追跡する。

## 6. 関連

- [`.claude/rules/working-context.md`](../../.claude/rules/working-context.md)
  「C-3 Autonomous APPROVE」節（W-6 正本）
- [`.claude/rules/mode-classification.md`](../../.claude/rules/mode-classification.md)
  （5 段階モード分類 + AC-10 Hardening Override 対象パス 9 カテゴリ）
- [`.claude/rules/responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
  （AI-owned / Human-owned 境界の正本）
- [`docs/ai/project-rules.md`](./project-rules.md)（AI 運用 4 原則）
- issue [#353](https://github.com/s977043/plangate/issues/353)（C-3 Autonomous
  APPROVE 初出）
- issue [#626](https://github.com/s977043/plangate/issues/626)（C-3 承認モード切替、
  本 issue とは別論点）
- issue [#688](https://github.com/s977043/plangate/issues/688)（本 doc の起点）
