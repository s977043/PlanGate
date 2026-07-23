# Handoff — TASK-0907（ai-loop 適用ドメイン拡張・rollout-policy Phase 1 更新）

> Issue: [#907](https://github.com/s977043/plangate/issues/907) / EPIC [#870](https://github.com/s977043/plangate/issues/870)
> Mode: critical / lite_eligible: false / C-3: Human APPROVED（10:22:18Z・plan_hash 85770ff9…）

## 1. 要件適合確認結果（AC ごと）

| AC | 内容 | 判定 | 根拠 |
|----|------|------|------|
| AC-1 | §2 で lite/clean/reversible 帯が eligible（grep） | **PASS** | 3 語 + 「本番フロー変更」明示 |
| AC-2 | §5 diff ゼロ + §4/§6 additive-only | **PASS** | §5 削除行ゼロ・escalate 条件削除なし（diff 実測） |
| AC-3 | Human verbatim 記録 | **PASS** | §2 注記に 2 文 verbatim |
| AC-4 | command 整合 + ガード非後退 | **PASS** | lite/clean 帯明記・NO MERGE BY AI/touches-HO/無条件 escalate 保持（強化置換） |
| AC-5 | rollout-policy sync 冪等 / command cmp | **PASS** | dry-run no change / cmp exit 0 |
| AC-6 | carve-out（engine + policy 群） | **PASS** | ①`scripts/ai-loop/**` ②policy/criteria 6 文書 |
| AC-7 | 承認境界相当パスの非増加 | **PASS** | carve-out で判定基盤を除外・clean 集合点検 |
| AC-8 | #780 未導入下は決定論的 escalate | **PASS** | 「決定論的に escalate」明記・「寄り」不在 |

補助検証: L-0 markdownlint 0 issues（リポ実設定）/ doctor 新規失敗ゼロ（settings 未配線 FAIL は既存・無関係）/ validate Result PASS。

## 2. 既知課題一覧

- **KI-1（規範層 carve-out の機械層未接続）**: 判定基盤②（policy/criteria 文書群）の carve-out は現状**規範層**（§2 注記の文言）。`ho-paths.md` 原則2 の将来 HO-policy 登録で機械層化するまで、arbiter は policy 文書変更を boundary=clean と判定する（HO command 等の別 HO 接触がなければ escalate しない可能性）。→ V2 で HO-policy 登録により機械強制化。
- **KI-2（settings hooks 未配線）**: `bin/plangate doctor` が 7/10 hook 未配線で FAIL（環境既存・Human-owned settings wiring・本 PBI 無関係）。

## 3. V2 候補

- ai-loop 判定基盤（engine + policy 群）を `ho-paths.md` に **HO-policy 登録**し、規範層 carve-out を機械層強制へ昇格（原則2 の将来登録）。
- `lite.size_ok` の機械算出（#780 slice C）— plangate 本体の実機能 auto-approve 実運用の前提。
- ai-loop run の実走実証（arbiter が plangate 本体 lite/clean 変更を AUTO_APPROVED する初例）は #877 等の実 bug fix で（本 PBI は doc 変更でその素地を作る）。

## 4. 妥協点（採用しなかった選択肢と理由）

- **carve-out 方式 vs HO 登録**: engine + policy を今すぐ `ho-paths.md` に HO 登録する案（機械層で強い）は却下し、規範層 carve-out を採用。理由: HO 登録は通常の engine/policy 開発も全て Human patch 化＝重く、`ho-paths.md`（HO）自体の変更も要する。原則2 の将来登録に接続する規範層で当面充足（C-3 APPROVED）。
- **§2 表現案 A/B**: 表セル書換のみ（A）は誤読リスク、eligible 域+別判定節（B）は §4 断片化のため却下。案 C（表行拡張+注記節）採用。

## 5. 引き継ぎ文書（5 分サマリ）

rollout-policy §2 の plangate 本体行を「dogfooding 域 + lite/clean/reversible 帯の本番変更」へ拡張。承認境界（§5）は不動、§4/§6 は additive-only、#780 ハード順序制約を継承、ai-loop 判定基盤（engine code + policy 文書群）は carve-out で escalate 固定。実装は docs/command md のみ（論理コード変更ゼロ）。**ai-loop 初実走（run-026）で arbiter が HO 接触を検知し HUMAN_ESCALATED を返す実証済み**（承認境界遵守）。C-3 は Human 再承認（承認後 plan 微修正で一度 hash 無効化→--force 再承認で復旧）。HO command は Human patch 適用（H2 完了）。

## 6. テスト結果サマリ

- AC-1〜8 全 PASS（grep/diff/cmp 機械判定）
- sync 冪等（rollout-policy）・cmp 一致（command）
- L-0 lint 0 issues / doctor 回帰なし / validate PASS
- ai-loop run-026 decision record: `ai-loop-runs/20260723T100912Z-3b987a1.json`（HUMAN_ESCALATED）

## 7. run 実証の分離（R-006）

`/ai-loop-workflow run TASK-0907` の HUMAN_ESCALATED 実証は「ai-loop が承認境界を遵守して escalate する」Phase 1 挙動の確認であり、本 PBI の doc 完了 AC とは分離。doc 変更の合否は AC-1〜8 で判定済み。
