# TASK-1078 S-2 EXECUTION TODO

> 正本: [`plan.md`](./plan.md) / 受入基準: [`pbi-input.md`](./pbi-input.md) / 検証: [`test-cases.md`](./test-cases.md)
> mode = `high-risk` のため **各実装タスクに `rollback:` を必須記載**する。
> L-0 / V-1〜V-4 / PR 作成は workflow-conductor が制御するため本 TODO には含めない。

## 依存関係

> 🔴 **実行順の正本は各タスク定義の `depends_on` フィールド**（下記の図はその可読化にすぎない）。
> **下記の図・[`plan.md`](./plan.md) の「段階導入の要約」表・plan の Task 番号のいずれと食い違った場合も、
> `depends_on` を正とする**（R2-5。優先規定を todo 内部だけでなく **plan 側の表にも及ぼす**）。
> 旧版では図（`T-03 → H-01 → T-04`）とタスク定義（`T-04 ← T-03` / `T-05 ← T-04` / `H-01 ← T-05`）が
> **逆順に矛盾**しており、かつ警告文が**別のタスク ID を名指し**していた。本節はその是正版。

```text
T-00 ─┐
T-01 ─┴→ T-02 ─→ T-03 ─→ T-04 ─→ T-05 ─→ H-01(👤 Gate) ─→ T-05b ─[AC-07 PASS のみ]→ T-06 ─→ T-08 ─→ T-09
                                                              └─[AC-07 WARN]→ T-06 を実行せず T-08 へ（終端 B）
T-07（doc）は T-02 完了後いつでも可・H-01 に依存しない
H-02(👤 C-3) は exec 開始前・H-03(👤 C-4) は全タスク完了後
```

### 🔴 EIC 不変条件（証拠が不可逆変更より先）

```text
T-06 を実行してよい ⇔ T-05b で AC-07 が PASS（bypass 無しの block 証跡が存在する）
AC-07 が WARN → T-06 を実行しない → kill switch 保持 → 「Codex 側に強制力なし（現状維持）」で完了
```

**「AC-07 が WARN かつ T-06 実行済み」は完了条件違反（FAIL）**とする。
これにより「**AC 全 PASS ＋ hooks 5 件登録 ＋ 実効 block 0**」という終端は**定義上構成できない**。

### 🔴 不可逆ステップは **T-06** ただ 1 つ

⚠️ **T-06（注記キー除去＝有効化）は H-01 の承認なしに実行してはならない。** 本 PBI で唯一の不可逆ステップ。

**T-04 ではない。** 番号の取り違えを防ぐため、可逆性を明示する:

| ID | 内容 | 可逆性 | H-01 承認が要るか |
|---|---|---|---|
| T-04 | **matcher の死に文字列除去**（`Edit`/`Write`） | 可逆（`git checkout` 1 コマンド。**Codex 未登録のまま**） | 不要 |
| T-05 | `trusted_hash` **手順の文書化** + hash 範囲の実測 | 可逆（文書のみ） | 不要 |
| T-05b | **サンドボックス実走で AC-07 を確定** | 可逆（**実リポジトリ無変更**・サンドボックス削除で戻る） | **必須**（課金あり） |
| **T-06** | **注記キー除去＝有効化** | 🔴 **不可逆点**（ここで初めて Codex に登録・発火しうる） | **必須 + AC-07 PASS** |

> **plan.md の Task 番号とは別体系**である。plan「Task 4」は **Human ゲート**、todo「T-04」は **matcher 除去**。
> 対応は [`plan.md`](./plan.md) §Work Breakdown 冒頭の対応表を参照する。

## 🤖 Agent タスク

### 準備フェーズ

