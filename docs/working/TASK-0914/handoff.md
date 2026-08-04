---
task_id: TASK-0914
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-08-02
author: qa-reviewer
v1_release: "0ebb8fee0951631aad4a0107049f5d9dad27402d"
---

# Handoff Package — TASK-0914

> **status: final**（2026-08-04 確定）= draft に留めていた唯一の残条件 `bin/plangate doctor --check-settings` PASS が充足されたため final 化した。経緯: Human が main checkout で `sh scripts/apply-claude-settings.sh` を実行（AI は self-mod ガードにより実行不可 = Human-owned）→ 同 checkout で `bin/plangate doctor --check-settings` が `PASS: settings wiring 契約準拠(target=user)` / **rc=0** を出力 → AI（オーケストレーター）が同コマンドを独立に再実行して同一結果を確認。V-1 独立検査（2026-08-02）の**条件付き PASS** は、この条件充足により **PASS** へ確定（§1）。
> mass-delete guard の 3 経路拡張（#877 follow-up）+ R-204: extras harness 判別の AND 統一 + standalone env 無害化。

## メタ情報

```yaml
task: TASK-0914
related_issue: https://github.com/s977043/plangate/issues/914
author: qa-reviewer
issued_at: 2026-08-02
v1_release: "0ebb8fee0951631aad4a0107049f5d9dad27402d"  # PR #986 マージ commit（2026-08-04T22:18:46Z / C-4 by s977043）
```

- Mode: **high-risk**（C-3 Human APPROVED 2026-08-02 12:40 / autonomous APPROVE 不可）
- ブランチ: `fix/914-mass-delete-guard`（exec 基点 = origin/main `f25ae8b`。plan 基点 `90c313d` からの前進差分は本 PBI 対象 3 領域に影響なし — status.md「計画からの変更点」）
- 実装完了 head: `ef65021`（T-01〜T-09）+ 記録コミット（T-10/T-11/handoff）

## 1. 要件適合確認結果

exec 内機械検証（T-06 / T-09 / T-11）と **V-1 独立検査（acceptance-tester・2026-08-02 実施）**の結果。V-1 は status.md「T-09」節の V-1-A / V-1-B / V-1-B' / AC-9 スニペットの独立再実行 + test-cases.md 全件突合で判定した（独立再実行の実測: ta-26 standalone **30/0**・V-1-A/B/B' 各 **64 PASS / NG 0**・AC-9 **残存 0 / 包含 MISSING=0**・フルスイート **467/0**・rc すべて 0。いずれも当時の基点 `f25ae8b` での実測値。**2026-08-05 の再実測は 538〜539 passed / 0 failed**〔§2 鮮度〕）。

