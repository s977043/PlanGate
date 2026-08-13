# TASK-1078 S-2 テストケース定義

> 正本: [`plan.md`](./plan.md) / 受入基準: [`pbi-input.md`](./pbi-input.md)
> 実行系: **`tests/extras/ta-65-codex-bridge-io.sh`**（新規・**フラット配置必須**・`tests/extras` の共有 exit 契約に従う）

## 前提（全 TC 共通）

- **配置**: loader は `tests/run-tests.sh:165` の **`"$EXTRAS_DIR"/ta-*.sh` フラット glob**。
  **サブディレクトリに置くと CI で 1 度も実行されない**。
  **fixture は `tests/fixtures/codex-bridge/`**（既存慣行。`FIXTURES_DIR` = `tests/fixtures` / `tests/run-tests.sh:23`）。
- **実行形態**: extras は **source** される。`pass` / `fail` カウンタを共有し `pg_extra_contract_init "ta-65" …` を先頭で呼ぶ。
- **サンドボックス**: bridge を `<mktemp -d>/.codex/hooks/eh-bridge.sh` に複製すると `REPO_ROOT` がサンドボックスへ移る。
  実 hook / stub hook は `<sandbox>/scripts/hooks/`・`<sandbox>/scripts/` に置く。**`scripts/**` を 1 行も変更しない**。
  **bridge に解決先の override 環境変数を新設しない**（guard の解決先を実行時に差し替えられる穴になる）。
- **env はテストが明示設定する**。セッションからの継承を禁止する（計画時に `PLANGATE_HOOK_TASK` の継承で判定が変わることを実測）
  - `PLANGATE_HOOK_TASK`: 各 TC で指定（`unset` の場合は `env -u` で明示的に外す）
  - `PLANGATE_HOOK_STRICT`: 既定 `0`（本 PBI で既定を変えない）
  - `PLANGATE_DELEGATION_NOCOMMIT`: 各 TC で指定
- **stdin は必ず明示的に与える**（`printf '%s' "$payload" | ...`）。無いと bridge の `INPUT=$(cat)` がハングしうる。
- payload は実測形状（`hook_event_name` / `tool_name` ∈ {`apply_patch`, `Bash`} / `tool_input` / `cwd` / `permission_mode` / `tool_use_id`。
  実物は `evidence/codex-exec-spike.md` 追記 1 L189-196 / 追記 2 L292-298）
- 判定は bridge の stdout から `hookSpecificOutput.permissionDecision` を抽出して行う

## 受入基準 → テストケース マッピング

> **AC-06 は欠番**（登録は受入基準ではなく **前提条件 P-1**）。TC-13 は P-1 の確認手順であり AC に紐づかない。

| AC | 内容 | TC |
|---|---|---|
| AC-01 | deny すべきケースで deny | TC-01・TC-02・TC-03・TC-04・**TC-17**・**TC-18** |
| AC-02 | allow すべきケースで allow | TC-05・TC-06・TC-07 |
| AC-03 | 変異注入で FAIL する | TC-08・TC-09・**TC-21** |
| AC-04 | stderr は判定に使わない | TC-10 |
| AC-05 | 未知 rc は deny / reason 非空 | TC-11・TC-12 |
| ~~AC-06~~ | **欠番**（前提条件 P-1 へ移動） | （TC-13 は P-1 の確認手順） |
| AC-07 | ランタイム block 証跡（**bypass 無し**） | TC-14 |
| AC-08 | Claude 側非回帰 | TC-15 |
| AC-09 | 責務分界の一意性 + 限界 4 点の明記 | TC-16 |
| **AC-10** | **複数パス `apply_patch` の全件評価** | **TC-19** |
| **AC-11** | **hooks.json が Codex 受理形 / matcher に死に文字列なし** | **TC-22** |
| **AC-12** | **hook 解決のフォールバック** | **E-4 / E-5**（自動化・下記） |

> **EH-1 / EH-6 の deny が 0 件だった問題（R-F07）**: 旧版は plan `:97` 自身が「5 hook すべての挙動が変わる」と書きながら
> **EH-1（plan-exists）と EH-6（forbidden-files）の deny 側 TC が 1 件も無かった**。TC-17 / TC-18 で埋める。
> また旧版 TC-09 が参照していた「STRICT=1 の EH-1 ケース」は**当時どこにも定義されていない幽霊参照**だった（TC-17 として実体化）。

