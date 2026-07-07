# Frictions Digest 001（Run-011 派生ダイジェスト）

> 本書は元ログ（`run-001-frictions.md`・append-only 時点記録）の**検証つき派生ダイジェスト**。
> 元ログが一次情報であり、本書と食い違う場合は元ログが正。更新は -002 等の新番で行い
> 本書は上書きしない。採用判断は C-4。

## 状態表（F-1〜F-24 全件）

| F-ID | 一言要約（元ログの文言に忠実）                                                                                                                                                   | 状態               | 反映先/根拠                                                                                                                                                                                    |
| ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| F-1  | reject_category を日本語で返され L1 が正規化を要した。委託プロンプトに enum 厳格指定（英語小文字 14 語彙）が必要                                                                 | optimized-verified | `.claude/skills/ai-loop-cycle/SKILL.md` L105「reject_category は enum の英小文字値をそのまま（verbatim）返させる」＋ `scripts/ai-loop/arbiter.py` の `reject_category` 正規化・provenance 出力 |
| F-2  | asset-inventory.md/related-specs.md はスナップショットで living index の置き場が未定義                                                                                           | optimized-verified | `docs/ai/ai-loop/README.md`「living な文書地図はどこにあるか」（Run-002 の人間判断 (a) を受けた薄い入口の新設）                                                                                |
| F-3  | ho-paths.md L101「Phase 0 限定の例外」が恒久指定か期間限定免除か曖昧                                                                                                             | open               | `docs/ai/ai-loop/ho-paths.md` L101 は現状も同文言のまま未改訂。issue #739（ho-paths 曖昧性）で追跡（`run-003-loopspec.md` L110 に言及）                                                        |
| F-4  | deterministic 検証が「部分同期」を PASS させる穴。AC を機械検証可能な形に落とす規律が必要                                                                                        | optimized-verified | `docs/workflows/ai-loop/loopspec.md` L59・L100「機械検証コマンドの列挙（構造化）」                                                                                                             |
| F-5  | Model A/B が同一前提に収斂せず真に分岐（非対称 W チェックの独立性が実証された）                                                                                                  | recorded           | 成功シグナル（run-001-frictions.md 記録のみ、対応不要）                                                                                                                                        |
| F-6  | L1 が自分に不利な証拠で lite 自己申告を訂正 → arbiter が決定論で escalate。安全側デフォルトが機能                                                                                | recorded           | 成功シグナル（同上）                                                                                                                                                                           |
| F-7  | Model B が計画自身の AC 設計に F-4 同型の穴を検出。「AC の機械検証化」は再帰適用すべき規律と判明                                                                                 | optimized-verified | `run-003-loopspec.md` L6・L59「AC（機械検証 — F-7 反映）」で範囲厳密化を実装                                                                                                                   |
| F-8  | AC-3「記録層または契約層」の曖昧さ。配置の選択肢は W チェック前に 1 つへ確定させる方が安い                                                                                       | optimized-verified | `run-003-loopspec.md` L7・L66「Files（Expected Diff・一意確定 — F-8 反映）」で以降のフィールドは `w_check.reject_category` に一意確定                                                          |
| F-9  | F-1 Optimize が初適用で機能（reject_category が enum 準拠）。記録→Optimize→効果確認の I-5 ループが 1 巡した                                                                      | recorded           | 成功シグナル                                                                                                                                                                                   |
| F-10 | provenance に Model B の reject_category と C/D 起動理由が記録されず、severity 分類根拠が record 単体で追跡不能                                                                  | optimized-verified | `scripts/ai-loop/arbiter.py`（`classify_severity` / `w_check["reject_category"]` 格納・全 decision record 生成箇所への引き渡し）                                                               |
| F-11 | 裁定エンジンの記録方式を裁定エンジン自身のガバナンスで変更する自己参照構造。arbiter.py 判断ロジック変更は touches_ho:unconditional 相当の固定ルール化を検討すべき（#739 と同族） | open               | issue #739 と同族（`run-001-frictions.md` L71 に明記）。arbiter.py の decision table 優先順位・SEVERITY_MAP 変更ゲートの固定ルール化は未実装                                                   |
| F-12 | 機械検証コマンド自体に欠陥が2度混入。検証コマンドは計画時に実機で PASS/FAIL 両方向を確認する規律が必要                                                                           | optimized-verified | `docs/workflows/ai-loop/loopspec.md` L101・L121「deterministic の各コマンドは、計画時に実機で PASS/FAIL 両方向の挙動を確認してから AC に採用する」                                             |
| F-13 | W チェックの両極性が実証（A も reject を出し、B は無限 reject 禁止の下で承認に収束。3ラウンド規律の全経路が1 run内で発火）                                                       | recorded           | 成功シグナル                                                                                                                                                                                   |
| F-14 | 計画の「実機で両方向検証済み」申告自体が虚偽だった。レビュアーは事前検証の申告に実行出力の貼付（証跡）を要求すべき                                                               | optimized-verified | `.claude/skills/ai-loop-cycle/SKILL.md` L74「『検証済み』申告には証跡（実行出力の貼付）があるか確認し、なければ未検証として扱う」＋ `docs/workflows/ai-loop/loopspec.md` L123                  |
| F-15 | F-1 Optimize の連鎖確認: スキル定型使用で4ラウンド連続 reject_category が enum 準拠                                                                                              | recorded           | 成功シグナル                                                                                                                                                                                   |
| F-16 | 教訓の事前適用でラウンド数が3→1に短縮。「前 run の reject 理由を次 run の計画チェックリストに変換する」が最も効率の高い Optimize                                                 | recorded           | 成功シグナル                                                                                                                                                                                   |
| F-17 | 証跡の「貼付」水準が要約で満たされ得る曖昧さ・捏造には無力。多層防御が前提であることを規律の限界として明記すべき                                                                 | recorded           | 限界として明記済み（`docs/workflows/ai-loop/loopspec.md` L114「maker の誠実申告と checker の突合という多層防御を前提とする（F-17 と同族の限界）」）。恒久的限界の記録であり追加対応の余地なし  |
| F-18 | deterministic 欄が「コマンド+日本語注記」混在でそのまま実行不可。純粋コマンド+期待exit codeの分離フィールド形式が必要                                                            | optimized-verified | `docs/workflows/ai-loop/loopspec.md` L59「構造化 — F-18/Run-006」・`cmd`/`expect_exit`/`note` の分離フィールド定義                                                                             |
| F-19 | 構造体は expect_stdout を持たず、count≥N型判定は exit code単体で表現できない footgun                                                                                             | optimized-verified | `docs/workflows/ai-loop/loopspec.md` L102「count ≥ N 型の判定は cmd 内で exit code に畳み込む」で当面の対策は反映済み。expect_stdout 追加自体は L3 自動実行設計時に再検討（open backlog 参照） |
| F-20 | 設計判断を含む run は lite を誠実に false 申告→W チェック前に human へ、の経路が機能。escalate の2型が出揃った                                                                   | recorded           | 成功シグナル                                                                                                                                                                                   |
| F-21 | allowed_paths/ho-paths の glob 意味論（fnmatch/globstar/git pathspec）が未定義のまま表記慣習で運用                                                                               | open               | `docs/ai/ai-loop/ho-paths.md` に glob/fnmatch/globstar の明示定義なし（grep 該当なし）。L2/L3 の機械マッチング実装時に方言確定が必要                                                           |
| F-22 | escalate第2型→人間選択→ワンラウンド合意→execのパターンがRun-006/008で再現し標準経路として安定                                                                                    | recorded           | 成功シグナル                                                                                                                                                                                   |
| F-23 | 「双方に反映」と宣言する改訂は両側のACを対で切るべき（片側のgrep AC欠落はV-1で実装漏れを見逃す）                                                                                 | open               | Run-010 で実証されたが、`docs/workflows/ai-loop/loopspec.md` 等への一般規律としての明文化は未確認（grep 該当なし）。次 run での規律追記候補                                                    |
| F-24 | Bが3ラウンドかけてtrust boundary機構の「誠実な安全主張」を段階的に締めた。安全機構導入runではBの連続rejectは正常なコスト                                                         | recorded           | 成功シグナル                                                                                                                                                                                   |