- [ ] **T-00**: 既存 `ta-15` の棚卸しと責務分界
  - owner: agent / depends_on: なし / AC: AC-11 の土台
  - `tests/extras/ta-15-codex-hook-bridge.sh` の 7 TC を実行し、**現行の PASS 内容**を `evidence/verification/` に記録する
  - **TC-03（`valid JSON`）と TC-04（`wires all 5 PlanGate hooks`）は、Codex が受理していない設定に対して PASS している**（緑の誤シグナル）
  - 責務分界を決める: **ta-15 = 静的検査（存在 / 構文 / top-level キー / 記述）/ 新規 extras = I/O 契約の振る舞い検査**
  - TC-03 に **top-level キー集合**の検査を足す。🔴 **実装は「stage 依存 2 値 assertion」に統一する**
    （`{description, hooks}` 一致 → enabled 分岐 / それ以外 → 「未知キーが実在する＝ kill switch が効いている」を assert。
    **どちらの分岐でも必ず 1 つ以上 assert する**）。**2 値にすることで T-06 とのコミット同期が不要**になり、
    **`depends_on: なし` のまま単独で GREEN になる**（R2-6）
  - TC-04 の文言から「wires（配線済み）」の断定を外す
  - ⚠️ **他タスクの完了を待つ要件を本タスクに持たせない**。Task 2 実施後の ta-15 回帰確認（TC-05/06/07）は **T-02 のチェックポイント**で行う
  - 🚩 チェックポイント: **「登録されていない状態で配線済みと読める表明」がゼロ** / **単独で `sh tests/run-tests.sh` GREEN**
  - `rollback:` `git checkout -- tests/extras/ta-15-codex-hook-bridge.sh`

- [ ] **T-01**: fixture と baseline テストの導入
  - owner: agent / depends_on: なし / AC: AC-01 の土台・**AC-11（TC-22a のみ。TC-22b は T-04 が所有）**
  - 実 payload 形状の fixture（`apply_patch` / `Bash`。実物は `evidence/codex-exec-spike.md` 追記 1・追記 2）
  - 🔴 **番号は契約値ではない**。着手時に `git fetch origin main && git ls-tree --name-only origin/main tests/extras/` で**次の空きを実測**する
    （**2026-08-14 時点の実測: `ta-65` / `ta-66` は main に既存 → 次は `ta-67`**。前版の `ta-65` は main が進んで stale 化した）
  - 🔴 **配置は `tests/extras/ta-67-codex-bridge-io.sh`（フラット）**。loader は `tests/run-tests.sh:165` の
    **`"$EXTRAS_DIR"/ta-*.sh` フラット glob** であり、**サブディレクトリは永久に実行されない**。
    旧版の `tests/extras/codex-bridge/run.sh` は**誤り**（CI で 1 度も走らない）
  - extras は **source される**（実行ではない）ため `pass` / `fail` を共有し、`pg_extra_contract_init "ta-<NN>" …` で共有 exit 契約に載せる
  - **stub / 実 hook は `mktemp -d` サンドボックスへ配置**する。bridge を `<sandbox>/.codex/hooks/` に複製すると
    `REPO_ROOT` がサンドボックスへ移るため、**`scripts/**` を 1 行も触らずに検証できる**（bridge に解決先 override を新設しない）
  - **env（`PLANGATE_HOOK_TASK` / `PLANGATE_HOOK_STRICT` / `PLANGATE_DELEGATION_NOCOMMIT`）を必ず明示設定**する（継承禁止・unset は `env -u`）
  - bridge 呼び出しは **必ず stdin を与える**（`INPUT=$(cat)` のハング回避）
  - 期待値は **実行結果で確定**する（plan の実測表からの転記で固定しない。差分が出たら plan 側を訂正）
  - **`tests/extras/README.md` の一覧表に新規テストの行を追記**する（既存規約 / R2-4）
  - 🔴 **一意マーカー `PG_TA_CODEX_BRIDGE_IO_V1` を出力する**（到達性判定に使う。導入時に `grep -r` で衝突が無いことを確認）
  - 🔴 **本タスクで入れる stage 依存 TC は TC-22a（2 値）まで。TC-22b（matcher に `Edit`/`Write` 無し）は T-04 が所有**する。
    T-01 で TC-22b を入れると **T-01〜T-03 の完了条件（スイート全体 GREEN）を満たせなくなる**（R2-1）
  - 🔴 **E-9（一時ファイル）の検査は `TMPDIR` に依存させない**。`darwin` の BSD `mktemp` は `TMPDIR` を無視することを実測済み。
    **stub hook が `$PPID` から予測可能名の不在を観測する方式**を使う（設計と実測は `test-cases.md` の E-9 設計根拠）
  - 🚩 チェックポイント: **`sh tests/run-tests.sh` の出力に `PG_TA_CODEX_BRIDGE_IO_V1` が現れる**こと
    （🔴 **番号（`TA-NN`）で判定しない**。`ta-65` は #1089 の既存テストが `=== TA-65: …` を出力するため、
    **未配置でも真になる**ことを実測済み＝ R3-F5）/ `.codex/` と `scripts/` に差分が無いこと
  - `rollback:` `git rm tests/extras/ta-67-codex-bridge-io.sh` + fixtures — ランタイム影響なし

