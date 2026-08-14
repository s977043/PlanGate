# TASK-1078 S-2 テストケース定義

> 正本: [`plan.md`](./plan.md) / 受入基準: [`pbi-input.md`](./pbi-input.md)
> 実行系: **`tests/extras/ta-67-codex-bridge-io.sh`**（新規・**フラット配置必須**・`tests/extras` の共有 exit 契約に従う）

## 前提（全 TC 共通）

- **配置**: loader は `tests/run-tests.sh:165` の **`"$EXTRAS_DIR"/ta-*.sh` フラット glob**。
  **サブディレクトリに置くと CI で 1 度も実行されない**。
  **fixture は `tests/fixtures/codex-bridge/`**（既存慣行。`FIXTURES_DIR` = `tests/fixtures` / `tests/run-tests.sh:23`）。
- **実行形態**: extras は **source** される。`pass` / `fail` カウンタを共有し `pg_extra_contract_init "ta-<NN>" …` を先頭で呼ぶ。
- 🔴 **番号は契約値ではない**。着手時に `git ls-tree --name-only origin/main tests/extras/` で次の空きを実測する
  （2026-08-14 実測: `ta-65` / `ta-66` は main に既存 → **`ta-67`**）。
- 🔴 **到達性の判定は一意マーカー `PG_TA_CODEX_BRIDGE_IO_V1`** に対して行う。**`TA-NN` で判定しない**
  （既存 `ta-65-eh3-ho-task-context.sh` が `=== TA-65: …` を出力するため、**未配置でも真になる**）。
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
| AC-03 | 変異注入で FAIL する | TC-08・TC-09・**TC-21**・**TC-23**・**変異 5（TC-24 を対象）** |
| AC-04 | stderr は判定に使わない | TC-10 |
| AC-05 | 未知 rc は deny / reason 非空 / **出力が常に valid JSON** | TC-11・TC-12・**TC-24** + **全 deny TC の `json.loads` assertion** |
| ~~AC-06~~ | **欠番**（前提条件 P-1 へ移動） | （TC-13 は P-1 の確認手順） |
| AC-07 | ランタイム block 証跡（**bypass 無し**） | TC-14 |
| AC-08 | Claude 側非回帰 | TC-15 |
| AC-09 | 責務分界の一意性 + 限界 4 点の明記 | TC-16 |
| **AC-10** | **複数パス `apply_patch` の全件評価** | **TC-19**・E-10 |
| **AC-11** | **hooks.json が Codex 受理形 / matcher に死に文字列なし / 宣言 stage と実体の drift 検出** | **TC-22a**（T-01 所有・drift 検出）・**TC-22b**（T-04 所有） |
| **AC-12** | **hook 解決のフォールバック** | **E-4 / E-5**（自動化・下記） |
| **AC-02（追加）** | **env の持ち越しで判定が汚染されない** | **E-11 / E-12** |
| **—（AC 対応なし）** | **一時ファイルの予測可能性と leak**（AC-05 の付随・R-9 の再発防止） | **E-9a / E-9b**（TC-23 が検出力を担保） |
| **—（AC 対応なし）** | **#1089 の限界を現状固定**（R-8。**あるべき挙動ではない**） | **TC-20** |

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

### TC-14: ランタイム block 証跡（🔴 **サンドボックスで実施・不可逆な有効化の前** / Human 承認が前提）

- 🔴 **実施場所**: **`mktemp -d` のサンドボックス**（`todo T-05b`）。**実リポジトリの `.codex/hooks.json` は変更しない**。
  - 実リポジトリの **`.codex/hooks/eh-bridge.sh`（T-02 修正後）と `scripts/hooks/*.sh` をそのまま複製**する
  - サンドボックスの `hooks.json` は **T-06 適用後の目標形と同一内容**にする
  - **理由**: 有効化は不可逆であり、**AC-07 が WARN に終わった場合に「登録済み・実効 0」を作らないため**（EIC 不変条件 / R3-F1）
- 前提: サンドボックスで `hooks/list` 5 件・`warnings[]` 空・`trusted_hash` 付与済み + Human が実走 1 回を承認
- 手順: `codex exec` を 1 回
  - 🔴 **`--dangerously-bypass-hook-trust` を付けない**（付けた run の結果は AC-07 の根拠にできない）
  - 非 `--ephemeral` / deny 対象を先 / 「ブロックされても retry しない」を prompt に明示
