# TASK-1045 INDEX

> Issue: [#1045](https://github.com/s977043/plangate/issues/1045)（P2 / bug / milestone `v8.19.0`）
> EH-13 token-guard が stderr リダイレクト（`2>/dev/null` / `2>&1` / `>&2`）を
> 書き込みと誤判定し、読み取り専用コマンドを block する欠陥の修正
> 由来: **#1042 の後続** / 関連: **#1023**（EH-13 実装元）

## 現在フェーズ

**B 完了（plan パッケージ + C-1 + C-2 3 ラウンド + River Review 済）→ 👤 Human C-3 待ち**
（mode: **`critical`** = 人間 C-3 必須・同期。autonomous APPROVE **不可**）

**確定 `plan_hash`**: `sha256:744b3c4f0cb05e10dc756e43e89ff263743c571c526838757fc9dee270fe2c7f`

## ファイル

| ファイル | 内容 |
|---|---|
| [pbi-input.md](pbi-input.md) | PBI INPUT PACKAGE（Context / Scope / 受入基準 AC-01〜13 / Risks / Unknowns） |
| [plan.md](plan.md) | EXECUTION PLAN（**GC-1〜GC-8 の制約階層** / Step 1〜8 / **SC-1〜9・RT-1〜5** / Mode 判定） |
| [todo.md](todo.md) | EXECUTION TODO（A-1〜A-14 / H-1・H-2 / **TC 追加の owner 表**） |
| [test-cases.md](test-cases.md) | T1045-TC-01〜22 + TC-22b（**23 件** / 変異注入 2 方向） |
| [review-self.md](review-self.md) | C-1 セルフレビュー（独立 checker）+ 簡易 C-1 #1〜#3 |
| [review-external.md](review-external.md) | C-2（2 レーン × 3 ラウンド）+ River Review（**R-001〜R-018**・追記専用） |
| [current-state.md](current-state.md) | 現在状態スナップショット |
| [decision-log.jsonl](decision-log.jsonl) | 判断履歴（append-only） |

## キーポイント

- **欠陥**: `_has_write_intent()` が `printf '%s' "$_wc" \| grep -q '>'` で
  **`>` を 1 文字でも含めば write intent**と判定（`check-approval-token-write.sh:48`）。
  `2>&1` / `2>/dev/null` / `>&2` は fd 複製・破棄でファイル書き込みではない
- **修正方向**: 「**任意のファイル宛リダイレクトは block 維持、
  fd 複製（`N>&M` / `>&N` / `N>&-`）と `/dev/null` 破棄のみ除外**」。
  **`>` を token path 宛に限定する実装は禁止**（`T1023-TC-09` が退行 FAIL する / **GC-3**）
- **GC-8（fail-closed 契約）**: 正規化ヘルパは `sed` を **fail-open で持ち込まない**。
  必須 3 件 = (i) `|| _wc_n="$_wc"` フォールバック / (ii) `command -v sed`
  （**`_parse_unknown()` 定義の後に置く**。前に置くと `rc=127` = 非 block）/ (iii) `LC_ALL=C`
- **GC-4-A / GC-4-C**: focused 群は **7 件**（`TC-01`〜`06` + `TC-20`）。
  **RED ウィンドウの期待 FAIL は 6 件**（新 TC 4 + `T1023-TC-15pre` + `T1023-TC-17post`）で、
  それ以外の FAIL は `SC-1` 発火
- **検出力**: 変異 2 方向（修正前へ戻す / 弱める側）+ **`TC-22`（要件 ii）と
  `TC-22b`（要件 i）の 2 本**。**`TC-22` 単独では (i) 欠落を素通しする**（R-009 実測）
- **記法**: トークンパス literal を地の文に書かない（本 PBI の欠陥が文書作業自体を阻害するため）。
  **`route=` は文書内の説明ラベルで guard 出力ではない**（R-017）
- **C-3 の裁定事項**: **Q-1**（Mode を `high-risk` へ引き下げるか）/
  **Q-2**（`&>` を block 維持でよいか）/ **Q-3**（`Files / Components to Touch` に
  `evidence/` 等を追加して `plan_hash` を取り直すか）