## open backlog（優先順・次 run 候補）

1. **F-3 / F-11 → #739**（ho-paths.md L101「Phase 0 限定」の恒久性/期間限定曖昧さ、および arbiter.py 裁定ロジック自己変更ゲートの固定ルール化。同族課題として1件のissueに集約されている）
2. **F-21 → glob 意味論の確定**（allowed_paths / ho-paths の fnmatch / globstar / git pathspec 方言統一。L2/L3 機械マッチング実装の前提）
3. **F-23 → AC対称ペアリング規律の明文化**（「双方に反映」宣言時の両側 grep AC 必須化をloopspecテンプレートへ追記）
4. **F-19 残課題 → expect_stdout フィールド追加の再検討**（L3 自動実行設計時、優先度は低）

## メタ観測（記録から機械的に導ける範囲のみ）

- **ラウンド数推移**: Run-003=3 → Run-004=3 → Run-005=1 → Run-006=1 → Run-008=1 → Run-010=3（+ ラウンド上限到達後の Model C/D 裁定）
- **escalate 型の分布**: 第1型（W チェックが検出・Run-001）= 1 件 / 第2型（申告段階で誠実 lite=false 自己検出・Run-006, Run-008, Run-010）= 3 件
- **成功シグナル数**: F-5, F-6, F-9, F-13, F-15, F-16, F-20, F-22, F-24 の 9 件（`recorded` 状態）