- 期待: stderr に `Command blocked by PreToolUse hook:` + PlanGate hook 名 / **対象ファイルが生成されていない**
- 種別: E2E（課金あり・**S-2 全体で 1 回限り**）
- **未承認時 / 未発火時**: **WARN**（理由・代替・未充足リスクを handoff と `settings-wiring-contract.md` に記録）。
  **bypass を付けて再走して PASS にしない**
- 🔴 **判定の帰結**:
  - **PASS** → `todo T-06`（不可逆な有効化）に進んでよい（**終端 A**）
  - **WARN** → 🔴 **`todo T-06` を実行しない**。kill switch を保持したまま完了する（**終端 B**）
- 備考: 未発火は「失敗」ではなく **U-4 が否定側に確定した成果**として扱う（S-4 の前提が 1 つ確定する）

### TC-15: Claude 側の非回帰

- 手順: `PG_BASE=$(git merge-base HEAD origin/main); git diff "$PG_BASE" -- scripts .claude`
  （🔴 **`scripts` 全体**を対象にする。`scripts/hooks` に絞ると **T-02 (e) が新設する `scripts/` 直下フォールバック**の
  対象ディレクトリが検査外になる＝ R3-F7d）
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

### TC-24: deny の reason に JSON を壊す文字が入っても出力が valid JSON である

- 前提: **stdout に `\`（バックスラッシュ）・`"`・制御文字（`\t` / `\x01`）・日本語**を混ぜた
  `{"continue":false,"stopReason":"…"}` を返し、**`rc=0`** で終了する stub hook
- 入力: 任意の `apply_patch` payload
- 期待:
  1. `permissionDecision="deny"`
  2. **bridge の stdout 全体が `json.loads` できる**
  3. `permissionDecisionReason` が**非空**
  4. 切り詰めが起きた場合も **UTF-8 として妥当**（不正バイト列で終わらない）
