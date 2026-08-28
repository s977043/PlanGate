# #1135 patch — AI-owned レーンを EH-3 の no-task 経路へ接続（**Human 適用**）

> 対象: `scripts/hooks/check-plan-hash.sh`（**Hardening Override 対象**）/ `.claude/rules/`（新規正本・**HO 対象**）
> 測定基点: `origin/main` = `5ad3191` / 2026-08-18
> 責務: **設計・差分・変異注入の設計は AI-owned（本書）/ 適用は Human-owned**

## 結論先行

**承認境界のパス集合は変更しません。** 変えるのは **「no-task セッションで `.md` 以外を一律 block している」判定 1 箇所**だけです。

### ⚠️ ただし本 patch には **#1101 への強い依存**があります（RiverReview で critical 検出）

**現 main には既に `..` を含むパスで HO を迂回できる穴があります（#1101 が起票済み）。** 実測:

```
rc=2  CLAUDE.md                                                   HARDENING_OVERRIDE
rc=0  docs/working/templates/../../../CLAUDE.md                   DOC_LIGHT_SKIP  ← 迂回
rc=2  .claude/rules/mode-classification.md                        HARDENING_OVERRIDE
rc=0  docs/working/templates/../../../.claude/rules/mode-classification.md  ← 迂回
```

`_norm_target` の正規化は **`./` 除去と `$REPO_ROOT/` 除去の 2 つだけ**で、**`..` を畳みません**（実装で確認）。

**本 patch を traversal ガードなしで適用すると、この穴が `.md` 限定から全拡張子へ拡大し、`scripts/hooks/check-plan-hash.sh` 自身と承認トークンへ到達します。**

```
tests/extras/../../scripts/hooks/check-plan-hash.sh        → レーンに一致（ガード本体）
docs/working/templates/../TASK-9999/approvals/…            → レーンに一致（承認トークン）
docs/working/templates/../../_maintenance/…                → レーンに一致
```

→ **差分 0（traversal fail-closed）を必須の前提として本 patch に含めます。これが無い適用は行わないでください。**

> **「HO 判定が前段にあるから安全」は誤りでした。** 前段にあることは HO 判定が**完全**であることを意味しません。当初本書に書いた「レーンが HO を弱めることは構造的に起こらない」という記述を**撤回します**。

## 実測（現 main で再現）

```
rc=0  docs/ai/hook-enforcement.md            DOC_LIGHT_SKIP: non-HO .md
rc=2  docs/working/templates/plan.md         BLOCK: plan.md edited without TASK  ← テンプレート
rc=2  docs/working/TASK-9999/plan.md         BLOCK: plan.md edited without TASK  ← 正しい
rc=2  tests/extras/ta-09-metrics.sh          SKIP 拒否: SKIP_REASON 未設定       ← テストコード
rc=2  scripts/lib/foo.sh                     SKIP 拒否: SKIP_REASON 未設定
rc=2  scripts/x.txt                          SKIP 拒否: SKIP_REASON 未設定
rc=2  .claude/rules/mode-classification.md   HARDENING_OVERRIDE                  ← 正しい
rc=2  CLAUDE.md                              HARDENING_OVERRIDE                  ← 正しい
```

**判定軸が「承認境界かどうか」ではなく「`.md` かどうか」**になっています。

### 重要: **HO 判定は no-task 分岐より前**にある（#1089 で移動済み）

`.claude/rules/mode-classification.md` が `DOC_LIGHT_SKIP` ではなく `HARDENING_OVERRIDE` で落ちることが実測で確認できます。

→ レーン判定は HO 判定の**後段**にしか置けません。**この順序は変更しません。**

> ⚠️ **ただしこれは「安全である」ことを意味しません。** 前段にあることは HO 判定が**完全**であることを意味せず、実際に `..` を含むパスは HO 判定を素通りします（冒頭の実測 / #1101）。**順序だけを根拠に安全性を主張しないでください。**

## 実害（#1092 の 1 セッションで観測）

| 区分 | 件数 |
|---|---:|
| `.md` で完結し main まで到達 | **7 issue** |
| **`.sh` / `.py` を要し patch 提示に留まった** | **11 issue** |

**とくに以下は承認境界と無関係です**（テストコード）:

`#1021`（`ta-09`）/ `#947`（`ta-42` / `ta-54`）/ `#1044`（`tests/extras/*.sh` ×16・**plan は APPROVED 済**）/ `#921`（`tests/extras/*.sh` ×45）

