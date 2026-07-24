# C-2 外部レビュー — TASK-0907（追記専用集約）

> 2 レーン（設計妥当性・敵対的 / コードベース整合）+ オーガナイザー独立検証。
> review-principles §7-bis 準拠。承認境界変更のため敵対的観点を含む。

## 監査表（R-NNN・追記専用）

| R-NNN | lane | severity | status | reflected_in | notes |
|-------|------|----------|--------|--------------|-------|
| R-001 | 設計妥当性 | critical | 採用 | plan(§2注記/AC-6/Q) todo(T2a) test-cases(TC-6) | ai-loop 強制エンジン自己改変の auto-approve 化 |
| R-002 | 設計妥当性 | major | 採用 | plan(AC-2強化/AC-7) test-cases(TC-2拡張) | 承認境界は §5 のみでない（§4/§6/command/ho-paths） |
| R-003 | 設計妥当性 | major | 採用 | plan(Constraints/AC-8) | #780 順序制約の「継承」軟化（「寄り」排除） |
| R-004 | 設計妥当性 | major | 採用 | plan(AC-4強化) test-cases(TC-4拡張) | command ガード緩和の非後退未検証 |
| R-005 | 設計妥当性 | minor | 採用 | plan(AC-1) test-cases(TC-1) | AC-1「読める」を grep 機械化 |
| R-006 | 設計妥当性 | info | 採用 | handoff(記載予定) | run 実証は doc AC でない・V-3 送り |
| R-101 | コードベース整合 | critical相当 | 採用 | plan(S2/S5書換/AC-5) test-cases(TC-5書換) | rollout-policy plugin は link-rewrite 派生 → cmp byte 一致は誤検証 |
| R-102 | コードベース整合 | major | 採用 | plan(Files/S2/S3) | command と rollout-policy で sync 方向・正本が逆 |
| R-103 | コードベース整合 | major | 採用 | plan(S3削除/順序ロック) todo(T4削除) | command plugin 先行編集は sync で revert |
| R-104 | コードベース整合 | info | 確認済 | — | command は現在 .claude↔plugin byte 一致（前提成立） |
| R-107 | ai-loop run-026 Model B | critical | 採用 | plan(Goal/Constraints/AC-6) test-cases(TC-6) | carve-out が policy/criteria 文書を除外せず自己緩和経路が残る（R-001 拡張） |
| R-108 | PR前敵対レビュー | major | 採用 | rollout-policy §2 / plan / test-cases / handoff | R-107 の**列挙が不完全**（00_concept・design-philosophy 等 判定正本 7 件漏れ・自ファイル §5/§6 が正本と名指す 2 件を欠く自己矛盾）→ **glob 化**（Human 決定 2026-07-24） |
| R-109 | PR前敵対レビュー | major | 採用 | rollout-policy §2 注記 / command patch v3 | command 文言が carve-out の**機械層 escalate を実態より強く断言**し handoff KI-1 と矛盾（arbiter は carve-out を clean 判定）→ 機械層/規範層を分離記述 |
| R-110 | River Review M-1 | major | 採用 | rollout-policy §2 ③ / plan / test-cases / handoff | carve-out の穴: `ai-loop-cycle` SKILL.md（W チェック定型・reject_category enum・escalate 分岐・grader 上限）が carve-out にも HO にも不在 → ③として skill glob 追加 |
| R-111 | River Review M-2 | major | **Human 判断待ち** | （未反映） | `docs/ai/ai-loop/concept.md` §3 等 7+ 兄弟正本・arbiter.py docstring・CLAUDE.md が旧狭域を「不変条件」と宣言しており本変更と反転。plan の Out of scope（B-1 Q2）は *参照整合* の範囲で、*規範の反転* を含むか要 Human 再確認 |
| R-112 | River Review M-3 | major | 採用 | patches/ho-apply-approval.md / handoff KI-3 | 手順書が v1 patch のみ指示し v2 未言及 → 手順どおりだと R-109 が残存。**v3 へ統合**（v2 削除）+ sync 手順明記 + KI-3 記録 |
| R-113 | River Review m-1 | minor | 採用 | rollout-policy §2 注記 | 配布コピー扱いの非対称 → 「配布派生は正本 carve-out で保護・drift-check で検出」に統一 |
| R-114 | River Review m-2 | minor | 採用 | rollout-policy §2 注記 | ho-paths 原則2 の射程（policy ファイル限定）を超えた引用 → 「原則2 の拡張として V2 で ①〜③ を HO 登録」と射程差を明記 |
| R-115 | River Review m-3 | minor | 採用 | command patch v3 | patch と §2 の carve-out 集合が 1 項目ずれ → v3 で §2 注記へ**参照委譲**し drift 構造的に排除 |
| R-116 | River Review m-4 | minor | 採用 | review-external §実行不可記録 | C-2 の unavailable 記録が §10 必須項目未充足 → 下記の形式で展開・本 River Review 完了により resolved |
| R-117 | River Review i-1 | info | 採用 | 本監査表 | R-105/R-106 欠番の理由未記載 → 下記注記 |
| R-118 | River Review i-2 | info | 採用 | rollout-policy §2 注記 | §3 前提2条件と本体 run の関係が未言明 → 「allowed_paths は本体 run にも適用」を明記 |

