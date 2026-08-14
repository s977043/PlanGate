# PBI INPUT PACKAGE: #1078 S-2 — Codex hook bridge の I/O 契約修正

> フェーズ A（PBI INPUT）。正本: [`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md) の「pbi-input.md」節。
> 本 PBI は [#1078](https://github.com/s977043/plangate/issues/1078) のスライス **S-2**。S-1（文書是正）は PR #1080 / #1083 で完了済み。

## Context / Why

`.codex/hooks.json` は top-level の仕様外キー 2 つ（`$schema_note` / `$note`）により **Codex に受理されず**、
PlanGate の hook は Codex ランタイムに **1 件も登録されていない**（`hooks/list` 実測。証跡: [`evidence/codex-exec-spike.md`](./evidence/codex-exec-spike.md)）。

> ⚠️ **「parse 拒否」の正確な意味**: 当該ファイルは **JSON 構文としては valid** である
> （`python3 -m json.tool` は rc=0。既存テスト `tests/extras/ta-15-codex-hook-bridge.sh` の TC-03 が PASS しているのはこのため）。
> 拒否しているのは **Codex 側のスキーマ層**（top-level に許されるのは `description` / `hooks` のみ）。
> したがって「JSON が壊れている」という表現は使わない。

しかし **注記キーを消すだけでは強制力は回復しない**。`.codex/hooks/eh-bridge.sh` が
PlanGate hook の I/O 契約に合っていないため、登録されても **allow に倒れ続ける**。
その状態は「`hooks/list` に 5 件登録・warnings 空」という**緑のシグナルだけが増え、実態は 0 のまま**という、
issue #1078 が潰そうとしている「**登録 ≠ 強制力**」の誤りを**是正行為そのものが再生産する**経路になる。

本 PBI 計画時の実測（本ファイル記載の全数値は sandbox 実測。詳細は [`plan.md`](./plan.md) §前提の実測検証）で、
**支配的な欠陥が stdin ではなく出力契約であること**が判明した:

| 事実 | 実測 |
|---|---|
| 配線済み 5 hook のうち **4 本（EH-1 / EH-2 / EH-6 / EH-9）は block を `rc` で表さない** | block 時も **`rc=0`**、stdout に `{"continue":false,"stopReason":...}` を出す |
| bridge は **rc だけ**で allow/deny を決める（`:79-90`） | 上記 4 本の block 判定は **bridge で捨てられる** |
| **stdin 転送だけを実装しても deny は 1 件も増えない** | 18 ケース × STRICT × TASK の 4 条件で **現行 bridge と完全一致** |
| stdin 転送の固有の寄与は **EH-9（Bash command 判定）1 本のみ** | 出力契約のみ修正 → EH-9 は allow のまま / 両方修正 → deny |

したがって S-2 は「stdin 転送 1 点」ではなく **入力・出力の両方を含む I/O 契約の修正**である。

## What（Scope）

### In scope

- `.codex/hooks/eh-bridge.sh` の I/O 契約修正
  - **入力**: 受け取った stdin JSON を hook へ**そのまま転送**する（Codex の入力経路は stdin のみ）
  - **出力**: hook の **stdout を判定チャネル**として解釈する（`{"continue":false}` / `permissionDecision:"deny"` → deny）。**stderr は判定に使わない**（reason 生成のみ）
  - **未知 exit code の fail-closed 化**（現行は allow に落とす fail-open）
  - hook 実体の解決を `scripts/hooks/` 固定から **`scripts/hooks/` → `scripts/` の順**へ拡張
  - **複数ファイルを含む `apply_patch` の全パス評価**（現行は `re.search` で**先頭 1 件のみ**＝後続パスが無検査）
  - **判定用一時ファイルの `mktemp` 化**（現行は `/tmp/eh-bridge-out.$$` ＝ 予測可能名）
  - **stdin 異常系の fail 方向の確定**（壊れた JSON → deny / 空 stdin → allow。根拠は plan に記載）
- `.codex/hooks.json` の matcher から Codex に存在しないツール名（`Edit` / `Write`）を除去
- **既存テスト `tests/extras/ta-15-codex-hook-bridge.sh` の棚卸し**（同一対象を検査しており、
  「登録されていない設定」に対して `valid JSON` / `wires all 5 hooks` と緑を出し続けている。責務分界と表明文言の是正）
- `.codex/hooks.json` の注記キー除去（`$schema_note` / `$note` → `description`）。**ただし上記の修正が検証済みになるまで実施しない**
- bridge の I/O 契約に対する **fixture 駆動の自動テスト**（実 payload 形状・課金ゼロ）
- `hooks/list` による登録状態の確認手順（**受入基準ではなく前提条件**として扱う）
- `docs/ai/settings-wiring-contract.md` の責務分界節の曖昧さ解消（下記 Notes 参照）

### Out of scope

- **EH-13 / EH-12 の新規配線**（S-2 では行わない。理由と前提条件は plan の「後続への申し送り」に記す）
- `scripts/hooks/*.sh` および `scripts/*.sh` の hook 本体の改変（**HO パス / Human-owned**）
- `.claude/settings.json` / `.claude/settings.example.json` の変更（Human-owned）
- `PLANGATE_HOOK_STRICT` の既定値変更（Claude / Codex いずれも現状 未設定＝warning 既定。**本 PBI で既定を変えない**）
- `.codex/skills` の同期（#1078 の別スライス）
- `hooks/list` 検査の doctor / CI 組み込み（**S-3**）

## 受入基準

- [ ] **AC-01**: 実 Codex payload 形状の fixture を入力したとき、`eh-bridge.sh` が **deny を返すべきケースで deny を返す**ことが、課金ゼロの自動テストで示される（対象: EH-9 の commit/push 境界、EH-3 の HO パス、EH-2 の C-3 未承認）
- [ ] **AC-02**: 同テストが **allow を返すべきケースで allow を返す**（誤検出ゼロ側）。通常の実装作業に相当する payload が deny されないことを含む
- [ ] **AC-03**: AC-01 のテストが **修正前の bridge では FAIL する**ことを、変異注入（stdin 転送の除去 / stdout 解釈の除去 を個別に戻す）で示す（テストの検出力の実証）
- [ ] **AC-04**: hook が **stderr にのみ** block 相当の文字列を出した場合に **deny にならない**
      （**判定に使うのは stdout と exit code の 2 つで、stderr は使わない**。「stdout のみ」と短縮すると EH-3 の `rc=2` deny を落とすため使わない）
- [ ] **AC-05**: 未知 exit code（例 `127`）で **deny** が返る（fail-closed）。かつ deny の `permissionDecisionReason` が**常に非空**であり、
      🔴 **bridge の出力が常に valid JSON である**（reason 素材に `\` / 制御文字 / 日本語が入っても壊れない。
      切り詰めは**文字境界**を守る）。**全 deny TC で `json.loads` 可能性を検査する**（部分文字列一致だけで PASS にしない）
- [ ] ~~**AC-06**~~ **欠番**。「`hooks/list` への登録」は**受入基準ではなく前提条件 P-1 へ移動**した（下記「前提条件（Preconditions）」）。
      理由: **AC は定義上 完了ゲートである**ため、免責文を添えても「登録できたら 1 項目クリア」と読める構造が残る。
      本 PBI が潰そうとしている誤り（**登録 ≠ 強制力**）を受入基準の形で再生産しないよう、AC の外に出す。番号は再採番せず欠番のままにする
- [ ] **AC-07**: **Codex セッションで実際に block された証跡**（stderr の `Command blocked by PreToolUse hook:` + 対象ファイルが生成されていないこと）が 1 件取得される。
      🔴 **取得は「実リポジトリの kill switch を撤去する前に、サンドボックスで」行う**
      （実リポジトリの `eh-bridge.sh` と `scripts/hooks/*.sh` をそのまま複製し、hooks.json は有効化後の目標形と同一内容にする）。
      🔴 **本 AC の判定が「注記キー除去（不可逆な有効化）を実行してよいか」を決める**。
      **PASS のときのみ有効化してよく、WARN なら有効化しない**（EIC 不変条件）。
      **必須条件 1: 当該実走で `--dangerously-bypass-hook-trust` を使わない**（使った場合は PASS にしない）。
      🔴 **必須条件 2（env の固定）: `PLANGATE_HOOK_STRICT` を本番既定（未設定）のままにする**。
      **STRICT を上げれば EH-1 / EH-2 が広く deny するため block は容易に取れるが、
      plan 自身が「STRICT 既定 warning のため S-2 完了後も EH-1/2/6 は Codex で block しない」と書いている以上、
      それは「サンドボックスで PASS・本番で実効ゼロ」を意味する**。**STRICT を上げないと block が取れないなら AC-07 = WARN**。
      deny 対象は **実運用に実在する条件**（EH-9 × `NOCOMMIT=1`、または EH-3 HO × `HOOK_TASK` 未設定）に固定し、
      **使用 env 一式を evidence に逐語で残す**。
      **AC-07 = PASS は「常に block する」ではなく「その運用条件で block する」を意味し、条件を doc に列挙する**。
      取得には `codex exec` の実走 1 回を要するため **Human の明示承認**を前提とする。
      承認が得られない場合、または **bypass 無しでは発火しなかった場合**は AC-07 を **WARN（未達・理由記録）** とし、
      `settings-wiring-contract.md` の軸 C を「**bridge 単体では deny を返すところまで実証／ランタイム発火は未実証（U-4）**」と明記する
- [ ] **AC-08**: `.claude` 側の hook 挙動が**無傷**である（**`scripts` 全体**および `.claude` に差分が無いことを diff で示す。
      🔴 **`scripts/hooks` に絞らない** — `scripts/` 直下フォールバックを新設するため。**基点は `git merge-base HEAD origin/main` で固定**する）
- [ ] **AC-09**: `docs/ai/settings-wiring-contract.md` の「既存 hook 改変は Human-owned」の適用範囲が**パス単位で一意に読める**記述になる。
      あわせて **S-2 の強制力の限界**が明記される:
      (a) bridge 単体 / (b) ランタイム発火の状態（**終端 A1 = 実リポジトリで実測 / 終端 A2 = サンドボックス実測・実リポジトリ未観測 /
      終端 B = 未有効化・現状維持**。**A2 を「実リポジトリで block する」と書かない**）/
      (c) **`trusted_hash` 未設定環境は対象外** / (d) **TASK 文脈下の HO block は #1089 のため効かない** /
      (e) 🔴 **`trusted_hash` に bridge 内容が含まれるかの実測結果**（含まれないなら「trusted 済み環境では AI が bridge 改変で強制力を消せる」）/
      (f) **`$(git rev-parse --show-toplevel)` の CWD 依存**（ネスト repo / submodule / 別 worktree で別リポジトリの bridge が解決されうる）/
      (g) **`PLANGATE_BYPASS_HOOK=1` は被規制主体の agent 自身が設定できる**（強制力の主張から除外する）/
      (h) **現時点で Codex 側が実際に止められるものの列挙**（EH-9 は `NOCOMMIT=1` 時のみ / EH-1・EH-2・EH-6 は STRICT 既定 warning のため 0）。
      **「11 wiring 分の強制力が揃った」とは書かない**
- [ ] **AC-10**: **複数ファイルを含む `apply_patch` payload** で、**2 件目以降のパスも検査される**（無害なパスを先頭に置いて HO パスを後続に隠す入力が **deny される**）。
      全件評価が困難な場合の代替は「複数パスを含む `apply_patch` は deny」（fail-closed）とし、**allow に倒す実装は不可**
- [ ] **AC-11**: `.codex/hooks.json` が **Codex に受理される形**である（**top-level キーが `description` / `hooks` のみ**）ことと、
      matcher に **Codex に存在しないツール名（`Edit` / `Write`）が含まれない**ことが機械的に検査される（JSON 構文 valid だけでは不十分）。
      検査は **「テスト内に宣言した期待 stage」と「実体」の drift 検出**とし、
      **有効化後に kill switch を戻された場合も、未有効化のまま誤って有効化された場合も FAIL** になること。
      かつ **どの段階でもスイートが RED にならない**こと（宣言は該当タスクのコミットで更新する）
- [ ] **AC-12**: hook 実体の解決が **`scripts/hooks/<name>` → `scripts/<name>` の順にフォールバック**し、
      どちらにも無い場合のみ **deny（reason 非空）** になる（stub による課金ゼロ検証）

## 前提条件（Preconditions / 完了条件ではない）

> **受入基準と分けて書く**。ここが充足しても本 PBI の成果にはならない。逆に**ここが未充足なら AC-07 の判定に進めない**。

- **P-1（登録状態）**: 注記キー除去後、`hooks/list` が PlanGate hook を **期待件数だけ登録**し `warnings[]` が空で、
  各 hook の `enabled` が true。`trustStatus` も記録する（`trusted` 表示は**発火の証明ではない** — U-4）。
- **P-2（Human 承認）**: AC-07 の実走 1 回（課金あり）について Human の明示承認がある。
- **P-3（trust 設定）**: `CODEX_HOME/config.toml` の `trusted_hash` 付与は **Human-owned の外部状態変更**であり、AI は手順提示までを担う。

## 完了条件

- **AC-01〜AC-05・AC-08〜AC-12 が PASS**
- **AC-07 が PASS、または WARN（理由・代替・未充足リスクを記録）**
- 🔴 **EIC 不変条件: 「AC-07 が WARN かつ 注記キー除去（有効化）を実行済み」は完了条件違反（FAIL）**。
  終端は次のいずれかでなければならない:
  - **終端 A1**: AC-07 = PASS / 有効化済み / **実リポジトリでの発火を観測**（確認実走 2 回目）/ `hooks/list` 5 件
  - **終端 A2**: AC-07 = PASS / 有効化済み / **実リポジトリ未観測**（doc に「サンドボックス実測／実リポジトリ未観測」と明記）/ `hooks/list` 5 件
  - **終端 B**: AC-07 = WARN / **未有効化** / `hooks/list` **0 件**（kill switch 保持）/ 宣言 stage = `disabled` /
    **回復経路（U-4 の観測結果と再開条件）が issue として起票済み**
- **前提条件 P-1 は終端 A の場合のみ充足**（成果としては報告しない）
- `scripts/**` / `.claude/**` に差分 0
- `handoff.md` が必須 6 要素を満たして発行済み

## Notes from Refinement

- **順序の逆転を禁止**する。注記キーの除去は **最後**。理由は「除去すると使用不能になるから」ではなく（それは誤りで、実測は allow）、**除去が先行すると無効なガードが「登録済み」に見える**ため。
- **注記キーは事実上の kill switch として機能する**。除去前は bridge をどれだけ変えても Codex ランタイムには一切影響しない（parse 拒否のため）。これを**段階導入の安全装置として明示的に利用する**。
- **責務分界の曖昧さ**: `settings-wiring-contract.md` の責務分界節は「新規 hook 追加（`.codex/hooks.json` / `.codex/hooks/*.sh`）は AI-owned」の直後に「既存 hook 改変は Human-owned」と書いており、**`eh-bridge.sh` の改変がどちらに当たるか読めない**。機械判定（`check-plan-hash.sh` の HO case 文）では `.codex/**` は **HO 対象外**であり、AI 改変を技術層で block していない。→ 解消案は plan の該当節。
- 🔴 **未確定（U-4）**: **`--dangerously-bypass-hook-trust` 無しで Codex の PreToolUse hook が発火するかは未実証**。
  `evidence/codex-exec-spike.md` の 3 回の実走で **block が観測できたのはすべて bypass フラグ付き**であり
  （L287: `trustStatus=untrusted` のまま bypass で発火）、**bypass 無しで発火した観測は 1 件も無い**（L99: trusted な probe の呼び出し回数 **0**）。
  さらに L109 は「手書き `[hooks.state]` の trust は **`hooks/list` には反映されるが実行時には効かない**」を失敗候補として挙げている。
  → **「`hooks/list` が `trusted` なら発火する」という前提は取れない**。AC-07 は bypass 無しで判定し、
  未発火なら **WARN 固定**＋`trusted_hash` の実行時有効性検証を **S-4 の前提**として申し送る。
- **配布境界（R-7）**: `trusted_hash` は各利用者の `CODEX_HOME/config.toml` にあり **git 管理外**。
  main にマージした時点で、著者以外の全クローンは「登録される / 発火するかは不明」状態に入る。
  **S-2 が強制力を保証できるのは trusted 設定済み環境のみ**であることを doc に明記する（AC-09）。
- **#1089 との切り分け**: `PLANGATE_HOOK_TASK` が設定された状態では EH-3 の Hardening Override block が発火しない
  （`check-plan-hash.sh` の HO 判定が `if [ -z "$task_id" ]` の内側）。これは **本 PBI の scope 外**（HO パス / Human-owned）。
  S-2 完了後も残る限界として doc と handoff に明記する。

## Estimation Evidence

### Risks

- **R-1（最大）**: 「登録された」を「効いている」と誤認したまま完了宣言する。
  → **登録を受入基準から外し前提条件 P-1 とした**（AC 化されていれば「1 項目クリア」と読まれるため）。AC-01 / AC-07 で担保。
- **R-2**: 未知 exit code の fail-closed 化により、hook の実行時エラーが**全操作の deny**に化ける。→ 注記キー（kill switch）による即時無効化手順を rollback に明記。
- **R-3**: stdout / stderr を混ぜて判定すると、**stderr の警告文字列で false deny** が起きる（本計画時に実測で再現済み）。→ AC-04。
- **R-4**: `PLANGATE_HOOK_TASK` がセッション環境から**継承**され、hook の判定を変える（本計画時に実測で遭遇。TASK を与えると EH-3 の HO block が消えた）。→ テストは env を明示的に制御する。
- **R-5**: U-4 が「untrusted は発火しない」だった場合、S-2 単独では AC-07 を満たせない。

### Unknowns

- **U-4（最重要）**: project hook が **`--dangerously-bypass-hook-trust` 無しで**実行時に発火するか。**反証寄りの実測がある**（上記）。
- **U-5**: `codex exec`（非対話）が PreToolUse hook を評価する条件（run #1 は `--ephemeral` あり・bypass 無しで probe 0 回。run #2 で 2 変数を同時に変えたため未切り分け）。
- **U-6**: Codex が 1 つの matcher group に複数 hook を並べたとき、**最初の deny で打ち切る**か全件実行するか（bridge の設計には影響しないが、証跡の読み方に影響する）。
- **U-7（gating ではない）**: Codex の matcher が完全一致か部分一致か。`apply_patch|Edit|Write` → `apply_patch` は
  **どちらの解釈でも `apply_patch` へのマッチを減らさない**ため、T-04 の実施を妨げない。観測は Stage 3 で行う。

### Assumptions

- Codex の PreToolUse payload 形状は [`evidence/codex-exec-spike.md`](./evidence/codex-exec-spike.md) の
  **追記 1（L189-196）/ 追記 2（L292-298）に載っている実 payload 実物**どおり
  （`tool_name` は `apply_patch` / `Bash` のみ、入力は stdin のみ、`CODEX_HOOK_*` env は存在しない）。
  ⚠️ 旧版が参照していた `evidence/codex-payload-spike.md` は**本ブランチに存在しない**（PR #1088・未マージ）。**参考リンクとしてのみ扱う**。
- **非空 reason の deny は Codex ランタイムで実際に block される**（3 回目実走で確定）。空 reason の deny は**黙って握り潰される**。
  ⚠️ ただしこの実測は **bypass フラグ付きの run** であり、「**deny が伝われば止まる**」ことの証明であって
  「**通常運用で hook が呼ばれる**」ことの証明ではない（U-4）。
- `PLANGATE_HOOK_STRICT` は Claude / Codex いずれの設定にも無く、既定は warning。
