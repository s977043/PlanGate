# TASK-1391 スライス B の C-4 前提（TASK-1623 からの引き継ぎ）

> 2026-11-26 Human 決定 D-4（TASK-1623 plan `ba206960` の Decisions）により記載する。
> TASK-1391 の plan.md と approvals/c3.json は変更しない。本ファイルはスライス B（バイト再検査 P1B-7 の skip を外す PR）を C-4 に渡す前提を定める。
> **H-1391-1〜6 の文面の正本は本ファイル**（TASK-1623 C-2 R5 / R-031）。TASK-1623 側は本ファイルの commit を参照するだけで文面を持たない。文面を変えるときは本ファイルを更新し、同じ変更で TASK-1623 側の参照 commit を更新する。初版の転記元は TASK-1623 plan `ba206960`。

## C-4 前提

スライス B の PR は、次の H-1391-1〜6 それぞれについて evidence（CI run の URL・ログ抜粋・判断記録のいずれか）を PR 本文または `docs/working/TASK-1391/evidence/` に残すまで C-4 に渡さない。

- H-1391-1: #1391 後半（バイト再検査 P1B-7 の skip を外す PR）で、前半の最悪ケース fixture の構造（キー集合・`canonical_bytes` の `json.dumps` 引数）を実 `run_event` validator と照合する検査を新設し、同じ PR に含める
- H-1391-2: H-1391-1 の検査が #1391 PR の CI で実行され（skip 0 件・未実行でない）、PASS したことをその CI run のログで確認し evidence に残す。番兵を設けるかは H-1391-4 の検討結果に従い、設ける場合は印の導入と PASS を同一 PR で行い部分着地 PR は作らない（R-017）
- H-1391-3: RT-2 の監視対象定義行（R-004）が `6756a597` から変わった場合、前半の最悪ケース fixture と定数を測り直してから #1391 をマージする
- H-1391-4（D-3 / R-018 / R-019）: 番兵を #1391 後半で設計する場合、印の各判定条件が main（基準 tree）で偽になることを実物で測る（main `run_event.py:50` に `decision_made` key がある）。判定は 3 値（印あり / 印なし / 判定不能 = FAIL）とし、例外を「印なし」に倒さない。そもそも V2 構造が実在する tree では番兵は不要で、実 validator 照合だけでよい可能性を先に検討する
- H-1391-5（D-3 / R-016 / R-021）: 実照合テストの未実行検出。必須テスト名の固定リストはテストと同時改名で素通りするため、採用するなら固定リストを別ファイル・別 owner に置くか件数下限と併用する
- H-1391-6（D-3 / R-005 / R-020）: 前半の最悪ケース event が実 `validate_event` を通り、`canonical_bytes` が前半 fixture の byte 数と同値であること（AC-1 の validator 通過）を #1391 後半で確かめる。検査は V2 tree 上でだけ走らせ、tree 依存の期待値を持たない

## 監視対象の定義行（`6756a597:scripts/ai-loop-v2/run_event.py`）

`DECISION_REQUIRED_KEYS` 39-42 / `DECISION_OPTIONAL_KEYS` 43 / `EVENT_PAYLOAD_KEYS`（`decision_made` は 68）52-70 / `COMMON_ACCEPTED_KEYS` 71-74 / `canonical_bytes` 81-84 / `_validate_decision` 136-171 / `_validate_append_only` 467-474
