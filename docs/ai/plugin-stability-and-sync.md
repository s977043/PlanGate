# Plugin 安定性・バージョン同期・カスタマイズ API（正本）

> `plugin/plangate/` を消費側リポジトリで使うための **正本**。安定性保証
> レベル / バージョン同期メカニズム（release archive 方式）/ カスタマイズ
> API / 手動コピー版からの移行を規定する。
> 関連: [#224](https://github.com/s977043/plangate/issues/224) / TASK-0090 /
> [`../plangate-plugin-migration.md`](../plangate-plugin-migration.md) /
> [`versioning-stability-policy.md`](./versioning-stability-policy.md)（#225 / PR #263 マージ済・main 在席）/
> [`staged-adoption-guide.md`](../staged-adoption-guide.md)

## 1. Plugin 安定性宣言

`plugin/plangate/` 全体の安定性レベルは **Beta**。レベル定義（Stable=
breaking は major のみ・移行ガイド必須 / Beta=breaking を CHANGELOG
明記の上 minor 許容 / Experimental=互換保証なし）の正本は
[versioning-stability-policy.md](./versioning-stability-policy.md) §3
（#225 / PR #263 マージ済）。本節は同ポリシーが無い環境でも単独で
読めるよう内訳を自己完結で宣言する。

| Plugin コンポーネント | レベル | 互換契約 |
|----------------------|--------|---------|
| `.claude-plugin/plugin.json`（マニフェスト構造） | **Stable** | フィールド削除/必須化は major |
| `commands/`（`/pg-*` スラッシュコマンド名と引数） | **Beta** | コマンド削除/リネームは CHANGELOG `[BREAKING]` 明記の上 minor 可 |
| `agents/`（同梱エージェントの責務契約） | **Beta** | 責務の非互換変更は明記の上 minor 可 |
| `skills/`（同梱スキルの入出力契約） | **Beta** | 入出力の非互換変更は明記の上 minor 可 |
| `rules/`（同梱ルールの規範） | **Beta** | 規範強化は明記の上 minor 可 |
| `hooks/`（同梱フックの既定挙動） | **Stable** | 既定 block 化は major（[versioning §2.2](./versioning-stability-policy.md)）|

> Beta コンポーネントの非互換変更は **CHANGELOG に影響度タグ必須**
> （[versioning-stability-policy.md](./versioning-stability-policy.md) §4）。
> Plugin 全体が Stable に昇格した時点で本表は §3.1 厳格適用へ移行し
> CHANGELOG に `[STABILITY]` を記載する。

## 2. バージョン同期メカニズム（release archive 方式）

消費側が使用中の plugin バージョンを **固定・更新** する標準手段は
**GitHub Release アーカイブのバージョン固定取得** とする。Git submodule /
npm package は採用しない（消費側に submodule 運用 / npm 依存を新規強制
しないため。[versioning-stability-policy.md](./versioning-stability-policy.md)
§6 と整合）。

### 2.1 固定取得（pin）

```sh
# 消費側リポジトリで、特定リリースの plugin を固定取得する
PLANGATE_VERSION=v8.7.0   # 固定したいタグ
mkdir -p .plangate-plugin
curl -fsSL "https://github.com/s977043/plangate/archive/refs/tags/${PLANGATE_VERSION}.tar.gz" \
  | { rm -rf .plangate-plugin/* 2>/dev/null || true; tar -xz --strip-components=3 -C .plangate-plugin \
    "plangate-${PLANGATE_VERSION#v}/plugin/plangate"; }
echo "$PLANGATE_VERSION" > .plangate-plugin/.plangate-version
```

> **安全性**: 取得は必ず **固定タグ**（`refs/tags/<ver>`、可変ブランチ
> 不可）で行う。展開前に `curl -fsSL <url> | tar -tz` で対象パス
> （`plangate-<ver>/plugin/plangate/...` のみ）を確認し、想定外パスを
> 含むアーカイブは展開しない。リリースの signature / commit を併せて
> 確認できる場合は確認する。

- アーカイブ内パスは `plangate-<ver>/plugin/plangate/<kind>/...`。
  `--strip-components=3` で `plangate-<ver>` / `plugin` / `plangate` の
  3 段を除去し、`.plangate-plugin/<kind>/...`（§3/§4 の前提パス）に展開する。
- `.plangate-version` に固定タグを記録する（バージョン明示）。
- 取得元タグは [versioning-stability-policy.md](./versioning-stability-policy.md)
  §6 の「最新安定版ポインタ」を推奨（同一 major 内で互換）。

### 2.2 更新（update）

1. 更新先タグの CHANGELOG を確認し、影響度タグ（`[BREAKING]` /
   `[MIGRATION REQUIRED]` / `[SAFE UPDATE]`）を判定。
2. `[SAFE UPDATE]` のみなら §2.1 を新タグで再実行するだけ（§2.1 の
   取得は展開前に `.plangate-plugin/` を消去するため、旧版で削除された
   ファイルが残る ghost file は発生しない）。
3. `[BREAKING]` / `[MIGRATION REQUIRED]` を含む場合は CHANGELOG が指す
   移行手順（[versioning-stability-policy.md](./versioning-stability-policy.md)
   §5）に従ってから再取得する。
4. `.plangate-version` を更新後タグへ書き換え、コミットで固定する。

### 2.3 検証

バージョンは 2 軸で管理する。混同しないこと:

| 軸 | 記録先 | 形式 | 意味 |
|----|--------|------|------|
| PlanGate リリースタグ | `.plangate-plugin/.plangate-version` | `vX.Y.Z`（例 `v8.7.0`）| 取得元の PlanGate リリース。固定・更新の単位 |
| Plugin 内部バージョン | `.plangate-plugin/.claude-plugin/plugin.json` の `version` | `X.Y.Z`（例 `0.5.0`）| plugin パッケージ自身の版。情報用 |

- 導入側 CI での突合は **`.plangate-version`（リリースタグ）を真とし**、
  期待タグと一致するかを検証する（`plugin.json` の内部バージョンとは
  比較しない＝採番系列が異なるため）。
- 乖離検出の CI 実装は任意（本 PBI は手順正本まで）。

## 3. カスタマイズ API（overlay precedence）

消費側はエージェント / スキル / ルール / コマンドを **追加・上書き**
できる。上書き規約（overlay precedence）を以下に固定する。

### 3.1 優先順位

```
消費側 .claude/<kind>/<name>   >   .plangate-plugin/<kind>/<name>（plugin 同梱）
```

- 消費側 `.claude/` に **同名ファイル** を置くと plugin 同梱版を上書きする。
- 消費側 `.claude/` にしか無いファイルは **追加**（plugin を汚さない）。
- plugin 側ファイルは消費側で **直接編集しない**（更新で消える）。
  変更が必要なら同名ファイルを `.claude/` に置いて上書きする。

### 3.2 上書き可否境界

| 対象 | 上書き | 理由 |
|------|--------|------|
| `agents/` 個別エージェント | 可 | 責務を消費側都合で差し替え可 |
| `skills/` 個別スキル | 可 | 観点・手順を拡張可 |
| `commands/` `/pg-*` | 可（非推奨） | コマンド契約は揃える方が安全 |
| `rules/` 規範 | **追加のみ推奨** | 統制ルールの上書きはゲート無効化リスク |
| `hooks/` 強制フック | **不可** | 強制力の上書きは [responsibility-classes.md](https://github.com/s977043/plangate/blob/main/.claude/rules/responsibility-classes.md) の Workflow/CI-owned 境界を壊す |

> **`hooks/` は C-3 承認があっても overlay 上書き不可**（強制力の
> 上書きはゲートの決定論的強制を壊す）。フックの挙動を変える必要が
> ある場合は overlay ではなく upstream / plugin 更新、または
> `.claude/settings.json` 適用プロセス（人間適用）で扱う。
>
> **C-3 明示承認の例外は `rules/` の上書きのみ**に限定する。`rules/`
> 上書きも「ゲートを実質無効化」し得るため、行う場合は C-3 で人間が
> 明示承認した記録を要する（AI 自己完結禁止 ・
> [orchestrator-mode.md](https://github.com/s977043/plangate/blob/main/.claude/rules/orchestrator-mode.md) AI 自己完結禁止条項に準ずる）。

### 3.3 カスタマイズの記録

消費側は上書き / 追加した一覧を自リポジトリの `CLAUDE.md`（案件固有情報・
[hybrid-architecture.md](https://github.com/s977043/plangate/blob/main/.claude/rules/hybrid-architecture.md) Rule 4）に
記載し、plugin 更新時の差分確認の起点とする。

## 4. 手動コピー版からの移行

`.claude/commands/` 等を手動コピー/派生して運用している消費側
（ai-agent-template / growth-lab 等）向けの段階移行手順。

| Step | 内容 | 確認 |
|------|------|------|
| **Step 1: インストール** | §2.1 で `.plangate-plugin/` に固定取得 | `.plangate-version` 記録 |
| **Step 2: 差分確認** | 手動コピー版 `.claude/<kind>/` と `.plangate-plugin/<kind>/` を diff し、消費側独自変更を特定 | 独自変更の一覧化 |
| **Step 3: 重複削除** | plugin と同一内容のコピーを削除。独自変更分のみ `.claude/` に残す（§3.1 overlay で上書き継続） | plugin 経由で動作確認 |
| **Step 4: カスタマイズ設定** | 残した上書き一覧を消費側 `CLAUDE.md` に記録（§3.3） | 差分確認の起点確立 |

- 既存の段階移行（評価 → 部分 → 完全）の運用は
  [`plangate-plugin-migration.md`](../plangate-plugin-migration.md) が正本。
  本節はその **手動コピー起点** の具体手順を補完する。
- 急いで移行する必要はない（plugin と `.claude/` はデュアル運用可能）。

## 4-bis. versioning-stability-policy 参照（解決済）

本書は [`versioning-stability-policy.md`](./versioning-stability-policy.md)
（#225 / PR #263）を補強参照する。**PR #263 はマージ済**で当該ファイルは
main 在席のためリンクは解決済（安定性レベルの実体は §1 に自己完結記載）。

## 5. 関連

- [`../plangate-plugin-migration.md`](../plangate-plugin-migration.md) — 段階移行手順 / FAQ（正本）
- [`versioning-stability-policy.md`](./versioning-stability-policy.md) — 安定性レベル / 影響度タグ / LTS（§6 と整合）
- [`staged-adoption-guide.md`](../staged-adoption-guide.md) — 段階的導入（Phase 0-3）
- [hybrid-architecture.md](https://github.com/s977043/plangate/blob/main/.claude/rules/hybrid-architecture.md) — Rule 4（案件固有は CLAUDE.md）
- [#225](https://github.com/s977043/plangate/issues/225) / [#226](https://github.com/s977043/plangate/issues/226) — OSS 採用基盤（同系）