### 実装フェーズ

- [ ] **T-02**: bridge の I/O 契約修正（TDD）
  - owner: agent / depends_on: T-01, T-00 / AC: AC-01・AC-02・AC-04・AC-05・AC-10・AC-12
  - 期待値を修正後契約に更新 → **RED 確認** → 実装 → **GREEN 確認** の順を守る
  - 実装内容:
    (a) stdin 転送
    (b) stdout / stderr の分離捕捉 + **一時ファイルの `mktemp` 化と確実な削除**（現行 `/tmp/eh-bridge-out.$$` は予測可能名）
    (c) **判定は stdout と exit code の 2 つ**（**stderr は判定に使わない**。「stdout のみ」と書くと EH-3 の `rc=2` deny を落とす）
    (d) 未知 rc → deny（fail-closed・reason に rc）
    (e) `scripts/hooks/` → `scripts/` フォールバック（無ければ deny）
    (f) deny の reason 常時非空
    (g) **`apply_patch` の複数パス全件評価**（`re.search` → 全件。1 件でも deny なら deny。困難なら「複数パスは deny」の fail-closed 代替。**allow に倒さない**）
    (h) **壊れた JSON → deny / valid だが object でない JSON（`null`・配列・文字列）→ deny / 空 stdin → allow**
    （根拠は plan の「fail 方向の contract」。**`isinstance(d, dict)` を明示判定する**。
    現行は `AttributeError` で python が rc=1 終了し、シェルの `2>/dev/null || echo ""` により
    **黙って「パス不明」レーンへ落ちている**ことを実測済み＝ R2-8）
    (i) **一時ファイルの `mktemp` 化は `TMPDIR` に依存させない**（BSD `mktemp` が `TMPDIR` を無視することを実測済み）
  - 🚩 チェックポイント: `scripts/**` と `.claude/**` に差分が無いこと（HO 不可侵）/ 一時ファイルが残らないこと /
    **既存 `ta-15` の TC-05・TC-06・TC-07 が PASS のままであること**（T-00 から移した回帰確認＝ R2-6）
  - `rollback:` `git checkout -- .codex/hooks/eh-bridge.sh` — **この時点では Codex 未登録のため無害**

- [ ] **T-03**: 変異注入によるテスト検出力の実証
  - owner: agent / depends_on: T-02 / AC: AC-03
  - 変異 1: stdin 転送を戻す → **EH-9 ケース（TC-01 / TC-02）が FAIL** すること
  - 変異 2: stdout 判定を戻す → **EH-1 / EH-2 ケース（TC-04 / TC-17）が FAIL** すること
  - 変異 3: 複数パス抽出を `re.search` に戻す → **TC-19 が FAIL** すること
  - 変異 4a: 一時ファイル名を `/tmp/eh-bridge-out.$$` に戻す → **E-9a が FAIL** すること（TC-23）
  - 変異 4b: 一時ファイルの `rm -f` を除去する → **E-9b が FAIL** すること（TC-23）
  - 変異は **call site（bridge の該当行）を壊す**。テスト側の期待値を書き換えて FAIL を作らない
  - **FAIL を起こせなかった TC は「空振り」として handoff の乖離帯に記録する**
  - 変異 5: reason のシリアライザ生成を文字列連結に戻す → **TC-24 が FAIL** すること（R3-F2）
  - 🚩 チェックポイント: **6 変異（1 / 2 / 3 / 4a / 4b / 5）とも FAIL** を確認し、**元に戻したうえで GREEN** を再確認する
  - `rollback:` 変異は一時適用のみ。`git checkout -- .codex/hooks/eh-bridge.sh` で復帰