さらに **#1018** は `docs/working/templates/plan.md:73` の**見出し 1 行**の修正ですが、**basename が `plan.md` なので block** されます。

---

## 差分

### 0. **traversal を fail-closed で弾く（必須・前提）**

レーン判定に先立って、`..` と `//` を含むパスを**レーンから除外**します。

```sh
    # ===== #1135 / #1101: traversal fail-closed =====
    # _norm_target は ./ 除去と $REPO_ROOT/ 除去しか行わず `..` を畳まない。
    # `..` を含むパスは HO 判定を素通りしうるため、レーンの対象から外して
    # SKIP_REASON 要求へ落とす（安全側）。
    _trav=0
    case "/$_norm_target/" in
      */../*|*//*) _trav=1 ;;
    esac
```

**実測（本ガードの効果）**:

```
LANE(rc=0)        tests/extras/ta-09-metrics.sh                     ← 正常系は通る
LANE(rc=0)        docs/working/templates/plan.md                    ← 正常系は通る
LANE(rc=0)        tests/extras/ta-65-eh3-ho-task-context.sh         ← 誤検出なし
BLOCK(traversal)  tests/extras/../../scripts/hooks/check-plan-hash.sh
BLOCK(traversal)  docs/working/templates/../../../CLAUDE.md
BLOCK(traversal)  docs/working/templates/../TASK-9999/approvals/…
BLOCK(traversal)  docs/working/templates//..//../.claude/settings.json
BLOCK(traversal)  docs/working/templates/../TASK-9999/plan.md/       ← 末尾スラッシュ形も閉じる
GRAY(SKIP_REASON) scripts/lib/foo.sh                                 ← Gray は不変
```

> ⚠️ **doc-light（`.md`）側にも `_trav` を適用するかは Human 判断です。** 適用すると `docs/x/../y.md` が rc=0 → rc=2 に変わり、**これは #1101 の是正そのもの**になります。レーン側にのみ適用して **`.md` の HO 迂回は #1101 に残す**選択も可能ですが、**その場合 `.md` 経由の HO 迂回は開いたままです**。

### 1. `plan.md` ガードをディレクトリ限定にする

**現行**（no-task 分岐の冒頭）:

```sh
  _tf_lc=$(printf '%s' "$target_file" | sed 's/[[:space:]]*$//' | tr 'A-Z' 'a-z')
  case "$_tf_lc" in
    */plan.md|plan.md)
      reason="plan.md edited without TASK context (EH-3 bypass guard): $target_file"
```

**是正案** — **`_norm_target` の完全一致**で except する:

```sh
  _tf_lc=$(printf '%s' "$target_file" | sed 's/[[:space:]]*$//' | tr 'A-Z' 'a-z')
  case "$_tf_lc" in
    */plan.md|plan.md)
      # AI-owned: テンプレートは承認成果物ではない（#1135 / #1018）
      #   _norm_target は (i) の正規化で ./ 除去・REPO_ROOT 除去済み（#1089）。
      #   完全一致で判定し、任意の前置きを許さない。
      #   HO 判定は本分岐より前で評価済みなので、この except が HO を弱めることはない。
      case "$_norm_target" in
        docs/working/templates/plan.md) : ;;   # 通す（後段の doc-light で SKIP）
        *)
          reason="plan.md edited without TASK context (EH-3 bypass guard): $target_file"
          log_event "VIOLATION" "$reason"
          printf '[Hook EH-3] BLOCK: plan.md edited without TASK context.\n' >&2
          printf '  target: %s\n' "$target_file" >&2
          printf '  Set PLANGATE_HOOK_TASK=TASK-XXXX to allow plan.md edits.\n' >&2
          exit 2
          ;;
      esac
      ;;
  esac
```

### ⚠️ この形にした理由 — **`*/…` の glob は過剰一致します**

当初 `*/docs/working/templates/plan.md` という except パターンを設計しましたが、**実測で過剰一致を確認しました**:

```
evil/docs/working/templates/plan.md        -> ❌ except（通ってしまう）
vendor/x/docs/working/templates/plan.md    -> ❌ except（通ってしまう）
```

**`*` は任意の前置きに一致する**ため、**リポジトリ内のどこかに `docs/working/templates/plan.md` という並びを作れば `plan.md` ガードを迂回できます**。

