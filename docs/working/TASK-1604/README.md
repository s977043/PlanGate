# TASK-1604 — README 導入導線の第一段階

## 状態と範囲

2026-11-03 JST。Refs #1604 / #1636。plugin README の文書修正と検証記録です。#1604 全体の完了、実機導入成功、C-3/C-4 承認、merge-ready を宣言する記録ではありません。

- 基準 main: `0d8d9468b815ed7068b31b1a5742667d745ad202`
- ブランチ: `docs/TASK-1604-onboarding-20261103`
- 実行: direct-implementer-mode。同一 assistant による I0 のセルフレビュー。Task/独立サブエージェントの実行手段を確認できず、独立レビューは未実施。
- 変更対象: `plugin/plangate/README.md` と本ディレクトリの記録・検証用スクリプトだけ。
- 非対象: production code、installer 本体、hook・権限・承認 artifact、CI、schema、manifest の変更。ユーザー端末への導入も未実施。

## 実行計画

1. 最新 main、#1604、関連 #1600、進行中 PR を照合し、完了済み変更と残る矛盾を分離する。
2. 利用者が迷う plugin README を先行し、Marketplace を推奨経路として、導入・成功確認・安全境界・やめ方を整理する。
3. 5 回の局所サイクルで、失敗する検査→一次情報との照合とレビュー→文書修正→同じ観点の再検査を行う。
4. 撤去の安全性に疑義があれば実ユーザー環境では実行せず、使い捨て fixture で再現する。runtime 修正は別 Issue に分ける。
5. PR の exact-head CI、独立レビュー、必要な Human C-4 を確認する。未確認を PASS と置換せず、条件未成立なら Draft を維持する。

## 現状確認と採用判断

root README には既に Codex の `marketplace add` と `plugin add` があり、#1600 は closed/completed でした。一方 plugin README と同梱 PoC の導入例は marketplace 登録だけで完了としていました。#1604 本文の「README は 34 行」は取得した main と一致せず、過去の記述として扱いました。

今回の変更は、導入経路の意味を揃える、Claude Code の導入・撤去 scope を対応させる、初回体験を計画確認までに限定する、plan と exec の間に人間の承認を明示するものです。承認の強制ロジックは変更していません。元の配布一覧や詳細セクションは維持しています。

参照した主な一次情報:

