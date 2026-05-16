# TASK-0069 外部AIレビュー結果（C-2）

> 生成日: 2026-05-15 / レビュアー: orchestrator（backend-specialist + Explore 統合）

## 判定: WARN（MAJOR 2 / minor 3）→ 全件 plan/todo/test-cases/pbi-input へ反映済み

| ID | 指摘 | 対応 | 反映先 |
|----|------|------|--------|
| MAJOR-1 | `doctor --json` は `doctor_check.py --scope v8.6.0` 専用・human と別系統。hook-wiring を載せる scope 設計が未定 | `doctor_check.py` に scope `hooks` 新設、v8.6.0 出力バイト互換維持と確定 | plan Step1/4, todo T-6.5/T-9, AC-7, TC-7 |
| MAJOR-2 | 期待集合の正本範囲が曖昧（`scripts/hooks/×10` と example 配線数 5 が乖離） | 「期待集合 = settings.example.json の .hooks command 全集合、ファイル数と独立」と明記。EH-8 責務重複ガード追加 | pbi-input Context, plan Step1/Risks |
| minor-1 | AC-3 backup 条件が無条件 vs TC は「既存時のみ」で矛盾 | AC-3 を「既存時のみ .bak」に訂正 | pbi-input AC-3 |
| minor-2 | 非 tty + `--yes` 無し時の挙動未定義（hang リスク） | 「非 tty → no-write abort」仕様化 + TC-E4 追加 | plan Step3, test-cases TC-E4 |
| minor-3 | `tests/run-tests.sh` 登録は不要かつ #170 規約違反（自動 loader） | 本体編集削除、extras 配置のみに変更 | plan Step6/Files, todo T-10 |

## 事実確認（本セッションで検証済み）

- `tests/run-tests.sh:124-134` extras loader が `ta-*.sh` を自動 source（本体編集不要）
- `scripts/doctor_check.py:145-147` は `scope != "v8.6.0"` で `return 2`（新 scope は分岐改修必須）
- `.claude/settings.example.json` の hook 正本 = SessionStart 1 + PreToolUse 4

## C-2 後の C-3 推奨

MAJOR 2 件は AC 直結だったが全件 plan へ反映済み。簡易 C-1 再実行（後述 review-self.md 追記）で PASS を確認 → **C-3 は APPROVE 可能水準**（CONDITIONAL から格上げ）。最終判断は人間。

---

## C-3 追加外部レビュー（2026-05-16 / Codex + Gemini 並列委託）

> レビュアー: Codex CLI 0.128.0 / Gemini CLI 0.38.2（plan.md / pbi-input.md / test-cases.md 対象）

| レビュアー | 判定 | 内訳 |
|----|------|------|
| Codex | CONDITIONAL | major 4 / minor 2 |
| Gemini | CONDITIONAL | major 1 / minor 1 / info 2 |

### 指摘と対応（全件反映済み）

| ID | 指摘 | レビュアー | 対応 | 反映先 |
|----|------|----------|------|--------|
| C3-MAJOR-1 | `bin/plangate` が `--json` 検出時に常に `--scope v8.6.0` を呼ぶため `--json --scope hooks`（AC-7）が到達しない | Codex+Gemini | cmd_doctor で `--scope` を解析し doctor_check.py へ透過転送と明記 | plan Step1ck/Step3 |
| C3-MAJOR-2 | 配線判定が command 文字列集合のみだと別 event/matcher で誤 PASS | Codex | `(event,matcher,type,command)` ブロック単位照合へ変更 | plan Step1/Risks, TC-1/TC-E2 |
| C3-MAJOR-3 | dry-run 非書込テストが settings.json 偏重（EH-8 chmod/.gitignore/mkdir 未検証） | Codex | TC-2 に全修復対象の非書込を追加 | test-cases TC-2 |
| C3-MAJOR-4 | 既存 `.bak` 上書き安全性が未定義 | Codex | 既存 `.bak` を `.bak.<epoch>` ローテート退避方針を確定 | plan Constraints/Step2/Risks, AC-3, TC-3b |
| C3-minor-1 | TC-3 が新規/既存ケース混在 | Codex | TC-3a（新規）/ TC-3b（既存+ローテート）に分割 | test-cases |
| C3-minor-2 | AC-6 gh/codex 未導入時の挙動が曖昧 | Codex | Step3 に「自動インストールせず --fix 時に案内」明記 | plan Step3 |
| C3-info-1 | settings.json 二重リスト構造マージの確実性 | Gemini | Risks に二重構造保持を明記（TC-E2 で担保） | plan Risks, TC-E2 |
| C3-info-2 | EH-8 を将来 example 正本に含めるか設計合意 | Gemini | Non-goals に注記 | pbi-input Non-goals |

### C-3 判定への示唆

両レビュアーとも CONDITIONAL（骨格は妥当、条件付き承認可）。共通核心 C3-MAJOR-1/2 を含む全 8 件を plan/test-cases/pbi-input に反映済み。簡易 C-1 再実行で PASS 確認 → **C-3 APPROVE 可能水準**。最終判断は人間。

---

## C-3 再レビュー（2026-05-16 / Codex + Gemini 並列・2回目）

> 8 件反映後の再検証。証跡: `evidence/c2-review/c3-{codex,gemini}-rereview-2026-05-16.md`

| レビュアー | 判定 | 残指摘 |
|----|------|--------|
| Codex 0.128.0 | **APPROVE** | minor 1 / info 1（表現補強・任意） |
| Gemini 0.38.2 | **APPROVE** | なし |

- 前回 8 件: 両者一致で**全件「解消」**判定
- Codex 残 minor/info（任意・実装前の可読性補強。本セッションで反映済み）:
  - [minor] `ta-10-doctor-fix.sh` が doctor_fix.py を直接叩く単体テスト群である旨を TC-8 に明記 → 反映済み
  - [info] AC-2 マッピングの dry-run / 非tty 混在を表現分離 → 反映済み
- 両者「exec 着手して安全な水準」と明言

### C-3 最終推奨

外部レビュアー2系統が独立に **APPROVE**、簡易 C-1 ×3 PASS、残 major/critical なし。**C-3 APPROVE 可能水準（二重確認済み）**。最終判断は人間。