`_norm_target` の**完全一致**なら:

```
evil/docs/working/templates/plan.md        -> block  ✅
docs/working/templates/plan.md             -> except ✅
docs/working/TASK-9/plan.md                -> block  ✅
```

> **`case` は先勝ちです**（実測確認済み）。except を `*/plan.md` の**後ろ**に書くと**一切効きません**。上の構造は外側 `case` で `plan.md` 全体を捕まえ、**内側で `_norm_target` を完全一致判定**することで順序事故を防いでいます。

> **`_tf_lc` は小文字化済み**ですが **`_norm_target` は小文字化されていません**。`docs/working/Templates/plan.md` は except に落ちず block されます（**安全側**）。大小文字非区別の環境で except を広げたい場合は別途判断が必要です。

### 2. AI-owned レーンを doc-light の隣に追加

**現行**（doc-light 判定）:

```sh
    _dl_ext=$(printf '%s' "$_norm_target" | sed 's/.*\.//; y/ABC.../abc.../')
    if [ "$_dl_ext" = "md" ]; then
      ... DOC_LIGHT_SKIP ... exit 0
    fi
```

**是正案** — `.md` の隣に**明示 allowlist** を足す:

```sh
    _dl_ext=$(printf '%s' "$_norm_target" | sed 's/.*\.//; y/ABC.../abc.../')

    # ===== #1135: AI-owned レーン =====
    # 承認境界（HO 9 カテゴリ / 承認トークン / merge）は含めない。
    # HO 判定は本分岐より前で評価済み（#1089）＝ここに到達した時点で非 HO。
    # allowlist であって bypass ではない（列挙外は従来どおり SKIP_REASON 必須）。
    _ai_lane=0
    case "$_norm_target" in
      tests/extras/*.sh)            _ai_lane=1 ;;   # テストコードは承認境界ではない
      docs/working/templates/*)     _ai_lane=1 ;;   # テンプレートは承認成果物ではない
    esac

    [ "$_trav" = "1" ] && _ai_lane=0    # traversal はレーン対象外（差分 0）

    if [ "$_dl_ext" = "md" ] || [ "$_ai_lane" = "1" ]; then
      _dlog_dl="$WORKING_DIR/_audit/skip-decision-log.jsonl"
      mkdir -p "$(dirname "$_dlog_dl")"
      _ts_dl=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
      # JSON エスケープは同ファイルの EH-3_SKIP 経路と同じ形へ揃える。
      # tr -d だけでは " と \ を素通しし、ログ行が不正 JSONL になる。
      _esc_dl=$(printf '%s' "${_norm_target:-unknown}" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r\t')
      # レーン判定の根拠を記録に残す（監査で「なぜ通ったか」を追える）
      if [ "$_ai_lane" = "1" ]; then _ev="EH-3_AI_LANE_SKIP"; else _ev="EH-3_DOC_LIGHT_SKIP"; fi
      printf '{"ts":"%s","event":"%s","target":"%s","acknowledged_by":null,"acknowledged_at":null}\n' \
        "$_ts_dl" "$_ev" "$_esc_dl" >>"$_dlog_dl"
      reason="${_ev}: non-HO target (${_norm_target:-unknown}) -- auto-skipped"
      log_event "$_ev" "$reason"
      printf '[Hook EH-3 %s] %s\n' "$_ev" "$reason"
      exit 0
    fi
```

**`skip-decision-log.jsonl` の event を分ける**ことで、**「doc-light で通ったのか AI-owned レーンで通ったのか」が監査で区別できます**。同じ event 名にすると、レーン導入の影響を後から測れません。

> ⚠️ **ただし「監査で追える」と「ゲートで止まる」は別です。** `scripts/check-skip-acknowledged.sh` が未追認検査の対象にしているのは **`EH-3_SKIP` のみ**で、`EH-3_DOC_LIGHT_SKIP` も新設の `EH-3_AI_LANE_SKIP` も **CI の追認対象外**です。**レーン経由の skip は 1 件も CI に上がりません。** 追認対象へ含めるかは Human 判断項目として残します。