## テストケース一覧

### TC-01: EH-9 が委譲文脈の commit を deny する（stdin 依存）

- 前提: `PLANGATE_DELEGATION_NOCOMMIT=1` / `PLANGATE_HOOK_TASK` unset
- 入力: `tool_name=Bash` / `tool_input.command="git commit -m wip"` → `check-delegation-commit-boundary.sh`
- 期待: `permissionDecision="deny"` / reason 非空
- 種別: Unit（自動）
- 備考: **stdin 転送が無いと allow になる**（計画時実測）。stdin 修正の唯一の直接証明

### TC-02: EH-9 が委譲文脈の force push を deny する

- 前提: TC-01 と同じ
- 入力: `tool_input.command="git push --force origin main"`
- 期待: `deny`
- 種別: Unit（自動）

### TC-03: EH-3 が HO パスへの書き込みを deny する（stdout 非依存・rc=2 経路）

- 前提: `PLANGATE_HOOK_TASK` **unset**
- 入力: `tool_name=apply_patch` / patch 本文に `*** Update File: .claude/settings.json` → `check-plan-hash.sh`
- 期待: `deny` / reason に `HARDENING_OVERRIDE` を含む
- 種別: Unit（自動）
- 備考: **修正前 bridge でも deny**（rc=2 経路）。回帰検出用の固定点

### TC-04: EH-2 が C-3 未承認を deny する（stdout 依存・STRICT=1）

- 前提: `PLANGATE_HOOK_STRICT=1` / `approvals/c3.json` 不在
- 入力: `apply_patch` → `docs/working/TASK-9999/plan.md` → `check-c3-approval.sh`
- 期待: `deny`
- 種別: Unit（自動）
- 備考: hook は **rc=0 + stdout `{"continue":false}`**。**stdout 判定の直接証明**

### TC-05: 通常の実装作業が allow される（誤検出ゼロ側）

- 前提: `PLANGATE_HOOK_TASK` unset / `STRICT=0` / `NOCOMMIT` unset
- 入力: `apply_patch` → `docs/working/TASK-9999/plan.md`（plan.md 実在）→ 4 hook すべて
- 期待: **全件 `allow`**
- 種別: Unit（自動）

### TC-06: 通常セッションの git commit が allow される

- 前提: `PLANGATE_DELEGATION_NOCOMMIT` **unset**
- 入力: TC-01 と同じ command
- 期待: `allow`
- 種別: Unit（自動）
- 備考: EH-9 の blast radius が委譲文脈に限定されることの保証

### TC-07: 非 HO パスの production 編集が allow される（既定 STRICT=0）

- 前提: `STRICT=0` / `PLANGATE_HOOK_TASK` unset
- 入力: `apply_patch` → `docs/ai/notes.md` → 4 hook
- 期待: 全件 `allow`
- 種別: Unit（自動）

### TC-08: 変異 1 — stdin 転送を除去すると TC-01 / TC-02 が FAIL する

- 前提: bridge の stdin 転送行（call site）を修正前へ戻す
- 期待: **TC-01・TC-02 が FAIL**、他は PASS のまま
- 種別: Mutation（手動適用 + 自動判定）
- 備考: 期待値側を書き換えて FAIL を作らない

### TC-09: 変異 2 — stdout 判定を除去すると TC-04 / TC-17 が FAIL する

- 前提: bridge の stdout 判定ブロックを削除する
- 期待: **TC-04 と TC-17（STRICT=1 の EH-1 ケース）が FAIL**、**TC-03 は PASS のまま**（rc=2 経路のため）
- 種別: Mutation（手動適用 + 自動判定）
- 備考: TC-03 が PASS のまま残ることが「stdout 経路と rc 経路が別物である」ことの対照になる

### TC-10: stderr の block 相当文字列で deny にならない

- 前提: stdout に `{"continue":true}`、**stderr にのみ** `"continue":false` を含む文字列を出す stub hook
- 期待: `allow`
- 種別: Unit（自動）
- 備考: 計画時に **false deny を実測で再現済み**。判定チャネル分離の回帰テスト

