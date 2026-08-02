---
name: codex-mvp-split
description: "規模 L 以上の機能の最小 MVP (Phase 1) を Codex に選定相談し Phase 分割表を作る。Use when: A フェーズ前段で規模 L 機能の MVP を決めたい時 / 事前メトリクス検証で実数 ≥ 3 倍判定時。"
---

# Codex MVP Split (PlanGate / Codex 共用)

規模 L 以上の機能を着手前に **最小 MVP (Phase 1)** に分割する skill。
実行ロジック・質問テンプレ詳細は `docs/ai/codex-mvp-split.md` を正本とし、
skill は読む順序と入出力規約のみを担う。

## Read First

### 参照解決順（導入先で必ずこの順に探す）

本 skill の参照は上流リポジトリ基準の相対パスで書かれている。導入先ではそのままでは
解決できないものがあるため、**次の順で探索する**:

1. 導入先リポジトリの相対パス（例: `.claude/rules/mode-classification.md`）
2. 無ければ plugin root 配下（例: `<plugin_root>/rules/mode-classification.md`）。
   `<plugin_root>` は **Bash で `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` を実行して展開・確認した
   絶対パス**（Read ツールは絶対パスを要求し環境変数を展開しないため、`${CLAUDE_PLUGIN_ROOT}/...`
   という文字列をそのまま Read しない）。変数が空・未設定ならキャッシュを glob で推測せず 3 へ進む
3. どちらにも無い場合は **「正本 `<path>` を参照できなかった」と明示**し、推測で内容を補わない

導入経路ごとに配置されるものが違う:

| 参照 | `install.sh --claude` 経由 | plugin（Claude marketplace）経由 | Codex 経由 |
|------|---------------------------|----------------------------------|-----------|
| `rules/*.md` | `.claude/rules/` に着地（解決可） | `<plugin_root>/rules/` で解決 | **未配置（解決不可 → 手順 3 へ）** |
| `docs/**` | コピー対象外（解決不可） | バンドル対象外（解決不可） | 未配置（解決不可） |

`install.sh --claude` のコピー対象は `agents` / `skills` / `commands` / `rules` の 4 ディレクトリ
のみ。Codex 経由（`install_codex()`）は `install-plangate-skills.sh` を呼ぶだけで **skills しか
配置されない**ため、rules 参照は解決順 1・2 とも成立せず必ず手順 3 に落ちる。

> **本 skill 固有の注意**: 下記 1・2・4 は `docs/**` 配下＝**3 経路とも配布対象外**である。
> これらが解決できない環境では、本 skill の「Output」「Rules」節（質問構成 4 選択肢 +
> 工数 S/M/L + 判断材料 3 軸、Phase 分割表の構成）を代替正本とし、Phase 分割表に
> 「正本 `<path>` を参照できなかった」旨を記録する。

### 読む順序

1. `docs/ai/codex-mvp-split.md`（質問テンプレ・判定基準・実例の正本。**配布対象外**）
2. `docs/ai/plan-metrics-verification.md`（#351 / TASK-0117、前段の規模判定。**配布対象外**）
3. `.claude/rules/mode-classification.md` → fallback `<plugin_root>/rules/mode-classification.md`
   （5 段階 mode）
4. `docs/working/templates/README.md`（Phase 分割表 section / pbi-input.md template は未作成、README に記述。**配布対象外**）

## 想定 phase

A フェーズ (PBI INPUT PACKAGE 作成) **前段**。

## Input

- `<topic>`: MVP 分割を検討する機能・トピック名
- 規模見積もり (TASK-0117 事前メトリクス検証の結果、L 以上推奨)

## Output

- Codex への質問 (4 選択肢 A/B/C/D + 工数 S/M/L + 判断材料 3 軸)
- PBI INPUT PACKAGE への **Phase 分割表** (Phase 1 着手 / Phase 2+ 繰延)

## Rules

- 質問テンプレは `docs/ai/codex-mvp-split.md` を正本とする。skill は順序のみ。
- 判断材料 3 軸: ユーザ価値 / 実装の独立性 / 次フェーズへの拡張性
- Phase 1 のみ本セッション scope、Phase 2 以降は別 PBI に繰延
- TASK-0117 (#351) 事前メトリクス検証で実数 ≥ 3 倍 (規模 L 相当) 判定時に起動推奨

## 次フェーズへ

Phase 1 確定後は `ai-dev-plan` skill で plan 生成 (B-1 → 事前メトリクス検証 → B-2 → B-3)。
