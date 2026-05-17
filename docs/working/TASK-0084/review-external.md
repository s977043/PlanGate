---
task_id: TASK-0084
artifact_type: review-external
schema_version: 1
status: done
phase: V-3
---
# V-3 外部レビュー — TASK-0084（#229 Trace Timeline v1）

standard。Codex 実行（Gemini 出力なし→Codex 主体・前例運用）。

## 判定: Codex=critical0/major2/minor3 → fix-loop（全反映）

| # | Sev | 指摘 | 対応 |
|---|-----|------|------|
| MJ-1 | major | gate_id/parent_event_id が任意文字列＝Privacy(#202) を schema で物理阻止できない（path/prompt/人名混入可）| schema に `pattern ^[A-Za-z0-9._:-]{1,64}$` + maxLength64（slash/空白/自由文 reject）|
| MJ-2 | major | docstring「phase/gate/ts 順」と実装「ts→phase→gate」がズレ | #229 AC-3 契約どおり sort を `phase→gate→ts` に修正・docstring 整合 |
| mn-1 | minor | events 不在時の JSON shape が通常と不一致 | schema_version/experimental/count を付与し shape 統一 |
| mn-2 | minor | help が `--json` を report-only と説明だが timeline も JSON | help を `--report / --timeline` に修正 |
| mn-3 | minor | `--timeline --aggregate/--markdown-section` が黙殺 | 併用を exit2 で拒否 |

Codex OK 確認: const→enum["1.0","1.1"] は後方互換 / phase enum 追加は additive /
additionalProperties:false 維持 / --timeline 独立 return で既存 mode 非破壊 /
quickstart 非掲載 妥当。

## 確認
- 再 V-1: gate_id slash reject・EH-3 valid・1.0 後方互換 valid・--timeline
  --aggregate exit2・hook 78/0・CLI 64/0・schema-self valid

## 出典
- Codex: /tmp/t0084-codex-v3.md（critical0/major2/minor3）
- Gemini: /tmp/t0084-gemini-v3.md（出力なし）
