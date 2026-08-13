# PBI INPUT PACKAGE: #1078 S-2 — Codex hook bridge の I/O 契約修正

> フェーズ A（PBI INPUT）。正本: [`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md) の「pbi-input.md」節。
> 本 PBI は [#1078](https://github.com/s977043/plangate/issues/1078) のスライス **S-2**。S-1（文書是正）は PR #1080 / #1083 で完了済み。

## Context / Why

`.codex/hooks.json` は top-level の仕様外キー 2 つ（`$schema_note` / `$note`）により **JSON 全体が parse 拒否**され、
PlanGate の hook は Codex ランタイムに **1 件も登録されていない**（`hooks/list` 実測。証跡: [`evidence/codex-exec-spike.md`](./evidence/codex-exec-spike.md)）。

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
- `.codex/hooks.json` の matcher から Codex に存在しないツール名（`Edit` / `Write`）を除去
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
- [ ] **AC-04**: hook が **stderr にのみ** block 相当の文字列を出した場合に **deny にならない**（判定チャネルは stdout のみ）
- [ ] **AC-05**: 未知 exit code（例 `127`）で **deny** が返る（fail-closed）。かつ deny の `permissionDecisionReason` が**常に非空**である
- [ ] **AC-06**: 注記キー除去後、`hooks/list` が PlanGate hook を **期待件数だけ登録**し `warnings[]` が空で、各 hook の `enabled` が true・`trustStatus` が `trusted` である（**前提条件の確認**であって本 PBI の成果主張には使わない）
- [ ] **AC-07**: **Codex セッションで実際に block された証跡**（stderr の `Command blocked by PreToolUse hook:` + 対象ファイルが生成されていないこと）が 1 件取得される。取得には `codex exec` の実走 1 回を要するため **Human の明示承認**を前提とする。承認が得られない場合は AC-07 を **WARN（未達・理由記録）** とし、`settings-wiring-contract.md` の軸 C を「bridge 単体では deny を返すところまで実証／ランタイム経路は既存証跡の援用」と明記する
- [ ] **AC-08**: `.claude` 側の hook 挙動が**無傷**である（`scripts/hooks/*.sh` および `.claude/settings*.json` に差分が無いことを diff で示す）
- [ ] **AC-09**: `docs/ai/settings-wiring-contract.md` の「既存 hook 改変は Human-owned」の適用範囲が**パス単位で一意に読める**記述になる

## Notes from Refinement

- **順序の逆転を禁止**する。注記キーの除去は **最後**。理由は「除去すると使用不能になるから」ではなく（それは誤りで、実測は allow）、**除去が先行すると無効なガードが「登録済み」に見える**ため。
- **注記キーは事実上の kill switch として機能する**。除去前は bridge をどれだけ変えても Codex ランタイムには一切影響しない（parse 拒否のため）。これを**段階導入の安全装置として明示的に利用する**。
- **責務分界の曖昧さ**: `settings-wiring-contract.md` の責務分界節は「新規 hook 追加（`.codex/hooks.json` / `.codex/hooks/*.sh`）は AI-owned」の直後に「既存 hook 改変は Human-owned」と書いており、**`eh-bridge.sh` の改変がどちらに当たるか読めない**。機械判定（`check-plan-hash.sh` の HO case 文）では `.codex/**` は **HO 対象外**であり、AI 改変を技術層で block していない。→ 解消案は plan の該当節。
- **未確定（U-4）**: `trustStatus:"untrusted"` の hook が実行時に発火するかは**未検証**。発火しないなら、注記キー除去だけでは登録されても発火せず、**再び「登録≠強制力」状態**になる。よって `trusted_hash` の運用（#1078 S-4）は S-2 の**後続ではなく前提**として扱う。

## Estimation Evidence

### Risks

- **R-1（最大）**: 「登録された」を「効いている」と誤認したまま完了宣言する。→ AC-06 を成果主張に使わない・AC-01/AC-07 で担保。
- **R-2**: 未知 exit code の fail-closed 化により、hook の実行時エラーが**全操作の deny**に化ける。→ 注記キー（kill switch）による即時無効化手順を rollback に明記。
- **R-3**: stdout / stderr を混ぜて判定すると、**stderr の警告文字列で false deny** が起きる（本計画時に実測で再現済み）。→ AC-04。
- **R-4**: `PLANGATE_HOOK_TASK` がセッション環境から**継承**され、hook の判定を変える（本計画時に実測で遭遇。TASK を与えると EH-3 の HO block が消えた）。→ テストは env を明示的に制御する。
- **R-5**: U-4 が「untrusted は発火しない」だった場合、S-2 単独では AC-07 を満たせない。

### Unknowns

- **U-4**: untrusted な project hook が実行時に発火するか（`--dangerously-bypass-hook-trust` 無しで）。
- **U-5**: `codex exec`（非対話）が PreToolUse hook を評価する条件（1 回目の実走では probe が 0 回・2 回目では発火）。
- **U-6**: Codex が 1 つの matcher group に複数 hook を並べたとき、**最初の deny で打ち切る**か全件実行するか（bridge の設計には影響しないが、証跡の読み方に影響する）。

### Assumptions

- Codex の PreToolUse payload 形状は [`evidence/codex-payload-spike.md`](./evidence/codex-payload-spike.md) / [`evidence/codex-exec-spike.md`](./evidence/codex-exec-spike.md) の実測どおり（`tool_name` は `apply_patch` / `Bash` のみ、入力は stdin のみ、`CODEX_HOOK_*` env は存在しない）。
- **非空 reason の deny は Codex ランタイムで実際に block される**（3 回目実走で確定）。空 reason の deny は**黙って握り潰される**。
- `PLANGATE_HOOK_STRICT` は Claude / Codex いずれの設定にも無く、既定は warning。