| 受入基準 | exec 内判定 | V-1 独立検査 | 根拠 / evidence |
|---------|------------|--------------|----------------|
| AC-1: 経路2（ai-loop refs）guard 発火 + `guard_fired` 経由 exit 3 | PASS | PASS（ta-26 standalone 30/0 再実行） | TC-20/21/22/25 PASS（`evidence/test-runs/t05a-tc20-25-standalone.log`）+ sandbox 手動再現（`evidence/verification/t03-path2-guard-repro.log`）+ M-1/M-3/M-4 変異で FAIL 実証 |
| AC-2: 経路1（汎用 refs）guard 発火 + exit 3 | PASS | PASS（ta-26 standalone 30/0 再実行） | TC-26/27/32 PASS（`t05b-tc26-34-standalone.log`）+ sandbox 再現（`t04-path1-guard-repro.log`）+ M-2/M-3/M-4/M-5 変異で FAIL 実証 |
| AC-3: 各経路の負側 + 正常系 TC が ta-26 に存在（検出力実証込み） | PASS | PASS（TC 存在は 30/0 内・変異 M 系は evidence-based — WARN ②） | 負側 TC-20/21/22/26/27・正常系 TC-24/29・境界 TC-34・dry-run 一致 TC-25/32 追加。変異 8 件（M-1〜M-7 + M-6b）全てで期待 FAIL 実測・空振り fixture 0（status.md「T-06 変異注入マトリクス」+ `t06-m{1..7,6b}-*.log` 8 本） |
| AC-4: `PLANGATE_ALLOW_MASS_DELETE=1` override が全経路一貫 | PASS | PASS（ta-26 standalone 30/0 再実行） | TC-23/28 PASS + 既存 TC-11/TC-15 PASS 維持。M-7（override 判定削除）で TC-23/28 + 既存 TC-11 が FAIL = 共通関数 1 箇所で全経路担保の裏付け（`t06-m7-override-removed.log`） |
| AC-5: `tests/extras/README.md` に判別規約明記 | PASS | PASS（ta-26 30/0 内 TC-30） | 規約 8（AND 判別 / 非 export / standalone 側 = 安全側 / 7 env unset / TC-33 言及）追記 + 規約 7 末尾是正（RV-m3）。TC-30 PASS（`t08-ta26-all30-pass.log`） |
| AC-6: 11 extras 移行後、フルスイート 0 failed + standalone 3 条件（①`[FAIL]` 不在 ②exit 0 ③`[PASS]` 件数 baseline 一致） | PASS | PASS（V-1-A 64 PASS / NG 0 + フルスイート 0 failed・rc 0） | V-1-A: 64 PASS・NG 0・per-file baseline（T-01 表）全一致（`t09-v1a-clean.log`）。フルスイート **467 passed / 0 failed**（基点 `f25ae8b`。T-08 `t08-full-suite-467.log` / T-11 `t11-full-suite-clean.log`。todo 記載 444 は基点前進で 467 へ読み替え = status.md「計画からの変更点」）。**2026-08-05 再実測 = 538〜539 passed / 0 failed・rc 0**（worktree + squash 前ブランチ tree で 538／primary checkout + main 起点 `0ebb8fe` で 539。差は #947 の既知変動＝worktree で `ta-13 TC-17` が素通りするため）。総数は基点依存のため契約値にしない（AC の本体は「0 failed」） |
| AC-7: 汚染 env 下でも AC-6 と同結果 | PASS | PASS（V-1-B / V-1-B' 各 64 PASS / NG 0・rc 0） | V-1-B（6 env + `FIXTURES_DIR` 注入）+ V-1-B'（`PG_HARNESS_SOURCED` 単独）とも 64 PASS・NG 0・baseline 一致（`t09-v1b-contaminated.log` / `t09-v1bprime-single.log`）。移行前 NG_TOTAL=8 → 移行後 0 の対比で検出力証明（`t01-ac7-contaminated-pre.log`） |
| AC-8: exit code 伝播欠落の別 issue 起票 + 妥協点記録 | PASS | PASS（V-1-C 成果物確認。等価記述で実質充足 — WARN ①） | [#921](https://github.com/s977043/plangate/issues/921) 起票済（P1）+ W1/T-01 実測根拠を[コメント追記](https://github.com/s977043/PlanGate/issues/921#issuecomment-5155633541)（2026-08-02）。妥協点は本書 §4（R-309 の 2 点） |
| AC-9: `FIXTURES_DIR` 単独判別の残存 0 + unset 集合の包含（件数ハードコードなし・ta-26 も対象） | PASS | PASS（独立再実行: 残存 0 / 包含 MISSING=0・rc 0） | TC-33 PASS + TC-33 と独立の grep -L / awk 実装で残存 0・harness 7 env 集合の包含成立（`t09-ac9-static.log`。対象は当時 12 ファイル → **2026-08-05 再実測で 15 ファイル・残存 0**。対象数は main 前進で増えるため契約値にしない） |
| （不変条件）`sync_dir` 経路の挙動が共通関数化で不変 | PASS | PASS（ta-26 standalone 30/0 再実行） | 既存 TC-08〜TC-17 全 PASS 維持（T-02 チェックポイント 16/16 → 最終 30/30。`t11-ta26-standalone.log`） |

**総合（exec 内）**: 9/9 AC PASS + 不変条件 PASS
**総合（V-1 独立検査）**: **PASS**（2026-08-04 確定）。2026-08-02 の V-1 実施時点では **条件付き PASS**（条件 = `bin/plangate doctor --check-settings` PASS 待ちのみ。テストケース側 FAIL 0）であり、2026-08-04 に Human が main checkout で `sh scripts/apply-claude-settings.sh` を実行 → `bin/plangate doctor --check-settings` が PASS（rc=0）→ AI が独立に再実行して同一結果を確認、をもって唯一の条件が充足されたため PASS へ確定した（条件付きだった経緯は監査連続性のため保持）
**V-1 WARN 2 件**（いずれも判定を覆さない）: ① V-1-C の確認語「`exit $fail` 欠落」の字句は #921 本文に不存在だが、等価記述（伝播欠落の実測記述）で実質充足 ② 変異 M 系（M-1〜M-7 + M-6b）は evidence-based 検証（検査側のファイル編集禁止制約により、T-06 evidence ログ 8 本の突合で判定）
**FAIL / WARN の扱い**: テストケース側 FAIL 0（上記 WARN 2 件のみ）。**handoff 完了の前提 `bin/plangate doctor --check-settings` PASS は 2026-08-04 に充足済み**（Human が main checkout で `sh scripts/apply-claude-settings.sh` 適用 → `PASS: settings wiring 契約準拠(target=user)` / rc=0 を実測、AI が独立再実行で確認。適用後の `.claude/settings.json` PreToolUse は 8 本 = EH-1 / EH-2 / EH-3〔`${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}` 引数付き〕/ EH-6 / approval-token-write ×2 / EH-9 / EH-12。既存の EH-9・EH-12 は保持）。なお worktree 内では gitignored `.claude/settings.json` が非複製のため同コマンドは構造的に FAIL する（環境制約であり Shadow Config ではない。PASS 実測は main checkout 側で行う必要がある — §2）。

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| extras standalone の exit code 伝播欠落（`fail > 0` でも exit 0。11 本に限らず extras 全般） | major | open（**#921** で追跡・本 PBI スコープ外 = 案 C） | Yes（#921 完了時に AC-6 判定を exit code ベースへ戻す） |
| 全変異で TC-13 が副次 FAIL する連鎖構造（TC-13 は子プロセスで ta-26 を再帰実行するため、他 TC の FAIL が必ず伝播する — W3/T-06 観察） | minor | accepted（構造どおりの挙動。単独原因の特定は「期待 FAIL TC」列で行う運用） | No |
| test-cases.md V-1-B' スニペットの env 引数順が BSD/GNU env 仕様（オプションは NAME=VALUE より前）に反し rc=127 で実行不可 | minor | workaround（status.md「計画からの変更点」の読み替え `env -u FIXTURES_DIR PG_HARNESS_SOURCED=1 sh "$f" </dev/null` で運用。C-3 承認後の plan 変更禁止のため原本未修正） | Yes |
| フルスイート総数の期待値が環境依存（ベースが 452/453/454 と振れる既知事象 #947・#942。worktree で ta-13 TC-17 が素通り / トピックブランチで ta-57 TC-14 が実行される） | minor | open（#947 / #942 で追跡。本 exec は worktree + トピックブランチで一貫して 453 ベース + 14 = 467/0 を実測。2026-08-05 の基点更新後は 538/0（worktree）/ 539/0（primary checkout）で、**この振れ自体が本事象の再現**。**総数を期待値として固定せず「0 failed」で判定する**運用へ是正済み — §2 鮮度） | No |
| `bin/plangate doctor --check-settings` が worktree 内で構造的 FAIL（gitignored `.claude/settings.json` が worktree に複製されない） | minor | accepted（**Human 待ちは 2026-08-04 に解消**: main checkout で `sh scripts/apply-claude-settings.sh` 適用後に PASS / rc=0 を実測 → AI が独立再実行で確認 → V-1 は PASS 確定・handoff final 化済み。ただし「worktree 内では構造的に FAIL する」という制約自体は仕様どおり残存し、doctor の実測は常に main checkout 側で行う必要がある） | No |
| 経路1 の stale 集計が dst 側 symlink を `[ -L ]` で除外する一方、削除ループは除外せず非対称（River Review F-1・test-cases E-7 の残穴が実測再現で確定） | minor | open（**#970** で起票済み・follow-up。C-3 plan_hash 束縛下の設計残穴のため本 PBI では変更しない。現リポジトリの該当 references/ に symlink 0 件で顕在化しない） | Yes（#970 で追跡） |
| `tests/extras/ta-54-ai-loop-link-selfcontained.sh` L43/L63 の `\|\| true` がスクリプト失敗を握りつぶす構造 | minor | accepted（**指示による仕様判断の記録**: ta-54 は #914 の対象 11 本〔ta-39/43/44/45/46/47/49/50/51/52/53〕に含まれず、#947 が追跡する既知の別件。本 PBI では変更しない） | No |
| guard の発火境界: `stale > base` のみ発火し、`stale == base`（== src）は非発火（正当な全量入れ替え同期を許容） | info | accepted（**仕様として意図した境界**。境界は TC-34 で固定し、`>=` への変異 M-6b が TC-34 で検出されることを実証済み） | No |
| 経路2 base 算出の未 quote `set --` が pathname 展開に晒される（River Review F-5） | info | accepted（対処不要判定: 対象が repo 管理下 docs ファイル名のため実害窓は無視できる） | No |
| **AC-9 の機械ゲート（TC-33 検査 (1)）が移行済みファイルに対し空振りする** — 検査 (1) はファイル全体への `grep -q 'PG_HARNESS_SOURCED'` だが、検査 (2) が同名を含む harness 7 env の unset を要求するため、**検査 (2) を通るファイルでは検査 (1) が常に真**になる。結果、判別行だけを `FIXTURES_DIR` 単独へ差し戻す変異を TC-33 は検出しない（sandbox 実測: `ta-59:21` を単独判別へ戻して `[PASS]`。ファイル全体から削除した場合のみ検出）。**本 PBI が閉じた穴の再発を機械ゲートが見逃す**という意味で AC-9 の検出力に構造的な限界がある | major | open（**[#994](https://github.com/s977043/PlanGate/issues/994)** で追跡。C-3 plan_hash 束縛下のため本 PBI では検査ロジックを変更しない。対処案 = 判別行そのものを対象にする検査へ差し替え + **判別行のみの差し戻し変異で FAIL することを実証**〔現状この fixture の検出力が未検証だった〕） | Yes（#994 で追跡） |
| **経路2 の guard は少数側正本ディレクトリの完全欠損を検出しない**（base が `docs/workflows/ai-loop/` と `docs/ai/ai-loop/` の**合算**であるため、少数側 `docs/ai/ai-loop/` を丸ごと消しても `stale <= base` のままとなり WARN なし・exit 0 で削除が通る。逆向き〔多数側 `docs/workflows/ai-loop/` の欠損〕は正しく block する — sandbox 実測で双方向を確認） | minor | accepted（**実装バグではなく plan 論点 C-2 で Human 承認済みの設計選択**。ディレクトリ単位の完全欠損を検出するには正本ごとに base を分離する必要があり、本 PBI のスコープ外。`scripts/sync-plugin-plangate.sh` の該当コメントを保証範囲どおりに是正済み。follow-up issue **[#991](https://github.com/s977043/PlanGate/issues/991)** 起票済み） | Yes（#991 で追跡） |

**Critical 課題の対応**: critical なし。

**鮮度（River Review F-4 更新・2026-08-05 是正）**: 従来この節は「main 前進との接触ファイル交差 0」を V-1 PASS の鮮度根拠にしていたが、**この根拠付けは誤りだったため撤回する**。

- **全体量化子を含む AC の鮮度は接触ファイル交差では担保できない。base 更新のたびに機械ゲートを再実行して判定する必要がある。** AC-9（「`FIXTURES_DIR` 単独判別の残存 **0**」「unset 集合の**包含**」）はリポジトリ全体に対する不変条件であり、ブランチが触っていないファイルでも main 側が `tests/extras/` に 1 本追加するだけで破れる。交差 0 が意味するのは「テキスト衝突が起きない」ことだけで、「全体不変条件が保たれている」ことではない。
- **実害として顕在化（因果は 3 段階。1 つの出来事に圧縮しないこと）**:
  1. **破れ**: main に `ta-58-git-destructive-guard.sh`（`c25c022` / #967）と `ta-59-apply-settings-merge.sh`（`a667c0d` / #976）が入り、**ブランチが 1 行も触っていないのに AC-9 が破れた**（＝交差 0 が鮮度を担保しない実例。本節の論旨はここで成立する）
  2. **是正済み**: 上記の破れは **[PR #988](https://github.com/s977043/PlanGate/pull/988)（`7680145`）が解消**した（ta-58 を `PG_HARNESS_SOURCED` AND 判別へ変更 + standalone 分岐に 7 env unset を追加 / ta-59 は判別式が既に AND で、`unset` の行継続を 1 行化）。`be53897` 時点で **ta-58・ta-59 はいずれも規約準拠済み**である
  3. **別経路での再発**: その後 `ta-60-run-evidence.sh`（#989）が `unset` を行継続（末尾 `\`）で 3 行に分けて持ち込み、**TC-33 のパーサが継続行を読めない**ことによる false positive が発生。これが `be53897` 時点で残っていた CI 2 failed（ta-26 の TC-33 + その TC-13 連鎖）の**直接原因**である（`ta-60` 自体は 7 env すべて unset 済みで修正不要）
- **本コミット（`7dad6dd`）が実際に直したもの**: ① TC-33 のパーサを awk で行継続結合してから走査するよう是正 ② **ta-58 の standalone fallback**（`pass`/`fail`/`register_cleanup` + 末尾 drain・サマリ・exit code）を追加 — これは #988 の積み残しで、**AND 判別と 7 env unset は #988 で既に入っていた**。fallback が無い間は standalone でカウンタもサマリも未定義のため、FAIL があっても exit 0 で素通りしていた
- **是正後の運用**: 鮮度判定は接触ファイル交差ではなく、**base 更新のたびに `sh tests/run-tests.sh`（AC-6/7）と AC-9 静的検査スニペット（全文は status.md「T-09」節に収録）を再実行し、その実測 rc / 件数で行う**。

**再実行の実測（2026-08-05・本コミット tree）**: フルスイート **538〜539 passed / 0 failed**・rc=0（TC-13 / TC-33 を含む全 PASS）。3 者独立実測（オーケストレーター + W チェック Model A / Model B）で **0 failed** は完全一致し、総数のみ 538（worktree）/ 539（primary checkout・main 起点 `0ebb8fe`）に振れた＝**#947 の環境依存変動が実測で再現**（`ta-13 TC-17` が worktree では素通りする）。この振れ自体が「総数を契約値にしない」判断の裏付けになっている。AC-9 静的検査 = 検査対象 **15 ファイル**（`FIXTURES_DIR:-` を含む extras 全件）・単独判別残存 **0**。件数は基点により増えるため契約値として固定しない（検査自体は件数非依存）。

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|-----------|
| **#921 完了時に AC-6 の判定を exit code ベースへ戻す**（代理判定〔`[FAIL]` 文字列不在 + `[PASS]` 件数 baseline 一致〕の解消） | 代理判定は exit code 伝播欠落が直る（#921 AC-6）までの暫定。恒久化させない | High | [#921](https://github.com/s977043/plangate/issues/921) |
| standalone preamble の共通化（7 env unset のインライン 12 ファイル重複の解消） | 論点 E-2（インライン）採用の代償。drift は AC-9 静的検査で機械検出できるため緊急性は低い（R-306 / U-3） | Low | — |
| test-cases.md V-1-B' スニペットの原本是正（env 引数順） | C-3 plan_hash 束縛下で原本を触れなかった。次に plan 系文書を正規手順で更新する機会に反映 | Low | — |
| `tests/extras/README.md`「現行テスト一覧」表のドリフト是正（53 本中 12 本のみ掲載） | #921 本文でも Out of scope とされた別の文書負債 | Low | — |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| **案 C: 判別式統一 + env 無害化まで。exit code 伝播は #921 へ分離**（R-309 ①） | 同一 PBI で伝播まで実施（案 A/B） | 2026-07-25 Human 決定によるスコープ境界。**代償: 同一 11 ファイル（+README）を本 PBI と #921 で 2 回触る**（コンフリクト・二重レビューのコスト）。#921 に W1 実測根拠をコメント固定して引き継ぎコストを最小化 |
| **AC-6 を代理判定（`[FAIL]` 不在 + `[PASS]` 件数 baseline 一致）で検証**（R-309 ②） | exit code ベースの判定（「standalone が非ゼロ終了しない」） | 伝播欠落（#921）が残る間、exit code 判定は無条件成立で空振りする（R-301）。**代償: 代理判定が #921 完了まで恒久化** → §3 の V2 候補（High）で exit code ベースへ戻すことを明記 |
| 7 env unset を各 extras へインライン記述（論点 E-2） | 共有 preamble ファイル `_standalone-preamble.sh`（E-1） | ta-26 既存実装と同型（既存パターン準拠）。共有ファイルは `ta-*.sh` glob 外の新規ファイルで extras 自己完結の慣習を崩す。重複 drift は AC-9（`run-tests.sh` 集合 ⊆ 各 extras 集合）で機械検出 |
| 変異注入の復元元を W2 完了 head `1e1c074` に固定（todo 記載 `90c313d` から読み替え） | `git show 90c313d:` からの復元（plan 時点の表記） | 90c313d へ戻すと W1/W2 実装（guard 3 経路 + TC）ごと消えて変異と無関係の FAIL が出る。オーガナイザー指示 + decision-log 記録済み。全 8 サイクルで復元後 diff 空 + 30/0 復帰を実測 |

## 5. 引き継ぎ文書

### 概要

前段の #877（v8.18.0）で `sync_dir` 経路に入った mass-delete guard（fail-closed / exit 3 / `PLANGATE_ALLOW_MASS_DELETE` override）を、`scripts/sync-plugin-plangate.sh` に残っていた 2 つの削除経路 — 経路1（汎用 skill references）/ 経路2（ai-loop references）— へ共通関数 `_mass_delete_blocked()` として拡張した。あわせて R-204（外部 env 漏れによる誤判定）対策として、`tests/extras/` 11 本の harness 判別を `FIXTURES_DIR` 単独から **`PG_HARNESS_SOURCED` AND `FIXTURES_DIR`** へ統一し、standalone 分岐で 7 env を unset（片方欠けは standalone 側 = 安全側へ倒す）。

検証は新規 14 TC（ta-26 は 16 → 30 TC）+ **変異注入 8 件全てで期待 FAIL を実測**（空振り fixture なし）+ AC-6/7/9 の 3 独立ループ機械検証（64 PASS × 3・baseline 全一致）+ フルスイート **538〜539 passed / 0 failed**（2026-08-05。CI 修正コミット `7dad6dd` を含む tree で実測。main 起点で再現する場合の基点は `0ebb8fe`＝PR #986 の squash merge。exec 当時の基点 `f25ae8b` では 467/0）。現状: **exec 完了・V-1 PASS 確定（2026-08-04 に残条件の doctor PASS が充足。実施時点〔2026-08-02〕は条件付き PASS）・[PR #986](https://github.com/s977043/PlanGate/pull/986) は 2026-08-04T22:18:46Z に C-4 APPROVE + マージ済み（merge commit `0ebb8fe`）**。

### c3.json の顛末（承認トークンの保全記録）

`approvals/c3.json` は Human 発行（2026-08-02T03:37:59Z・CLI = `plangate approve`）→ 並行セッションの `git stash push -u` により untracked のまま作業ツリーから退避 → `stash@{0}^3`（untracked を保持する第 3 親）から非破壊抽出し、コミット `fb443e8` で tracked 化した（River Review F-2 解消）。教訓: **承認トークンは発行直後に tracked 化する**（untracked のまま置くと並行セッションの stash / clean に巻き込まれ、承認証跡が消失しうる）。

### 触れないでほしいファイル

- `scripts/sync-plugin-plangate.sh` の guard 3 箇所と閾値 `stale > base`: M-3（+100）/ M-6b（`>=`）で境界の両側を変異検証済み。閾値・呼び出し位置を動かすと 14 TC + 変異マトリクスの均衡が崩れる
- `tests/extras/ta-*.sh` の判別式（AND 化済み **15 ファイル**・2026-08-05 実測。exec 当時は 12 ファイル）: TC-33 + AC-9 独立検査が静的に守っている。`FIXTURES_DIR` 単独判別へ戻すと即 FAIL する（意図された防御）
- `docs/working/TASK-0914/plan.md`: C-3 APPROVED の plan_hash 束縛下。編集すると EH-3 が mismatch 検知する
- `docs/working/TASK-0914/decision-log.jsonl`: append-only（既存行の編集・削除禁止）

### 次に手を入れるなら

- **V-1（実施済み・2026-08-02 / 2026-08-04 に PASS 確定）**: acceptance-tester が test-cases.md 全件突合 + status.md「T-09」節の V-1-A / V-1-B / V-1-B' / AC-9 スニペット再実行で**条件付き PASS** → 残条件（doctor PASS）充足により **PASS**（§1）。再実行時の注意はそのまま有効: **全ループ `sh "$f" </dev/null` 必須**（ta-50 が非 tty stdin 未リダイレクトで無限ハング — RV-M1）
- **完了条件の消化状況**: ✅ ① `sh scripts/apply-claude-settings.sh` を **Human が実行**（AI は self-mod ガードで不可・2026-08-04 実施） → ✅ ② `bin/plangate doctor --check-settings` PASS を実測（rc=0・AI が独立再実行で確認。§2） → ✅ ③ handoff frontmatter を `status: final` 化（2026-08-04） → ✅ ④ [PR #986](https://github.com/s977043/PlanGate/pull/986) 作成 → **C-4 APPROVE + マージ（2026-08-04T22:18:46Z / merge commit `0ebb8fe` / by s977043）**。

> ⚠️ **マージ後に判明した記録上のギャップ（2026-08-05）**: PR #986 は head `7dad6dd`（CI 全 pass）でマージされたが、その直後に作られたレビュー反映コミット（本ファイルを含む guard コメント是正・鮮度根拠是正・#991 / #994 の記録）は **closed 済みの PR ブランチへ push されたため main に入らなかった**（closed PR は head 更新も CI も走らない）。当該変更は本 follow-up PR で main へ届ける。
>
> high-risk のため V-2 / V-3 は本来必須（mode-classification フェーズ適用）だが、**実施前にマージされた**。未実施であることを事実として記録する（§3 V2 候補・§4 妥協点を参照）。

- アンチパターン: `scripts/sync-plugin-plangate.sh` の素実行禁止（検証は必ず sandbox 経由 = `_t26_mk_*_sandbox` ヘルパー）/ 変異検証の復元元に `HEAD:` を使わない（exec 中に移動する）/ 汚染注入で `PG_HARNESS_SOURCED` と `FIXTURES_DIR` を同時に立てない（harness 分岐へ入り検証が消える — RV-M2）

### 参照リンク

- 親 issue: [#914](https://github.com/s977043/plangate/issues/914) / follow-up: [#921](https://github.com/s977043/plangate/issues/921) / 前段: [#877](https://github.com/s977043/plangate/issues/877)（PR #915）
- status.md: [`docs/working/TASK-0914/status.md`](./status.md)（T-01 baseline 表 / T-06 変異マトリクス / T-09 検証コマンド全文 / 計画からの変更点）
- plan: [`plan.md`](./plan.md) / [`todo.md`](./todo.md) / [`test-cases.md`](./test-cases.md) / C-2: [`review-external.md`](./review-external.md)

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| ta-26 standalone（guard TC: 既存 16 + 新規 14） | 30 | 30 | 0 | — |
| 移行 11 本 standalone（V-1-A / V-1-B / V-1-B' の 3 独立ループ） | 64 × 3 | 192 | 0 | — |
| フルスイート `sh tests/run-tests.sh`（T-11 / clean env・基点 `f25ae8b`） | 467 | 467 | 0 | — |
| フルスイート `sh tests/run-tests.sh`（2026-08-05 再実測 / clean env。main 起点で再現する場合の基点は `0ebb8fe`） | 0 failed | 538〜539 | 0 | 3 者独立実測で 0 failed 一致・総数のみ 538（worktree）/ 539（primary checkout）。総数は基点依存のため契約値にしない |
| `bash tests/extras/ta-58-git-destructive-guard.sh` standalone（2026-08-05） | 0 failed + サマリ/exit code 出力 | 40 | 0 | rc=0。変異注入時は 39/1・**rc=1**（修正前の HEAD 版は同じ変異で 1 FAIL でも rc=0 の素通り）を対比実測 |
| `bash tests/extras/ta-26-plugin-sync.sh` standalone（2026-08-05） | 0 failed | 30 | 0 | rc=0。修正前の HEAD 版は TC-33 が ta-60 の行継続 `unset` を読めず false positive で 29/1 |
| 変異注入（M-1〜M-7 + M-6b） | 8 変異 | 8/8 で期待 FAIL 実証 | 空振り 0 | — |
| 静的検査（TC-30 / TC-33 + AC-9 独立実装） | 3 検査 | 3 | 0 | — |

**FAIL / SKIP の詳細**: テスト FAIL なし。`doctor --check-settings` の worktree 内 FAIL は環境制約（§2）でありテスト失敗ではない。T-05c 時点の TC-30/33 FAIL は TDD RED（実行順による想定内・T-07/T-08 で PASS 転化を対比実測済み — status.md「計画からの変更点」）。

## 7. Metrics summary（任意）

該当なし（本 run では `bin/plangate metrics` を未 collect）。
