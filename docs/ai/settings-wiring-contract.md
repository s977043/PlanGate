# settings wiring 契約（正本 / TASK-0080 S1）

> `.claude/settings.json` が満たすべき PreToolUse hook wiring の**正本**。
> `bin/plangate doctor --check-settings` がこの契約と実体を突合する。
> 適用は `scripts/apply-claude-settings.sh`（**ユーザー実行**。AI は
> self-mod ガードで `.claude/settings.json` を編集できないため）。

## 必須 PreToolUse hooks（matcher: Edit|Write 系）

| Hook | command（必須トークン） |
|------|------------------------|
| EH-1 plan-exists | `scripts/hooks/check-plan-exists.sh` |
| EH-2 c3-approval | `scripts/hooks/check-c3-approval.sh` |
| EH-3 plan-hash | `scripts/hooks/check-plan-hash.sh ${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}` |
| EH-6 forbidden-files | `scripts/hooks/check-forbidden-files.sh` |
| EH-9 delegation-commit-boundary | `scripts/hooks/check-delegation-commit-boundary.sh` |

### 契約ポイント

- **EH-3 は `${PLANGATE_HOOK_FILE:-}` を第2引数に含む**（P4(d) ファイルパス
  感応 SKIP / TASK-0070 AC-8。これが本セッション通底の未適用 wiring）。
- **EH-9 wiring が存在する**（委譲 commit 境界 / TASK-0073）。
- 上記トークンが `.claude/settings.json` の PreToolUse command 群に
  すべて存在すれば `doctor --check-settings` PASS。1 つでも欠落で FAIL。
- **matcher `""`（省略）/ `"*"` は全ツール発火として契約充足に数える**。
  この解釈は `scripts/check-settings-wiring.sh` の `has()` と
  `scripts/apply-claude-settings.sh` の包含判定で**一致させること**。
  片方だけが `*` を全ツールとみなすと、適用側は「配線済み」・検証側は
  「不足」となり **何度適用しても収束しない**（#928 で実害化）。

## 検証・適用

- 検証: `bin/plangate doctor --check-settings`（未適用箇所を列挙し非0）
- 適用: `sh scripts/apply-claude-settings.sh`（冪等。ユーザーが実行）
- CI: settings drift check（required）が契約逸脱を fail させる