> ⚠️ **`_esc_dl` のエスケープが不十分です（既存実装の踏襲）。** 現行の `tr -d '\n\r\t'` は `"` と `\` を素通しするため、**パス名に `"` を含めると監査ログ行が不正 JSONL になり、`check-skip-acknowledged.sh` が `JSONDecodeError` で無言 skip します**（＝監査が fail-open）。同ファイルの `EH-3_SKIP` 経路（`sed 's/\\/\\\\/g; s/"/\\"/g'`）と同じ形へ揃えてください。**`.md` 限定だった注入面が全拡張子へ広がるため、本 patch では必須です。**

### 3. `.claude/rules/ai-owned-lane.md`（新規正本）

**レーン定義の正本を 1 箇所に置き、hook はそれを実装する**形にします（他ドキュメントは参照のみ・再定義しない）。

```markdown
# AI-owned レーン（正本 / #1135）

> 本正本は **承認境界を変更しない**。[`responsibility-classes.md`](./responsibility-classes.md)
> の 4 分類のうち **AI-owned の具体範囲**を定義する。

## 3 帯

| 帯 | 範囲 | no-task セッションでの扱い |
|---|---|---|
| **AI-owned** | `docs/**/*.md`（アーカイブ除く）/ `docs/working/TASK-*/**`（`plan.md` 除く）/ **`docs/working/templates/**`** / **`tests/extras/*.sh`** | 書ける（rc=0） |
| **Human-owned** | **HO 9 カテゴリ**（[`mode-classification.md`](./mode-classification.md) の承認境界パス）/ 承認トークン（`approvals/*.json` / `maintenance.json`）/ **merge** | **常時 block（変更なし）** |
| **Gray** | 上記以外すべて（`scripts/` 本体 / `bin/` / `schemas/` / `.github/` …） | `SKIP_REASON` または maintenance 承認が必要（**変更なし**） |

## 不変条件

1. **AI-owned への追加は allowlist であって bypass ではない。** 列挙外は Gray のまま
2. **HO 判定はレーン判定より前**（`check-plan-hash.sh` / #1089）。レーンが HO を弱めることは構造的に起こらない
3. **`docs/working/TASK-*/plan.md` は引き続き block。** テンプレートのみ except
4. **判定不能なら Gray**（安全側。[`working-context.md`](./working-context.md) AC-8 と一貫）
```

---

## ⚠️ 本 patch の中心論点 — **`tests/extras/*.sh` を開けてよいか**

**テストコードは「承認境界」ではありませんが「検証の土台」です。**

> **壊れたテストを AI が書けば、緑が意味を失います。**

これは抽象的な懸念ではありません。**本セッションだけで、AI が書いた検査が実際に別のものを測っていた事例が 2 件あります**:

| 事例 | 内容 |
|---|---|
| #960 再発防止検査 | **防ぐはずの退行を変異注入で検出できなかった**（同一行に `C-2` の数字が並ぶ文体で近接判定が壊れる） |
| #963 の照合 | 「壊れた参照 3 件」と判定したが、**3 件とも意図的な「削除済み」明記**だった |

**対抗策として AC-6（変異注入で検出力を実証）を必須にしています。** それでも「AI が自分のテストを甘くする」余地は残るため、**この帯を開けるかどうかは Human の判断**です。

### 段階導入の選択肢

| 案 | 範囲 | リスク |
|---|---|---|
| **A. 一括** | 差分 0+1+2 全部 | 最大。塞がっている 12 issue が一度に動く |
| **B. 差分 0 + 差分 1 のみ**（**推奨**） | traversal ガード + `plan.md` の except | **最小**。#1018 の 1 行修正が通り、レーン機構を実地検証できる |
| C. 差分 0 + 差分 2 の `tests/extras` のみ | テストコード帯 | 中。**検証の土台を先に開けることになる** |

**B を推奨します。** ただし**当初の案 B 定義を訂正**しました。

**`docs/working/templates/` の非 `.md` ファイルは `evidence-tdd-ledger.json` の 1 件だけ**で、他はすべて `.md` ＝ **既に doc-light で通っています**。つまり **差分 2 の `docs/working/templates/*` エントリは実利がほぼ無く、traversal の攻撃面を足すだけ**でした。**#1018（`templates/plan.md` の 1 行修正）は差分 1 だけで満たせます。**

### ⚠️ 案 A / C を採るなら — **開放対象に EH-3 自身のガードテストが含まれます**

`tests/extras/*.sh` のうち **10 本が `check-plan-hash.sh` を検査**しています:

```
ta-10-doctor-fix.sh          ta-11-plan-hash-contract.sh   ta-12-maintenance.sh
ta-15-codex-hook-bridge.sh   ta-20-codex-review.sh         ta-39-eh3-doc-light.sh
ta-45-c3-mode-config.sh      ta-59-apply-settings-merge.sh ta-61-extra-contract.sh
ta-65-eh3-ho-task-context.sh
```

**とくに `ta-65-eh3-ho-task-context.sh` は #1089（HO 迂回）の再発検知そのもの**で、「全 HO カテゴリが同一挙動」を表明する唯一のテストです。

**AI がこれらの期待値を緩めれば、#1089 と同型の退行が再び無検出になります。** AC-6（変異注入）は「**新規**テストの検出力」を証明する規律であって、「**既存**テストが弱められていないこと」は証明しません。

→ **案 A / C を採る場合は `tests/extras/ta-{10,11,12,15,20,39,45,59,61,65}-*.sh` をレーンから控除する**ことを併せて検討してください。

---

## 検証（適用後に必須）

### 1. 退行なし（**HO が弱まっていないこと**）

> ⚠️ **rc だけを見てはいけません。** 当初本書に書いた「rc=2 を確認する」検証は、**HO block と SKIP_REASON block を区別しません**。実測で、**`scripts/hooks/*.sh` の HO case を丸ごと削除しても 10 件中 5 件は rc=2 のまま**でした（非 `.md` は doc-light に落ちず SKIP 拒否で 2 を返すため）。**HO を壊しても緑になります。**

> ⚠️ **`PLANGATE_HOOK_FILE` を必ず unset してください。** 実装は `target_file=${PLANGATE_HOOK_FILE:-${2:-}}` で **env が位置引数に優先**します。この変数が残った端末では**全ケースが同一ファイルを測って全件 rc=2 の緑**になります。

```sh
# HO 9 カテゴリ × 変換クラスの直積を全件 block で確認する。
# rc ではなく HARDENING_OVERRIDE の出力で判定すること（これが検出力の本体）。
for t in .claude/rules/x.md .claude/settings.json .claude/commands/x.md \
         .claude/agents/x.md scripts/hooks/x.sh bin/plangate \
         schemas/x.schema.json .github/workflows/x.yml CLAUDE.md AGENTS.md; do
  out=$(env -u PLANGATE_HOOK_TASK -u PLANGATE_SKIP_REASON \
            -u PLANGATE_HOOK_FILE -u PLANGATE_HOOK_STRICT -u PLANGATE_BYPASS_HOOK \
        sh scripts/hooks/check-plan-hash.sh "" "$t" </dev/null 2>&1); rc=$?
  printf '%s' "$out" | grep -q 'HARDENING_OVERRIDE' \
    && echo "OK   rc=$rc $t" \
    || echo "FAIL rc=$rc $t  ← HO で止まっていない"
done
# 期待: 全件 OK（rc=2 かつ HARDENING_OVERRIDE）
```

**変異注入で実証済み**（`scripts/hooks/*.sh` の HO case を 1 行削除した複製で実測）:

```
rc=2  .claude/settings.json      HARDENING_OVERRIDE
rc=2  scripts/hooks/x.sh         SKIP 拒否: SKIP_REASON 未設定   ← 変異の影響はここだけ
rc=2  bin/plangate               HARDENING_OVERRIDE
rc=2  schemas/x.schema.json      HARDENING_OVERRIDE
rc=2  .github/workflows/x.yml    HARDENING_OVERRIDE
rc=2  .claude/rules/x.md         HARDENING_OVERRIDE
rc=2  CLAUDE.md                  HARDENING_OVERRIDE
```

**7 件すべて rc=2 のままです。** rc のみの検証は**この変異を 1 件も検出できません**。出力を見て初めて `scripts/hooks/x.sh` の脱落が分かります。

### 2. レーンが効いていること

```sh
env -u PLANGATE_HOOK_TASK -u PLANGATE_SKIP_REASON -u PLANGATE_HOOK_FILE \
  sh scripts/hooks/check-plan-hash.sh "" docs/working/templates/plan.md </dev/null; echo "rc=$?"
#   期待: rc=0

env -u PLANGATE_HOOK_TASK -u PLANGATE_SKIP_REASON -u PLANGATE_HOOK_FILE \
  sh scripts/hooks/check-plan-hash.sh "" docs/working/TASK-9999/plan.md </dev/null; echo "rc=$?"
#   期待: rc=2（**引き続き block**）
```