> **R-105 / R-106 は欠番**（R-107 が ai-loop run-026 由来の採番として先行確定したため。指摘の取りこぼしではない — i-1/R-117 対応）。

## 独立検証（オーガナイザー・一次ソース）

- **R-001 CONFIRMED**: `scripts/hooks/check-plan-hash.sh` L124-133 の HO case 文に `scripts/ai-loop/*` は不在。`docs/ai/ai-loop/ho-paths.md` HO 一覧（L22-46）も `scripts/hooks/**` は HO だが `scripts/ai-loop/**` は非HO。→ arbiter/delivery/c3_contract/metrics は boundary=clean。拡張ドメインに入れると自己改変が AUTO_APPROVED になり得る。**§5 diff ゼロでは検出不能**（承認境界の実質緩和）
- **R-101 CONFIRMED**（レーン B 実測）: `cmp` 正本↔plugin rollout-policy = exit 1（char 2792/line 50・リンク書換 6 行）。`sync --dry-run` は現状変更報告ゼロ＝現 plugin コピーは正規状態（drift ゼロ）。cmp byte 一致は rollout-policy に対し**誤った AC**

- **R-107 CONFIRMED**（ai-loop run-026 W チェック Model B・オーガナイザー一次検証）: `docs/workflows/ai-loop/{rollout-policy,lite-criteria,decision-table}.md` は非HO（check-plan-hash.sh case 文・ho-paths.md HO 一覧いずれも不在）。`docs/ai/ai-loop/arbiter-policy.md` は ho-paths.md L35「docs/ai/ai-loop/ 配下は対象外」で clean。ho-paths.md 原則2（L119-121）が「policy は Human-owned・将来 HO-policy 登録予定＝現状 clean」を明記。→ R-001 の engine-only carve-out では policy 自己緩和経路が残る。carve-out を判定基準 policy/criteria 文書群へ拡張（AC-6 更新）

## Disposition 方針（確定反映）

1. **R-001**: §2 拡張の適用対象から **`scripts/ai-loop/**` + 配布版（`plugin/plangate/skills/ai-loop-cycle/scripts/**`）を carve-out**（強制エンジン自己改変防止・escalate 固定）。ho-paths self-protection 原則（ho-paths.md 自身が HO な理由）と同型の最小安全修正。§5 は不変のまま additive 注記。**C-3 論点として Human 確認**（carve-out 方式 vs ai-loop engine の HO 登録）
2. **R-101/R-102/R-103**: rollout-policy（正本=docs・plugin=link-rewrite 派生）と command（正本=.claude HO・plugin=cp 派生）の sync 機構差を Files/Work Breakdown に反映。**AC-5 を cmp byte 一致 → sync 冪等（dry-run 変更ゼロ）へ是正**。command 用は .claude↔plugin cmp を維持。**S3（AI が plugin command 先行編集）を削除**（sync で revert されるため）。command は Human patch（.claude 正本）→ sync 再生成のみ
3. **R-002/R-003/R-004**: AC 群を承認境界の非後退検証へ強化（§4/§6 additive-only・#780 ハード順序制約・command ガード非後退）
4. **R-005/R-006**: AC-1 grep 化・run 実証は handoff で doc 完了と分離

### PR 前レビュー（2026-07-24・commit b5f49ec）

- **R-108 CONFIRMED**（一次検証）: `00_concept.md`/`design-philosophy.md`/`c3-prime-contract.md`/`loopspec.md`/`delivery-state-machine.md`/`stop-rollback.md` すべて ho-paths HO 表 hit 0（=clean）。rollout-policy §5 L107 が design-philosophy を I-1 正本、§6 L112 が 00_concept を escalate 経路正本と名指すのに carve-out 未収載＝自己矛盾。→ **列挙を廃し glob**（`docs/workflows/ai-loop/**` + `docs/ai/ai-loop/**`）
- **R-109 CONFIRMED**（一次検証）: `arbiter.py` `boundary_check` は ho_patterns（ho-paths HO 表）からのみ touches-HO を導出 → carve-out パスは clean 判定＝機械 escalate しない。command の断言を機械層（HO パス）/規範層（ai-loop corpus・実行者責務）に分離し KI-1 と整合させた
- **River Review レーン: 初回は実行不可 → 再実行で完了（§10 形式・resolved）**
  - `status`: unavailable → **resolved**（2026-07-24 再実行で完了）
  - `reason`: 初回実行時に API エラー（Connection closed mid-response）でエージェント異常終了
  - `alternative_coverage`: 同時実行した独立敵対レーンが major 2 件（R-108/R-109）を検出し一次ソース CONFIRMED 済み
  - `residual_risk`（当時）: docs 整合・正本間矛盾の観点が未カバー → **再実行で解消**（M-2/R-111 の正本間矛盾を実際に検出）
  - `verdict`: WARN（初回時点）→ 再実行完了により解消
- **River Review 再実行結果（HEAD 84fcb40）**: critical 0 / major 3 / minor 4 / info 2。**承認境界の実質緩和なし**を実測確認（§5/§6 diff ゼロ・ho-paths 未変更・arbiter に domain 判定なし＝規範層の帯入替）。総合 = Human review recommended

総合判定: **conditional**（R-001 carve-out 反映 + AC 強化を確定反映 → 簡易 C-1 → 人間 C-3 APPROVED を条件に exec 可）
