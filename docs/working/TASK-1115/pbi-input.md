# PBI INPUT PACKAGE — TASK-1115 (#1115)

## Context / Why

EH-13（承認トークン書き込みガード / `scripts/check-approval-token-write.sh`）の
Bash レーンは、外側ゲートで `_is_token_path "$_cmd"`（**コマンド文字列全体**が
保護パターンに glob マッチするか）を評価し、真のときだけ `_has_write_intent` に
進む。

`_is_token_path` は「保護パターン（`*c3.json*` 等）で **リテラル文字列**を照合する」
判定なので、**照合される側（コマンド）にワイルドカードが入って保護対象の
ファイル名リテラルを途中で崩す**と、文字列一致が外れて外側ゲートごと素通りする。

```text
_is_token_path("... approvals/c3.json")  → *c3.json* に一致 → block
_is_token_path("... approvals/c3.jso*")  → どのパターンにも不一致 → ゲート素通り
```

#1101（HO が `bin/../bin/plangate` で迂回できる）と**同クラス**＝
**正規化対象にワイルドカードが入っていない**。

### 実測（本 PBI 着手時 / `origin/main` = `17cd044`）

`hook_event_name=PreToolUse` / `tool_name=Bash` の PreToolUse payload を stdin に
供給し、rc を測定（本番経路と同一）。

| # | コマンド | 期待 | 実測（是正前） |
|---|----------|------|----------------|
| G1 | `echo x > docs/working/TASK-9999/approvals/c3.json` | rc=2 | rc=2 |
| G2 | `echo x > docs/working/TASK-9999/approvals/c3.jso*` | rc=2 | **rc=0 素通り** |
| G3 | `echo x > docs/working/TASK-9999/approvals/c3.js?n` | rc=2 | **rc=0 素通り** |
| G4 | `echo x > docs/working/*/approvals/c3.json` | rc=2 | rc=2 |
| G5 | `echo x > docs/working/TASK-9999/approvals/*.json` | rc=2 | rc=2 |
| G6 | `echo x > docs/working/TASK-9999/approvals/c[3].json` | rc=2 | rc=2 |

規則性: **glob が保護対象のファイル名リテラルを途中で崩すと照合が外れる**
（ディレクトリ側の glob は末尾 `.json` / `c3.json` リテラルが残るので生き残る）。

### 追加実測 1: redirect レーンだけの問題ではない（オーガナイザー指示の「全数確認」）

外側ゲートが素通りするため、**引数解析を持つ他レーン（copy-like / inplace-edit）も
同型に素通り**する。

| コマンド | 期待 | 実測（是正前） |
|----------|------|----------------|
| `cp /tmp/x docs/working/TASK-9999/approvals/c3.jso*` | rc=2 | **rc=0** |
| `printf x \| tee docs/working/TASK-9999/approvals/c3.jso*` | rc=2 | **rc=0** |
| `sed -i '' -e 's/a/b/' docs/working/TASK-9999/approvals/c3.jso*` | rc=2 | **rc=0** |
| `echo x > docs/working/_maintenance/maintenance.jso*` | rc=2 | **rc=0** |
| `tee docs/working/TASK-1/approvals/parent-c3.jso*` | rc=2 | **rc=0** |
| `tee docs/working/TASK-1/approvals/parent-integration.js?n` | rc=2 | **rc=0** |
| `echo x > docs/working/TASK-9999/approvals/c[3].jso*` | rc=2 | **rc=0** |

### 追加実測 2: 実際に上書きが成立するか（中立名 `tok/x9.json` で測定）

**トークンパスには一切書き込まず**、中立名で shell の展開挙動のみ測定した。

| shell | `cp src tok/x9.jso*` | `tee tok/x9.jso*` | `> tok/x9.jso*` |
|-------|----------------------|-------------------|------------------|
| bash | **上書き** | **上書き** | **上書き** |
| zsh | **上書き** | **上書き** | **上書き** |
| sh (macOS) | **上書き** | **上書き** | リテラル名を作成（不成立） |
| dash | **上書き** | **上書き** | リテラル名を作成（不成立） |

