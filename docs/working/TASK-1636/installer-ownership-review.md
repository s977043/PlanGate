# TASK-1636 installer 所有権の保護

対象は Claude 直接展開と撤去。基準 main は `0d8d9468b815ed7068b31b1a5742667d745ad202`。Codex の撤去は対象外。

新規作成した通常ファイルごとに SHA-256、device、inode、ctime、mode を v2 manifest に記録する。再導入では記録を維持し、存在しないことを観測した記録を失効する。撤去と `--force` 更新は記録が一致するファイルだけを対象とする。削除前に記録を失効し、ファイル書込・記録更新の途中で中断した場合は残存ファイルを保護する。未所有・変更済みファイル、リンク、旧 manifest は保持する。旧 manifest は引き継がないため、旧バージョンの installer でアンインストールしないこと。

安全側の制限として、target の祖先を含むシンボリックリンクを拒否する（macOS の `/tmp` なども実体パスを指定する）。ctime や inode が変わるコピー・復元、メタデータ変更でも削除対象外となる。所有記録を失ったファイルは手動確認が必要。ファイル操作と照合の間に同時変更が起きないことを前提とし、悪意ある並行プロセスに対する TOCTOU 防御は提供しない。旧 manifest のある環境で旧 installer を使うと従来の危険は残る。

## 検証とレビュー

独立担当が fixture と実装をレビュー。基準 installer は13件中3成功・4失敗・6エラー。修正後、17件成功。`sh -n install.sh`、`python3 -m py_compile tests/test_installer_ownership.py`、standalone の extras wrapper が成功。部分 snapshot のため全体 `tests/run-tests.sh` はローカル未実施。

| 観点 | 検証と対応 |
| --- | --- |
| 1 要件 | 既存、新規、再導入、編集、旧 manifest、dry-run を隔離 fixture で確認。旧記録の自動所有化はしない。 |
| 2 動作 | 独立レビューで欠損記録の再利用による誤削除を検出。欠損観測時に失効し、再作成テストで確認。 |
| 3 設計 | 同一内容の置換を識別するため inode 等を追加し、親リンク・変更済み・force を保護。並行変更は上記制約。 |
| 4 回帰 | テストを既存 extras 契約に接続、単独実行は成功。GitHub CI と全体 suite は PR の exact HEAD で確認が必要。 |
| 5 完了 | 最終差分・CI・必須レビューと Human C-4 は未確認。Draft とし、マージしない。 |

独立レビューの指摘: stale receipt、同内容の別 inode、Python 3.8/3.9 の `Path.stat` 互換性、旧版アンインストール、target のリンク祖先、並行変更。前3件は修正と fixture を実施し、後3件は上記制約として記録。実機導入、全OS・全ファイルシステム、並行変更は未検証。
