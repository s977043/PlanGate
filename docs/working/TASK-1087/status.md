# STATUS — TASK-1087 (#1087)

## 全体構成

| 項目 | 値 |
|------|-----|
| ブランチ | `fix/1087-distribution-checks` |
| base | `origin/main` = `387ea21` |
| Mode | **high-risk**（`lite_eligible=false`） |
| PR | 未作成（C-3 前） |

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|------|---------|------|
| 2026-08-18 | A: PBI INPUT | `pbi-input.md` 作成。issue 記載値（2026-08-13）を全件測り直し |
| 2026-08-18 | B: Plan | `plan.md` / `todo.md` / `test-cases.md` 生成 |
| 2026-08-18 | D: exec | 検査 2 本の是正 + ドキュメント 1 件修正 + TC 追加 |
| 2026-08-18 | 検証 | ta-69 新規 17 TC / ta-52 更新 / 変異注入 7 系統 |
| 2026-08-18 | C-1 | `review-self.md` — **PASS**（WARN 2 / FAIL 0） |
| 2026-08-18 | レビュー対応 | コーディネータ指摘 1〜4 に対応（下記「指摘対応」） |
| 2026-08-18 | C-1 再 | `review-self-2.md` — **PASS**（WARN 2 / FAIL 0）。初回は保持 |
| 2026-08-18 | CI FAIL 対応 | PR #1149 の `plangate CLI tests` が 7 FAIL。**harness モード固有の `set -e` 事故**を特定し是正 |
| 2026-08-18 | C-1 再2 | `review-self-3.md` — **PASS**（WARN 2 / FAIL 0 / **FAIL-1 を新規記録**） |
| 2026-08-18 | — | **C-3 待ち（人間）**。`c3.json` は発行していない |

## CI FAIL の根本原因と是正（2026-08-18 / PR #1149）

**症状**: ローカル standalone 19 passed / 0 failed に対し、CI で 7 FAIL。
規則性は「**rc=1 を期待する TC が全滅・rc=0 を期待する TC は全通過**」。

**根本原因**: OS 差ではなく **standalone と harness の差**。
`run-tests.sh` は `set -eu` で extras を source する。ta-69 の rc 捕捉

```sh
( cd "$D" && python3 x.py >/dev/null 2>&1; echo $? )
```

は `set -e` 下で、python3 が rc=1 を返すと AND-list 失敗 →
**`echo $?` に到達する前にサブシェルが終了** → 捕捉値が空文字になる。
`[ "" = "1" ]` が偽になり rc=1 系が全滅、`[ "0" = "0" ]` は真なので
rc=0 系は **空のサンドボックスでも通る**。素の代入で使った TC-S9 では
`set -e` が **ハーネス全体を中断**（CI ログが TC-S8 で止まった理由）。

**決め手**: CI ログに ta-61 が ta-69 を **standalone 実行して PASS させている**
行があり、OS 差説を棄却できた。

**是正**: rc 捕捉を OR-list（`_t69_rc_of`）へ統一 + **注入の前提条件検証**
（`_t69_assert_defs` / `_t69_assert_probe` / TC-G1 / TC-G2 / TC-G3）を追加。
`ta-52` にも同じ silent-green 性質があったため同様のガードを追加した。

**実証**: standalone / harness の **両モードで** ta-69 = 22 passed 0 failed、
ta-52 = 6 passed 0 failed。注入を no-op に壊す変異で
`sandbox injection failed (want=N got=M)` として落ちることを実測。
是正前の同変異では 3 TC が **緑のまま**だった。

**再発防止（handoff 送り）**: extras を追加・変更するときは
**単一 extra を harness 文脈（`set -eu` + source）で走らせる**検証を必須にする
（フルスイート実行は ta-61 の入れ子再帰があるため不可）。

## 指摘対応（2026-08-18）

| 指摘 | 内容 | 対応 |
|------|------|------|
| **1** critical 相当 | **本 PR が 4 root drift を新規に持ち込んだ**（`.codex/skills` 未追従） | 正本 `.agents/skills` から追従。`sync --dry-run` rc=0 / 4 root blob 一致を実測 |
| **2** major | stale-refs が配布 root を走査していない（collisions は走査している） | **(b) 射程を明文化 + follow-up 起票内容を plan に記載**。理由は実測（新規 FP 16 件 / ai-loop レーンの真の stale / #1086 待ち） |
| **3** minor | doctor 配線の主張が裏取りできない | **撤回せず精密化**。コーディネータの grep は zsh の glob 展開失敗で**未実行**だった。ただし私の表現も不正確（到達経路は `--json` のみ）だったため実測表に差し替え |
| **4** | 4 root 追従漏れを今後検出できるか | **内容一致による一般検出は不可能**と実測（`.agents` vs `.codex` は 39 中 26 が正当に相違）。固定リテラルのゼロ集合 assert **TC-R1** を追加し、実際の退行で kill 実証 |