### TC-11: 未知 exit code が deny になる（fail-closed）

- 前提: `exit 127` を返す stub hook
- 期待: `deny` / reason に `rc=127` を含む
- 種別: Unit（自動）

### TC-12: 無出力 block でも reason が非空

- 前提: 無出力で `exit 2` / `exit 1` を返す stub hook
- 期待: `deny` かつ `permissionDecisionReason` が**非空**
- 種別: Unit（自動）
- 備考: 空 reason の deny は Codex ランタイムで**黙って握り潰される**（実測）

### TC-13: 登録状態（**前提条件 P-1 の確認・AC ではない**）

- 前提: 注記キー除去後
- 手順: `codex app-server` の `hooks/list`
- 期待: PlanGate hook **5 件** / `warnings[]` 空 / 全件 `enabled=true` / `trustStatus` を**記録**する
- 種別: Manual（課金ゼロ）
- ⚠️ **本 TC の PASS を成果として報告しない。** 登録は前提であって強制力ではない
- ⚠️ **`trustStatus="trusted"` を発火の証明として扱わない**（U-4。evidence L109 が「trusted 表示は実行時に効かない可能性」を挙げている）

### TC-14: ランタイム block 証跡（**Human 承認が前提**）

- 前提: TC-13（P-1）充足 + Human が実走 1 回を承認
- 手順: `codex exec` を 1 回
  - 🔴 **`--dangerously-bypass-hook-trust` を付けない**（付けた run の結果は AC-07 の根拠にできない）
  - 非 `--ephemeral` / deny 対象を先 / 「ブロックされても retry しない」を prompt に明示
- 期待: stderr に `Command blocked by PreToolUse hook:` + PlanGate hook 名 / **対象ファイルが生成されていない**
- 種別: E2E（課金あり・1 回限り）
- **未承認時 / 未発火時**: **WARN**（理由・代替・未充足リスクを handoff と `settings-wiring-contract.md` に記録）。
  **bypass を付けて再走して PASS にしない**
- 備考: 未発火は「失敗」ではなく **U-4 が否定側に確定した成果**として扱う（S-4 の前提が 1 つ確定する）

### TC-15: Claude 側の非回帰

- 手順: `PG_BASE=$(git merge-base HEAD origin/main); git diff "$PG_BASE" -- scripts/hooks .claude`
- 期待: **差分 0**。使用した `PG_BASE` の SHA を evidence に併記する
- 種別: Manual（自動化可）
- ⚠️ **`git diff origin/main` を使わない**。origin/main は動く基点で、**無関係な他 PR の変更を本 PBI の差分として拾う**

### TC-16: 責務分界の一意性と限界の明記

- 手順: `docs/ai/settings-wiring-contract.md` の責務分界節が**パス単位の表**で、`.codex/hooks/*.sh` の新規追加・既存改変の双方の帰属が読めることを目視確認する
- 期待:
  1. `.codex/**` = AI-owned / HO 9 カテゴリ = Human-owned が一意。機械判定（`check-plan-hash.sh` の case 文）との一致が明記されている
  2. **軸 C に S-2 の限界 4 点**（bridge 単体の実証範囲 / ランタイム発火の状態 / `trusted_hash` 未設定環境は対象外 / #1089 の TASK 文脈）が書かれている
- 種別: Manual（レビュー）

### TC-17: EH-1 が未計画 TASK への書き込みを deny する（stdout 依存・STRICT=1）

- 前提: `PLANGATE_HOOK_STRICT=1` / `docs/working/TASK-8888/plan.md` が**不在**
- 入力: `apply_patch` → `docs/working/TASK-8888/notes.md` → `check-plan-exists.sh`
- 期待: `deny` / reason 非空
- 種別: Unit（自動）
- 備考: **旧版で「STRICT=1 の EH-1 ケース」として言及されながら実体が無かった幽霊 TC の実体化**（R-F07）。TC-09（変異 2）の判定対象

### TC-18: EH-6 が forbidden files への書き込みを deny する

