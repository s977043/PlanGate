# TEST CASES — TASK-1115 (#1115)

すべて **PreToolUse JSON payload を stdin へ供給**して評価する
（`.claude/settings.json` からの本番呼び出しと同一経路。明示引数 / テスト専用 env に
偏らせない — diff-audit Phase 6 item 7）。

配置: `tests/extras/ta-25-approval-token-guard.sh`（既存 `t25_guard` ヘルパーを再利用）。

## 受入基準 → テストケース マッピング

| AC | 内容 | TC |
|----|------|----|
| AC-1 | redirect 先のファイル名 glob 崩しを block | T1115-TC-01 |
| AC-2 | 非 redirect レーン（cp / tee / sed -i）も block | T1115-TC-02 |
| AC-3 | 真の陽性を落とさない | 既存 T1023 / T1045 / T1110 全件 + T1115-TC-05 |
| AC-4 | #1110 の誤検出解消が戻っていない | 既存 T1110-TC-01/02 + T1115-TC-04 |
| AC-5 | 日常 glob コマンドを誤 block しない | T1115-TC-03 |
| AC-6 | 変異で検出力実証 | T1115-M-7〜M-11 |

## テストケース一覧

### T1115-TC-01: redirect 先の glob 崩しを block（AC-1）

| 項目 | 内容 |
|------|------|
| 前提 | EH-13、bypass なし |
| 入力 | `echo x > docs/working/TASK-0001/approvals/c3.jso*` / `...c3.js?n` / `...c[3].jso*` / `...x9.jso*` |
| 期待 | すべて **rc=2** |
| 種別 | 自動（M-7 / M-8 / M-9 の kill 対象） |

### T1115-TC-02: 非 redirect レーンの glob 崩しを block（AC-2）

| 項目 | 内容 |
|------|------|
| 入力 | `cp /tmp/x <approvals>/c3.jso*` / `printf x \| tee <approvals>/c3.jso*` / `sed -i '' -e 's/a/b/' <approvals>/c3.jso*` / `echo x > docs/working/_maintenance/maintenance.jso*` / `tee <approvals>/parent-integration.js?n` |
| 期待 | すべて **rc=2** |
| 種別 | 自動（M-7 / M-9 の kill 対象） |

### T1115-TC-03: 日常 glob コマンドを誤 block しない（AC-5 / 負側）

| 項目 | 内容 |
|------|------|
| 入力 | `cp schemas/*.json /tmp/` / `cp docs/*.md /tmp/` / `sed -i.bak -e 's/a/b/' docs/working/*/status.md` / `sed -i '' -e 's/a/b/' docs/working/*/approvals-notes.md` / `cp /tmp/x docs/working/*/approvals/notes.md` |
| 期待 | すべて **rc=0** |
| 種別 | 自動（**M-10 = 先頭 glob ガード除去 の kill 対象**） |

### T1115-TC-04: #1110 の誤検出解消が維持されている（AC-4 / 負側）

| 項目 | 内容 |
|------|------|
| 入力 | `git commit -m 'docs: <TOKEN>' > /tmp/log.txt`（glob なし）／ `git commit -m 'docs: <approvals>/c3.jso* handling' > /tmp/log.txt`（**glob 語 + 無関係な redirect**） |
| 期待 | 両方 **rc=0** |
| 種別 | 自動。2 件目は「glob 語検出だけでは block しない＝書き込み意図との AND を維持」の対照 |

### T1115-TC-05: 読み取りは block しない（AC-3 / 負側）

| 項目 | 内容 |
|------|------|
| 入力 | `cat docs/working/*/approvals/*.json` / `ls docs/working/*/approvals/` |
| 期待 | **rc=0** |
| 種別 | 自動（`_has_write_intent` との AND が保たれていることの確認） |

### T1115-TC-06: block 詳細に glob 候補語が出る

| 項目 | 内容 |
|------|------|
| 入力 | `cp /tmp/x docs/working/TASK-0001/approvals/c3.jso*` |
| 期待 | rc=2 かつ stderr に `glob_candidate=` を含む |
| 種別 | 自動 |

### T1115-TC-07: ディレクトリ側 glob の既存挙動が不変（回帰）

| 項目 | 内容 |
|------|------|
| 入力 | `echo x > docs/working/*/approvals/c3.json` / `echo x > <approvals>/*.json` / `echo x > <approvals>/c[3].json` |
| 期待 | **rc=2**（是正前と同じ） |
| 種別 | 自動 |

## 変異注入（AC-6）

| ID | 変異（**call site を壊す**） | 分類 | kill 対象 TC |
|----|------------------------------|------|--------------|
| M-7 | `_cmd_may_target_token` 呼び出しを `_is_token_path` に戻す | **レーン全体** | T1115-TC-01 |
| M-8 | ルール (A) approvals-dir の `case` を never-match に | **レーン内部の分類** | T1115-TC-01（`x9.jso*` のみが該当する語） |
| M-9 | ルール (B) basename-glob の照合ループを無効化 | **レーン内部の分類** | T1115-TC-02（`maintenance.jso*` が非 approvals パス） |
| M-10 | 先頭 glob ガード（`'*'*` 等 → return 1）を除去 | **レーン内部の分類 / 誤検出方向** | T1115-TC-03（`cp schemas/*.json`） |
| M-11 | basename 抽出 `${w##*/}` を語全体に変更 | **レーン内部の分類** | T1115-TC-02 |

- M-7 だけではレーン内部の分類ミスを検出できないため M-8〜M-11 を別に立てる。
- M-10 は **block を広げる方向**の変異で、負側 TC でしか殺せない
  （正側 TC だけでは原理的に検出不能）。

## エッジケース（実測: `evidence/edge-cases.txt`）

| ケース | 期待 | 実測 | 備考 |
|--------|------|------|------|
| `cp /tmp/x docs/working/*/approvals/notes.md` | rc=0 | rc=0 | (A) は basename に glob があるときのみ |
| `sed -i.bak … docs/working/*/approvals-notes.md` | rc=0 | rc=0 | `approvals/` を含まない |
| `cp /tmp/x foo/c3.jso*` | rc=2 | rc=2 | approvals 外でもルール (B) が拾う |
| `echo x > <approvals>/"c3.jso"*` | rc=2 | rc=2 | 混在引用は引用除去版の照合で閉じる |
| `echo "<div>*</div>" > /tmp/a.html` | rc=0 | rc=0 | 引用文中の `>` + `*` は誤 block しない（無条件 block 案なら落ちる） |
| `echo "-> *bold*" > /tmp/b.md` | rc=0 | rc=0 | 同上 |
| `git commit -m 'note about approvals/x9.jso* handling'` | rc=0 | rc=0 | 書き込み意図との AND が維持されている |
| `cp x foo/*3.json` | rc=0 | rc=0 | **残存クラス**（先頭 glob 除外のトレードオフ / plan に明記） |
| `OUT=c3.jso* cp /tmp/x $OUT` | rc=0 | rc=0 | **残存クラス**（変数代入語） |
| `rm <approvals>/*.json` | rc=0 | rc=0 | **既存ギャップ**（`rm` は `_has_write_intent` に無い / 本 PBI 範囲外） |
