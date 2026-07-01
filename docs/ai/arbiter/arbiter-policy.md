# Arbiter L0 policy

> 適用ドメイン: Arbiter-workflow（docs/workflows/arbiter/ 配下）のみ
> 非適用: PlanGate 本番フロー（WF-00〜WF-07）
> 上位制約の優先順: core-contract.md > responsibility-classes.md > 本 policy
> 本 policy は「detect/escalate 判断基準」のみを追加する

---

## 1. 目的

on-the-loop 運用における AI の自律許可範囲と責務拡張を定義する L0 policy 文書。
PlanGate 既存の L0 契約（in-the-loop 前提）を継承せず、Arbiter 固有の責務モデルを定義する。

---

## 2. 責務モデル拡張（on-the-loop 用）

| 主体 | 責務 |
| ------ | ------ |
| AI-owned | 実装・テスト・PR 準備・auto-approve 発行 |
| Human-owned | policy 制定・例外裁定・事後監督（実行前承認から退却） |
| CI-owned | drift 検出・逸脱検知・サーキットブレーカー発火 |
| Workflow-owned | DoD・学習ループ・昇格予算管理 |
| Policy-owned | 事前定義された自律許可の裁定（人間でも AI でもない第三主体） |
| Sensor-owned | 逸脱検知の責務 |

### Human-owned の変化

PlanGate（in-the-loop）では各実行の事前承認を Human-owned とした。
Arbiter（on-the-loop）では Human-owned は policy 制定・例外裁定・事後監督に移行する。

実行前承認は Policy-owned に委譲されるが、以下は永久 Human-owned:

- policy 制定・改版（第0の承認境界）
- boundary=touches-HO の操作
- W チェック不一致かつ severity=critical/major
- merge（C-4）

---

## 3. 基本原則: flow → detect → escalate

```text
flow      : 低リスク変更（boundary=clean かつ lite=true）は実行前ブロックせず流す
detect    : 変更を W チェック（2 モデル非対称）と boundary 判定で逸脱検知する
escalate  : 逸脱（W チェック不一致 / boundary=touches-HO / 予算超過）のみ人間昇格する
```

---

## 4. W チェック（2 モデル非対称）

### 4.1 基本判定表

| モデル A | モデル B | → 裁定 |
| --------- | --------- | -------- |
| approve | approve | 合意 → auto-approve 候補（boundary=clean 時） |
| approve | reject | 不一致 → **severity 分類へ進む** |
| reject | approve | 不一致 → ブロック（A が設計妥当性で NG） |
| reject | reject | 合意 → ブロック |

モデル A（順方向）: 設計妥当性「正しく作られているか」を検証
モデル B（逆方向）: adversarial「どう壊れるか」を検証

### 4.2 不一致時の severity 分類と裁定

W チェック不一致（A=approve, B=reject）を検出した場合、拒否理由の severity を分類する。
critical/major は即座に human escalate。minor/low は観点特化モデル（C/D）による追加裁定を経る。

| severity | 判定基準 | → 裁定 |
| ---------- | ---------- | -------- |
| critical | HO パス接触・権限変更・不可逆操作・セキュリティ破壊 | human escalate 固定 |
| major | 公開 API 変更・データ整合性・マイグレーション・認証変更 | human escalate 固定 |
| minor | ロジック変更・パフォーマンス影響・テスト不足 | Model C/D 裁定へ |
| low | ドキュメント・フォーマット・命名 | Model C/D 裁定へ |

### 4.3 観点特化 multi-agent 裁定（Model C/D）

severity=minor/low の不一致を、観点が異なる 2 モデルが独立に再判定する。

```text
Model C: セキュリティ・認証・権限観点（adversarial 視点で安全性を検証）
Model D: 後方互換・データ整合観点（既存契約との破壊的変化を検証）
```

| Model C | Model D | → 最終裁定 |
| --------- | --------- | ----------- |
| approve | approve | 合意 → auto-approve（provenance に C/D 裁定を記録） |
| approve | reject | 不一致 → human escalate |
| reject | approve | 不一致 → human escalate |
| reject | reject | 合意 → ブロック |

Model C/D は Model A/B と独立して動作する。
C/D の結果は provenance に記録され、policy 改善（L4 学習）の入力となる。

---

## 5. 承認境界（絶対条件）

boundary=touches-HO の場合、lite 値・W チェック結果にかかわらず、必ず human escalate 固定。
この条件は W チェック・severity 分類・観点特化裁定のいずれをもスキップする。

> **「承認境界に触れた瞬間に全部 human に戻る」**

touches-HO 判定の正本: `docs/ai/arbiter/ho-paths.md`

---

## 6. 第0の承認境界（policy 制定）

本 policy（auto-approve を許す policy ルールを含む）の制定・改版は Human-owned 固定。
AI は policy draft を提案できるが、発行・適用は Human-owned。

「自分の枠を自分で書き換えない」

---

## 7. escalate 予算

human 昇格の洪水を防ぐため、昇格件数に上限（予算）を設ける。
具体的な上限値は Phase 1 以降のパラメータ化で定義する（TBD）。

- severity=critical: 予算外（即時昇格・予算消費しない）
- severity=major: 予算消費（上限到達時はサーキットブレーカー）
- severity=minor/low で C/D 不一致: 予算消費

---

## 8. 安全装置（on-the-loop 固有の死因と抗体）

| 死因 | 抗体 |
| ------ | ------ |
| サイレント逸脱 | 逸脱検知の完全配線（検知器に穴を残さない） |
| 監督の幻想 | **承認 provenance**（誰が・どの policy で・対象 SHA・W チェック結果を刻印） |
| 自己免疫疾患 | **policy/gate 生成は永久 in-the-loop**（第0の承認境界 §6 参照） |
| 例外昇格の洪水 | human 昇格の**予算**（上限 N + 重大度トリアージ §7 参照） |
| 承認境界の漸進侵食 | 境界の常時 block 維持 + 発行元検証（provenance）を塞ぐ |
| 不可逆性 | **サーキットブレーカー**（`decision-table.md §5` 参照） |

---

## 9. 関連ドキュメント

- `docs/ai/arbiter/ho-paths.md` — touches-HO 判定の正本
- `docs/ai/arbiter/concept.md` — Arbiter の基本概念
- `docs/ai/core-contract.md` — 上位制約（Iron Law）
- `.claude/rules/responsibility-classes.md` — PlanGate 責務分類（参照のみ）
