# flow-detect — Arbiter 動作フロー定義

> 適用ドメイン: Arbiter-workflow（docs/workflows/arbiter/ 配下）のみ
> 非適用: PlanGate 本番フロー（WF-00〜WF-07）
> W チェック定義正本: 本ドキュメント §3.1

---

## 1. フロー概要

```text
変更対象ファイルのリスト
        ↓
[boundary 判定]  → touches-HO? → human escalate（即時）
        ↓ clean
[lite 判定]      → lite=false?  → human escalate
        ↓ true
[detect: W チェック A/B]
        ↓
[severity 分類 / C/D 裁定 / escalate 判定]
        ↓
auto-approve または human escalate
```

---

## 2. flow フェーズ

低リスク変更の通過条件（すべて満たす場合のみ flow して detect へ進む）:

| 条件 | 説明 |
|------|------|
| `boundary = clean` | 変更対象が HO パス（`docs/ai/arbiter/ho-paths.md`）のいずれにも含まれない |
| `lite = true` | 低リスク要件を満たす（高リスク要素なし） |

どちらか一つでも満たさない場合 → human escalate。

**boundary=touches-HO の場合、lite 値・W チェック結果にかかわらず、必ず human escalate 固定。**

---

## 3. detect フェーズ — W チェック（2 モデル非対称）

### 3.1 基本判定

| モデル A | モデル B | → 裁定 |
| --------- | --------- | -------- |
| approve | approve | 合意 → auto-approve（boundary=clean 時） |
| approve | reject | **不一致 → severity 分類へ** |
| reject | approve | 不一致 → ブロック（A が設計妥当性で NG） |
| reject | reject | 合意 → ブロック |

モデル A（順方向）: 設計妥当性「正しく作られているか」を検証
モデル B（逆方向）: adversarial「どう壊れるか」を検証

### 3.2 不一致時の severity 分類

W チェック不一致（A=approve, B=reject）を検出した場合:

| severity | 判定基準 | → 裁定 |
| ---------- | ---------- | -------- |
| critical | HO パス接触・権限変更・不可逆操作・セキュリティ破壊 | human escalate 固定 |
| major | 公開 API 変更・データ整合性・マイグレーション・認証変更 | human escalate 固定 |
| minor | ロジック変更・パフォーマンス影響・テスト不足 | Model C/D 裁定へ |
| low | ドキュメント・フォーマット・命名 | Model C/D 裁定へ |

**安全側既定**: 分類不能・根拠不足・判定が曖昧な場合は安全側に倒し
**critical 扱い（human escalate）**とする（PlanGate の AC-8 安全側原則
[`working-context.md`](../../../.claude/rules/working-context.md)
と整合）。

**Phase 1 論点（未確定）**: severity 分類の判定主体（Model B の reject
理由から導出するのか、専用の分類器を置くのか）は本ドキュメントでは
確定しない。Phase 1 で決定する。

### 3.3 観点特化 multi-agent 裁定（Model C/D）

severity=minor/low の不一致を 2 つの観点特化モデルが独立に再判定する:

```text
Model C: セキュリティ・認証・権限観点
Model D: 後方互換・データ整合観点
```

| Model C | Model D | → 最終裁定 |
| --------- | --------- | ----------- |
| approve | approve | auto-approve（provenance に C/D 裁定を記録） |
| approve | reject | human escalate |
| reject | approve | human escalate |
| reject | reject | ブロック |

Model C/D は Model A/B と独立して動作する。
C/D の裁定結果は provenance に記録され、policy 改善（L4 学習）の入力となる。

---

## 4. escalate フェーズ

### 4.1 human escalate の条件

| 条件 | 理由 |
| ------ | ------ |
| boundary=touches-HO | HO パスに触れる変更（絶対条件） |
| lite=false | 高リスク変更（低リスク帯外） |
| W チェック不一致 かつ severity=critical | 権限変更・不可逆操作 |
| W チェック不一致 かつ severity=major | 公開 API 変更・認証変更 |
| W チェック不一致 かつ C/D の判定が不一致（approve/reject の割れ） | minor/low でも観点特化で割れた |

### 4.2 escalate 予算

human 昇格の洪水を防ぐため:

- severity=critical: 予算外（即時昇格・予算消費しない）
- severity=major: 予算消費（上限 N 件・Phase 1 以降でパラメータ化）
- severity=minor/low で C/D 不一致: 予算消費

---

## 5. provenance 刻印

> **provenance スキーマの正本は
> [`docs/workflows/arbiter/decision-table.md`](./decision-table.md) §5**。
> 本セクションの責務は刻印**タイミング**の定義のみに限定し、フィールド名の
> 独自定義は持たない（二重定義防止）。

刻印タイミングは以下のいずれか:

- **A/B 合意時**（`verdict=approve-approve`）: auto-approve と同時に provenance を刻印する
- **C/D 合意時**（severity=minor/low の不一致を Model C/D が独立裁定し合意した場合）:
  auto-approve と同時に provenance を刻印する。この場合は
  [`decision-table.md`](./decision-table.md) §5 の
  「C/D 裁定時の追加フィールド」（`w_check.severity` / `w_check.model_c` /
  `w_check.model_d`）が併せて記録される。

フィールド定義・必須項目・値域は [`decision-table.md`](./decision-table.md) §5 のみを参照すること。

---

## 6. 関連ドキュメント

- `docs/ai/arbiter/arbiter-policy.md` — W チェック拡張の policy 定義
- `docs/ai/arbiter/ho-paths.md` — boundary=touches-HO 判定の正本
- `docs/ai/arbiter/concept.md` — Arbiter の基本概念
- `docs/workflows/arbiter/00_concept.md` — WF との並立関係
