# PreCompact Memory Guard（正本 / TASK issue #742）

> **Status**: 仕様 + ステージング済み hook 本体（非HO）。`.claude/settings.json` /
> `scripts/hooks/` への実配線は Hardening Override (HO) 対象のため **Human 適用**。
> 関連 Issue: [#742](https://github.com/s977043/plangate/issues/742)

## 目的

Claude Code の `/compact`（自動・手動問わず）は会話履歴を要約に置き換える。
このとき、判断履歴・却下理由・進行中タスクのコンテキスト（PlanGate Memory /
`current-state.md` 相当）が更新されないまま compact されると、次のセッション
（あるいは compact 後の同一セッション）が過去の判断を再現できず、既に却下した
選択肢を再検討する・進行中タスクを見失う、といった劣化が起きる
（[`.claude/skills/plangate-working-discipline/anti-patterns.md`](../../.claude/skills/plangate-working-discipline/anti-patterns.md)
の anti-pattern #12「compact で判断履歴を失う」に対応）。

現状、この規律は以下の **規範層のみ** に存在し、Hook 層の強制力を持たない:

- [`working-context.md`](../../.claude/rules/working-context.md) の
  `current-state.md` 運用（タスク完了ごとに更新）
- [`.claude/skills/plangate-working-discipline/plan-memory.md`](../../.claude/skills/plangate-working-discipline/plan-memory.md)
  （PENDING-VERIFY 前置・Last Updated 記録）
- [`example-prompts.md`](../../.claude/skills/plangate-working-discipline/example-prompts.md)
  の `/compact` 前プロンプト例（#9）

本仕様は、compact 直前（`PreCompact` hook）に作業コンテキストの鮮度を機械的に
検査し、規範の**取りこぼしを warn で可視化する**（block は opt-in）。

## 位置づけ（hybrid-architecture との整合）

[`hybrid-architecture.md`](../../.claude/rules/hybrid-architecture.md) の
「強制力が必要な決定論的制御は Hook」に従う。ただし本 hook は **検査・警告のみ**
であり、規範（plan-memory / working-context）の内容そのものを変更しない
（Rule 1〜5 と直交、既存正本は不変）。

## 検査ロジック

### 入力

| 入力                                       | 出典                                               | 用途                                                                                                                   |
| ------------------------------------------ | -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| PreCompact hook stdin JSON                 | Claude Code hook 呼び出し（`session_id` 等を含む） | 将来拡張用に読み取るが、本仕様では判定に必須ではない（読めなくても動作継続）                                           |
| `PLANGATE_HOOK_TASK`                       | env（EH-2/EH-3 等 既存 Hook と同じ規約）           | 検査対象 TASK の特定。**未設定なら無音**（誤爆ゼロ設計）                                                               |
| `PLANGATE_PRECOMPACT_MAX_AGE_MIN`          | env（既定 `120`）                                  | 鮮度しきい値（分）                                                                                                     |
| `PLANGATE_PRECOMPACT_BLOCK`                | env（既定 `0`）                                    | `1` で block opt-in                                                                                                    |
| `PLANGATE_TEST_MODE` / `PLANGATE_TEST_NOW` | env（テスト専用）                                  | `PLANGATE_TEST_MODE=1` のとき `PLANGATE_TEST_NOW`（epoch seconds）で「現在時刻」を固定注入し、テストを時刻非依存にする |

### 判定フロー

```text
1. PLANGATE_HOOK_TASK が未設定
   → 無音（exit 0）。TASK 文脈がない一般会話・非 PlanGate リポジトリでの
     誤爆を防ぐ（誤爆ゼロ設計の中核）。

2. PLANGATE_HOOK_TASK が設定済み
   → docs/working/<TASK>/current-state.md を検査:

   (a) ファイル不在
       → WARN「current-state.md が見つかりません」

   (b) ファイルの mtime が「現在時刻 - PLANGATE_PRECOMPACT_MAX_AGE_MIN 分」より古い
       → WARN「最終更新が N 分より古い可能性があります」
       （セッション開始時刻との比較は Hook 単体では取得不可能なため、
       「ファイル mtime が既定しきい値より古い」を代理シグナルとして使う。
       誤検知を許容し warn 止まりにすることで安全側に倒す）

   (c) ファイル内容に `PENDING-VERIFY` を含む
       → WARN「PENDING-VERIFY 項目が残っています（compact 前に確定 or
         明示的に持ち越しと記録してください）」

   いずれかに該当した場合:
     - 既定（PLANGATE_PRECOMPACT_BLOCK 未設定 or 0）: stderr に warn を出し
       exit 0（compact を止めない）
     - PLANGATE_PRECOMPACT_BLOCK=1: 既存 Hook（EH-3 等）の作法に合わせ
       exit 2 で block 相当の終了コードを返す（実効性は下記の注意を参照）

3. いずれの WARN 条件にも該当しない（current-state.md が新しく、
   PENDING-VERIFY を含まない）
   → 無音（exit 0）
```

> **⚠️ 注意（block opt-in の実効性）**: PreCompact hook に対する exit code
> block の実効性は **ハーネス（Claude Code）仕様依存で未検証** である
> （PreCompact が exit code による block をサポートしない可能性がある）。
> **本ガードは warn-only を前提とし、`PLANGATE_PRECOMPACT_BLOCK` は実験的
> opt-in（効かない可能性あり）** として提供する。block を有効化しても
> compact が抑止されることを保証しない。確実な運用は「stderr の warn を
> 見て compact 前に current-state.md を更新する」規範側フローに依る。

### `PLANGATE_HOOK_TASK` の形式検証（パストラバーサル防止）

`PLANGATE_HOOK_TASK` はファイルパス
（`docs/working/<TASK>/current-state.md`）に展開されるため、hook は
検査前に形式を検証する（`scripts/hooks/check-forbidden-files.sh` の
既存パターン踏襲 + traversal ガード）:

- `TASK-*` 形式に一致しない → 無音 SKIP（exit 0）
- `/`（パス区切り）または `..` を含む → 無音 SKIP（exit 0）

これにより `../../outside` のような値で `docs/working/` 外のファイルが
読まれることを防ぐ。

## 誤爆ゼロ設計

- **TASK 文脈がない場合は一切発火しない**（`PLANGATE_HOOK_TASK` 未設定で
  即 exit 0）。PlanGate を使わない一般的な Claude Code セッション、
  ドキュメント読み取りだけのセッション等では絶対に警告を出さない。
- 既定は **warn のみ**（exit 0）。block は明示的な opt-in
  （`PLANGATE_PRECOMPACT_BLOCK=1`）でのみ有効化される。
- mtime 判定は「古いから即異常」ではなく、既定 120 分という緩やかなしきい値
  （`PLANGATE_PRECOMPACT_MAX_AGE_MIN` で調整可能）を採用し、通常の作業ペース
  では発火しないよう設計する。

## Human 適用手順

本 hook 本体（`scripts/precompact-memory-guard.sh`）と検証テスト
（`tests/extras/ta-50-precompact-guard.sh`）は非 HO（AI-owned）で提供済み。
実配線（`scripts/hooks/` への設置 + `.claude/settings.json` の `PreCompact` 登録）
は Hardening Override 対象のため Human が適用する:

```sh
# 1. 差分確認（書き込みなし）
sh scripts/apply-precompact-guard.sh --dry-run

# 2. 適用（Human 実行のみ）
sh scripts/apply-precompact-guard.sh --apply

# 3. 検証
sh tests/extras/ta-50-precompact-guard.sh
bin/plangate doctor
```

適用後、`.claude/settings.json` の `hooks.PreCompact` に
`scripts/hooks/precompact-memory-guard.sh` が登録され、`PLANGATE_HOOK_TASK`
が設定されたセッションで compact 直前に鮮度検査が発火する。

## 関連

- [`.claude/rules/working-context.md`](../../.claude/rules/working-context.md)
  （`current-state.md` 運用・settings タスクロックの考え方）
- [`.claude/skills/plangate-working-discipline/plan-memory.md`](../../.claude/skills/plangate-working-discipline/plan-memory.md)
  （PlanGate Memory テンプレート・PENDING-VERIFY 規約）
- [`.claude/skills/plangate-working-discipline/example-prompts.md`](../../.claude/skills/plangate-working-discipline/example-prompts.md)
  （`/compact` 前プロンプト例 #9）
- [`.claude/rules/hybrid-architecture.md`](../../.claude/rules/hybrid-architecture.md)
  （Hook 境界：強制力が必要な決定論的制御は Hook に置く）
- [`.claude/rules/responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
  （settings 適用・Hardening Override は Human-owned）
- Issue [#742](https://github.com/s977043/plangate/issues/742)

## やらないこと（Non-goals）

- compact 自体の抑止（block は opt-in の警告強化に留め、既定では compact を
  止めない）
- 要約内容そのものへの介入（PreCompact hook は summary 生成前の検査に限定）
- 非 TASK 文脈での発火（`PLANGATE_HOOK_TASK` 未設定時は常に無音）
