# Run-001 摩擦記録（L4 Remember / review-feedback-loop 入力）

> 初回実走（2026-07-07）で観測した事実の記録。Optimize（gate/skill/プロンプト更新）は
> 本記録を根拠に別途行う（design-philosophy I-5: 記録なき最適化の禁止）。

## 結果サマリ

- decision: **HUMAN_ESCALATED**（priority 2: boundary=clean だが lite=false）
- W チェック: Model A=approve / Model B=reject（不一致）
- lite=false の根拠: Model B 指摘 #3（「自己資産」第3分類の追加は分類スキーマ拡張 = new design）
  を受け、L1（呼び出し側）が no_new_design を **true→false に自己訂正**して入力した
- decision record: `20260707T021653Z-b209dbe.json`

## 摩擦点（Remember）

| #   | 観測事実                                                                                                                                                                                                                         | 種別                                                      |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| F-1 | Model B が REJECT_CATEGORY を語彙外の日本語「ロジック変更」で返し、L1 が "logic" へ正規化する必要があった。W チェック委託プロンプトに **enum 厳格指定（英語小文字の 14 語彙のみ）** が必要                                       | プロンプト定型の不備                                      |
| F-2 | asset-inventory.md / related-specs.md は「Phase 0 時点固定スナップショット」であり、後代資産を追記すると provenance を毀損する（Model B 指摘 #1）。**「living な資産索引」の置き場が未定義** という設計ギャップが露呈            | タスク設計の欠陥（計画段階で検出できず W チェックが捕捉） |
| F-3 | ho-paths.md L101「docs/ai/ai-loop/ 配下は **Phase 0 限定の例外**」が、恒久のディレクトリ指定か期間限定免除か曖昧。Phase 3 完了後の現在、AI が boundary=clean を自己判定する根拠が弱い（I-1 周辺のグレーゾーン。Model B 指摘 #4） | 正本の曖昧さ                                              |
| F-4 | LoopSpec の deterministic 検証（lint+リンク解決）では「5 件中 3 件しか追記していない部分同期」が PASS する穴（Model B 指摘 #5）。**AC を機械検証可能な形（例: 資産名 5 件の grep 存在確認）で deterministic に落とす**規律が要る | 検証設計の穴                                              |
| F-5 | （正常動作の確認）Model A/B は同一前提に収斂せず真に分岐した（#731 の failure mode「合意が誤りを補強」は発生せず）。非対称 W チェックの独立性が初回実走で実証された                                                              | 成功シグナル                                              |
| F-6 | （正常動作の確認）L1 が自分に不利な証拠（B 指摘）で lite 自己申告を訂正 → arbiter が決定論で escalate。安全側デフォルト（I-4）が end-to-end で機能                                                                               | 成功シグナル                                              |

## Optimize 候補（次サイクル以降・記録に基づく提案）

1. F-1 → ai-loop-cycle スキル / runbook §2-(2) の委託プロンプト定型に reject_category の
   enum 厳格出力を追記（実装先: `.claude/skills/ai-loop-cycle/`・非HO）
2. F-2 → 人間判断（本 run の escalate 事項）: living index の置き場を決める
3. F-3 → ho-paths.md の「Phase 0 限定」文言の明確化 issue を起票（HO 判定の正本につき
   変更自体は慎重に・まず issue）
4. F-4 → loopspec.md の verification.deterministic 節に「AC の機械検証化（grep 等）」の
   推奨を追記（非HO）

---

## Run-002 追記（同ファイルに連続記録）

### 結果サマリ（Run-002）

- decision: **AUTO_APPROVED**（priority 5: severity=low・C/D=approve-approve）— 初の auto-approve + provenance 刻印
- 経路: A=approve / B=reject(documentation・**F-1 の enum 厳格化が機能し語彙準拠**) → severity 分類 →
  Model C/D 観点特化裁定 → 決定論 auto-approve → exec（maker=sonnet）→ deterministic AC 全 PASS
- decision record: `*-run002.json`

### 摩擦点（Remember・次の Optimize 候補）