- 種別: Unit（自動）
- 🔴 **現行実装では FAIL する**: サニタイズは `tr '"' "'"` のみで **`\` と制御文字が素通り**し、
  `head -c 400` は**バイト単位**なので**日本語の途中で切れる**（`eh-bridge.sh:75,84`）。
  不正 JSON になると Codex が decision を読めず、**既知の「空 reason の fail-open」と同種の黙った allow** に化ける

> 🔴 **全 deny TC 共通の追加 assertion（R3-F2）**: TC-01〜TC-04・TC-11・TC-12・TC-17〜TC-19 の
> **すべての deny ケースで「bridge の stdout が `json.loads` できること」を検査する**。
> **`deny` という部分文字列の一致だけで PASS にしない**（現行の TC-03 / TC-11 / TC-12 はそうなっていた）。

### TC-23: 変異 4 — 一時ファイルの是正を戻すと E-9a / E-9b が FAIL する

- 変異 4a: bridge の一時ファイルを **`/tmp/eh-bridge-out.$$`（予測可能名）へ戻す** → **E-9a が FAIL**
- 変異 4b: bridge の **`rm -f`（削除）を除去する** → **E-9b が FAIL**
- 種別: Mutation（手動適用 + 自動判定）
- 備考: **どちらも plan 作成時にサンドボックスで実測済み**（E-9 の設計根拠を参照）。
  4a は `predictable_present=YES` を、4b は `/tmp/eh-bridge-out.<pid>` にマーカーが残ることを確認した
- ⚠️ **この 2 変異のどちらかが FAIL を起こせなかった場合、その E-9 は空振り**である。
  修正できない場合は**乖離帯として handoff に記録**する（黙って PASS のままにしない）

### TC-22: `.codex/hooks.json` の stage 別 assertion（**TC-22a / TC-22b に分割**）

> 🔴 **本 TC を「T-06 適用後にだけ成立する単一 assertion」にしてはならない**（R2-1）。
> 新規 extras は **T-01 で導入**され、T-01〜T-05 の各チェックポイントの完了条件は **`sh tests/run-tests.sh` の全体 GREEN** である。
> 「T-06 後にだけ真」の assertion を T-01 で入れると、**T-01〜T-05 の間ずっとスイートが RED** になり、
> 完了条件を満たせないか、**期待値を緩めて空振りテストへ退行**する。以下の 2 分割でこれを構造的に回避する。

#### TC-22a: **宣言 stage vs 実体の drift 検出**（T-01 で導入）

> 🔴 **旧案（stage を hooks.json 自身から推論する 2 値）は採らない**（R3-F3）。
> 推論方式だと **main マージ後に誰かが top-level へ 1 行足して Codex 側強制力を全滅させても、
> テストは「disabled 分岐」として GREEN のまま**になる。**`hooks/list` の doctor / CI 化は S-3 送り**なので、
> S-2 完了時点で無効化を検出する機械が 1 つも存在しなくなる。

- **テスト本体に「期待する stage」を定数として宣言する**（例 `PG_EXPECTED_STAGE=disabled|enabled`）。
  この定数は **リポジトリ内にあり、レビュー可能な差分として変更される**（env による外部指定にしない）。
- 手順（課金ゼロ・静的）:
  1. `python3` で `.codex/hooks.json` を読み、**top-level のキー集合**を取得する
  2. **実体 stage を判定する**: キー集合が `{description, hooks}` に一致 → `enabled` / それ以外 → `disabled`
  3. 🔴 **宣言 stage と実体 stage が一致することを assert する**（**不一致は FAIL**）
  4. さらに宣言 stage 別に assert する:
     - **`enabled`**: キー集合が `{description, hooks}` に**厳密一致**（余分なキーが 1 つも無い）
     - **`disabled`**: **未知キーが実在する**（＝ kill switch が効いている）かつ想定どおりのキー（`$schema_note` / `$note` 等）
  5. **どちらでも 5 hook の記述が存在する**ことを assert する（stage 非依存の不変条件）
- 期待: 宣言 == 実体 かつ 該当分岐が成立
- 種別: Unit（自動 / 静的）
- 🔴 **検出できるようになる 2 方向**:
  - **有効化後に kill switch を戻された**（宣言 `enabled` / 実体 `disabled`）→ **FAIL**（R3-F3 が指摘した無効化の検出）
  - **未有効化のまま誤って有効化された**（宣言 `disabled` / 実体 `enabled`）→ **FAIL**（EIC 不変条件の違反検出）
- **所有**: T-01 で導入（宣言 = `disabled`）。**T-06 が同一コミットで宣言を `enabled` に更新する**。
  **更新を忘れるとスイートが RED になる**ため、宣言と実体の drift は機械的に検出される
- **F-1 との整合**: AC-07 = WARN で **T-06 を実行しない**場合、宣言は `disabled` のまま・実体も `disabled` なので **PASS**。
  「WARN で kill switch を保持する」設計と **衝突しない**（宣言方式にした理由の 1 つ）

#### TC-22b: matcher に死に文字列が無い（**T-04 のコミットで導入**）

- 手順: matcher 文字列に **`Edit` / `Write`** が含まれないことを確認する
- 期待: 含まれない
- 種別: Unit（自動 / 静的）
- 🔴 **T-04（matcher 除去）より前は偽であるため、T-04 と同一コミットで導入する**（**所有: T-04**）。
  T-01 の時点で入れるとスイートが RED になる。stage 検出でごまかさない（matcher 自身が唯一の観測点で、
  「T-04 の前か後か」を matcher 以外から判定する手段が無い＝ stage 依存にすると循環する）

> ⚠️ **「JSON として valid」だけでは不十分**。既存 `ta-15` TC-03 は `python3 -m json.tool` で PASS しており、
> **Codex が受理していない設定に対して緑を出していた**（R-F04）。TC-22a は top-level キー集合まで見ることでその穴を塞ぐ。
> ⚠️ **表明文言に「配線済み（wires）」を使わない**。ファイルに記述があることと Codex に登録されていることは別。
> ⚠️ **`ta-15` TC-03 にも TC-22a と同じ 2 値方式を適用する**（T-00 が所有）。こうすると T-06 との**コミット同期が不要**になる。

## エッジケース

> **fail 方向の設計原則**: 入力側（stdin の異常）と出力側（rc の異常）で **fail の向きを揃える**。
> 出力側は fail-closed（AC-05: 未知 rc → deny）なので、**入力側で「情報が失われうる異常」も fail-closed に寄せる**。
> ただし「そもそも評価対象が無い」ケースまで deny にすると Codex 以外からの誤起動でセッションを壊すため、そこは allow に残す。
> **どちらを選んだかを根拠つきで固定する**（レビューで再燃させない）。

| # | ケース | 期待 | 根拠 |
|---|---|---|---|
| E-1 | `tool_input` にファイルパスが無い `apply_patch`（Add/Delete/Update いずれの行も無い） | **hook に委譲**（`PLANGATE_HOOK_FILE` 未設定で起動し hook の判定に従う）。**crash しない** | bridge が独自に allow を返すのではなく、判定権を hook に残す |
| E-2 | stdin が空（Codex 以外からの起動） | **allow**。**bridge 自体が異常終了しない** | 評価対象のツール入力が存在しない。Codex 経由では発生しない。deny にすると誤起動でセッションを壊す副作用が勝る |
| E-3 | stdin が**壊れた JSON**（構文エラー） | 🔴 **deny**（fail-closed）/ reason 非空・stderr に診断 | **壊れた JSON はパスを隠せる**。v8.19.0 の EH-13 が parse-unknown を block 扱いにした先例と同じ向き（**旧版の allow から変更**） |
| **E-3'** | **JSON としては valid だが object でない**（`null` / 配列 / 文字列 / 数値） | 🔴 **deny**（fail-closed）/ reason 非空 | **E-3 と同じ情報欠落側**。「object でない＝ツール入力を評価できない」。下記 ❗ の実測を参照 |
| E-4 | hook 名が `scripts/` 直下にのみ実在（EH-13 相当） | フォールバックで解決され、not-found deny にならない（**AC-12**） | stub で自動検証可能 |
| E-5 | hook 名がどちらにも無い | 従来どおり `deny` / reason 非空（**AC-12**） | 既存挙動の維持 |
| E-6 | hook が 15 秒を超える | Codex の timeout 設定に従う。**bridge 側では扱わない**（挙動を変えない） | scope 外 |
| E-7 | `PLANGATE_BYPASS_HOOK=1` | 全 hook が allow を返す（既存 escape hatch が生きていること） | 緊急 rollback 手段の生存確認 |
| E-8 | 同一 matcher group の複数 hook のうち 1 本が deny | Codex 側の打ち切り仕様は U-6（未確定）。**bridge の期待値は hook 単位で判定する** | bridge は 1 プロセス 1 hook |
| **E-9a** | **予測可能な名前の一時ファイルを作らない**（詳細は下記 ❗） | stub hook が実行中に `/tmp/eh-bridge-out.$PPID` の**不在**を観測する | 是正対象の性質は「残る/残らない」ではなく **名前が予測可能かどうか**。ここを直接検査する |
| **E-9b** | **一時ファイルが残らない**（leak） | bridge 終了後、**hook stdout に出したユニークマーカーを含むファイル**が候補ディレクトリのどこにも無い | 削除漏れの検出。マーカー検索なのでファイル名の実装に依存しない |
| **E-10** | **`apply_patch` に 3 件以上のパス**（うち 1 件が HO） | `deny`（TC-19 の一般化） | 「先頭 1 件のみ検査」の取りこぼしが 2 件目に限らないこと |
| **E-11** | **セッション env に `PLANGATE_HOOK_FILE=<古いパス>` がある状態で、パスを抽出できない payload** を渡す | hook が **古いパスを見ない**（bridge が毎回 export か明示 unset で確定させる） | 現行 `eh-bridge.sh:55-65` は `FILE_PATH` が空のとき **export しないだけで既存 env をクリアしない** → **セッションの古いパスで判定される**（誤 allow / 誤 deny の両方向。R3-F7b） |
| **E-12** | 同上を `PLANGATE_HOOK_TASK` で行う（bridge の自動導出 `:57-64` が働かない payload） | セッションの古い TASK が判定に漏れ込まない | R-4 を「テストの問題」ではなく **bridge の契約**として閉じる |

❗ **E-3' の実測（R2-8）**: 現行の抽出器は **`try/except` が `json.loads` しか包んでいない**ため、
object 以外の valid JSON では `d.get(...)` が `AttributeError` を送出して **python が rc=1 で異常終了**する:

```text
printf '%s' '[1,2]' | python3 -c '... ti = d.get("tool_input") or {} ...'
  AttributeError: 'list' object has no attribute 'get'
  PY_EXIT=1
