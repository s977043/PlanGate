# #1586 レビュー記録（追記専用）

## ラウンド 1（2026-10-19）

レビュアー:

- 敵対レビュー（Claude subagent）: sandbox に全体を展開し、両スクリプトを適用したうえで ta-71 / ta-74 / ta-77 / ta-81 / ta-32 / ta-13 を実走した
- Codex 独立レビュー（read-only）: rollout jsonl で `gpt-6-luna` が使われたことを確認した

| ID | severity | 指摘 | 出所 | status | reflected_in | notes |
|----|----------|------|------|--------|--------------|-------|
| R-001 | major | `changes` job が失敗すると、4 job が黙って skipped になる | 敵対 | 採用 | ho/apply-ci-cost.sh | `!cancelled()` を含む if 式にした（`always()` だと cancel-in-progress で取り消された run でも走るため） |
| R-002 | minor | law / 承認境界の検査が sha256 固定と同語反復になっている。比較範囲に `</law>` が含まれていない | 敵対 + Codex | 採用 | ho/README.md, ho/apply-claude-agents-md.sh, report.md §3 | — |
| R-003 | minor | 16 行目の要約が CHANGELOG v8.24.0 の主題 4 つのうち 2 つしか挙げていない | 敵対 | 採用 | ho/apply-claude-agents-md.sh | — |
| R-004 | minor | AGENTS.md の行番号が 1 ずれている（正しくは 28-36） | 敵対 | 採用 | report.md | — |
| R-005 | minor | fail-open と fail-closed の表記が混在している | 敵対 + Codex | 採用 | report.md #1, ho/* | 「迷ったら実行側」に統一する |
| R-006 | minor | 日本語などの非 ASCII パスがクオートされ、.md のみの変更と判定されない | 敵対 | 採用 | ho/apply-ci-cost.sh | `core.quotePath=false` を指定する |
| R-007 | minor | dirty ガードの除外がパスの部分一致になっている | 敵対 | 採用 | ho/* | 完全一致に変える |
| R-008 | minor | 途中で失敗すると、一部だけ適用・一部だけ rollback された状態が残る | Codex | 採用 | ho/* | — |
| R-009 | minor | report #12 の HO 判定が不正確（`plugin/` は HO 対象外） | 敵対 | 採用 | report.md | — |
| R-010 | major | `HEAD^1` を基準にする前提が実走で確認されていない | Codex | 不採用 | — | 敵対レビューが depth 2 で clone した merge commit で実走し、`HEAD^1..HEAD` が topic 側の差分になることを確認済み |

## ラウンド 2（2026-10-19）

焦点は、R1 で行った是正そのものを疑うこと。レビュアーは次の 2 系統。

- 敵対レビュー: sandbox で、chflags を使って mv を意図的に失敗させ、復元の経路を実際に走らせた。awk の完全一致はリネーム・引用符・空白を含むパスで確認した。sha256 は自分で再計算した
- Codex: rollout jsonl を見て、モデルが `gpt-6-luna` であることを確認した

是正の効果は次のとおり。いずれも実測で確認した。

- R-001: needs.result の値域（success / failure / skipped / cancelled）と照合し、push 時に changes job が code=true を返すことを確認した
- R-002 / R-003 / R-007: 効いている
- R-008: mv が失敗したときの復元の経路を実際に走らせて PASS した

新しい回避クラスは、敵対レビューと Codex のどちらからも出なかった（同じ型の取りこぼしのみ）。

| ID | severity | 指摘 | 出所 | status | reflected_in | notes |
|----|----------|------|------|--------|--------------|-------|
| R-011 | major（Codex）/ minor（敵対） | 復元の cp が失敗しても気づかれず、部分適用のまま残る | 両方 | 採用 | ho/apply-*.sh | 復元に失敗したパスを表示し、非ゼロで止める |
| R-012 | minor | 一時ファイル名が固定のため、同名の未追跡ファイルを上書きする | Codex | 採用 | ho/apply-*.sh | 書き込む前に存在を確認し、あれば止める |
| R-013 | minor | 退避コピーが SIGKILL で消える | 敵対 | 採用 | ho/README.md | `git checkout --` で戻す手順を記載した |
| R-014 | info | R-001 の notes の記述が実装と食い違っている | 敵対 | 採用 | review-external.md | — |

R2 での是正後、`sh -n` と `shellcheck -s sh` はどちらも rc=0。生成物は変わっていないので、sha256 の固定値も変わらない。

## 最終試走（2026-10-19、R2 是正後）

使い捨て repo（基準 SHA を archive で展開）で両スクリプトを試走した。

| 項目 | 結果 |
|------|------|
| dry-run / verify（未適用）/ apply / apply 再実行 / verify | 両スクリプトとも rc 0 / 1 / 0 / 0 / 0 |
| 一時ファイルの残骸 | 0 |
| rollback（両方）後の BASE との差分 | 0 ファイル |
| R-012: 同名の一時ファイルがある状態で apply | rc=1、CLAUDE.md は未変更 |
| main 上で apply | rc=1 |

markdownlint はローカルにツールがなく、PR の CI（required check `Markdown lint`）で確認する。