**引数レーン（`cp` / `tee` 等）の bypass は shell 非依存で成立する**
（引数の pathname expansion は POSIX 必須）。redirect レーンのみ bash/zsh 限定。
Claude Code の Bash ツールは zsh を使う環境があるため live。

## What (Scope)

### In scope

- 外側ゲートを **「コマンド中に、展開後トークンパスになりうる glob 語があるか」**
  まで拡張する（`_cmd_may_target_token`）。これにより redirect / copy-like /
  inplace-edit / line-editor / git-restore の**全レーン**が同時に閉じる。
- リダイレクト先にワイルドカードが含まれる場合は fail-closed で block
  （`_redirect_writes_token` の既存 glob 分岐が発火するようになる）。
- `ta-25` に glob bypass の TC（`c3.jso*` / `c3.js?n` / `c[3].jso*` /
  非 redirect レーン / 誤検出の負側）を追加。
- 変異注入で検出力を実証（レーン全体 / レーン内部の分類の両方）。

### Out of scope

- HO 側の正規化（**#1101**。同クラスだが別実装 `scripts/hooks/check-plan-hash.sh`）
- `&>` / `&>>` の相関判定（#1110 で意図的に据え置き）
- `rm` / `mv` 先頭引数など「書き込み意図」検出そのものの拡張
- 文字列連結による回避（`open("...c3.jso"+"n","w")` 等）＝別クラス

## 受入基準

- **AC-1**: `c3.jso*` / `c3.js?n` / `c[3].jso*` のようにファイル名リテラルを
  glob で崩したリダイレクト先が rc=2 で block される。
- **AC-2**: 同型の崩しが `cp` / `tee` / `sed -i` 等の非 redirect レーンでも
  rc=2 で block される。
- **AC-3**: 真の陽性（既存 `ta-25` 全 TC）を 1 件も落とさない。
- **AC-4**: #1110 が解消した誤検出（`git commit -m 'docs: <TOKEN>' > /tmp/log.txt`
  が rc=0）が戻っていない。
- **AC-5**: block を広げる方向の誤検出が実測で限定的であること
  （`cp schemas/*.json /tmp/` 等の日常 glob コマンドが rc=0 のまま）。
- **AC-6**: 変異注入で、レーン全体を落とす変異と**レーン内部の分類を誤らせる
  変異**の双方が実 TC で kill される（空振りは正直に記録）。

## Notes from Refinement

- 「先が保護対象に一致しうるか」の一般判定は困難だが、**無条件 block は
  誤検出が大きすぎる**（`cp schemas/*.json dst/` まで落ちる）ため、
  「approvals ディレクトリ配下でファイル名が glob」「ファイル名 glob が
  保護 basename に**パターンとして**一致し、かつ先頭が glob でない」の
  2 条件に絞る（下記 plan §判定設計）。
- 照合方向を逆転させる（保護リテラルを subject、候補語を pattern に置く）のが
  本質的な是正。`case "c3.json" in c3.jso*)` は一致する。

## Estimation Evidence

### Risks

- **R-1**: block を広げるため誤検出が増える。→ 実測表で影響範囲を確定し、
  先頭 glob（`*.json`）を照合対象から外すことで日常 glob を保護する。
- **R-2**: 既存 TC の期待値反転が必要になる可能性。→ 実測の結果 **反転は 0 件**
  （新規 block はすべて現状 rc=0 の bypass ケース）。
- **R-3**: `case` のパターンに変数展開を使うため、語中の `|` が
  パターン区切りと誤解される shell 差異。→ パターンごとに `case` を分ける。

### Unknowns

- 引用混在（`"c3.jso"*`）は shell が glob 展開するが静的抽出では引用が残る。
  → basename から引用符を除去した形でも照合する（保守的側）。

### Assumptions

- 保護 basename は `_is_token_path` の 4 リテラル
  （`maintenance.json` / `c3.json` / `parent-c3.json` / `parent-integration.json`）
  と `*/approvals/*.json` に閉じている。