```

シェル側は `2>/dev/null || echo ""` で受けるため **`FILE_PATH` が空**になり、結果として
**E-1（パス不明 → hook に委譲）と同じレーンへ黙って落ちる**。
「例外を握って `sys.exit(0)` している」わけではない（送出は捕捉されていない）。
**新契約では E-3 と同じく deny に倒す**。実装時は `isinstance(d, dict)` を明示的に判定し、
偽なら**診断を stderr に出して deny を返す**（例外任せにしない）。

❗ **E-9 の設計根拠（R2-2 / 実測で 2 度作り直した箇所。実装時にここを読まずに簡略化しない）**

**却下: 「サンドボックス内に残っていないこと」だけを見る方式**（旧 E-9）
→ bridge は `/tmp` に書くため、**修正前でも修正後もサンドボックス内には何も残らない**。**常に PASS する空振り**。

**却下: 「`TMPDIR=<sandbox>` を明示すれば `mktemp` がそこに書くので assertion が意味を持つ」方式**
→ 🔴 **実測で否定された**。`darwin`（BSD `mktemp`）では **`TMPDIR` を設定しても無視される**:

```text
TMPDIR=<sandbox> sh -c 'echo "$TMPDIR"; mktemp; mktemp -t ehprobe'
  TMPDIR inside = <sandbox>                                  ← 環境変数は伝播している
  bare  = /var/folders/.../T/tmp.pauTRMnvjW                   ← TMPDIR を無視
  -t    = /var/folders/.../T/ehprobe.iPaX4yy6Ct               ← -t でも無視