## 検証証跡

```console
$ test -f docs/working/ai-loop-runs/frictions-digest-001.md; echo "AC-1 exit=$?"
AC-1 exit=0

$ M=0; for i in $(seq 1 24); do grep -qE "F-$i([^0-9]|$)" docs/working/ai-loop-runs/frictions-digest-001.md || M=$((M+1)); done; test "$M" -eq 0; echo "AC-2 exit=$? missing=$M"
AC-2 exit=0 missing=0

$ test "$(git diff --numstat docs/working/ai-loop-runs/run-001-frictions.md | wc -l | tr -d ' ')" -eq 0; echo "AC-3 exit=$?"
AC-3 exit=0

# optimized-verified 判定の反映先 grep（本文引用済みだが実行結果を再掲）
$ grep -n "verbatim" .claude/skills/ai-loop-cycle/SKILL.md            # F-1
105:**reject_category は enum の英小文字値をそのまま（verbatim）返させる ...

$ grep -n "reject_category" scripts/ai-loop/arbiter.py | wc -l        # F-1/F-10
20

$ grep -n "living な文書地図" docs/ai/ai-loop/README.md               # F-2
6:## living な文書地図はどこにあるか

$ grep -n "機械検証コマンド" docs/workflows/ai-loop/loopspec.md       # F-4/F-18
59:    deterministic: # 必須（最低1件）。機械検証コマンド（構造化 — F-18/Run-006）

$ grep -n "F-7 反映" docs/working/ai-loop-runs/run-003-loopspec.md    # F-7
59:- **AC（機械検証 — F-7 反映）**:

$ grep -n "F-8 反映" docs/working/ai-loop-runs/run-003-loopspec.md    # F-8
66:- **Files（Expected Diff・一意確定 — F-8 反映）**:

$ grep -n "実機で PASS/FAIL 両方向" docs/workflows/ai-loop/loopspec.md  # F-12
121:deterministic の各コマンドは、計画時に**実機で PASS/FAIL 両方向** ...

$ grep -n "証跡（実行出力の貼付）" .claude/skills/ai-loop-cycle/SKILL.md  # F-14
74:...計画中の『検証済み』申告には**証跡（実行出力の貼付）**があるか確認し ...

$ grep -n "cmd 内で exit code に畳み込む" docs/workflows/ai-loop/loopspec.md  # F-19
102:...**count ≥ N 型の判定は cmd 内で exit code に畳み込む** ...

$ grep -n "Phase 0" docs/ai/ai-loop/ho-paths.md                        # F-3（未改訂を確認）
3:> **Status**: Phase 0 ドキュメント（2026-07-01）。
101:1. **docs/ai/ai-loop/ 配下は Phase 0 限定の例外**: ...

$ grep -n "glob\|fnmatch\|globstar" docs/ai/ai-loop/ho-paths.md; echo "exit=$?"  # F-21（未定義を確認）
exit=1

$ grep -n "対で" docs/workflows/ai-loop/loopspec.md docs/ai/ai-loop/*.md; echo "exit=$?"  # F-23（未反映を確認）
exit=1
```