- [plugin README の基準版](https://github.com/s977043/PlanGate/blob/0d8d9468b815ed7068b31b1a5742667d745ad202/plugin/plangate/README.md)
- [root README の基準版](https://github.com/s977043/PlanGate/blob/0d8d9468b815ed7068b31b1a5742667d745ad202/README.md)
- [workflow コマンドの入力・出力・C-3](https://github.com/s977043/PlanGate/blob/0d8d9468b815ed7068b31b1a5742667d745ad202/plugin/plangate/commands/ai-dev-workflow.md)
- [Claude Code plugin CLI](https://code.claude.com/docs/en/plugins/cli-reference)
- [Claude Code plugin scope / discovery](https://code.claude.com/docs/en/discover-plugins)
- [Codex plugin / marketplace CLI](https://learn.chatgpt.com/docs/cli/reference)

公式仕様との照合は端末上の動作証明ではありません。

## 5 回の検証・レビュー・修正・再レビュー

各行の件数は累積した対象文書の文字列・構造検査です。アプリ E2E や独立レビュー件数ではありません。

| 回 | 検証・レビューでの発見 | 修正 | 再検証 |
| --- | --- | --- | --- |
| 1 | Marketplace 登録と導入の混同、古い list 未実装の説明 | Codex の `plugin add`、導入状態の確認、PoC 例を同期 | 4/4、exit 0 |
| 2 | 推奨経路より先に代替スクリプトを提示 | Marketplace を先頭に、scope と名前空間、旧見出し anchor を維持 | 9/9、exit 0 |
| 3 | 撤去 scope、残存設定、古い settings.plugins 配列、広すぎる削除案内 | scope 対応、`--plugin-dir`、個別撤去と残存物の説明 | 15/15、exit 0 |
| 4 | plan と exec が同じブロックで連続し承認が不明瞭 | 最小成果物の確認→Human C-3→別操作の exec、日英で境界を明記 | 20/20、exit 0 |
| 5 | 公式出典の不足、検査器がコード内の shell コメントを H1 と誤認 | 出典・前提を追加、検査器はコードフェンス外だけを数えるよう是正。#1636 と初回導線へのリンク追加 | 27/27、exit 0 |

最終版に対する負例は、Codex plugin add の削除、uninstall scope の取り違え、利用例の C-3 の削除、H1 の重複追加の 4 種をすべて検出しました。文書の安全性全般を網羅するテストではありません。

実行結果と各回の文書 SHA-256 は [evidence/results.json](evidence/results.json) に保存しています。途中の全文 snapshot はコミットしていないため、保存済み checker で再実行できるのは最終版と手元で用意した負例です。履歴のハッシュから中間本文を復元できるとは主張しません。

## 再現方法

リポジトリ root から、Python 3 の標準ライブラリだけで実行できます。

```bash
python3 docs/working/TASK-1604/evidence/verify_readme.py plugin/plangate/README.md --stage 5
python3 -m py_compile docs/working/TASK-1604/evidence/verify_readme.py docs/working/TASK-1604/evidence/reproduce_uninstall.py
git diff --check
```

installer の欠陥は、基準ソースを取得した上で隔離 fixture だけに対して再現します。下記 harness は基準 blob が一致しなければ実行を拒否し、一時ディレクトリ内で自作したファイルだけを操作します。

```bash
baseline=$(mktemp)
git show 0d8d9468b815ed7068b31b1a5742667d745ad202:install.sh > "$baseline"
python3 docs/working/TASK-1604/evidence/reproduce_uninstall.py "$baseline"
rm -- "$baseline"
```

再現 harness の exit 0 は「不具合を再現できた」を意味し、「installer が安全」を意味しません。動作前提は POSIX sh と Python 3 です。

## Source integrity と検証限界

- plugin README の基準 blob: `12b36d82534cddfbe5daf1f44cecdcf89b92a555`
- `install.sh` の基準 blob: `6f5433b70cd4b05574226e55d9109bfb48f76587`（9435 bytes）
- 修正 README blob: `f80b0a1bdc0f3fc32bd04d868c3116a728483ea3`
- 修正 README SHA-256: `59c2a034591a0f97c65892f1050d05fc55973c3e5eac6e866b0d58a1327b3bf3`

GitHub connector で取得したソースを局所再構成し、変更前の Git blob SHA1 を照合しました。環境の git clone は GitHub の DNS 解決で失敗しました。従って完全 checkout ではなく、全体テスト・全リンク検証・既存 Markdown linter は未実行です。Claude Code / Codex 実行バイナリもなく、Marketplace 導入・計画生成・撤去の実機 E2E は未実施です。

`install.sh` はソース全体の hash 一致後、最小配布 fixture で実行しました。既存ファイルが導入時にスキップされるのに manifest に入り、撤去時に消えることを再現し、#1636 に切り出しています。製品全体の導入試験ではありません。

## 残タスク・次の実行条件

- [ ] 本 PR の exact-head CI と独立レビュー、必要な Human C-4。包括的な継続指示を個別の承認記録へ変換しない。
- [ ] #1636: installer の所有権記録・編集済みファイル保護を別計画で修正し、回帰テストする。
- [ ] #1604: root `README.md` / `README_en.md` の最初の体験と撤去導線を同期する。
- [ ] #1604: marketplace description の一文、getting-started、関連 #1144 の現状を照合して整理する。
- [ ] CLI を利用できる環境で、検証用プロジェクトにおける導入→計画確認→撤去を実行し、CLI version と成功・失敗の証跡を残す。
- [ ] River Review / DAT への不足分だけの展開は、その最新 README を再取得して別差分として扱う。

`claude-session-triage` 自体の導入、端末のセッション改名・アーカイブ、定期実行登録は本変更に含めません。

## Rollback / Detection

- Kill-switch: 本 PR の文書・検証記録の変更だけを revert する。既存 hook や approval を撤去しない。
- Detection signal: CLI 仕様との不一致、導入と保護の混同、不要な削除を誘発する記述、I0 を独立レビューと誤認させる記録。
- Observation window: PR レビュー時と次の実機導入・撤去試験時。runtime の変更はありません。