| # | 観測事実 | 種別 |
|---|---|---|
| F-7 | Model B が計画自身の AC 設計に F-4 同型の穴を検出（no_duplicate_taxonomy が review 観点のみで機械検証不能・コピーによる迂回を AC-4 が検知しない）。**「AC の機械検証化」は再帰的に適用すべき規律**であることが判明 | 検証設計 |
| F-8 | AC-3「記録層**または**契約層」の曖昧さを B が設計判断の残置と指摘 → Model D の裁定（契約層が妥当）で解消された。**配置の選択肢は W チェック前に 1 つへ確定させる**方が安い | 計画粒度 |
| F-9 | （成功）F-1 Optimize が初適用で機能（B の reject_category が enum 準拠）。**記録→Optimize→次サイクルで効果確認**の I-5 ループが 1 巡した | 成功シグナル |

| F-10 | decision record（arbiter.py の provenance 出力）に Model B の `reject_category` と C/D 起動理由が記録されず、「なぜ severity=low と分類されたか」が record 単体から追跡できない（C-4 レビュー指摘）。**record の手編集は provenance 改竄になるため行わず**、arbiter.py の provenance schema 拡張（`w_check.reject_category` フィールド追加 + test_arbiter 更新）を Optimize 候補とする | 記録スキーマの不足 |

---

## Run-003 追記（初のコード run・3 ラウンド収束）

### 結果サマリ（Run-003）

- 経過: R1 A✓/B✗(test_shortage) → 4改訂 → R2 **A✗(naming)/B✗(logic) 同一欠陥に独立到達 →
  arbiter BLOCKED 刻印（reject-reject 経路の初発火）** → 改訂5-7 → R3 A✓/B✓ →
  **AUTO_APPROVED（priority 6 合意）** → exec 62/62 PASS
- F-10 達成の実証: run-002 相当入力の smoke で `w_check.reject_category: "documentation"` が刻印

### 摩擦点（Remember）

| #    | 観測事実 | 種別 |
| ---- | -------- | ---- |
| F-11 | 本 run は「裁定エンジンの記録方式を裁定エンジン自身のガバナンスで変更する」自己参照構造（R1/R2 の B が連続指摘）。歯止め（severity マッピング・裁定ロジック不変）で許容したが、**arbiter.py の判断ロジック（decision table 優先順位・SEVERITY_MAP）変更は touches_ho:unconditional 相当の固定ルール化を Human 判断で検討**すべき（構造的ゲート昇格の提案。#739 と同族） | I-1 境界設計 |
| F-12 | 機械検証コマンド自体に欠陥が 2 度混入（R1: BSD sed 非互換で 0 行 / R2: grep パターンが命名規約と不整合で正しい実装を FAIL 判定）。**「検証コマンドは計画時に実機で通し、規約準拠のサンプル入力で PASS/FAIL 両方向を確認する」**を loopspec 検証設計の規律に追加すべき | 検証の検証 |
| F-13 | （成功）W チェックの両極性が実証: 順方向 A も R2 で reject を出し（naming）、B は R3 で I-6 注意（無限 reject 禁止）の下で approve に収束。**3 ラウンド規律 + reject-reject BLOCKED + 合意 AUTO_APPROVED の全経路が 1 run 内で発火** | 成功シグナル |

---

## Run-004 追記

### 結果サマリ（Run-004）

- 経過: R1 A✓/B✗(logic — **私の AC-2 regex の括弧不整合を実機 CONFIRMED + 「両方向検証済み」が虚偽申告と暴露**) →
  R2 A✓/B✗(logic — AC 固定句と追記文言の矛盾) → R3 A✓/B✓ → AUTO_APPROVED → exec 全 AC PASS
- Run-003 の omit 実装が record で動作確認（model_b=approve → reject_category 不在）

### 摩擦点（Remember）

| #    | 観測事実 | 種別 |
| ---- | -------- | ---- |
| F-14 | 計画の「実機で両方向検証済み」という**申告自体が虚偽**だった（AC-1 のみ検証し AC-2 は未検証のまま「同様」と記載 → B が exit 2 を実機再現して暴露）。対策: レビュアーは事前検証の申告に**実行出力の貼付（証跡）**を要求する。working-discipline 原則 12 の運用強化として「検証した」には証跡を伴わせる | 申告の検証 |
| F-15 | （成功）F-1 Optimize の連鎖確認: ai-loop-cycle スキル定型（3 行 raw + enum）を L1 が使用した結果、**4 ラウンド連続で reject_category が enum 準拠**（test_shortage/logic/logic/none）。スキル定型の使用が非準拠を構造的に防いだ | 成功シグナル |

