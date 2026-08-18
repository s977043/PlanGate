# TEST CASES — TASK-1087 (#1087)

> **件数契約の禁止（AC-9）**: `46` / `7` を assert しない。
> `.claude/` と `plugin/` は運用で増減するため、
> 「true collision = 0」「stale = 0」「注入した違反が出力集合に含まれる」で契約する。

## 受入基準 → テストケース マッピング

| AC | TC |
|----|----|
| AC-1 | TC-E1 |
| AC-2 | TC-E2 |
| AC-3 | TC-C1 |
| AC-4 | TC-S1 |
| AC-5 | TC-C3 / TC-C4 / TC-C5 / TC-C6 |
| AC-6 | TC-S4 / TC-S5 |
| AC-7 | TC-E3 |
| AC-8 | TC-C7 |
| AC-9 | TC-M0 |
| AC-10 | TC-P1 |
| AC-11 | TC-M1 / TC-M2 |
| AC-12 | TC-D1 / TC-D2 |

---

## A. collisions — 本番経路（引数なし）

| ID | 前提 | 入力 | 期待 | 種別 |
|----|------|------|------|------|
| **TC-C1** | 本番ツリー | `python3 scripts/check-skill-name-collisions.py` | **rc=0**。出力に true collision が 0 件 | 自動 |
| **TC-C2** | 同上 | 同上 | ミラー対が **情報として印字される**（黙って消えない） | 自動 |

## B. collisions — 分類境界（サンドボックス / 既定経路で実行）

| ID | サンドボックス構成 | 期待 | 種別 |
|----|------------------|------|------|
| **TC-C3** | `.claude/skills/x/` + `plugin/p/skills/x/`（**root 内相対パス一致**） | **rc=0**（accepted mirror） | 自動 |
| **TC-C4** | `.claude/skills/x/` + `plugin/a/skills/x/` + `plugin/b/skills/x/`（**3 定義**） | **rc=1**（#692 の動機ケース） | 自動 |
| **TC-C5** | `plugin/a/skills/x/` + `plugin/b/skills/x/`（repo-local 無し） | **rc=1** | 自動 |
| **TC-C6** | `.claude/skills/foo/` と `plugin/p/skills/bar/` が**両方 `name: foo`**（非ミラー位置） | **rc=1** | 自動 |
| **TC-C7** | `.claude/skills/a/` と `.claude/skills/b/` が**両方 `name: x`**（**同一 root 重複**） | **rc=1**（現行は検出不能 = 検出力の追加） | 自動 |
| **TC-C8** | ミラー対だが **description が異なる** | **rc=0**（M-1: drift-check が担保） | 自動 |
| **TC-C9** | 定義が 1 つだけ（plugin only / repo-local only） | **rc=0**（多重定義ではない） | 自動 |

## C. stale — 本番経路

| ID | 前提 | 期待 | 種別 |
|----|------|------|------|
| **TC-S1** | 本番ツリー | `python3 scripts/check-stale-skill-refs.py` → **rc=0** | 自動 |
| **TC-S2** | `.claude/settings.json` が**存在しない**環境（CI 相当） | rc=0 | 自動 |
| **TC-S3** | `.claude/settings.json` が**存在する**環境（開発機相当） | rc=0（**環境非依存**であること） | 自動 |

## D. stale — 分類境界

| ID | 入力 | 期待 | 種別 |
|----|------|------|------|
| **TC-S4** | 実在しない `scripts/no-such-file-1087.py` への **通常の Markdown リンク** | **WARN される**（真の stale） | 自動 |
| **TC-S5** | 実在しない `docs/no-such-1087.md` への **インラインコード参照** | **WARN される** | 自動 |
| **TC-S6** | `` `[file.md](./file.md)` `` 形式（**コードスパン内のリンク記法**） | WARN されない（S-1） | 自動 |
| **TC-S7** | gitignore 対象パス（`.claude/settings.json`） | WARN されない（S-2） | 自動 |
| **TC-S8** | gitignore パターンに**合致しない** typo（`.claude/settingz.json`） | **WARN される**（除外が広すぎないことの実証） | 自動 |
| **TC-S9** | `git` が使えない環境 | **除外なしへ縮退**（= 現行挙動。crash しない） | 自動 |

