# tests/fixtures/apply-baseline/

`scripts/apply-*.sh`（HO 適用スクリプト）の**振る舞い回帰テスト用に凍結した入力**。

## なぜ実 repo からコピーしないか

`ta-71` / `ta-73` / `ta-74` は当初 `.github/workflows/` の実ファイルを
mktemp サンドボックスへコピーして入力にしていた。この設計は **実 repo の適用状態に
依存する**:

- 未適用の checkout（CI は常にこれ）→ apply が差分を出す → 全 TC 緑
- **適用済みの checkout（適用を検証した人の手元）→ apply が `already applied` で
  no-op → dry-run が差分プレビューを出さず、冪等/ガード TC が成立しない**

結果として「正しく適用された」と「壊れた」を区別できず、CI は常に緑なのに
**適用を検証しようとした人の手元だけが赤くなる**（#997 の `test_run_evidence`
TC-45 と同クラス）。さらに悪いことに、`already applied` の入力では
「削除対象が消えている / 追加対象が既にある」ため、**検出力ゼロの恒真 PASS**
になる TC もあった（例: `ta-73` TC-05 / TC-11 / TC-14）。

そこで入力を **未適用状態で凍結したスナップショット**に置き換えた。適用済み
checkout でも未適用 checkout でも、テストは常に同じ入力から始まる。

## 中身

`workflows/*.yml` — `origin/main` @ `6370573`（3 本の apply スクリプトの
**いずれも未適用**な時点）の `.github/workflows/*.yml` をバイト単位でコピーしたもの。

| 使う TA | 使うファイル | 対象スクリプト |
|---------|-------------|---------------|
| `ta-71` | `ci.yml` | `scripts/apply-ci-lint-wiring.sh` |
| `ta-73` | `check-pr-issue-link.yml` | `scripts/apply-pr-issue-link-comment-removal.sh` |
| `ta-74` | `workflows/` 全体 | `scripts/apply-workflow-hygiene.sh` |

## 更新してよい / いけない条件

- **実 repo の `.github/workflows/` を追随コピーして更新してはならない。**
  実 repo が適用済みなら、コピーした瞬間に上記の恒真 PASS が復活する。
- 更新が必要なのは、apply スクリプトが**新しいアンカー**を要求するように変わり、
  凍結スナップショットではもう適用できなくなったときだけ。その場合も
  「未適用状態の YAML」を手で作る（＝適用後の産物を入れない）。
- 各 TA は本 fixture が**未適用であること**を body の最初に検査する
  （`前提検査` TC）。適用済みの YAML を誤って置くと **SKIP ではなく FAIL** する。

## 実 repo との乖離はどう見るか

fixture が凍結される代わりに、各 TA は **実 repo の対象パスに対して
`--dry-run` を 1 回だけ走らせ、rc=0 であること**を別 TC で確認する
（`実 repo アンカー probe`）。dry-run は 1 バイトも書かないので HO パスに
触れない。実 workflow がアンカーを失う方向に drift すれば apply は
`anchor not found` で rc=1 になり、この TC が落ちる。

- 未適用 checkout: dry-run は `WILL CHANGE` を出して rc=0
- 適用済み checkout: dry-run は `already applied` を出して rc=0

どちらの状態でも rc=0 なので、**この probe は適用状態に依存しない**。
