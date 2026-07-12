# TASK-0822 項目4: stop条件と巻き戻し 設計案B（チェックリスト + 機械検証スクリプト案ベース）

> 親: #822 EPIC（HITL→HOTL変革）
> 位置づけ: 項目4「stop 条件と巻き戻し」の**設計案B**。設計案A（手順書ベース＝実行順序に沿った逐次記述、を想定）に対し、本案は「実行してよいか／実行結果は正しいか」を判定する**チェックリスト・ゲート**として定義し、各項目に**機械検証の可否**を明記する切り口を取る。両案は排他ではなく、Aの各ステップの実行前提・実行後検証をBのチェックリストで裏付ける関係として統合できる（§4）。
> 制約: 本ドラフトは設計のみ。実装コードは含まない。既存正本（responsibility-classes.md / orchestrator-mode.md / design-philosophy.md / decision-table.md / lite-criteria.md / hotl-merge-entry-criteria.md / working-context.md）と矛盾しない範囲で構成する。

## 0. 設計方針（3原則）

1. **検証(read-only)と実行(write/destructive)を分離**し、実行は既存正本に従い常に人間固定とする（responsibility-classes.md merge Human-owned固定 / hotl-merge-entry-criteria.md 条件2「事後revertの自動化」は❌未設計）。本設計は「実行してよいと判断するための検証」までを扱い、revert・PR close・policy再承認の**実行そのものを自動化しない**。
2. **判定不能・データ欠落は fail ではなく unknown→human escalate に倒す**（design-philosophy.md I-4 安全側デフォルトの継承）。「機械検証できない」は「問題なし」ではない。
3. **新規の永続状態ストア・常駐デーモンは提案しない**。既存の decision record（JSON）・git履歴・loopspec.mdの読み取りのみで完結する検証を優先する。CB-1のpolicy_suspended状態管理のような未実装機構は「本設計のスコープ外・将来課題」として明記に留め、過大な自動化を避ける。

## 1. Stop条件対応チェックリスト（要件(1)）

design-philosophy.md I-6「停止機構は2層」を軸に整理する。これは設計案Aが想定する時系列の手順記述とは異なる、**機構の階層構造**による切り口である。

- **Layer 1（反復の停止＝個別裁定のterminal state）**: `scripts/ai-loop/arbiter.py` priority 0〜6、`scripts/ai-loop/discovery.py` A-1〜A-4
- **Layer 2（自律そのものの一時停止＝サーキットブレーカー）**: `decision-table.md` §6 CB-1〜3

### 1.1 Layer 1 チェックリスト

