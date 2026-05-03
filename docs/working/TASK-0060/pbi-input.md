# PBI INPUT PACKAGE: TASK-0060 (PBI-HI-008 / Issue #202)

## Why

Metrics v1 (PBI-HI-001 / #195, v8.6.0) を public repo で運用すると、ファイル名・エラー内容・モデル名・provider・作業対象などが意図せず公開されるリスクがある。実装前に redact / retention / public data policy を確定する。

## What

In scope:
- 保存可能な metrics 列挙
- 保存禁止な metrics 列挙
- file path / stack trace / command output / provider metadata の扱い
- redact / sanitize 方針
- retention policy
- public repo / private repo での運用差分
- PBI-HI-001 (#195) との接続

Out of scope:
- 完全 DLP 実装、外部監査ツール連携、暗号化ストレージ、外部 DB 連携、`docs/working/` 公開方針再設計

## Mode 判定

light（doc only、metrics-privacy.md 1 ファイル）。

## AC

Issue #202 の 8 項目。
