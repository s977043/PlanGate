# 簡易 C-1 再実行 — TASK-1109 (#1109) / V-3 REJECT 反映後

> 対象: `review-external.md`（V-3 相当・REJECT / major 3）の 1 回確定反映後の状態。
> 範囲: **差分が触った箇所に限った簡易 C-1**（初回のフル 17 項目は
> [`review-self.md`](./review-self.md)。判定が変わった項目のみ再掲する）。
> **判定: PASS（critical 0 / major 0 / WARN 2）**

## 反映の妥当性（R-NNN ごと）

| R-NNN | 反映したか | 反映が指摘の**機序**を潰しているか（実測） |
|-------|-----------|------------------------------------|
| R-001 | ✅ | 既定 root 不在を violation 化。**M-A 再注入 → TC-02/13/16 FAIL（kill）**。v1 は生存だった |
| R-002 | ✅ | `ignored=1` を撤去し同値照合へ。**skills root にファイル追加 → 17/17 PASS**。v1 は TC-10 FAIL |
| R-003 | ✅ | fixture repo で既定経路の負側 TC を新設。**M-B 再注入 → TC-14 FAIL（kill）**。v1 は生存だった |
| R-004 | ✅ | `root_label()` で REPO_ROOT 相対化。**TC-17 が violation 行の一意性（2 行）を照合** |
| R-005 | ⚠️ 部分（明文化のみ） | コード変更なし。検査の意味範囲をスクリプト冒頭に明記し、Q-4 へ送った（レビューア推奨と一致） |
| R-006 | ✅ | plan F-7 / status を本 PR 後の 3 経路に更新 |
| R-007 | ✅ | plan F-9 と patch ヘッダに「post-merge only / PR 側は ta-68」を明記 |

## 再判定した C-1 項目

| ID | 項目 | v1 | v2 | 根拠 |
|----|------|----|----|------|
| C1-PLAN-01 | 受入基準の網羅性 | PASS | **PASS** | AC-9（既定経路の検出力）/ AC-10（root 区別）を追加し TC を 1:1 で紐付けた |
| C1-PLAN-03 | スコープ制御 | PASS | **PASS** | 追加変更は検出器・テスト・plan doc に閉じる。`.codex/skills` / 配布物の実データは v1 から不変（`git diff` で確認） |
| C1-PLAN-04 | テスト戦略 | PASS | **PASS** | 12 → **17 TC**。負側が `--target` 経路に偏っていた欠陥を是正し、既定経路の正側 1 + 負側 2 を追加 |
| C1-TC-02 | Edge case 網羅 | PASS | **PASS** | 「既定 root 片方不在（#1086 後）」を**設計先送りから TC-15 へ格上げ**。「非ディレクトリが増える」も追加 |
| C1-X-01 | 絶対件数を契約値にしていない | PASS（誤判定） | **PASS（是正済）** | v1 は TC-10 の `ignored=1` を見落として PASS にしていた。v2 は同値照合。**判定の見落とし自体が W-3** |
| C1-X-02 | fail-closed を緩めていない | PASS（要件変更） | **PASS** | v1 唯一の緩和（既定 root 不在を violation にしない）を**撤回**。緩和は現在ゼロ |

## WARN（2 件）

| # | 内容 | severity | 対応 |
|---|------|----------|------|
| **W-2**（継続） | 配布物 `openai.yaml` はどの script でも生成されない手書き資産で、**生成側の再発防止は入れていない**。新 skill 追加時に CI が赤で気付く運用 | minor | 意図的（Non-goal）。Q-1 として Human 判断へ |
| **W-4**（新規 / R-005 由来） | `icon_*` は値の宣言のみ検査し、**marketplace 直読み経路でパスが解決するかは判定不能**のまま | minor | Q-4 として follow-up。レビューアも「本 PR のブロッカーにしない」と明記 |

> v1 の **W-1（既定 target 不在を violation にしない fail-open）は解消**したためクローズ。
> **W-3（新規・プロセス指摘）**: v1 の C-1 は C1-X-01「絶対件数を契約値にしない」を
> 自ら掲げながら TC-10 の `ignored=1` を見逃して PASS を出した。
> **自己申告した制約は、その制約で自分の成果物を grep して確認する**まで PASS にしない。

## 判定

**PASS**（critical 0 / major 0 / minor(WARN) 2）
→ C-3（人間・同期）へ。**autonomous APPROVE 不可**（high-risk + HO 隣接）。
**`c3.json` は発行していない。**
