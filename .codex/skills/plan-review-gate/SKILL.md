---
name: plan-review-gate
description: "PlanGate の C-1 / C-2 / C-3 ゲートを確認し、exec 開始可否を判定する。Use when: plan レビュー通過済みか確認したい時、c3.json を発行したい時。"
---

# Plan Review Gate (PlanGate / Codex 共用)

PlanGate の **plan ゲート（C-1 セルフレビュー / C-2 外部レビュー / C-3 人間承認）** を確認する skill。EH-3（plan_hash 改竄検知）と整合する手順順序を担保する。

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md`（C-1 / C-3 三値ゲート / 条件付き降格 / settings タスクロック の正本）
4. `.claude/rules/review-principles.md`（5 観点 / Severity / C-2 2 レーン責務契約の正本）
5. `.claude/rules/mode-classification.md`（mode 別フェーズ適用マトリクス）
6. `docs/working/TASK-XXXX/plan.md`
7. `docs/working/TASK-XXXX/review-self.md`（C-1）
8. `docs/working/TASK-XXXX/review-external.md`（C-2、存在すれば）
9. `docs/working/TASK-XXXX/approvals/c3.json`（存在すれば）

> **参照解決順（`docs/**` / 導入先で必ずこの順に探す）**: 本 Skill が参照する `docs/**` は上流リポジトリ基準の相対パスであり、`install.sh --claude` / plugin（Claude marketplace）/ Codex の **3 経路とも配布対象外**（解決不可）。(1) 導入先リポジトリの同名パスを探す → (2) 見つからなければ **「正本 `<path>` を参照できなかった」と明示**し、本 Skill 内の記述を代替正本として扱い、推測で内容を補わない。**plugin root 配下の探索は `docs/**` には適用しない**: plugin が配布するのは `agents` / `commands` / `skills` / `rules` 等の定義ディレクトリのみで `docs/` を配布対象として認識せず、plugin root 配下に相当する配布物が存在しないため、plugin root 段を置いても必ず空振りする（クラス A の rules 参照が plugin root 配下で解決できるのは `rules/` が実際に配布されるからであり、この非対称を `docs/**` に持ち込まない）。

## 参照解決順（`.claude/rules/*.md` / 導入先で必ずこの順に探す）

本 Skill は C-1 / C-2 / C-3 の判定正本として `.claude/rules/working-context.md` /
`.claude/rules/review-principles.md` / `.claude/rules/mode-classification.md` を参照する
（§Read First 3〜5）。これらのパスは上流リポジトリ基準のため、導入先では **次の順で探索する**
（3 本それぞれに適用する）:

1. 導入先リポジトリの `.claude/rules/<name>.md`。
   ただし **本 skill が参照する節（例: `working-context.md` の「C-3ゲート（計画承認・三値）」節）が実在することを確認する**。同名でも別内容なら PlanGate の正本ではないため 2 へ進む
2. 無ければ plugin root 配下 `<plugin_root>/rules/<name>.md`。
   `<plugin_root>` は **Bash で `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` を実行して展開・確認した
   絶対パス**（Read ツールは絶対パスを要求し環境変数を展開しないため、`${CLAUDE_PLUGIN_ROOT}/...`
   という文字列をそのまま Read しない）。変数が空・未設定ならキャッシュを glob で推測せず 3 へ進む
3. どちらにも無い場合は **「正本 `<name>.md` を参照できなかった」と明示**し、
   推測で内容を補わない。判定基準を推測で代替して C-1 / C-3 を続行しない

## C-1 セルフレビュー

チェック項目の定義と項目数は `docs/working/templates/review-self.md` を正本とする（現行 全 25 項目）。mode に応じた適用範囲は `.claude/rules/working-context.md` の C-1 節および `.claude/rules/mode-classification.md` フェーズ適用マトリクスを正本とする。FAIL があれば修正後再実行。evidence は FAIL 時必須（`evidence/c1-review/`）。

## C-2 外部レビュー

- 2 レーン責務（設計妥当性 / コードベース整合）と R-NNN 採番・追記専用集約の規約は `.claude/rules/review-principles.md` §7-bis を正本とする
- 実行コマンド: 「CLI 呼び出し」節の表を参照（外部 AI モデル呼び出し。表記は実行環境で変わる）
- 指摘ゼロでも「指摘なし」を明示記録

## C-2 → 確定反映 → Plan Normalization → c3.json 発行（EH-3 整合・厳守順序）

1. R-NNN を `review-external.md` に集約（追記専用）
2. 1 回確定反映（plan/todo/test-cases へ反映、コミットメッセージに `Refs: R-NNN`）
3. **`plan-normalization` skill を実行し、`plan.md` を最終合意状態の Canonical Plan へ再構成する**
   - `evidence/plan-normalization/plan.before.md` を保存する
   - superseded / rejected な案を Plan 本文から除去する
   - 将来必要な却下理由・trade-off は append-only `decision-log.jsonl` に保持する
   - 上流リポジトリでは `python3 scripts/check-plan-normalization.py --before ... --after ...` を実行する
4. 正規化後の `plan.md` に対して簡易 C-1 を再実行し、`todo.md` / `test-cases.md` と矛盾がないことを確認する
5. **人間が APPROVED c3.json 発行**（正規化済み plan の `plan_hash: sha256:...` を含む）
6. exec 開始

> ⚠️ **Plan Normalization と簡易 C-1 は c3.json 発行より前**。C-3 後に `plan.md` を正規化すると EH-3 が plan_hash mismatch で block する。`canonical-plan.md` を別正本として増やさず、正規化済み `plan.md` 自体を Canonical Plan とする。

### Canonical Plan の最低条件

- 過去会話を知らない新規 Agent が `plan.md` と通常の L1 artifact だけで実装判断できる
- 「当初案」「前述の指摘」「先ほどのレビュー」など履歴依存表現が実行指示に残っていない
- AC / REQ / FR / NFR 等の stable contract ID が正規化前後で欠落していない
- Goal / Scope / Constraints / Work Breakdown / Verification Plan が具体的である
- 却下案の再提案防止に必要な rationale は `decision-log.jsonl` に残る

## C-3 三値判定

詳細は `.claude/rules/working-context.md` の C-3 ゲート節と条件付き降格節を正本とする。PlanGate CLI の `exec` は APPROVED の c3.json のみ受理する。

> **これは CLI（＝上流リポジトリの clone）がある環境でのみ成立する機械的な受理判定**であり、
> 導入先には CLI も hook も配布されない（#1144。下記「CLI 呼び出し」節）。CLI が無い環境では
> **判定基準そのものは不変**で、「APPROVED 以外では exec に進まない」を人手で維持する
> （下記「CLI 不在時のフォールバック」）。**機械 block が無いことを理由に C-3 を省略しない。**

## settings タスクロック

`bin/plangate doctor --check-settings` PASS は **V-1 / handoff 完了の前提条件**（`.claude/rules/working-context.md` 正本）。plan ゲート段階での block 対象ではないが、未配線なら verify フェーズ前に Human が `sh scripts/apply-claude-settings.sh` 実行が必要なことを認識しておく（`doctor` / `apply-claude-settings.sh` はいずれも**上流リポジトリの cwd でのみ**成立する。下記「CLI 呼び出し」節を参照）。

## CLI 呼び出し

> **前提（Human 決定 #1144）**: plugin / `install.sh --claude` / Codex が導入先へ配るのは
> **読み物層（`skills` / `rules` / `agents` / `commands`）だけ**であり、**CLI（PlanGate CLI 本体）も
> enforcement 層（`scripts/hooks/`）も配布物に含まれない**。したがって下表の「上流リポジトリの cwd」
> 列にしか成立しない手順は、導入先では **上流リポジトリ（`s977043/plangate`）の clone が無いかぎり
> 実行できない**。そこへ到達したら「CLI が無いため実行できない／上流リポジトリの clone が必要」と
> **明示して停止する**か、同表の代替手順へ置き換える。**CLI が無いことを理由に手順を黙って省略し、
> 実施済みと読める記録を残してはならない。**

**呼び出し表記は実行環境で変わる**。相対パス形式（`bin/plangate` / `./scripts/...`）が成立するのは
**上流リポジトリ（`s977043/plangate`）を clone した cwd に居るときだけ**で、導入先には `bin/` も
`scripts/`（の CLI 本体）も配置されない。導入先で PATH を通した場合のコマンド名は
**`plangate`**（`bin/plangate` ではない）。

| 用途 | 上流リポジトリの cwd | 導入先 + PATH に `plangate` あり | 導入先 + PATH に無い（**既定**） |
|------|---------------------|----------------------------------|--------------------------------|
| plan_hash / artifact 機械検証 | `bin/plangate validate TASK-XXXX` | `plangate validate --dir docs/working/TASK-XXXX` | 次節のフォールバック |
| Plan Normalization invariant 検証 | `python3 scripts/check-plan-normalization.py --before <snapshot> --after <plan>` | 配布対象外 → `plan-normalization` skill の手動チェック | 同左 |
| C-2 / V-3 外部 AI レビュー | `bin/plangate review TASK-XXXX --phase {c2\|v3}` | **導入先の TASK には使えない**（`--dir` 相当なし）→ 手動レビュー | 手動レビュー |
| settings 検証 | `bin/plangate doctor --check-settings` | **導入先は検査できない**（`--dir` 相当なし）→ `.claude/settings.json` を直接確認 | `.claude/settings.json` を直接確認 |
| gate 通過判定（artifact チェック）| `./scripts/ai-dev-workflow TASK-XXXX gate` | **配布対象外**（`scripts/` は導入先に無い）→ 次節のフォールバック | 次節のフォールバック |

> **注意: `TASK-XXXX` 位置引数は cwd ではなく CLI 本体の位置を基準に解決される。**
> `bin/plangate` は自身のパスから `plangate_root`（= `bin/` の親）を求め、
> `<CLI の repo root>/docs/working/TASK-XXXX` を読み書きする。`bin/` は導入先に配置されない
> ため、PATH 上の `plangate` は必ず**別の場所にある上流 clone** の実体を指す。cwd 非依存で
> パスを明示できる `--dir` を持つのは `validate` / `validate-schemas` **だけ**で、
> `review` / `doctor` / `exec` に相当オプションは無い。

> ⚠️ **`plangate review` は外部 AI モデル（gemini/codex 等）を呼び出す**。C-1 セルフレビュー目的で誤起動するとコスト発生・機密送信のリスクがある。C-1 は本 skill の手順に従い手動で実施する。

### CLI 不在時のフォールバック（導入先では既定）

**ゲートの厳密な強制には CLI + hooks（EH-3 等）が必要**であり、CLI が無い環境では
plan_hash 改竄検知と exec 受理の**機械的な block は成立しない**。それでも
**判定基準とゲート順序は不変**で、機械検証だけを手動チェックリストへ置き換える:

1. **C-1 / C-2 / Plan Normalization の判定基準は変えない** — C-1 チェック項目・5 観点・Severity・R-NNN 採番・
   「C-2 → 確定反映 → Plan Normalization → 簡易 C-1 → c3.json 発行」の順序は CLI の有無に関わらず不変
2. **Plan Normalization を手動検証する** — stable contract ID の保持、履歴依存表現の除去、Decision Log への rationale 退避、自己完結性を `plan-normalization` skill の PASS 条件で確認する
3. **plan_hash 突合を手で行う** — 手順の正本は `ai-dev-verify` skill
   「CLI 不在時のフォールバック」節（legacy c3.json の sha256 突合 / c3-prime の
   束縛検証という経路分岐を含む）。ここでは再定義しない
4. **exec 受理判定を手で行う** — `approvals/c3.json` を直接読み、legacy は
   `c3_status: APPROVED`、c3-prime（`approval_kind: "c3-prime"`）は
   `decision: "AUTO_APPROVED"` であることを確認する（判定手順の正本は
   `ai-dev-exec` skill「前提条件（exec 開始ゲート）」節）
5. **未実施を「PASS」と書かない** — 機械検証できなかった項目は、その事実を
   `status.md` と `decision-log.jsonl` に記録する。**CLI が無いことを理由に
   C-1 / C-2 / Plan Normalization / C-3 を省略しない**

## 判定

1 つでも未充足なら exec を始めない。不明点があれば status.md に追記候補を示す。