> ⚠️ **適用スクリプトの副作用（本契約の範囲外）**: `apply-claude-settings.sh`
> は本契約が定める PreToolUse 6 項目だけでなく、`.claude/settings.example.json`
> の **全 hook event**（SessionStart / PostToolUse / Stop を含む）を取り込む。
> そこには契約外かつ副作用の大きい hook が含まれうる（例: SessionStart の
> `scripts/gh-pin-account.sh` は `gh auth switch` で**マシン全体の gh CLI
> active account を切り替える**）。また「不足を足すが削除はしない」方針の
> 裏返しとして、**example から意図的に削除した hook は再実行のたびに復活**
> する（opt-out 手段は現状なし）。`--all-events` opt-in 化は
> [#975](https://github.com/s977043/plangate/issues/975) で follow-up。

## 不変

- `.claude/settings.json` の AI 直接編集は禁止（self-mod ガード・恒久制約）。
  AI は契約定義・検証・適用 script 提供まで。適用は人間。
- 本契約の追加 hook は settings.example.json と整合させること。


## 責務分離（V-3 MJ-2/MJ-3 反映）

| 層 | 検証対象 | 手段 | 役割 |
|----|---------|------|------|
| CI `settings-drift`（required）| `.claude/settings.example.json`（契約 reference）| `check-settings-wiring.sh --target example` | 正本 reference が契約と乖離しないことを保証（example が壊れたら全員に波及するため）|
| `bin/plangate doctor --check-settings` | `.claude/settings.json`（ユーザー実体）| 構造（JSON）検証 | 実環境の wiring 未適用＝Shadow Config を検出 |
| 既存 `bin/plangate doctor` hook-wiring check | `.claude/settings.json` vs `.claude/settings.example.json` | 既存 check（TASK-0069）| settings.example.json を契約整合させた結果、未適用を**通常 doctor でも FAIL**（従来の false-PASS を是正）|

`.claude/settings.json` は gitignore（ユーザーローカル）のため **CI では検出
不可**。実体 drift の検出は doctor（ローカル / V-1・handoff DoD）が担う。
両者は役割が異なり、どちらか一方では「Shadow Config を構造的に防ぐ」根拠に
ならない（CI=reference 健全性 / doctor=実体適用）。

## タスクロックの強制経路（V-3 MJ-1 反映）

V-1/handoff 完了の DoD（[`docs/workflows/05_verify_and_handoff.md`](../workflows/05_verify_and_handoff.md)
/ [`working-context.md`](../../.claude/rules/working-context.md)）に
「`doctor --check-settings` PASS」を必須化。強制は次の二重で成立する:

1. **DoD 明文 + 通常 `doctor` の hook-wiring FAIL**: settings.example.json を
   契約整合させたため、未適用環境では `bin/plangate doctor`（通常実行）も
   FAIL する。doctor FAIL 状態での完了報告は Iron Law（検証証拠なしに完了
   扱いしない）違反。
2. **`doctor --check-settings`**: 構造検証で未適用箇所を決定論的に列挙。

> ~~既知の限界（V2 候補）~~: ~~完全な PreToolUse-hook レベルの機械 block~~ — **解消済 (PR #347)**。`.codex/hooks.json` + `.codex/hooks/eh-bridge.sh` で Codex CLI 側にも EH-1/2/3/6/9 が物理 PreToolUse block として配線済。Claude Code 側は従来通り `.claude/settings.json` で配線。詳細は本ファイル後段の §Codex CLI parity 参照。


## Codex CLI parity (#336 / Gap 4) — ~~達成済~~ ~~部分達成（5 / 11 wiring）・強制力は未検証~~ **強制力 0 / 11（Codex 側 hook は 1 件も登録されていない）**

> **是正記録 2（2026-08-13 / [#1078](https://github.com/s977043/plangate/issues/1078) / 本節で 2 度目の是正）**:
> 直下の「是正記録 1」で **「部分達成（5 / 11 wiring）・強制力は未検証」** へ書き換えたが、
> **これもまだ実態より甘かった**。`codex app-server` の JSON-RPC **`hooks/list`**（モデル呼び出しを
> 伴わない＝課金ゼロ）で実測したところ、**`.codex/hooks.json` は JSON 全体が parse 拒否されており、
> PlanGate の hook は 1 件も登録されていない**。すなわち **EH-1 / EH-2 / EH-3 / EH-6 / EH-9 は
> Codex セッションで一度も発火していない**（「未検証」ではなく **0 件で確定**）。
> 「5 / 11」は **設定ファイルに記述されている件数**であって、**登録数でも強制力でもない**。
> 3 軸を分けた現況は下表「parity の 3 軸」を参照。過去の記述は削除せず残す。
>
> **本節では「達成済」も「部分達成」も強制力については使わない。** Codex 側の強制力は
> **0 / 11** であり、これは実測（`hooks/list` の `warnings` / 登録 0 件）に基づく確定値である。
>
> ---
>
> **是正記録 1（2026-08-13 / [#1078](https://github.com/s977043/plangate/issues/1078)）**:
> 本節の見出しは 2026-05-25 の PR #347 以来 **「達成済」** と記載していたが、
> #1078 の実測で **`.claude/settings.example.json` 側 11 wiring のうち Codex 側に
> あるのは 5 件**（EH-1 / EH-2 / EH-3 / EH-6 / EH-9）で、**6 件が欠落**している
> ことが判明した。さらに **配線済み 5 件についても「実際に発火し block している」
> 実走証跡が無い**（後述「未検証事項」）。過去の記述は削除せず、実測に基づく
> 現況を以下に追記する。**「達成済」は EH-1/2/3/6/9 の *設定ファイル上の配線*
> に限った記述として読むこと。強制力の等価は本節時点では主張しない。**
>
> **model tier の parity**: Claude Code は `.claude/agents/*.md` frontmatter の
> `model:`（inherit/sonnet）、Codex は `.codex/agents/*.toml` の
> `model_reasoning_effort`（low/medium）で同一の 2 tier を表現する。対応表の
> 正本は [`model-profiles.md`](./model-profiles.md) §11。

### parity の 3 軸（混同禁止 / #1078 実測）

**「何件配線したか」と「何件効いているか」は別の数**である。本節では以下 3 軸を分けて数える。
過去 2 回の誤りは、いずれも **軸 A の数を軸 C の主張に流用した**ことで起きた。

| 軸 | 定義 | 数え方 | 現況 |
|----|------|--------|------|
| **A. 記述（declared）** | 設定ファイルに hook として**書かれている**件数 | `.claude/settings.example.json` と `.codex/hooks.json` の静的差分 | Claude 11 / **Codex 5** |
| **B. 登録（registered）** | Codex ランタイムが実際に**読み込んで登録した**件数 | `hooks/list` の `hooks[]` を数える | **Codex 0** |
| **C. 強制力（enforced）** | 実際に**発火して block した**実走証跡がある件数 | 実走ログ（未取得） | **Codex 0** |

- **軸 B = 0 が軸 C = 0 を含意する**。登録されていない hook は原理的に発火し得ないため、
  軸 C の 0 は「実走証跡が無い（未検証）」ではなく **論理的帰結として確定**している。
- 軸 A の 5 は **依然として正しい**が、**これを「5 件は効いている」と読んではならない**。
- **Codex 側の parity を語るときは軸 C（0 / 11）で語る。** 軸 A の数を単独で見出しに置かない。

### 設定ファイル全体が parse 拒否されている（#1078 実測・根本原因）

`.codex/hooks.json` の **top-level に仕様外キーが 2 つある**:

| 行 | キー | 扱い |
|----|------|------|
| 2 | `$schema_note` | **仕様外**（JSON にコメント構文が無いため注記として置かれたもの） |
| 3 | `$note` | **仕様外**（同上） |

Codex CLI の hooks config パーサは top-level に **`description` と `hooks` の 2 キーしか許容しない**
（`deny_unknown_fields`）。**1 キーの違反でファイル全体が捨てられる**（部分適用ではない）。

`hooks/list`（cwd = 本リポジトリ）の実応答 warning（verbatim）:

```text
failed to parse hooks config <repo>/.codex/hooks.json: unknown field `$schema_note`, expected `description` or `hooks` at line 2 column 16
```

このとき登録されたのは **river-review plugin の PostToolUse 1 件のみ**で、
**PlanGate の PreToolUse 5 件は 0 件**。サンドボックスで**双方向に再現済み**
（注記キーを足すと `hooks[]` が空・外すと登録される＝決定論的）。

なお **project trust は本件の原因ではない**（本リポジトリは trusted 済み）。原因は parse 拒否である。

### 🚨 注記キーの単独除去は禁止（Codex が使用不能になる）

> **この 2 行を消すだけの PR を作ってはならない。**
> 「top-level の `$schema_note` / `$note` を消せば直る」は **誤り**である。
> 2 行を消すと **hook が登録され、動き出す**。しかし `eh-bridge.sh` には後述の構造欠陥
> （パス解決 / stdin 非転送 / matcher 死に文字列）があるため、**動き出した瞬間に
> Codex の操作が deny され続け、Codex CLI が使用不能になる**。
>
> **除去は `eh-bridge.sh` の I/O 契約修正と同一 PR でなければならない。**
> 順序としては **bridge を先に直し、注記キー除去を同じ PR に含める**。
> 単独除去は「3 年間 silent に無効だったガードが、いきなり全 deny になる」変更である。

### 「設定ファイルの存在は動作の証拠ではない」（構造原因）

本件の本質は **配線の記述を動作の証拠として扱っていた**ことにある。

- `.codex/hooks.json` が存在し・中身が意図どおりに書かれていたため、
  **レビューでも doctor でも「配線済み」と判定され続けた**。
- **`codex doctor` は hook を一切報告しない**（config / auth / sandbox / mcp のみ）。
  したがって doctor の PASS は **hook が登録されていることの根拠にならない**。
- 結果として **parse 拒否という silent failure が長期間検出されなかった**。

> **一般則**: 「設定ファイルが存在する / 正しく書けている」は **ランタイムがそれを受理した
> ことを意味しない**。強制力を主張するには **ランタイム側の登録状態を問い合わせた証跡**が要る。
> これは Shadow Config（本ファイル後段「Wiring Integrity Enforcement（#500）」）の
> Codex 版であり、同じ検出原理（実体への問い合わせ）で塞ぐ。

### 後続の必須スライス: `hooks/list` による機械検出

**課金ゼロで登録状態を機械検出できる**ため、これを doctor / CI に組み込むことを **必須スライス**とする。

- 経路: `codex app-server`（stdio JSON-RPC）の **`hooks/list`** メソッド。**モデル呼び出しを伴わない**。
- 応答: `hooks[] { key, eventName, matcher, command, source, currentHash, trustStatus, enabled }`
  \+ **`warnings[]` / `errors[]`**。`trustStatus` の enum は `managed` / `untrusted` / `trusted` / `modified`。
- **検査すべき不変条件**:
  1. PlanGate 由来の hook が**期待件数だけ登録されている**
  2. **`warnings[]` が空**（parse 拒否・trust 警告を見逃さない）
  3. 各 hook の `enabled` が true
- これがあれば **今回の silent failure 型（parse 拒否）を機械検出できる**。
- **`trusted_hash` の運用も併せて必要**: project hooks は既定 `untrusted` で登録され、
  `hooks.json` を編集するたび hash が変わる。**「編集 → 再 trust」が運用フローに要る**
  （hash は **hook 単位**。同一ファイル内の別 matcher group を個別に trust できる）。

**判明事項** (2026-05-25 PR #347): OpenAI Codex CLI は `PreToolUse` / `PostToolUse` hook API を公式提供しており、Claude Code の hook 仕様と直接互換 (matcher / stdin JSON / exit 2 で deny / `hookSpecificOutput.permissionDecision`)。公式仕様: https://developers.openai.com/codex/hooks

### 三層の強制機構

| 層 | 機構 | カバー範囲 |
|----|------|----------|
| 1. Session 前 | `scripts/codex-guarded.sh` (PR #343) | validate / doctor / EH-8 privacy / plan.md hash snapshot |
| 2. **Session 中 (物理 pre-Write block)** | ~~`.codex/hooks.json` + `.codex/hooks/eh-bridge.sh` (PR #347)~~ **機能していない** | ~~EH-1 / EH-2 / EH-3 / EH-6 / EH-9 を Codex 側でも発火~~ **登録 0 件・発火 0 件（#1078 実測）** |
| 3. Session 後 | `scripts/codex-guarded.sh` post-flight | plan.md hash drift 検知 + validate 再実行 |

> **層 2 の但し書き（#1078 / 2 度目の是正で強化）**: 当初「Codex 側でも発火」と書き、
> 1 度目の是正で「配線されていることを指す（実走証跡は無い）」に緩めたが、
> **実測では層 2 はまったく機能していない**。`.codex/hooks.json` は parse 拒否され
> **hook が 1 件も登録されていない**（上記「設定ファイル全体が parse 拒否されている」）。
> **層 2 は現時点で存在しないものとして扱うこと。**
> 層 1 / 層 3（`scripts/codex-guarded.sh` の pre/post-flight）は本件と独立に機能する。

### 等価強制マトリクス（全 wiring / #1078 で全数化）

比較対象は **`.claude/settings.example.json`**（`.claude/settings.json` は
gitignore でリポジトリに存在しないため）と **`.codex/hooks.json`** の全数差分。

> ⚠️ **本表は「軸 A（記述）」の表である。** 11 wiring 中 Codex 側に**記述**があるのは 5 件・
> 欠落 6 件。**ただし記述のある 5 件も含め、Codex 側の登録数は 0・強制力は 0**
> （上記「parity の 3 軸」）。**本表の ✅ は「効いている」ではなく「書かれている」を意味する。**

| # | 強制 | event / matcher | Claude Code (`settings.example.json`) | Codex CLI (`.codex/hooks.json`) |
|---|------|-----------------|---------------------------------------|--------------------------------|
| 1 | EH-1 plan-exists | PreToolUse `Edit\|Write` | ✅ | ✅ (matcher `apply_patch\|Edit\|Write`) |
| 2 | EH-2 c3-approval | PreToolUse `Edit\|Write` | ✅ | ✅ 同上 |
| 3 | EH-3 plan_hash | PreToolUse `Edit\|Write` | ✅（引数 `${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}` を渡す） | ⚠️ 配線あり・**引数を渡さず env のみ**（引数 / env / stdin の 3 系統が hook ごとに不統一） |
| 4 | EH-6 forbidden_files | PreToolUse `Edit\|Write` | ✅ | ✅ 同上 |
| 5 | EH-9 delegation-commit-boundary | PreToolUse `Bash` | ✅ | ✅ |
| 6 | **EH-13 approval-token-write（Edit/Write 系）** | PreToolUse `Edit\|Write` | ✅ `scripts/check-approval-token-write.sh` | **❌ 未配線** |
| 7 | **EH-13 approval-token-write（Bash 系）** | PreToolUse `Bash` | ✅ 同上 | **❌ 未配線** |
| 8 | **EH-12 git-destructive guard** | PreToolUse `Bash` | ✅ `scripts/check-git-destructive.sh` | **❌ 未配線** |
| 9 | **gh-pin-account** | SessionStart | ✅ `scripts/gh-pin-account.sh` | **❌ 未配線**（Codex 側に SessionStart 配線が無い） |
| 10 | **check-post-edit-diff** | PostToolUse `Edit\|Write\|MultiEdit` | ✅ `scripts/hooks/check-post-edit-diff.sh` | **❌ 未配線**（Codex 側に PostToolUse 配線が無い） |
| 11 | **check-stop-diff-status** | Stop | ✅ `scripts/hooks/check-stop-diff-status.sh` | **❌ 未配線**（Codex 側に Stop 配線が無い） |

**欠落 6 件を「単に名前を足せば直る」と読んではならない**。#6〜#9 の hook 実体は
`scripts/` **直下**にあり、`eh-bridge.sh` は `scripts/hooks/<NAME>` を**ハードコード**
で解決するため、名前だけ足すと **not-found 分岐で無条件 `deny`** になる（実測）。
是正には bridge の I/O 契約変更（パス解決 / stdin 転送 / payload 正規化）が要り、
**実装は本節の範囲外**（#1078 の別スライス）。

### matcher の死に文字列（#1078 実測）

`.codex/hooks.json` の matcher は `apply_patch|Edit|Write` だが、**Codex CLI が送る
`tool_name` は `apply_patch` / `Bash` のみ**で、**`Edit` / `Write` / `MultiEdit` は
Codex に存在しない**（0.144.1 バイナリ埋め込みの JSON Schema と
[公式仕様](https://developers.openai.com/codex/hooks) の一致で確認）。
したがって matcher 中の **`Edit` / `Write` は Codex 側では一致し得ない死に文字列**であり、
実質 `apply_patch` のみが一致する。また **`apply_patch` は `file_path` を持たない**
ため、bridge は `*** Update/Add/Delete File:` を正規表現で抽出している。

### 未検証事項（**「検証済み」と書いてはならない項目**）

以下のうち **U-3 は #1078 の `hooks/list` 実測で決着した**（ただし **想定と別の原因**で。
下表参照）。**U-1 / U-2 は引き続き未検証**であり、**現時点では「Codex 側の強制力が
働いている」ことの根拠にならない**。文言・状態表は実走証跡が得られるまで
「未検証」のまま扱う。

> **U-1 / U-2 の結果を先取りして書かないこと。** 両者は別途実走で確定作業中であり、
> 確定するまで本節に結論を書き込んではならない。なお **U-1 / U-2 がどちらに転んでも
> 軸 C（強制力 0 / 11）は変わらない** — 登録 0 件が上位の制約だからである。

| ID | 未検証事項 | 分かっていること（実測） | 分かっていないこと |
|----|-----------|------------------------|------------------|
| **U-1** | bridge の `allow` 応答が受理されるか | CLI バイナリに `PreToolUse hook returned unsupported permissionDecision:allow` という文字列が**実在**する。`eh-bridge.sh` は正常系で bare `permissionDecision: "allow"` を返している | 実行時に実際に `allow` が unsupported として弾かれるか。弾かれた場合の Codex 側の既定挙動（allow 継続 / エラー停止） |
| **U-2** | reason 空文字の deny が deny として通るか | 同じく `deny without a non-empty permissionDecisionReason` という文字列が**実在**する。PlanGate hook が無出力で終了した場合、bridge の `reason` は空文字になりうる | 空 reason の deny が無視される（= fail-open）か否か |
| ~~**U-3**~~ **解決済** | ~~hook trust により既存 5 hook がそもそも発火しているか~~ | **`hooks/list` 実測で決着。発火していない。ただし原因は trust ではなく `.codex/hooks.json` の parse 拒否**（上記「設定ファイル全体が parse 拒否されている」）。**EH-1/2/3/6/9 は登録 0 件＝一度も発火していない** | — （**「trust が原因」という当初の仮説は否定された**。trust は本件の原因ではないが、parse 拒否を直した後には別途 `trusted_hash` 運用が必要になる） |

> **U-1 / U-2 の実走はモデル API 呼び出しを伴う**ため、実施可否は **Human 判断**（#1078）。
> 一方 **登録状態の確認は `hooks/list` で課金ゼロ**に行える（上記「後続の必須スライス」）。
> **Codex セッションの安全性を `.codex/hooks.json` の存在に依拠して評価しないこと** —
> 存在していても **現に登録されていない**というのが本件の実測結果である。
> Session 前後の `scripts/codex-guarded.sh`（層 1 / 層 3）は本件と独立に機能する。

### なぜ「達成済」のまま気づかれなかったか（構造原因）

等価強制マトリクスは **EH-1/2/3/6/9 の 5 行のみ**で、**行単位では正しいが
集合として不完全**だった。新しい hook（EH-12 / EH-13 / SessionStart /
PostToolUse / Stop）を `.claude/settings*.json` に追加した際に
**本マトリクスへ追記することを求める運用ルールも、両者の集合差を検出する
機械チェックも存在しない**。結果、追加のたびに parity のギャップが静かに広がり、
見出しの「達成済」だけが残った。機械検出の追加は #1078 の後続スライス候補。

> **さらに深い原因（2 度目の是正で判明）**: 上の説明は **軸 A（記述）の集合差**しか
> 見ていない。**軸 A を全数化しても、記述された 5 件が実は 0 件しか登録されていない
> ことは検出できなかった**。集合差の機械チェックを足すだけでは不十分であり、
> **ランタイムの登録状態（`hooks/list`）を問い合わせる検査が要る**。
> 「マトリクスを全数化する」ことと「強制力を確認する」ことは別作業である。

### Codex bridge の動作（**設計上の意図**。現在この経路は動いていない）

> ⚠️ 以下 1〜6 は **PR #347 時点の設計意図**であり、**現況の記述ではない**。
> 手順 1 の時点で `.codex/hooks.json` が parse 拒否されるため、**2 以降は 1 度も実行されていない**。

1. Codex CLI が `apply_patch` / `Edit` / `Write` / `Bash` 呼び出し前に `.codex/hooks.json` を参照
2. 該当 matcher の `command` (= `.codex/hooks/eh-bridge.sh <HOOK_NAME>`) が起動
3. eh-bridge.sh が stdin JSON から file path (Edit/Write.file_path or apply_patch.command の `*** Update/Add/Delete File:`) を抽出
4. `PLANGATE_HOOK_FILE` / `PLANGATE_HOOK_TASK` を設定し `scripts/hooks/<HOOK_NAME>` を起動
5. exit code を Codex の `hookSpecificOutput.permissionDecision` (`allow` / `deny`) に翻訳
6. Codex CLI が deny 時は write を物理 block

> **手順 3〜4 の実測補足（#1078）**: bridge は stdin を `INPUT=$(cat)` で**吸い切り**、
> 手順 4 の hook 起動時に**その stdin を hook へ渡していない**（渡すのは
> `PLANGATE_HOOK_FILE` / `PLANGATE_HOOK_TASK` の env のみ）。**Codex の hook 入力経路は
> stdin のみ**（`CODEX_HOOK_*` 系 env はバイナリ内に 0 件）であるため、
> **stdin で判定する hook（例: v8.19.0 で stdin 常時独立評価・fail-closed 化された EH-13）は
> この bridge 経由では正しく判定できない**。手順 6 の「物理 block」も
> 上記「未検証事項」U-1〜U-3 の成立が前提であり、実走証跡は未取得。

### 責務分界 (継続)

- `.claude/settings.json` / `bin/plangate` / `scripts/hooks/*.sh` 等の Hardening Override 領域を改変するのは依然として **AI 改変不可** (Human-owned)
- 新規 hook 追加 (`.codex/hooks.json` / `.codex/hooks/*.sh`) は AI-owned (Override 対象外)
- 既存 hook 改変は Human-owned

## Wiring Integrity Enforcement（#500 / 配線整合性の強制・Specification）

> Status: Specification（方針確定。実装は HO パス絡みのため受け入れ条件ごとに段階 PBI へ分解）
> 出自: river 3 相レビュー（2026-06-08、Gemini + コードベース調査で代替実行 /
> external-reviewer-interface §10 unavailable 準拠）で検出した「規範↔実装」乖離
> （Shadow Config）への是正方針。

### 強制モード方針（example=warning / 本番=strict）

- `settings.example.json` は配布テンプレートのため **warning モード**（`PLANGATE_HOOK_STRICT`
  未設定）を既定とし、導入直後の破壊を避ける。
- **本番運用（承認境界を信頼する運用）では strict 必須**。`PLANGATE_HOOK_STRICT=1` を
  設定し EH-2 / EH-3 / EH-6 等を block モードで動かす。
- この warning↔strict の差は「設定の罠（Shadow Config）」になりうるため、後述の doctor
  検証で乖離を物理ブロックする。

### doctor によるモード別必須 strict 配線検証

- `bin/plangate doctor --check-settings` は、コード整合性に加えて **現在のモードで必須
  フックが strict 配線・有効化されているか** を検証する。
- Governance Contract（モード → 必須 strict フック集合）を定義する。
- **モード別 exit code**: **strict モード**では乖離があれば **exit 1 で物理ブロック**する。
  一方 **warning モード（example 既定）** では「導入直後の破壊を避ける」方針（上節）と
  整合させ、未配線・非 strict 配線に対して **warning を出力したうえで exit 0 で通過**させる
  （block しない）。モードごとの exit code 挙動を doctor 実装時に明示する。
- これにより「スクリプトは存在するが settings に配線されておらず動かない幽霊ガバナンス」を
  構造的に排除する。

### EH-13: 承認トークン書込みガードの採番・配線

> **採番改訂（TASK-1023 G-6 / Human 裁定 2026-08-10）**: 本節は当初 **EH-10** として
> 採番していたが、[`hook-enforcement.md`](./hook-enforcement.md) 側で **EH-10 / EH-11 は
> #760 / #762 用に予約済み**、**EH-12 は protected branch 破壊的 git 操作ブロック
> （`check-git-destructive.sh`）に採番済み**であり衝突していた（R-033）。予約体系を
> 尊重し、衝突しない最小の空き番号 **EH-13** へ改番する（G-6=(b)）。

- `scripts/check-approval-token-write.sh`（c3.json / maintenance.json 等の承認トークンへの
  AI 書込みガード）を **EH-13** として正規採番し、`PreToolUse(Edit|Write)` と
  `PreToolUse(Bash)` に配線する（Bash matcher は TASK-0128 R-002 / 実配線済み。
  MultiEdit は現行 Claude Code 2.1.226 に tool 自体が存在せず到達経路がない —
  TASK-1023 到達性実測 / G-9=(i)）。
- #420（maintenance.json 発行元検証ギャップ / R-012）と直結。provenance 検証はそちらと協調。
- **配線方式（重要）**: Claude Code のフック実行環境は env `PLANGATE_HOOK_FILE` を自動 export しないため、`.claude/settings.json` の配線で `${PLANGATE_HOOK_FILE:-}` を **引数として明示的に渡す**（EH-3 と同様）。`check-approval-token-write.sh` は引数 `$1` をターゲットファイルパスの fallback として受け取れるよう実装する（env のみ参照だと Claude Code 環境下でガードがスルーされる）。

### 検証ロジックの対称化・テスト空白の解消（実装方針）

| 受け入れ条件 | 実装方針 | 主パス（HO） |
|------------|---------|-----------|
| EH-2（c3_status）strict 化 | EH-3 と同じ python3 strict JSON 解析へ置換（permissive な grep/sed 抽出を廃止し EH-3 と対称化） | `scripts/hooks/check-c3-approval.sh` |
| EH-1/EH-2 stdin fallback | env 未注入時に stdin `tool_input.file_path` から解決し SKIP(allow) を解消 | `scripts/hooks/*.sh` |
| maintenance verdict テスト | VALID / CONSUMED / OUT_OF_SCOPE / HARDENING_OVERRIDE の fixture + assert を追加 | `tests/hooks/` |
| ta-06 ログ握りつぶし解消 | `>/dev/null 2>&1` 圧縮をやめ、どの EH が落ちたかをログに残す | `tests/.../ta-06-hooks.sh` |

### 段階 PBI 分解（HO 実適用は Human）

本仕様の HO 実装は以下の順で段階 PBI に分解する（各々 plan → C-3 承認 👤 → exec、
HO 適用は Human）:

1. **EH-2 strict 化 + EH-1/EH-2 stdin fallback**（hooks 堅牢化・最小単位・回帰リスク低）
2. **EH-13 採番・配線 + check-approval-token-write 統合**（#420 と協調。旧記載 EH-10 は TASK-1023 G-6 裁定で EH-13 へ改番）。配線時は既存の契約検証スクリプト `scripts/check-settings-wiring.sh` の `checks` リストにも EH-13（`check-approval-token-write.sh`）を追加し、CI / ローカルの契約ドリフト検知（`--target example`）に組み込んで配線漏れを防ぐ
3. **doctor Wiring Integrity Enforcement**（Governance Contract 定義 + exit 1）
4. **hooks 回帰テスト拡充**（maintenance verdict fixture + ta-06 ログ解消）

各段階は承認境界（HO）の変更を含むため `mode-classification.md` により最低 high・
Standard C-3 同期固定（autonomous APPROVE 無効）とする。

## CLI 配線（EH-4/5/7）— TASK-0143

> Status: Implemented（`scripts/apply-task-0143-eh457-wiring.sh --apply` 適用後に有効）

PreToolUse hook ではなく **`bin/plangate` CLI サブコマンド経由**で発火する配線。

| Hook | CLI 配線先 | 発火タイミング |
|------|----------|-------------|
| EH-4 (`check-test-cases.sh`) | `bin/plangate verify <TASK>` | V-1 実行**前**（strict=1、test-cases.md なしで block） |
| EH-5 (`check-verification-evidence.sh`) | `bin/plangate verify <TASK>` | V-1 通過**後**（warn のみ、evidence なしで WARNING） |
| EH-7 (`check-merge-approvals.sh`) | 手動呼び出し推奨 | merge 前: `sh scripts/hooks/check-merge-approvals.sh <TASK>` |

### doctor 可視化

`bin/plangate doctor` の `=== CLI Hook Wiring (EH-4/5/7) ===` セクションが:
1. EH-4/5/7 スクリプトの存在・実行権限を PASS/WARN/FAIL で報告
2. `bin/plangate verify` への配線状態（grep 確認）を PASS/WARN で報告

### 適用方法（Human-owned）

```sh
# 差分確認（必須）
sh scripts/apply-task-0143-eh457-wiring.sh --dry-run
# 適用
sh scripts/apply-task-0143-eh457-wiring.sh --apply
```

適用後: `bin/plangate doctor` の出力で `[PASS] EH-4 wired` / `[PASS] EH-5 wired` を確認する。

## C-3 Approval Mode 設定（EH-3 conversation 経路）— TASK-0144

> Status: Implemented（`scripts/apply-task-0144-c3-mode.sh --apply` 適用後に有効）

`.plangate.yml` プロジェクト設定で C-3 承認モードを選択できる経路。

### モード定義

| モード | 動作 | `c3.json` の `source` フィールド |
|--------|------|-------------------------------|
| `cli`（デフォルト） | `bin/plangate approve <TASK>` で対話的に承認・c3.json 生成 | `"cli"` |
| `conversation` | 会話内で人間が APPROVE 発話 → AI が exec 前に c3.json を生成 | `"conversation"` |

### 設計の核心

- **cmd_exec は変更しない**（R-001/R-002 反映）: c3.json は exec *前* に生成済みである必要がある
- **EH-3 の責務は「通す」のみ**: `approvals/c3.json` + conversation mode → SKIP (exit 0)。c3.json の中身検証は EH-2 と AI 生成コードに委ねる
- **自己承認にならない**: 人間が会話内で APPROVE を発話した後に AI が転記する形式（AI が自律的に承認を作るのではない）

### EH-3 conversation 経路（新規）

`scripts/hooks/check-plan-hash.sh` に追加された判定：

1. `target_file` が `docs/working/TASK-*/approvals/c3.json` にマッチ
2. `.plangate.yml` を読んで `c3_approval.mode` を取得
3. `conversation` の場合 → `EH-3_C3_CONVERSATION_SKIP` をログに記録して `exit 0`（Write を許可）
4. `cli` の場合 → 既存の maintenance / SKIP_REASON 判定に進む

### 追加ファイル

| ファイル | 種別 | 説明 |
|---------|------|------|
| `.plangate.yml` | 設定ファイル | プロジェクト設定（`c3_approval.mode: cli\|conversation`） |
| `schemas/plangate-config.schema.json` | Schema（HO） | `.plangate.yml` の JSON Schema 検証定義 |
| `schemas/c3-approval.schema.json` | Schema（HO 変更） | `source` フィールドを追加（optional） |
| `scripts/hooks/check-plan-hash.sh` | Hook（HO 変更） | conversation SKIP 経路を追加 |
| `bin/plangate` | CLI（HO 変更） | `_read_plangate_config()` 追加 / `source: "cli"` / doctor セクション追加 |

### 適用方法（Human-owned）

```sh
# 差分確認（必須）
sh scripts/apply-task-0144-c3-mode.sh
# 適用
sh scripts/apply-task-0144-c3-mode.sh --apply
```

適用後: `bin/plangate doctor` の出力で `=== C-3 Approval Mode ===` セクションを確認する。
