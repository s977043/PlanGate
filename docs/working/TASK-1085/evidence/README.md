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

## ドキュメントと実装の食い違い（validator が SSoT）

`references/plugin-json-spec.md` は top-level `hooks` をサンプルに載せているが、
`validate_plugin.py` は `hooks` を **未対応フィールドとして reject** する
（同ドキュメント末尾の「Plugin validation notes」も reject する旨を書いており、文書内で矛盾）。
本マニフェストは `hooks` を書いていない。

また `validate_plugin.py` は `interface.defaultPrompt`（または `default_prompt`）を
**必須**にしているが、実際に install 済みで動作している他 plugin
（`river-review` 1.76.1）のマニフェストには存在しない。**validator は loader より厳しい**。