- 前提: サンドボックスに `forbidden_files` 相当の設定を置く（`check-forbidden-files.sh` の実装が要求する形に合わせる）
- 入力: `apply_patch` → forbidden 指定パス → `check-forbidden-files.sh`
- 期待: `deny` / reason 非空
- 種別: Unit（自動）
- 備考: **配線済み 5 hook のうち EH-6 の deny が 1 件も検査されていなかった**（R-F07）。
  実装調査の結果 deny 条件を課金ゼロで再現できないと判明した場合は、**その事実と理由を handoff に記録**し
  「未検証の hook」として明示する（**黙って落とさない**）

### TC-19: 複数ファイル `apply_patch` の 2 件目以降も検査される

- 前提: `PLANGATE_HOOK_TASK` unset
- 入力: 1 つの `apply_patch` コマンドに **2 つの `*** Update File:` 行**を含める
  - 1 件目: `docs/ai/notes.md`（無害）
  - 2 件目: `.claude/settings.json`（**HO パス**）
- 期待: **`deny`** / reason に **2 件目のパス**が現れる
- 種別: Unit（自動）
- 備考: 現行 `eh-bridge.sh:50` は `re.search` で**先頭 1 件のみ**抽出するため、この入力は **allow** になる（＝ guard の素通り経路）。
  全件評価が困難で「複数パスを含む `apply_patch` は一律 deny」の代替を採った場合も、**期待値は `deny` のまま**変わらない

### TC-20: `PLANGATE_HOOK_TASK` 設定時の HO block（**現状固定・既知の穴**）

- 前提: `PLANGATE_HOOK_TASK=TASK-9999`（設定あり）
- 入力: `apply_patch` → `.claude/settings.json` → `check-plan-hash.sh`
- 期待: **reason に `HARDENING_OVERRIDE` が現れない**こと（＝ **HO 判定が発火していない**ことの固定）
- 種別: Unit（自動）
- ⚠️ **`allow` を期待値にしない**: TASK 文脈では EH-3 が plan / c3 の検査経路に入るため、
  **HO とは別の理由で deny になりうる**（`plan.md` / `approvals/c3.json` 不在など）。
  「decision が何か」ではなく「**HO 判定が効いていない**」ことを判定対象にする。
  最終的な期待値は T-01 の実行結果で確定し、根拠を TC のコメントに残す
