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
| 2026-08-18 | — | **C-3 待ち（人間）**。`c3.json` は発行していない |

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