| CL-ID | 検証内容（pass条件） | 対応する既存機構 | 機械検証可能性（現状） | 検証スクリプト案（名称・目的） | 不可時のfallback |
|---|---|---|---|---|---|
| CL-1 | `boundary_check=="clean"`（HO非接触） | arbiter priority 0/1 | 可（全record、`@v0`含む） | `verify-boundary-consistency`（record の `boundary_check` と、`target_sha` 到達可能時の実ファイル一覧を再突合） | git対象がunreachableならunknown |
| CL-2 | `scope_check=="in_scope"`（allowed_paths遵守） | arbiter priority 1.5 | 部分的（`@v1`以降のみ、#809）。`@v0`はフィールド欠落 | 同上ツールの副産物として算出 | `@v0`はunknown（retroactive適用不可と明記するのみ） |
| CL-3 | `gates.c1=="PASS"` かつ `gates.breakdown=="pass"` | arbiter priority 1.7 | 部分的（`@v2`以降のみ、#819） | N/A（値は入力由来。再現には元入力の別途保存が必要） | `@v0`/`@v1`はunknown |
| CL-4 | 申告 `lite.size_ok` と実測ファイル数の整合 | arbiter priority 1.9 | 部分的（`@v3`の判定結果はdecisionに反映されるが、判定の元値自体はprovenanceに非永続） | `verify-size-declaration`（`target_sha`到達可能時、`git show --stat`の実ファイル数と申告値を再計算） | 到達不能または`@v2`以前はunknown |
| CL-5 | `target_sha` が一意のreachableコミットに解決する | 全record共通（provenance必須項目） | 部分的（git履歴保持期間内のみ） | `verify-target-sha-resolvable`（`git cat-file -e`相当の存在確認） | unreachable→unknown（＝巻き戻し不能の可能性ありとして即human escalate） |
| CL-6 | ファイル名に埋め込まれたSHAとrecord内`target_sha`の一致 | （既存棚卸しで実測2件の不一致を確認済み: run016/run018） | 可（単純文字列比較のみ） | `verify-filename-content-consistency`（最も低コスト・即効性が高い） | 不一致→即human escalate（どちらが正か機械では判断しない） |
| CL-7 | 同一`run_id`内の`round_index`が一意昇順（最終roundの一意特定） | `run`メタ（#815、任意フィールド） | 部分的（`run`提供時のみ。`@v0-1`は欠落） | `verify-round-uniqueness`（同一`run_id`内で`round_index`重複・逆順がないかチェック） | `run`欠落はunknown（legacy record。timestamp最大値を運用ヒューリスティックとして併記するに留める） |
| CL-8 | discovery候補のopt-inラベル必須（A-1）等、着手前ゲートの通過根拠がrecord側からも遡って確認できる | discovery.py A-1〜A-4 | 可（issueラベル自体はGitHub側に残る） | `verify-discovery-gate-trace`（対象issueのラベル履歴とdiscovery出力の整合確認） | issueがclose/削除済みならunknown |

### 1.2 Layer 2 チェックリスト（サーキットブレーカー状態）

| CL-ID | 検証内容 | 対応機構 | 機械検証可能性 | 検証スクリプト案 | fallback |
|---|---|---|---|---|---|
| CL-9 | `policy_suspended` 状態がrecordと矛盾しない（suspended中にAUTO_APPROVEDが出ていないか） | CB-1 | 不可（状態ストア自体が未実装。実装コード側 grep 該当なし） | 実装しない（本設計は提案しない。将来のCB-1実装issueのスコープ） | 常にunknown＝「CB-1は現状仕様のみで実効性なし」と明記して停止 |
| CL-10 | 同一policyでのN回連続reject検知（`policy_expired`） | CB-2 | 不可（同上） | 同上 | 同上 |
| CL-11 | escalate予算超過（`circuit_open`） | CB-3 | 不可（同上） | 同上 | 同上 |

> **CL-9〜11 の扱い**: 本設計はCB-1〜3を実装しない。これらの項目は「現状ai-loopのサーキットブレーカーは仕様のみで実効性を持たない」ことを可視化するために列挙し、EPIC #822完了条件「不変条件が機械層で保持されている（回帰テスト）」に対する**既知ギャップの明記**として扱う。実装は別issueスコープとする（原則3の適用）。

> **既存 reversal_rate 指標との違い（要注意）**: `design-hotl-metrics.md`（項目3）が定義する `reversal_rate` は「**同一run内**で非AUTO_APPROVEDのroundの後、後続roundでAUTO_APPROVEDに収束した割合」であり、arbitration の収束性を測る指標である。これに対しCL-9〜11・本設計§2が扱う「事後reject」は、**一度確定したAUTO_APPROVEDを、run外の別の人間レビュー（PRレビュー・監査等）が後から覆す**CB-1由来の事象であり、時系列・主体ともに別概念である。本設計はreversal_rateの定義を変更・拡張しない。

## 2. AUTO_APPROVED後の事後reject巻き戻し 検証ゲート（要件(2)）

CB-1の4ステップ（policy一時停止・巻き戻し・human review昇格・再承認待ち）と、working-context.md AC-9の5ステップ（ブランチ破棄・PR close・成果物invalidation・ログ記録・派生成果物是正）を、「実行前に必ず機械検証すべき事前チェックリスト」と「実行後に確認すべき事後チェックリスト」の2ゲートとして再構成する。

### 2.1 Pre-flight チェックリスト（巻き戻し実行の"前"に人間または補助スクリプトが確認）

