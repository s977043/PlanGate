# TASK-1085 evidence — Codex plugin manifest / doctor 誤報

計測日: 2026-08-13 / `codex-cli 0.144.1` / branch `fix/1085-codex-plugin-manifest`（base `origin/main` = `8f57e59`）

## 結論（先に）

**issue #1085 の中核前提は実測で否定された。** `.codex-plugin/plugin.json` が
**無い状態（= `origin/main` そのもの）でも、Codex は plugin を install でき、
plugin cache 配下の skill root（`plugins/cache/<mp>/plangate/<ver>/skills`）が
skill 一覧に現れ、PlanGate skill 39 件がロードされる。**

- ⇒ **AC-1 は「マニフェスト追加の効果」としては実証できない**（追加前から root は出る）
- ⇒ **AC-2（負の対照）は成立しない**（マニフェストを退避しても root は消えない）＝ **停止条件 SC-2**

一方、**doctor の誤報（AC-5）は実在**し、原因は issue の推定とは別だった:
`codex plugin marketplace add` だけが実行され **`codex plugin add` が実行されていない**
（= plugin が install されていない）のに、旧 `check-codex-plugin-status.sh` は
marketplace cache ディレクトリの存在だけで `registered: YES` を返していた。

## ログ一覧

| ファイル | 内容 |
|---|---|
| `refutation-origin-main-git-marketplace.log` | **最重要**。実際の公開経路（`codex plugin marketplace add s977043/plangate` → `codex plugin add plangate@plangate`）を隔離 `CODEX_HOME` で実行。`origin/main`（`.codex-plugin/plugin.json` 不在）で `installed, enabled 8.19.0` になり、`r2 = .../plugins/cache/plangate/plangate/8.19.0/skills` が現れ `plangate:` skill 39 件がロードされる |
| `ac1-isolated-load-with-codex-manifest.log` | 本ブランチ（マニフェスト追加後）の隔離ロード。root と 39 skill を確認（＝**非回帰**の証跡。マニフェスト追加による破壊はない） |
| `ac2-isolated-load-manifest-stashed.log` | 同一手順で `.codex-plugin/plugin.json` を退避。**root も skill も消えない**（負の対照が取れない＝ SC-2） |
| `ac3-validator-before.log` | Codex 公式 validator（マニフェスト不在）: rc=1 `missing .codex-plugin/plugin.json` |
| `ac3-validator-after.log` | 同 validator（マニフェスト追加後）: rc=1。**エラーが別クラスへ移動**した（下記「AC-3 未達の理由」） |
| `ac5-status-real-home-before.log` | 修正前スクリプトを実 `~/.codex` で実行 → `registered: YES`（**false green**）※ このログは `/tmp` に展開した複製から実行したため `repo manifest:` 行の値は無効。判定対象は `registered:` 行のみ |
| `ac5-status-real-home-after.log` | 修正後 → `registered: NO` + 導入コマンド案内。`codex plugin list` の ground truth（`not installed`）と一致 |
| `ac5-status-installed-home-after.log` | 実際に install 済みの隔離 `CODEX_HOME` に対して → `registered: YES` + plugin root（正側も動くことの実証） |
| `run-tests.log` | `sh tests/run-tests.sh` の全出力 |

## 隔離手順（AC-1 / AC-2 で使用）

`scripts` はリポジトリに置いていない（一時ハーネス）。手順は各ログ冒頭の
`[probe]` 行に残している。

1. `CODEX_HOME` を temp に切る（ユーザーの `~/.codex` は一切変更しない）
2. marketplace root として `.claude-plugin/marketplace.json` + `plugin/plangate/` **だけ**を
   temp へ複製する（`.codex/skills` / `.agents/skills` を持ち込まない）
3. `codex plugin marketplace add <temp-src>` → `codex plugin add plangate@plangate`
4. **repo 外の空ディレクトリを cwd にして** `codex debug prompt-input`
   （repo-local root が混ざらない方を選択。混在出力からの判別ではない）
5. skill root 一覧（`r0`/`r1`/…）と `plangate:` skill 件数を抽出

`~/.agents/skills` は user root として残るが、PlanGate skill を 1 件も含まないため
（`ls ~/.agents/skills` で確認済み）対照として無害。

## AC-3 未達の理由（forbidden path）

マニフェスト追加で validator が **skill 階層まで降りるようになり**、
`plugin/plangate/skills/<name>/agents/openai.yaml` の
`icon_small` / `icon_large` = `./assets/plangate-small.svg` が
**skill root 相対で解決されて存在しない**（実体は plugin root の `assets/`）ため 35 skill × 2 件 = 70 error。