---

## Run-005 追記

### 結果サマリ（Run-005）

- 経過: **R1 で A✓/B✓ 即合意（初のワンラウンド通過）** → AUTO_APPROVED → exec 全 AC PASS
- Run-004 の教訓（AC 固定句と文言の事前結合・実機事前検証の証跡残置）を計画段階で先取りした
  効果が収束速度に直結（R 数: Run-003=3 → Run-004=3 → Run-005=1）
- maker が F-14 を実践（検証の実行出力を報告に貼付）・A も申告を再実行で独立検証

### 摩擦点（Remember）

| #    | 観測事実 | 種別 |
| ---- | -------- | ---- |
| F-16 | （成功）教訓の事前適用でラウンド数が 3→1 に短縮。**「前 run の reject 理由を次 run の計画チェックリストに変換する」**が最も効率の高い Optimize であることの実測 | 成功シグナル |
| F-17 | B 指摘の残課題（実害化前）: 証跡の「貼付」水準が要約で満たされ得る曖昧さ・貼付内容の改竄（実行していない出力の捏造）には無力。多層防御（deterministic 再実行 + adversarial 再検証）が前提であることを規律の限界として明記すべき | 証跡の限界 |
| F-18 | LoopSpec の deterministic 欄が「コマンド+日本語注記」混在で、そのままシェル実行できない（C-4 Gemini 指摘・Run-005）。**「純粋コマンド + 期待 exit code」の分離フィールド形式**（例: cmd / expect_exit / expect_stdout）へ loopspec.md テンプレートを改善する — 将来の自動実行（L3）への布石にもなる | テンプレート形式 |

---

## Run-006 追記

### 結果サマリ（Run-006）

- 経過: **誠実 lite 申告（no_new_design=false）→ flow 段階で HUMAN_ESCALATED（W チェック前の
  設計判断事前検出 — Run-001 とは別の escalate 経路の初通過）** → 人間判断「A」（構造体
  cmd/expect_exit/note）→ no_new_design=true へ更新 → R1 A✓/B✓ ワンラウンド合意（3連続）→
  AUTO_APPROVED → exec 全 AC PASS（maker が記入例の -ge 0 常真バグを自己検出し -eq 0 へ修正）

### 摩擦点（Remember）

| #    | 観測事実 | 種別 |
| ---- | -------- | ---- |
| F-19 | B 検出の footgun（実害前）: 構造体 A は expect_stdout を持たず、count ≥ N 型判定は exit code 単体で表現できない（grep -c は件数 1 でも exit 0）。対策として「cmd 内で test 畳み込み」を §3 に明記済み。将来 L3 自動実行の設計時に expect_stdout 追加を再検討 | スキーマ表現力 |
| F-20 | （成功）「設計判断を含む run は lite を誠実に false 申告 → W チェック前に human へ」の経路が機能。escalate の 2 型（Run-001: W チェックが検出 / Run-006: 申告段階で自己検出）が出揃い、後者はレビューコスト（W 2体分）を節約 | escalate 経路 |

---

## Run-008 追記

### 結果サマリ（Run-008）

- 経過: escalate 第 2 型（誠実 lite=false）→ 人間判断「B」（allowed_paths のみ・
  **enforcement なき cost cap 宣言は作らない**）→ R1 A✓/B✓ ワンラウンド合意 →
  AUTO_APPROVED → exec 全 AC PASS（maker が実行出力を貼付 = F-14 定着）
- #746→#749→Run-008 と、intake gap 分析の genuine gap が 2 run で schema に到達

### 摩擦点（Remember）

| #    | 観測事実 | 種別 |
| ---- | -------- | ---- |
| F-21 | B 検出（実害前）: allowed_paths / ho-paths の glob 意味論（fnmatch / globstar / git pathspec）が未定義のまま表記慣習で運用されている。Phase 0（自動マッチャー不在）では実害なしだが、**L2/L3 で機械マッチングを実装する際に方言を 1 つに確定**する必要がある（ho-paths.md と共通の将来課題） | glob 意味論 |
| F-22 | （成功）escalate 第 2 型 → 人間選択 → ワンラウンド合意 → exec のパターンが Run-006/008 で再現し、**設計判断つき変更の標準経路として安定**。要した人間の判断は 1 選択（B）のみ | 経路の定着 |