## 実測サマリ（是正前 → 是正後）

| 対象 | 是正前 rc | 是正後 rc |
|------|----------|----------|
| `python3 scripts/check-skill-name-collisions.py` | **1**（46 件） | **0** |
| `python3 scripts/check-stale-skill-refs.py` | **1**（7 件） | **0** |
| `.github/workflows/` 内の 3 本への言及 | 0 件 | 0 件（**patch 提示のみ・未適用**） |

## 計画からの変更点

### 変更 1: `app/admin` は検査側でなくドキュメント側を直した

plan 初稿では「引用（「…」）内を除外する」条件の追加を検討したが、
**検出力を恒久的に削る**判断になるため取り下げた。
参照と例示が機械的に区別できない書き方をしていたドキュメント側の欠陥と判断し、
プレースホルダ表記へ修正。**検査の除外条件を 1 つも増やさずに解決**した。

### 変更 2: drift-check の担保範囲の主張を実測に合わせて訂正

plan 初稿は「ミラー対の内容一致は `drift-check` job が担保する」と書いていたが、
実測で **skill だけ経路が違う**ことが判明した:

- agent / command: `.claude/` → `plugin/plangate/`（drift-check が担保）
- **skill: `.agents/skills/` → `plugin/plangate/skills/`**（`.claude/skills` は経由しない）
- `.claude/skills` ⇄ `.agents/skills` の内容 parity 検査は**存在しない**

plan の該当表と script の docstring を訂正し、
**既知の残存ギャップ（M-1b）として別 PBI に上げる**方針に変更した。

### 変更 3: 検出力を 1 クラス「追加」した（当初計画になし）

`find_collisions` の抽出条件を「distinct root_label が 2 以上」→「定義が 2 以上」に
変更したことで、**同一 root 内の重複**（従来は原理的に検出不能）が
新たに検出対象になった。検査を弱めるだけの変更にしない。

### 変更 4: 変異 M2a が空振りした（正直に記録）

`_has_exactly_two` の call site を壊しても TC が落ちなかった。
原因は TC の欠陥ではなく **`root_label` の値域に由来する論理的冗長性**。
条件は削らず残し、理由を `evidence/mutation-testing.md` に記録した。

## V 系ステップ進捗

| ステップ | 状態 |
|---------|------|
| C-1 | ✅ PASS（WARN 2 / FAIL 0） |
| C-2 | ⏸ 未実施（high-risk のため必要。オーガナイザー / 人間の判断待ち） |
| **C-3** | ⏳ **人間待ち**（high-risk = autonomous APPROVE 不可） |

## 残タスク

- [ ] **H-01 C-3 人間レビュー**（high-risk）
- [ ] H-02 CI 配線 patch の適用 — `owner: human` / `blocker: .github/workflows/* は Hardening Override` / `unblock_condition: C-3 APPROVE 後に人間が git apply`
- [ ] H-03 PR 作成 → C-4

### BLOCKED / 別 PBI 送り

| 項目 | blocker | owner | unblock_condition |
|------|---------|-------|-------------------|
| `.claude/skills` ⇄ `.agents/skills` の内容 parity 検査 | 新規検査の設計判断が必要（本 PBI のスコープ外） | human（PBI 起票） | 別 PBI 化 |
| `claude plugin validate --strict` の CI 配線 | frontmatter を持たない 5 command の是正が必要。正本 `.claude/commands/*.md` は **Hardening Override** | human | 5 command に frontmatter 追加後 |
| plugin にしか存在しない 15 skill の配布レーン非対称 | #1144 の領域 | — | #1144 |

## 参照ファイル一覧

- `docs/working/TASK-1087/{pbi-input,plan,todo,test-cases,review-self}.md`
- `docs/working/TASK-1087/evidence/classification/{collisions-46,stale-refs-7}.md`
- `docs/working/TASK-1087/evidence/mutation-testing.md`
- `docs/working/TASK-1087/ci-wiring.patch`（**未適用**）
- `scripts/check-skill-name-collisions.py` / `scripts/check-stale-skill-refs.py`
- `tests/extras/ta-69-distribution-checks.sh` / `tests/extras/ta-52-doctor-skill-collision.sh`
- `docs/ai/skill-collision-detection.md` / `docs/ai/stale-ref-detection.md`
