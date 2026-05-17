# Handoff — TASK-0100 / Plan Hash Utility 共有化（#193 follow-up / reuse H-1）
## 1. 要件適合確認
| AC | 判定 |
|----|------|
| AC1 plan_hash_util 3 関数集約 | PASS |
| AC2 3 消費者が util 使用・local 重複除去 | PASS |
| AC3 3 消費者出力 main 等価（in-place TASK-0095/0090/0096）| PASS |
| AC4 EH-3 shell↔python 契約テスト（ta-11）| PASS（4/4）|
| AC5 全スイート回帰なし | PASS（68 passed 0 failed）|
V-3（Codex）APPROVE・critical/major 0・minor 3 全反映。

## 2. 検討経緯（ユーザー指示: Codex相談→Gemini検証→方針決定）
- Codex 相談: H-1 を 1 PBI 化（shell 不触・python 共有・契約テスト）/ M-2 見送り を助言
- **実証検証**で Codex 案を補正: shell(sed) vs python(json) を異常系 fixture で
  機械比較→ 正常/注入/重複キーは shell≡python、不正JSON(末尾カンマ)のみ
  python strict 拒否。「shell を正に合わせる」でなく **python strict=不正
  c3.json を承認記録に信用しない安全側を正本**と確定
- Gemini 検証: 両モデル容量上限（exhausted）。確立 precedent（Gemini 失敗→
  Codex 主体）+ 実証検証（意見より強い機械検証）で代替し方針確定

## 3. 既知課題 / V2
- check-plan-hash.sh(shell EH-3) の不正JSON 寛容抽出（sed）を sed→python -c に
  ハードニングする選択肢は **承認境界変更**のため本 PBI Non-goal。V2 候補。
- M-2（REPO/WORKING パス 6+ 重複・命名不統一）は YAGNI 判断で見送り・V2 backlog。

## 4. 妥協点
- shell EH-3 を不触（実行経路変更=承認境界変更）。python 側のみ共有化し
  契約テストで shell との parity / 意図的 strict 差異を機械固定。

## 5. 引き継ぎ
reuse H-1 を解消。scripts/plan_hash_util.py（strict json 正本）に集約、
keep-rate/context-engine/metrics_collector を差し替え、ta-11+fixtures で
EH-3 shell 整合契約を固定。3 消費者 in-place 等価・全スイート 68/0・
check-plan-hash.sh 無変更を確認。EPIC #193 follow-up 完了。

## 6. テスト結果
V-1 AC1-5 + E1/E2 / V-3 minor3 反映後: 非object/不正JSON→None・ta-11 4/4・
run-tests 68 passed 0 failed・metrics plan_hash 等価・shell 無変更 全 PASS。