- validator は `..` を含むパスを拒否するため `../../assets/...` では解決できない
- 是正には `plugin/plangate/skills/**`（および生成元 `.agents/skills/**`）の変更が要るが、
  本作業の制約でこれらは **変更禁止**。よって AC-3 は本ブランチでは未達。
- なお **この 70 件は本ブランチが作った不具合ではなく、マニフェスト不在で
  validator が bail out していたため見えていなかった既存の状態**。

## 誤起票の根本原因（PR 前レビュー major / 2 巡目で是正）

`README.md` の Codex セクションが **「`marketplace add` で marketplace を登録します」で終わっていた**（`codex plugin add` への言及はリポジトリ全体の利用者向け `.md` に 0 件）。
このとおり導入すると **「marketplace add 済み・plugin 未 install」** に着地し、
まさに本 issue の false green の原因だった状態になる。#1085 の誤起票もこの記述が出発点。

是正（本ブランチ）:

- `README.md`: `codex plugin add plangate@plangate` を追記。注記を「**`marketplace add` は marketplace 登録のみ。plugin のロードには `codex plugin add` が別途必要**」へ書き換え（「`plugin install` は無い」という否定で終わらせず、何をすればよいかを書く）。`install.sh --codex` は `codex plugin add` を実行しない旨も明記
- `docs/plangate-plugin-migration.md`: 3 箇所（Marketplace 1 コマンド節 / Codex CLI 対応節 / FAQ）を同様に是正

## 2 巡目で追加した検出（no-op / 空振りの封鎖）

| 指摘 | 是正 | 実証 |
|---|---|---|
| `release-prep.sh --check` が `.codex-plugin` を見ない | `check_manifest_parity` を `run_checks` に追加 | 正常系 rc=1（**baseline と同一**。既存 2 NG に由来し本追加は `OK`）/ codex 側を `9.9.9` に変異させると `NG: plugin マニフェスト不整合` を出す一方、旧 `check_versions` は `OK: plugin version 一致 (8.19.0)` のままだった＝片側だけ見る判定の実害を再現 |
| parity checker が「両方に無いフィールド」を一致扱い | 比較前に name/version/skills の必須検査（rc=2） | `ta-66` TC-09（両マニフェストから `skills` を削除 → rc=2） |
| 「installed != repo」NOTE 分岐が未 assert | `ta-31` TC-08 に NOTE の grep を追加 | 変異 2 種で kill 確認（下記） |

### 変異注入による kill 実証（`ta-31` TC-08）

1. **変数取り違え**: `printf ... "$_inst_ver" "$_repo_ver"` → `"$_repo_ver" "$_inst_ver"`
   → 出力が `NOTE: installed(8.19.0) != repo(9.9.9)`（左右反転）になり **TC-08 FAIL**
2. **条件反転**: `[ "$_inst_ver" != "$_repo_ver" ]` → `=`
   → NOTE 行が消え **TC-08 FAIL**

いずれも変異前後で他 TC は緑のまま＝この assert が当該分岐だけを捕捉している。変異はすべて revert 済み（`git diff scripts/check-codex-plugin-status.sh` が空）。

### テスト ID の改番

`tests/extras/ta-65-codex-plugin-manifest.sh` → **`ta-66-codex-plugin-manifest.sh`**。
別ブランチ `fix/1089-ho-bypass` が `tests/extras/ta-65-eh3-ho-task-context.sh` を先に origin へ push
済みのため（`git ls-tree -r origin/fix/1089-ho-bypass` で確認）、origin 先着側を正とした。
機能上の衝突は無い（loader は basename を test-id にする）が、「TA-65」がログ上で 2 つの別物を
指す状態を避ける。

## ドキュメントと実装の食い違い（validator が SSoT）

`references/plugin-json-spec.md` は top-level `hooks` をサンプルに載せているが、
`validate_plugin.py` は `hooks` を **未対応フィールドとして reject** する
（同ドキュメント末尾の「Plugin validation notes」も reject する旨を書いており、文書内で矛盾）。
本マニフェストは `hooks` を書いていない。

また `validate_plugin.py` は `interface.defaultPrompt`（または `default_prompt`）を
**必須**にしているが、実際に install 済みで動作している他 plugin
（`river-review` 1.76.1）のマニフェストには存在しない。**validator は loader より厳しい**。