---

## Run-010 追記

### 結果サマリ（Run-010）

- 経過: escalate 第 2 型 → 人間判断「B」→ **R1 A✓/B✗（実効性3欠落）→ R2 A✓/B✗（検査限界の無開示）→
  R3 A✓/B✗（SKILL.md 側 AC 欠落・ラウンド上限到達）→ flow-detect §3.3 どおり Model C/D 裁定
  （C: 検査ロジックは AC-8 が担保・限界文言の冗長のみ / D: 自己不整合でなく AC 網羅の穴・
  統合補完可能=Run-002 F-7 先例）→ AUTO_APPROVED（priority 5）** → exec 全 AC + 統合補完 PASS
- **Run-003 実装の完全動作**: 本 run の provenance に reject_category=test_shortage・severity=minor が
  刻印され、record 単体で「なぜ C/D 経路に入ったか」を追跡可能（F-10 の目的を本番で達成）

### 摩擦点（Remember）

| #    | 観測事実 | 種別 |
| ---- | -------- | ---- |
| F-23 | 「双方に反映」と宣言する改訂は**両側の AC を対で切る**（B R3 検出: 片側の grep AC 欠落は V-1 で実装漏れを見逃す）。ラウンド上限到達時は改訂でなく C/D 裁定が正路であることも本 run で実証 | AC 設計の対称性 |
| F-24 | （成功）B が 3 ラウンドかけて trust boundary 機構の「誠実な安全主張」を段階的に締めた（判定既定 → 限界開示 → 検証対称性）。**安全機構の導入 run では B の連続 reject は正常なコスト**であり、C/D 裁定が過剰追及と実害の境界を引いた | 安全機構 run の型 |

---

## Run-011 追記

### 結果サマリ（Run-011）

- 経過: R1 A✓/B✓ ワンラウンド合意 → AUTO_APPROVED → exec 全 AC PASS。
  **Dreams パターン初適用**: 元ログ不変（AC-3 で機械検証）+ 検証つき派生 digest
  （frictions-digest-001.md）+ 採用は C-4 人間レビュー
- **直近 3 run で追加した LoopSpec フィールドが全稼働**: scope.allowed_paths（Run-008）・
  external_sources（Run-010・空配列の明示宣言として初運用）・構造化 deterministic（Run-006）
- 計画段階で AC-2 の部分一致バグ（F-2 が F-24 にマッチ）を**事前検証が自己検出**（F-12 の 2 例目）

### 摩擦点（Remember）

| #    | 観測事実 | 種別 |
| ---- | -------- | ---- |
| F-25 | 「原則 11」の引用元を design-philosophy と誤記しかけた（正: working-discipline skill。design-philosophy は I-1〜I-9）。A が citation nit として検出。**原則・規律の引用には出典ファイルを明示する** | 引用の正確性 |
| F-26 | （成功）F-14 が個別 LoopSpec でなく **checker 標準プロンプト（SKILL.md）に構造搭載**されているため全 run で自動的に機能する、と B が確認。「摩擦→skill 定型への昇格」が個別対処より高い恒久性を持つことの実証 | Optimize の置き場 |
| F-27 | **run の締め処理が「PR 作成と同時に auto-merge を arm」しており、Gemini の非同期レビュー（数分後着弾）を確認する工程が閉路に無かった**（ユーザー指摘 → 全 run PR 突合で確認: マージ済みは指摘 0 件の偶然かユーザー促しで救済・#755/#756 に未対応 5 件が露出していた）。runbook §2-(7) の「AI レビュー指摘対応」が auto-merge + Approve でバイパス可能。**対策（即日適用）: PR 作成後は Gemini レビューの着弾を確認し、指摘対応（または指摘なし確認）を経てから auto-merge を arm する** | 締め処理の閉路欠落 |
| F-28 | digest 系 AC の厳密形を確立（Gemini 指摘由来）: ID 収録は**状態表の行に限定**（行頭パターン `^\| F-$i` + 直後スペース）・元ログ不変は**削除行ゼロ**（`git diff <base> -- <log> \| grep -c '^-[^-]'` = 0）で「追記のみ」を検証 | AC の標準形 |