| PF-ID | 確認事項 | 誰が確認するか | 機械実行可能性 |
|---|---|---|---|
| PF-1 | 対象recordのCL-6（ファイル名/中身のtarget_sha一致）がPASSしている | スクリプト（read-only） | 今すぐ可能 |
| PF-2 | 対象recordのCL-5（target_sha reachable）がPASSしている | スクリプト（read-only） | 今すぐ可能（`git cat-file`相当） |
| PF-3 | target_shaが「計画時base」ではなく「実装後commit」であることの確認（decision-table.md §5 の両義性への運用判断） | 人間（record単体では機械判別不可と既に確認済み） | 機械化しない（意味論そのものがrecordに無く、誤判定リスクの方が高い） |
| PF-4 | 対象commitに対応するPR番号の特定（コミットメッセージ末尾 `(#NNN)` を抽出） | スクリプト（提案）+ 人間確認 | 部分可能。誤爆事例（本文中の別PR言及）が既知のため、**抽出結果は必ず人間が1件ずつ確認**（自動closeへは使わない） |
| PF-5 | 対象PRがmergeされているか／まだPR段階か | スクリプト（`gh pr view`相当の状態取得のみ、read-only） | 可能 |
| PF-6 | PF-5=「既にmerge済み」の場合、revert自動化は行わない | 人間（固定） | 恒久的に人間固定。hotl-merge-entry-criteria.md条件2が❌未設計である限り、merge後のrevertは完全手動 |
| PF-7 | 変更が可逆カテゴリに属する（lite-criteria.md §2可逆性要件・design-philosophy.md I-8の不可逆操作リストに抵触しない） | 人間（record由来では機械判定不可。`lite_check=true`は可逆性込みの申告値だが、申告の真正性検証は別課題） | 機械化しない（申告制の限界。CL-4と同種の「申告 vs 実測」検証は将来拡張候補としてのみ注記） |

> PF-1〜PF-7のいずれかがPASSしない、または「機械化しない」区分の項目で人間の判断が確定しない場合、**巻き戻し実行そのものを一時停止し、原因調査を先に行う**（design-philosophy.md I-4安全側デフォルトの適用）。「とりあえずrevertする」という即応優先の運用は本設計では推奨しない。

### 2.2 実行ステップ（人間固定・本設計は自動化しない）

working-context.md AC-9の5ステップを、ai-loopのrecord/branch/PR単位に読み替えて踏襲する（設計案Aが逐次手順を持つ場合はそちらに委ね、ここでは「何を実行するか」の一覧のみ示す。Bの主眼はあくまで前後の検証にある）:

1. 実装ブランチの破棄 or revert
2. 生成済みPRのclose（既にmergeされていればPF-6によりrevert PRを人間が別途起票。merge後revertの自動化は提案しない）
3. 当該recordのinvalidationマーク付与（§2.3）
4. decision record + loopspec.mdへのreject＋巻き戻し記録
5. 当該recordを参照した後続成果物（他recordのdependency欄、loopspec.mdの参照等）の追従是正

> **これらの実行系操作はすべてHuman-owned固定**（responsibility-classes.md）。本設計はここに自動実行を提案しない。

### 2.3 Post-flight チェックリスト（巻き戻し実行の"後"に確認）

| PO-ID | 確認事項 | 機械検証可能性 |
|---|---|---|
| PO-1 | 対象recordにinvalidationマーク（例: `invalidated: true`相当の追記）が付与されている | 可能（record/loopspec.mdの該当フィールド存在確認） |
| PO-2 | 対象ブランチ/PRがGitHub側でclose/削除済み | 可能（`gh pr view`のstate確認、read-only） |
| PO-3 | 他recordから当該target_shaへの参照（dependency記載等）が残っていないか | 部分可能。既存 `ref-integrity-scan` スキル等の**既存資産の再利用候補**。新規スクリプトを起こす前にこちらの適用可否を先に検討する |
| PO-4 | CB-1相当のpolicy一時停止状態が記録されている | 不可（CL-9と同じ理由。CB-1未実装のため「記録すべきだができない」ギャップとして明示するのみ） |

