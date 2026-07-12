# TASK-0780 Slice C: size_ok の機械検証（申告制 → git 由来 blast-radius）

> #780 Slice C。#807/#817 の順序制約「導入先の実機能 auto-approve は size_ok 機械算出を前提」を満たす。
> ai-loop の核心「観測を信じる（自己申告に依存しない）」を size 軸で実現。

## Goal

`lite.size_ok` の自己申告を、arbiter が `changed_files` の実ファイル数で**機械検証**する。
申告 size_ok=true だが実 blast-radius が閾値超なら escalate（申告と実測の不一致を検出）。

## 前提の実測検証

| 前提 | 検証 | 実測 | 判定 |
|------|------|------|------|
| arbiter は changed_files を受ける | grep changed_files arbiter.py | 入力必須 | ✅ |
| size_ok は現状申告 bool のみ | lite_check は 4 bool AND | 申告値をそのまま使用 | ✅ |
| lite-criteria の size 定義 | 「ファイル数 1〜2 目安」 | light 相当以下 | ✅ |
| POLICY_REF | 現行 @v2 | @v2 | ✅ |

## 設計（安全側・Slice B と同型: escalate 追加のみ）

1. **機械 size 検証**: `SIZE_OK_MAX_FILES = 2`（lite-criteria「1〜2」に一致・named 定数）。
   `machine_size_ok = len(changed_files) <= SIZE_OK_MAX_FILES`
2. **申告と実測の不一致検出**: 申告 `lite.size_ok == True` かつ `machine_size_ok == False`（ファイル数超過）
   → **HUMAN_ESCALATED**（reason=`size_ok 申告=true だが実ファイル数 <N> が閾値 2 を超過（申告と blast-radius 不一致）`）
   - 位置: lite（priority 2）判定の一部、または専用の前置チェック。scope(1.5)/plan-quality(1.7) の後・従来 lite(2) と同格〜直前
3. **申告 size_ok=false は従来どおり**（lite=false で priority 2 escalate・変化なし）
4. **他 lite 軸（no_new_design/follows_pattern/reversible）は申告制のまま**（Slice C は size 軸のみ機械化。他軸の機械化は別 slice/V2）
5. **POLICY_REF @v2 → @v3**（auto-approve の判定に機械 size 検証が加わる policy 改版）
6. SKILL 4 配置: 「size_ok は申告するが arbiter が changed_files 数で検証する。実ファイル数が 2 を超えて size_ok=true を申告すると escalate」を明記。lite-criteria.md に機械検証の記述追加

## 安全性の不変条件（レビュー主眼）

**この変更は escalate 条件を追加するのみ。以前 escalate だったものを auto-approve にする経路をゼロにする**
（機械 size 検証で size_ok=true 申告が「実測で否定される」場合のみ escalate 追加。逆方向＝以前 escalate が auto-approve になる、は発生し得ない）。差分検証で reverse_violations=0 を機械証明（Slice B と同じ方法）。

## Out of scope

- 行数ベースの blast-radius（changed_files からは行数不明。将来 diff_stat 入力で拡張検討）
- 他 lite 軸の機械化
- metrics.py 変更

## Testing

- 申告 size_ok=true + changed_files 1〜2 個 → 従来どおり（機械も true）
- 申告 size_ok=true + changed_files 3 個以上 → HUMAN_ESCALATED（不一致検出）
- 申告 size_ok=false → 従来どおり lite=false escalate
- 全 priority で HO/scope/plan-quality が size 検証に先行（優先順位不変）
- POLICY_REF == @v3
- 安全性差分: 申告と実測一致=main と同一裁定 / 不一致=escalate 一方向・逆方向 0

## Mode

standard（gate 挙動変更だが安全側・ファイル 4-5）。承認境界非接触。三層安全性証明（maker/統合/敵対）必須。