- [ ] **T-04**: matcher の死に文字列除去（**可逆・H-01 不要**）
  - owner: agent / depends_on: T-03 / AC: AC-11
  - `apply_patch|Edit|Write` → `apply_patch`。`Bash` group は不変。**注記キーは残す**（＝未登録のまま）
  - 🔴 **同一コミットで TC-22b（matcher に `Edit`/`Write` が無い）を新規 extras に追加する**（**本タスクが TC-22b の所有者** / R2-1）
  - ⚠️ **「挙動不変」と書かない**（R2-9）。matcher をリテラル完全一致として解釈する semantics では
    現行の `apply_patch|Edit|Write` は**何にもマッチしない**ため、本変更は「不変」ではなく **0→1 の有効化**になりうる。
    正確には「**`apply_patch` へのマッチを減らさない / この時点ではランタイム影響なし**」
  - **U-7（matcher の一致仕様）はこのタスクの gating ではない**: alternation の 1 項を残す変更のため、
    完全一致・部分一致のいずれでも `apply_patch` へのマッチは減らない
  - 🚩 チェックポイント: `hooks/list` が依然 PlanGate hook **0 件** + 同一 warning（＝未有効化のまま）。
    **この時点では matcher 文字列を観測できない**（0 件のため）。観測は T-06 後に行う
  - `rollback:` `git checkout -- .codex/hooks.json`

### 検証フェーズ

- [ ] **T-05**: `trusted_hash` 手順の確立（T-06 の前提・**可逆・H-01 不要**）
  - owner: agent / depends_on: T-04 / AC: 前提条件 P-1 / P-3・AC-09
  - `hooks.json` 編集後に hash が変わることを踏まえ、「編集 → 再 trust」の手順を文書化する
  - hash は **hook 単位**（同一ファイル内の別 matcher group は個別）である点を明記する（evidence L74）
  - 🔴 **`trusted_hash` は `CODEX_HOME/config.toml` のローカル状態で git に乗らない**ことを明記する。
    **マージ後、著者以外の全クローンは「登録される / 発火するかは不明」状態に入る**（R-7）
  - `rollback:` 不要（手順記述のみ・`CODEX_HOME` 側の設定変更は Human が実施）

- [ ] **T-05b**: 🔴 サンドボックス実走で **AC-07 を確定**（**T-06 の前**・課金あり 1 回）
  - owner: agent / depends_on: **H-01（承認）** / AC: AC-07
  - `mktemp -d` の git init 済みサンドボックス + 隔離 `CODEX_HOME` を用意する
  - **実リポジトリの `.codex/hooks/eh-bridge.sh`（T-02 修正後）と `scripts/hooks/*.sh` をそのまま複製**する（改変しない）
  - サンドボックスの `hooks.json` を **T-06 適用後の目標形と同一内容**にする（実リポジトリの `.codex/hooks.json` は**変更しない**）
  - `hooks/list` で 5 件・`warnings[]` 空を確認し `trusted_hash` を付与する
  - `codex exec` を **1 回**。🔴 **`--dangerously-bypass-hook-trust` を付けない** / 非 `--ephemeral` / deny 対象を先 / retry 禁止を明示
  - **block を観測 → AC-07 = PASS（T-06 へ進んでよい）** / **観測できない → AC-07 = WARN（T-06 に進まない・bypass で再走しない）**
  - 🚩 チェックポイント: 判定を **T-06 の実行可否として `status.md` に記録**する
  - `rollback:` サンドボックスを削除するだけ（**実リポジトリは無変更**）