## Run-012 での摩擦（2026-07-07 追記）

- 対象: F-27（レビュー確認→締め処理の順序）+ F-28（digest 系 AC 厳密形）の正本化 run。
  W チェック R1 A✓/B✗(logic) → R2 A✓/B✓ → **Human 指示「auto-mergeを設定するのはやめたい」
  で前提変更** → R3 A✓/B✗(logic) → C✗/D✓ 不一致 → **HUMAN_ESCALATED**
  （record: `20260707T092419Z-9d7af43-run012-r3.json`）→ Human 選択 1
  （consolidated AC ブロック追記）で解消

### 摩擦点（Remember）

| #    | 観測事実 | 種別 |
| ---- | -------- | ---- |
| F-29 | AC-1 の PASS 方向事前検証を「要求水準（≥2）未満のサンプル 1 件」で申告していた（R1 B が検出）。**PASS 方向の実測は AC の閾値・条件そのもので行う**（F-12 の運用厳密化） | 事前検証の水準 |
| F-30 | Round 改訂で AC を変更する際、文章宣言のみでは**機械実行前提の YAML deterministic ブロックと食い違う**（R3 C が指摘・C/D 不一致で escalate）。対策: AC 変更時は**機械可読な consolidated deterministic ブロックを追記**する（遡及編集せず監査記録不変と両立）。loopspec.md への正本化は次 run の Optimize 候補 | AC 改訂の機械可読性 |
| F-31 | run 途中の Human 指示（auto-merge 廃止）が確定文言・AC の前提を変えた。**運用前提の変更は即時に実運用（open PR）へも遡及適用**し（#757/#758 の arm 解除を実測）、run 側は Round 追記で追従する、の両輪が機能した | Human 指示の途中注入 |

## Run-013 での摩擦（2026-07-07 追記）

- 対象: #754 seeds-hygiene 仕様正本化（intake §6.1 の 3 例目・**HO 接触 run の初事例**）。
  escalate 第2型（HO 接触 + 配置選択）→ Human 選択 1 → W R1 A✓/B✗(ho_path_contact) →
  AC v2 強化（Round 3）→ W R2 A✓/B✓ → arbiter **priority 1 (boundary=touches-HO) で
  HUMAN_ESCALATED**（W 合意でも機械的に Human へ返る I-1 実機確認・
  record: `20260707T102937Z-94c9882-run013-r2.json`）→ Human 承認済みにより exec

### 摩擦点（Remember）

| #    | 観測事実 | 種別 |
| ---- | -------- | ---- |
| F-32 | ハーネスの Edit 後自動整形が retro-phase.md の既存テーブルを collateral 整形し +10/-9 の意図外 diff を発生 → **AC-6b（追加≤1・削除0）が設計どおり違反を機械検知** → maker が `printf >>` 直接追記へ切替えて +1/-0 に収束。数量 containment AC は整形フック事故の検出器としても機能する | containment AC の副次効果 |
| F-33 | Run-013 検証中、作業ツリーに**スコープ外の HO 変更**（.claude/settings.example.json 改変 + scripts/hooks/ 新規 2 本・#760 由来・本セッションが中止破棄した実装とは別系統・settings.json 実配線にも PostToolUse/Stop が出現）を検出。**別セッション/手動操作との並行実行**が原因とみられる。対応: 破棄せず（名指し外 tracked 変更保護）・run PR から明示除外（explicit path staging）・Human へ報告。多セッション並行時の worktree 共有は run の AC-6a（ファイル数）を偽陽性側に振らせ得る | 並行セッションの worktree 干渉 |

## Run-014 での摩擦（2026-07-07 追記）

- 対象: F-29/F-30 の loopspec.md 正本化（摩擦バックログ Optimize）。R1 A✓/B✓
  ワンラウンド合意 → AUTO_APPROVED（priority 6）→ exec 全 AC PASS・意図外 diff なし
- **新規摩擦なし**（監査連続性のための明示記録）。F-33 対策の分離 worktree 運用を初適用
  し、並行セッション（#760/PR #762）と無干渉で完走
