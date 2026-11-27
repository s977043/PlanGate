# MC-4 投稿本文案

投稿先は [Issue #1391](https://github.com/s977043/PlanGate/issues/1391)。Human 確認用の下書き。投稿は #1623-a マージ後の名指し承認を経て行う。

正本は [3a7373f0 の C-4 前提](https://github.com/s977043/PlanGate/blob/3a7373f02f2b7ae3b4e5843cb71ad627d55f6604/docs/working/TASK-1391/c4-preconditions.md#c-4-前提)。文面 SHA-256 は `ba4a1f169180801c42539f7da78fa5859937eff804b1515ea2fbda54b6a6704b`。

## 投稿本文

#1623-a から #1391 スライス B への引き継ぎです。以下の各項目について、C-4 前に CI run URL・ログ抜粋・判断記録のいずれかを PR 本文または TASK-1391 evidence に残してください。

- [ ] H-1391-1: #1391 後半（バイト再検査 P1B-7 の skip を外す PR）で、前半の最悪ケース fixture の構造（キー集合・`canonical_bytes` の `json.dumps` 引数）を実 `run_event` validator と照合する検査を新設し、同じ PR に含める
- [ ] H-1391-2: H-1391-1 の検査が #1391 PR の CI で実行され（skip 0 件・未実行でない）、PASS したことをその CI run のログで確認し evidence に残す。番兵を設けるかは H-1391-4 の検討結果に従い、設ける場合は印の導入と PASS を同一 PR で行い部分着地 PR は作らない（R-017）
- [ ] H-1391-3: RT-2 の監視対象定義行（R-004）が `6756a597` から変わった場合、前半の最悪ケース fixture と定数を測り直してから #1391 をマージする
- [ ] H-1391-4（D-3 / R-018 / R-019）: 番兵を #1391 後半で設計する場合、印の各判定条件が main（基準 tree）で偽になることを実物で測る（main `run_event.py:50` に `decision_made` key がある）。判定は 3 値（印あり / 印なし / 判定不能 = FAIL）とし、例外を「印なし」に倒さない。そもそも V2 構造が実在する tree では番兵は不要で、実 validator 照合だけでよい可能性を先に検討する
- [ ] H-1391-5（D-3 / R-016 / R-021）: 実照合テストの未実行検出。必須テスト名の固定リストはテストと同時改名で素通りするため、採用するなら固定リストを別ファイル・別 owner に置くか件数下限と併用する
- [ ] H-1391-6（D-3 / R-005 / R-020）: 前半の最悪ケース event が実 `validate_event` を通り、`canonical_bytes` が前半 fixture の byte 数と同値であること（AC-1 の validator 通過）を #1391 後半で確かめる。検査は V2 tree 上でだけ走らせ、tree 依存の期待値を持たない
