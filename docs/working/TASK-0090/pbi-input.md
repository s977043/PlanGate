# PBI INPUT — TASK-0090 / #224 Plugin モード成熟化と移行パス

## Context / Why
消費側（ai-agent-template/growth-lab 等）が PlanGate の .claude/ を手動コピー
運用し乖離・二重管理が常態化。導入手順/移行/バージョン固定/カスタマイズ境界
が未文書で plugin モードの採用可否を判断できない。

## What
- In: `docs/ai/plugin-stability-and-sync.md`（正本: 安定性宣言/release archive
  同期/カスタマイズ API/手動コピー版移行）+ plangate-plugin-migration.md・
  versioning-stability-policy.md からの相互参照
- Out: plugin.json バージョン変更 / plugin 実ファイル再編 / 同期スクリプト実装 /
  消費側リポジトリの実改修

## 受入基準
- AC1: Plugin 安定性宣言（コンポーネント別 Stable/Beta、versioning-policy §3 と整合）
- AC2: バージョン同期メカニズム = release archive 方式（固定取得/更新/検証手順）
- AC3: カスタマイズ API（overlay precedence + 上書き可否境界 + 記録）
- AC4: 手動コピー版からの移行 Step1-4（install/diff/dedup/customize）
- AC5: 既存 plangate-plugin-migration.md と versioning-stability-policy.md から相互参照
- AC6: rules/hooks 上書きのゲート無効化リスクと人間承認要件が明記

## Notes
ユーザー決定: release archive + 移行ガイド方式（submodule/npm 不採用）。
hooks 上書き不可は responsibility-classes / orchestrator AI 自己完結禁止に準拠。

## Estimation
Risks: 既存 migration doc との二重定義（緩和: 段階移行は既存正本参照、本書は
手動コピー起点+同期+カスタマイズに限定）/ Unknowns: 消費側 CI 突合は任意明記 /
Assumptions: GitHub Release tar.gz が常時取得可能