## 3. 機械実行可能性マトリクス（要件(3)）

| 操作カテゴリ | 検証（read-only） | 実行（write/destructive） | 本設計での扱い |
|---|---|---|---|
| record整合性チェック（CL-1, CL-2, CL-5, CL-6, CL-7） | 提案（スクリプト化可能） | — | 検証スクリプトの**提案**まで。実装は別issue |
| target_sha/PR特定（PF-2, PF-4, PF-5） | 部分提案（人間確認込み） | — | 抽出結果の自動適用（close/revert）はしない |
| ブランチ破棄・PR close・revert実行 | — | 常にHuman-owned | 自動化提案なし（responsibility-classes.md準拠） |
| CB-1〜3の状態管理（suspended/expired/circuit_open） | 未実装 | 未実装 | 本設計のスコープ外・将来issue |
| merge後のrevert自動化 | — | hotl-merge-entry-criteria.md条件2が❌未設計 | 本設計では一切提案しない（条件2の充足は別プロセス） |
| 派生成果物の参照是正（PO-3） | 既存 `ref-integrity-scan` の適用検討 | — | 新規実装より既存資産の再利用を優先 |

**既存precedentとの整合**: `discovery.py`の`--emit-next-command`（コマンド文字列を生成するが実行しない）パターンに倣い、本設計で提案する全ての「検証スクリプト案」は**判定結果の出力・候補コマンド文字列の生成までを行い、実行は行わない**という既存原則を踏襲する。これにより過大な自動化を構造的に回避する。

## 4. 設計案Aとの統合案

- Aの手順書の各ステップに対し、本設計のPF-*/PO-*のいずれが「実行前提条件」「実行後検証」として対応するかを注記として付記する形で統合できる（例: Aの「PRをcloseする」ステップの前提としてPF-4/PF-5、実行後確認としてPO-2を参照する）。
- 本設計は独立ドキュメントとしても成立するが、最終的にはAの手順書本文に「検証チェックポイント」として差し込む形、またはAppendixとして併記する形が望ましい。採用形態はA作成後のレビューで決定する。

## 5. 非スコープ（意図的に扱わないこと）

- CB-1〜3の実装（`policy_suspended`等の状態ストア新設）
- merge後のrevert自動化（hotl-merge-entry-criteria.md条件2の充足）
- provenanceスキーマの拡張提案（CL-3/CL-4で言及した「元値の非永続」問題の解消は指摘に留め、実装はarbiter.py改修側のスコープとする）
- `target_sha`意味論（計画時base／実装後）の機械判別（記録側の情報不足を機械で埋めようとしない）
- reversal_rate指標の再定義（項目3の既存設計と別概念のまま並立させる。§1.2脚注参照）

## 6. 既存正本との整合確認

| 本設計の記述 | 整合確認先 | 結果 |
|---|---|---|
| 実行系操作は常にHuman-owned | responsibility-classes.md | 矛盾なし（merge/self-mod以外の領域にも同原則を準用） |
| merge後revert自動化を提案しない | hotl-merge-entry-criteria.md 条件2 | 矛盾なし（❌未設計状態を維持） |
| 判定不能→unknown→escalate | design-philosophy.md I-4 | 矛盾なし（安全側デフォルトの継承） |
| CB-1〜3を実装しない | decision-table.md §6 | 矛盾なし（仕様は不変。実効性ギャップの指摘のみ） |
| 可逆性は申告制の限界を持つ | lite-criteria.md §2 | 矛盾なし（追加検証の実装は提案しない） |
| working-context.md AC-9の5ステップを継承 | working-context.md | 矛盾なし（in-the-loop文脈からai-loop文脈への読み替えとして明示） |
| reversal_rateと事後rejectを混同しない | design-hotl-metrics.md（項目3） | 矛盾なし（別概念として明記） |

---

以上、markdown設計ドラフトのみ。実装コードは含まない。
