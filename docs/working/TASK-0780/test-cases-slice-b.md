# TASK-0780 (Slice B) Test Cases — plan 品質 hard gate

> AC: (1) gates.c1 が PASS 以外/欠落なら escalate (2) gates.breakdown が pass 以外なら escalate
>     (3) 優先順位不変（fail-closed=0 > touches-HO=1 > scope=1.5 > **c1/breakdown=1.7** > lite=2 …）
>     (4) POLICY_REF @v2 (5) 既存経路の回帰なし

| TC | 入力（差分のみ） | 期待 | 種別 |
|----|------|------|------|
| B-1 | gates.c1="PASS", gates.breakdown="pass", 他は AUTO_APPROVED 条件 | AUTO_APPROVED | unit |
| B-2 | gates.c1="FAIL" | HUMAN_ESCALATED（reason=plan-quality: c1） | unit |
| B-3 | gates.c1 欠落 | exit 1 入力エラー（必須フィールド） | unit |
| B-4 | gates.breakdown="split-suggested" | HUMAN_ESCALATED（reason=plan-quality: breakdown split） | unit |
| B-5 | gates.breakdown 欠落 | exit 1 | unit |
| B-6 | touches-HO + gates.c1="FAIL" | HUMAN_ESCALATED・boundary=touches-HO（HO 優先・c1 で上書きしない） | unit |
| B-7 | gates.c1="PASS" だが scope 逸脱 | HUMAN_ESCALATED・scope_violation（scope=1.5 が c1=1.7 より先） | unit |
| B-8 | gates.c1="pass"（小文字）等の異表記 | HUMAN_ESCALATED（"PASS" 完全一致のみ通過・安全側） | unit |
| B-9 | POLICY_REF | "auto-approve-lite-clean@v2" を pin | unit |
| B-10 | gates フィールド全体が欠落（旧入力形式） | exit 1（入力契約変更＝必須化。移行は SKILL 手順で担保） | unit |
| B-11 | provenance に gates.c1 / gates.breakdown の値が刻まれる | record 検証 | unit |

エッジ: gates.c1 の許容値は "PASS" のみ（"PASS"/"FAIL" の 2 値。将来 "WARN" 追加は別 PBI）。breakdown は "pass"/"split-suggested" の 2 値。