- [ ] **T-06**: 注記キー除去＝**有効化**（🔴 **唯一の不可逆ステップ** / **AC-07 PASS が前提**）
  - owner: agent / depends_on: **H-01（承認）+ T-05b で AC-07 = PASS** / AC: AC-11 + 前提条件 P-1
  - 🔴 **ゲート**: **AC-07 が WARN なら本タスクを実行しない**（EIC 不変条件。kill switch を保持して終端 B へ）
  - **同一コミットで TC-22a の宣言 stage を `disabled` → `enabled` に更新する**（R3-F3）
  - top-level を `description` / `hooks` の 2 キーのみにする
  - `hooks/list` で 登録 5 件・`warnings[]` 空・`enabled` true・`trustStatus` を確認する（**P-1 の確認。成果ではない**）
  - **TC-22a が `enabled` 分岐で PASS すること**を確認する（宣言 stage を更新済みなので drift なし）
  - matcher 文字列と件数を記録する（U-7 の観測。**gate ではない**）
  - `sh tests/run-tests.sh` 全体 GREEN を確認する
  - ⚠️ **本タスクで `codex exec` は実行しない**（実走は T-05b で完了済み。**課金実走は S-2 全体で 1 回**）
  - 🔴 **bypass 付きで得た block を AC-07 の根拠にしない**（既存 evidence の block はすべて bypass 付き＝ U-4 未解決）
  - **参考: T-05b で block が観測できなかった場合**は AC-07 を **WARN** とし、(a) 使用コマンドと `trustStatus` /
    (b) **U-4 が否定側に確定したこと** / (c) `trusted_hash` の実行時有効性検証を **S-4 の前提**とすること、を記録する。
    **bypass を付けて再走しない**
  - 🚩 チェックポイント: **登録件数を成果として報告しない**
  - `rollback:`
    1. **即時無効化**: top-level に **未知キーを 1 行足す**（例 `"$note"`）→ Codex が受理せず全件未登録に戻る（双方向再現済み）。
       **JSON 構文を壊す方法は使わない**（他ツールを巻き添えにする）
    2. `git revert <T-06 commit>`
    3. 緊急時は `PLANGATE_BYPASS_HOOK=1`

- [ ] **T-07**: 責務分界の曖昧さ解消（doc）
  - owner: agent / depends_on: T-02 / AC: AC-09
  - `docs/ai/settings-wiring-contract.md` の責務分界節を**パス単位の表**へ置換し、機械判定（HO 9 カテゴリに `.codex` が無いこと）との一致を明記する
  - **軸 C（強制力）に S-2 の限界 4 点を書く**:
    (a) bridge 単体の deny は実証済み / (b) ランタイム発火は AC-07 の結果に従う（WARN なら「未実証」と書く）/
    (c) **`trusted_hash` 未設定環境では強制力を保証しない** / (d) **TASK 文脈下の HO block は #1089 のため効かない**
  - `rollback:` `git checkout -- docs/ai/settings-wiring-contract.md`

### 完了フェーズ

- [ ] **T-08**: 非回帰の証明
  - owner: agent / depends_on: **T-06（実行した場合）または T-05b（AC-07 = WARN で T-06 を実行しない場合）** / AC: AC-08
  - **基点を固定して**差分 0 を示す: `git diff $(git merge-base HEAD origin/main) -- scripts .claude`。
    🔴 **対象は `scripts` 全体**（`scripts/hooks` に絞らない）。T-02 (e) で **`scripts/` 直下**のフォールバックを新設するのに、
    そのディレクトリが非回帰検査の対象外だった（R3-F7d）
    **使用した base SHA を evidence に併記**する（`git diff origin/main` は動く基点で、無関係な他 PR の変更を拾う）
  - あわせて **`sh tests/run-tests.sh` 全体 PASS**（ta-15 を含む既存テストの非回帰）を保存する
  - `rollback:` 不要（読取のみ）

- [ ] **T-09**: status.md 追記 / handoff.md 発行
  - owner: agent / depends_on: T-08
  - `status.md` は**既存記述を改変せずフェーズ履歴を追記**する（S-1 の記録は別ワーカーの成果）
  - **どちらの終端に着地したかを明記**する: **終端 A**（AC-07 PASS・T-06 実行・有効化済み）/
    **終端 B**（AC-07 WARN・T-06 未実行・**kill switch 保持＝ Codex 側は現状維持**）
  - AC-07 が WARN の場合は理由・代替・未充足リスクを handoff に必須記載する
  - **「現時点で Codex 側が実際に止められるもの」を列挙**する（EH-9 は `NOCOMMIT=1` 時のみ / EH-3 は TASK 未設定時のみかつ #1089 の制約下 /
    EH-1・EH-2・EH-6 は STRICT 既定 warning のため **0**）。**「11 wiring 分の強制力が揃った」とは書かない**
  - `rollback:` 不要（文書のみ）

