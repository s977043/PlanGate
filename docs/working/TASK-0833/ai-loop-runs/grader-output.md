# rubric grader 出力（全文・run 記録 / #833）

- 対象: `git diff origin/main origin/docs/833-eh3-skip-reason-dispatch`（maker SHA 407386c）
- grader: maker 独立文脈の sonnet サブエージェント（read-only）
- 裁定 record: 同ディレクトリの arbiter record（AUTO_APPROVED / priority 6）と対

```text
verdict: pass
failed_criteria: なし
feedback: 差分は issue #833 の受入基準2項目を過不足なく満たし、PLANGATE_SKIP_REASON / docs/working/_audit/skip-decision-log.jsonl の実装一致、既存文書の表・番号リスト形式踏襲、境界緩和なしを確認した。TASK-0833 ai-loop 裁定レコードも変更対象宣言内。
```

## 証跡ブロック（基準ごと）

1. 正確性・正本整合: `scripts/hooks/check-plan-hash.sh` L281 `PLANGATE_SKIP_REASON`、L167/188/289 `$WORKING_DIR/_audit/skip-decision-log.jsonl` と、追記文中の変数名・パスが完全一致。`dispatch-template.md` 内リンクはファイル自身の相互参照として妥当。
2. 要件適合: (1) dispatch-template.md 要素6の表に EH-3 遭遇時の正規手順行を追加、(2) 同行末尾「Bash 経由の直接書き込みでゲートを迂回しない」で禁止事項を明記。behavior-norms.md にも同旨5項目目を追加し二重に補強。宣言外ファイル変更なし。
3. 文体・構造踏襲: dispatch-template.md は既存の表形式の行追加のみ、behavior-norms.md は既存の番号付き箇条書き（1〜4）に5番目を追加する形式で、見出し階層・文体を逸脱していない。
4. 境界安全: 追記内容は迂回禁止を強化する方向であり、承認境界・HO境界・停止規則を緩める記述は含まれない。既存「緩和不可」原則とも整合。
5. 重複定義回避: SKIP_REASON の運用手順自体を再定義せず、check-plan-hash.sh の既存実装・ログ出力先を参照する形に留まる。両ファイル間も相互リンク参照で重複定義なし。