## E. evidence / ドキュメント

| ID | 内容 | 期待 | 種別 |
|----|------|------|------|
| **TC-E1** | 46 件の全件分類 | `evidence/` に kind/name/判定理由が全件記載 | 手動 |
| **TC-E2** | 7 件の全件分類 | 同上 | 手動 |
| **TC-E3** | 見逃しクラス | M-1 / M-2 / S-1 / S-2 が docs と plan に明記 | 手動 |

## F. doctor 統合の回帰

| ID | 内容 | 期待 | 種別 |
|----|------|------|------|
| **TC-D1** | `ta-52` 相当のサンドボックスで doctor を実行 | rc 3 値契約（0=ok / 1=collision / その他=error）が不変 | 自動 |
| **TC-D2** | 検査スクリプト不在 | `ok=true` の skip（crash しない） | 自動 |

## G. 変異注入（AC-11 / diff-audit Phase 6 item 6）

> **変異は関数定義ではなく call site を壊す。**
> **レーン全体を落とす変異だけで済ませない** — レーン内部の分類を誤らせる変異を別に立てる。
> **空振りしたら正直に記録する。**

| ID | 系統 | 変異内容（call site） | 期待 |
|----|------|--------------------|------|
| **TC-M1** | **レーン全体** | 分類呼び出しの結果を `True` 固定にする（全部 accepted mirror 扱い） | TC-C4 / TC-C5 / TC-C6 / TC-C7 が **FAIL** |
| **TC-M2a** | **レーン内部** | ミラー条件から「**定義がちょうど 2 つ**」を落とす | **TC-C4** のみ FAIL（TC-C3 は PASS のまま） |
| **TC-M2b** | **レーン内部** | ミラー条件から「**root 内相対パス一致**」を落とす | **TC-C6** のみ FAIL |
| **TC-M2c** | **レーン内部** | ミラー条件から「**一方が repo-local**」を落とす | **TC-C5** のみ FAIL |
| **TC-M3** | **レーン内部（stale）** | gitignore 除外の call site を「**全て除外**」に壊す | **TC-S8** が FAIL |
| **TC-M4** | **レーン内部（stale）** | コードスパンマスクの call site を外す | **TC-S6** が FAIL（現行バグの再現 = 修正の必要性を実証） |
| **TC-M0** | — | 件数 assert が無いこと | `grep` で `46` / `7` の等値比較が TC に無い |

**本番経路の確認（diff-audit Phase 6 item 7）**:
TC-C3〜C9 / TC-S4〜S9 は **引数なしの既定経路**でスクリプトを起動する
（`--extra-root` 等のテスト専用引数に負側 TC を偏らせない）。
サンドボックスは `REPO_ROOT` ごと切り替えて既定経路を通す。

## H. CI 配線 patch

| ID | 内容 | 期待 | 種別 |
|----|------|------|------|
| **TC-P1** | `git apply --check docs/working/TASK-1087/ci-wiring.patch` | **rc=0** かつ **未適用**（`git status` に `.github/` の差分なし） | 自動 |
| **TC-P2** | patch の中身 | `claude plugin validate` 不在時に **job を失敗させる**（silently skip しない） | 手動 |

## エッジケース

- frontmatter 無しファイル → ファイル名から name を採る（現行挙動を維持）
- `README.md` は flat root で除外（現行挙動を維持）
- `plugin/` に複数 plugin がある場合 → repo-local + 2 plugin は **3 定義 = true collision**
- root 内相対パスは一致するが **kind が違う**（`command codex-mvp-split` と `skill codex-mvp-split`）
  → そもそも別グループ（`(kind, name)` キー）。衝突ではない