## 👤 Human タスク

- [ ] **H-01（C-3 相当の追加ゲート / exec 中の有効化判断）**
  - depends_on: T-05
  - 🔴 **一体の設問**（**分割して答えられない形にする** / R3-F1）:

    > **「サンドボックス実走 1 回（課金あり・bypass 無し）を許可し、その結果が PASS だった場合に限り
    > `.codex/hooks.json` の注記キー除去（不可逆な有効化）まで進めてよいか？」**
    >
    > - **Yes** → T-05b を実行 →（AC-07 = PASS のときのみ）T-06
    > - **No** → **実走も有効化も行わない**。AC-07 = WARN で終端 B に着地

  - ⚠️ **「有効化は可・実走は不可」という承認は成立させない**。
    それを許すと**証拠ゼロのまま不可逆な有効化だけ**が実行される（旧版で成立していた最悪経路）。
    逆の「実走は可・有効化は不可」は**許される**（安全側）
  - 判断材料:
    1. 有効化後の deny 範囲（plan の実測表 + T-01 で再現したログ）
    2. `CODEX_HOME` 側 `trusted_hash` 設定の適用（**外部状態の変更＝Human-owned**）
    3. **AC-07 が WARN で終わる可能性**（U-4 未解決。bypass 無しでの発火は未実証）
    4. **TC-18（EH-6 の deny）が課金ゼロで再現できたか**。できていない場合、
       **配線 5 本のうち 1 本は deny 経路が未検証のまま有効化することになる**
    5. **T-05 Step 4 の実測結果**（`trusted_hash` に bridge 内容が含まれるか。含まれないなら
       **trusted 済み環境で AI が bridge を書き換えるだけで強制力を消せる**）
  - ⚠️ この承認が無い限り **T-05b にも T-06 にも進まない**（自己設置 Gate。`/goal` や autonomy 指示では解除されない）

- [ ] **H-02（C-3 ゲート・本 plan の承認）**
  - `high-risk` のため **autonomous APPROVE 不可**。人間の同期 C-3 が必須
  - `approvals/c3.json` の発行は Human（AI は作成しない）

- [ ] **H-03（C-4 ゲート・PR レビュー）**
  - merge は Human-owned 固定

## 完了条件

> **「受入基準（AC）」と「前提条件（P）」を分ける**。P は充足しても成果ではない（[`pbi-input.md`](./pbi-input.md) 参照）。

- **AC-01〜AC-05・AC-08〜AC-12 が PASS**（**AC-06 は欠番** — 登録は前提条件 P-1 へ移動）
- **AC-07 が PASS、または WARN（理由・代替・未充足リスクを記録）**
- 🔴 **EIC 不変条件**: **「AC-07 が WARN かつ T-06 実行済み」は完了条件違反（FAIL）**。
  終端は次の 2 つのいずれかでなければならない:
  - **終端 A**: AC-07 = PASS / T-06 実行済み / `hooks/list` 5 件 / 宣言 stage = `enabled`
  - **終端 B**: AC-07 = WARN / **T-06 未実行** / `hooks/list` **0 件**（kill switch 保持）/ 宣言 stage = `disabled`
- **前提条件 P-1（`hooks/list` の登録）は終端 A の場合のみ充足**（成果としては報告しない）
- **`sh tests/run-tests.sh` が全体 PASS**（出力に **一意マーカー `PG_TA_CODEX_BRIDGE_IO_V1`** と `TA-15` が現れること。**番号で判定しない**）
- `scripts/**` / `.claude/**` に差分 0（基点は `git merge-base HEAD origin/main`）
- `handoff.md` が必須 6 要素を満たして発行済み。**S-2 の限界 4 点**（bridge 単体 / ランタイム発火の状態 /
  `trusted_hash` 未設定環境 / #1089 の TASK 文脈）が書かれている