- 🔴 **これは「あるべき挙動」ではない。** `check-plan-hash.sh` の Hardening Override 判定が `if [ -z "$task_id" ]` の内側にあるため
  TASK 文脈では HO block が発火しない（[#1089](https://github.com/s977043/plangate/issues/1089)）。
  修正対象は `scripts/hooks/*.sh` ＝ **HO パス / Human-owned** であり **S-2 の scope 外**。
  本 TC は「S-2 がこの穴を塞いだと誤解されないための固定点」であり、**#1089 の修正時に期待値が `deny` へ反転する**（その旨をコメントに明記する）

### TC-21: 変異 3 — 複数パス抽出を `re.search` に戻すと TC-19 が FAIL する

- 前提: bridge の全件抽出を `re.search`（先頭 1 件）へ戻す
- 期待: **TC-19 が FAIL**、他は PASS のまま
- 種別: Mutation（手動適用 + 自動判定）

### TC-22: `.codex/hooks.json` が Codex 受理形であり matcher に死に文字列が無い

- 手順（課金ゼロ・静的）:
  1. `python3` で読み込み、**top-level のキー集合が `{description, hooks}` に一致**することを確認する
  2. matcher 文字列に **`Edit` / `Write`** が含まれないことを確認する
  3. PlanGate 5 hook（`check-plan-exists` / `check-c3-approval` / `check-plan-hash` / `check-forbidden-files` / `check-delegation-commit-boundary`）の**記述**があることを確認する
- 期待: 3 点すべて成立（**T-06 適用後**）
- 種別: Unit（自動 / 静的）
- ⚠️ **「JSON として valid」だけでは不十分**。既存 `ta-15` TC-03 は `python3 -m json.tool` で PASS しており、
  **Codex が受理していない設定に対して緑を出していた**（R-F04）。本 TC は top-level キー集合まで見ることでその穴を塞ぐ
- ⚠️ **表明文言に「配線済み（wires）」を使わない**。ファイルに記述があることと Codex に登録されていることは別

## エッジケース

> **fail 方向の設計原則**: 入力側（stdin の異常）と出力側（rc の異常）で **fail の向きを揃える**。
> 出力側は fail-closed（AC-05: 未知 rc → deny）なので、**入力側で「情報が失われうる異常」も fail-closed に寄せる**。
> ただし「そもそも評価対象が無い」ケースまで deny にすると Codex 以外からの誤起動でセッションを壊すため、そこは allow に残す。
> **どちらを選んだかを根拠つきで固定する**（レビューで再燃させない）。

| # | ケース | 期待 | 根拠 |
|---|---|---|---|
| E-1 | `tool_input` にファイルパスが無い `apply_patch`（Add/Delete/Update いずれの行も無い） | **hook に委譲**（`PLANGATE_HOOK_FILE` 未設定で起動し hook の判定に従う）。**crash しない** | bridge が独自に allow を返すのではなく、判定権を hook に残す |
| E-2 | stdin が空（Codex 以外からの起動） | **allow**。**bridge 自体が異常終了しない** | 評価対象のツール入力が存在しない。Codex 経由では発生しない。deny にすると誤起動でセッションを壊す副作用が勝る |
| E-3 | stdin が**壊れた JSON** | 🔴 **deny**（fail-closed）/ reason 非空・stderr に診断 | **壊れた JSON はパスを隠せる**。v8.19.0 の EH-13 が parse-unknown を block 扱いにした先例と同じ向き（**旧版の allow から変更**） |
| E-4 | hook 名が `scripts/` 直下にのみ実在（EH-13 相当） | フォールバックで解決され、not-found deny にならない（**AC-12**） | stub で自動検証可能 |
| E-5 | hook 名がどちらにも無い | 従来どおり `deny` / reason 非空（**AC-12**） | 既存挙動の維持 |
| E-6 | hook が 15 秒を超える | Codex の timeout 設定に従う。**bridge 側では扱わない**（挙動を変えない） | scope 外 |
| E-7 | `PLANGATE_BYPASS_HOOK=1` | 全 hook が allow を返す（既存 escape hatch が生きていること） | 緊急 rollback 手段の生存確認 |
| E-8 | 同一 matcher group の複数 hook のうち 1 本が deny | Codex 側の打ち切り仕様は U-6（未確定）。**bridge の期待値は hook 単位で判定する** | bridge は 1 プロセス 1 hook |
| **E-9** | **一時ファイルが残らない** | bridge 実行後にサンドボックス内へ `eh-bridge-out.*` 等が残っていない | `mktemp` 化と確実な削除（現行は `/tmp/eh-bridge-out.$$` ＝ 予測可能名で、判定入力を外部から先回りできる） |
| **E-10** | **`apply_patch` に 3 件以上のパス**（うち 1 件が HO） | `deny`（TC-19 の一般化） | 「先頭 1 件のみ検査」の取りこぼしが 2 件目に限らないこと |

## 自動化可否

| 種別 | 対象 | 自動化 |
|---|---|---|
| Unit（bridge I/O） | TC-01〜TC-07・TC-10〜TC-12・**TC-17〜TC-20** + E-1〜E-5・E-7・**E-9・E-10** | ✅ 完全自動・課金ゼロ |
| Unit（静的） | **TC-22** | ✅ 完全自動・課金ゼロ |
| Mutation | TC-08・TC-09・**TC-21** | ⚠️ 変異適用は手動、判定は自動 |
| Manual（課金ゼロ） | TC-13（**前提条件 P-1**）・TC-15・TC-16 | ⚠️ TC-13 は S-3 で自動化予定 |
| E2E（課金あり） | TC-14 | ❌ Human 承認が必要・1 回限り・**bypass フラグ禁止** |

### 実行方法（必須）

- **`sh tests/run-tests.sh`（スイート全体）で PASS すること**を完了条件とする。
  出力に **`TA-65`** が現れることが「loader に拾われた」ことの唯一の証明であり、
  **単体実行だけで済ませると、置き場所を間違えていても気づけない**（R-F03）。
- あわせて **`TA-15`（既存テスト）が PASS のまま**であることを確認する（Task 2 で bridge の I/O が変わるため）。