### 3. Gray が閉じたままであること

```sh
for t in scripts/lib/foo.sh scripts/x.txt bin/x.py \
         tests/extras/../../scripts/hooks/check-plan-hash.sh \
         docs/working/templates/../../../CLAUDE.md; do
  env -u PLANGATE_HOOK_TASK -u PLANGATE_SKIP_REASON -u PLANGATE_HOOK_FILE \
    sh scripts/hooks/check-plan-hash.sh "" "$t" </dev/null >/dev/null 2>&1
  echo "rc=$? $t"    # 期待: 全件 rc=2（SKIP_REASON 要求）
done
```

### 4. **変異注入（AC-6 / 必須）**

**call site ではなくレーン判定関数内の各分岐を壊すこと。**

| 変異 | 期待 |
|---|---|
| **`_trav` 判定を削除**（差分 0 を外す） | **traversal TC が全件 FAIL**（最重要） |
| **`*/../*` を `*/../` に狭める** | 中間位置の `..` の TC が **FAIL** |
| **`tests/extras/*.sh` を `tests/extras/*` に緩める** | 過剰一致 TC が **FAIL** |
| **`docs/working/templates/*` を `docs/working/*` に緩める** | 過剰一致 TC が **FAIL** |
| **レーン判定を `if [ ! -f "$_maint" ]` の囲みの外へ出す** | maintenance 窓が開いている間の TC が **FAIL** |
| `_ai_lane=1` を `_ai_lane=0` に固定 | レーン TC が **FAIL** |
| `tests/extras/*.sh` の case を削除 | 対応 TC が **FAIL** |
| `docs/working/templates/*` の case を削除 | 対応 TC が **FAIL** |
| **内側 `case` の `docs/working/templates/plan.md` を `*/docs/working/templates/plan.md` へ緩める** | **`evil/docs/working/templates/plan.md` の迂回 TC が FAIL**（過剰一致・実測確認済み） |
| **except を外側 `case` の `*/plan.md` より後ろへ移動** | **テンプレート TC が FAIL**（`case` は先勝ち） |
| HO 判定をレーン判定より後ろへ移動 | **HO TC が全件 FAIL** |

**最後の 2 つが最重要です。** どちらも「動くが順序が違う」形の退行で、**結果だけ見ると気づけません**。

### 5. 全体

```sh
sh tests/run-tests.sh    # 単独で実行すること（並行実行は ta-42 / ta-61 で壊れます）
```

**baseline は着手時に現 main で再測定してください。絶対件数を契約値にしないこと。**

---

## 受入基準（#1135 の AC へのマッピング）

| #1135 AC | 本 patch での担保 |
|---|---|
| AC-1（正本が `.claude/rules/`） | 差分 3（`ai-owned-lane.md` 新規） |
| AC-2（`tests/extras/*.sh` が書ける） | 差分 2 の `_ai_lane` case |
| AC-3（テンプレートは可・TASK 配下は不可） | 差分 1 の except + 検証 2 |
| AC-4（HO 全件 block） | 検証 1（**直積で全数**） |
| AC-5（Gray は SKIP_REASON 要求） | 検証 3 |
| AC-6（変異注入で検出力） | 検証 4（**5 変異**） |
| AC-7（新規 FAIL なし） | 検証 5 |
| AC-8（塞がっていた作業が実際に動く） | **#1018 の 1 行修正を no-task セッションで完了させる**（案 B なら即実証可能） |

## 責務

| 作業 | 担当 |
|---|---|
| レーン設計・差分・変異注入の設計 | **AI-owned**（本書） |
| **段階導入の選択（A / B / C）** | **Human** |
| **`tests/extras/*.sh` を開けるかの判断** | **Human**（検証の土台を開けるため） |
| `scripts/hooks/check-plan-hash.sh` / `.claude/rules/` への適用 | **Human-owned**（**HO**） |

## この patch で解決しないこと

- **Bash 経路の穴**（#1104）— **レーンを広げる前に境界を固めるべき**という依存関係がある。**#1104 の判断が先**であれば本 patch は保留すべき
- **`scripts/` 本体 / `bin/` / `schemas/`** — Gray のまま。本 patch では開けない
- **`.md` 以外の文書**（`.txt` 等）— Gray のまま

Refs #1135
Refs #1035
Refs #1018
Refs #1092