```

GNU coreutils（CI の Linux）は `TMPDIR` に従うため、**この方式は「CI では効くが開発者の macOS では空振り」という
プラットフォーム依存の穴**になる。**採用しない。**

**採用する方式** — stub hook を観測点にする（プラットフォーム非依存・実測で検証済み）:

- bridge は hook を `sh "$HOOK_SCRIPT" > <capture> 2>&1` で起動するため、**hook の `$PPID` は bridge シェルの PID** であり、
  現行実装の `/tmp/eh-bridge-out.$$` の `$$` と**同じ値**になる。
- したがって **stub hook が実行中に `/tmp/eh-bridge-out.$PPID` の存在を見れば、名前が予測可能かどうかを直接判定できる**。
- **実測（現行の未修正 bridge をサンドボックス複製して実行）**:

  ```text
  ppid=33964
  tmpdir=<sandbox>
  predictable_present=YES      ← 現行実装では予測可能名のファイルが実在する
  ```

  → **修正前は FAIL / `mktemp` 化後は PASS** となり、assertion が実際に効く。
- **E-9b（leak）**: stub の stdout にユニークマーカー（例 `PG_MARKER_<random>`）を出し、bridge 終了後に
  候補ディレクトリ（`/tmp`・`${TMPDIR:-}`・`$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null)`）を
  **マーカー文字列で検索**する。ファイル名の実装に依存せず leak を検出できる。
- **実測（`rm -f` を除去した変異を適用した場合）**: `grep -l '<marker>' /tmp/eh-bridge-out.*` が
  `/tmp/eh-bridge-out.34164` を返した（**変異 4 は kill できる**）。
- 検索対象は**実行前後の差分**に限定し、他プロセスの残骸を拾わないようにする（マーカーが一意なので実務上は十分）。

## 自動化可否

| 種別 | 対象 | 自動化 |
|---|---|---|
| Unit（bridge I/O） | TC-01〜TC-07・TC-10〜TC-12・**TC-17〜TC-20**・**TC-24** + E-1〜E-5・**E-3'**・E-7・**E-9a・E-9b・E-10・E-11・E-12** | ✅ 完全自動・課金ゼロ |
| Unit（静的） | **TC-22a**（T-01 所有・drift 検出）・**TC-22b**（T-04 所有） | ✅ 完全自動・課金ゼロ |
| Mutation | TC-08・TC-09・**TC-21**・**TC-23（4a / 4b）**・**変異 5（TC-24）** | ⚠️ 変異適用は手動、判定は自動 |
| Manual（課金ゼロ） | TC-13（**前提条件 P-1**）・TC-15・TC-16 | ⚠️ TC-13 は S-3 で自動化予定 |
| E2E（課金あり） | TC-14 | ❌ Human 承認が必要・1 回限り・**bypass フラグ禁止** |

### 実行方法（必須）

- **`sh tests/run-tests.sh`（スイート全体）で PASS すること**を完了条件とする。
  出力に **一意マーカー `PG_TA_CODEX_BRIDGE_IO_V1`** が現れることが「loader に拾われた」ことの唯一の証明であり、
  **単体実行だけで済ませると、置き場所を間違えていても気づけない**（R-F03）。
- あわせて **`TA-15`（既存テスト）が PASS のまま**であることを確認する（Task 2 で bridge の I/O が変わるため）。
