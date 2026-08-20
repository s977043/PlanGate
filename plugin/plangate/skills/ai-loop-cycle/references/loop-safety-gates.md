# loop-safety-gates — flow 進入前の非停止プロンプト事前ゲート

> 対応 issue: [#728](https://github.com/s977043/plangate/issues/728)（loop-safety gates）
> 適用ドメイン（Phase 1）: ①plangate 本体 = docs/workflows/ai-loop/ 配下のみ（dogfooding 域・本番フロー WF-00〜07 非適用。
> [`design-philosophy.md`](./design-philosophy.md) 冒頭）。②導入先リポジトリ = ho-paths 確定 +
> LoopSpec scope.allowed_paths 宣言を前提に適用可。
> 思想的根拠: [`design-philosophy.md`](./design-philosophy.md) **I-6「停止できないループはループではない」**
> （+ サーキットブレーカーによる自律そのものの一時停止という 2 層停止機構）。
> 発火位置: [`flow-detect.md`](./flow-detect.md) **§2 flow フェーズへの進入前**に置く事前ゲート。
> flow-detect.md 本体（boundary / lite / class 判定）は変更しない。本書はその手前の
> 「ループを始めてよい指示か」を判定する層であり、flow-detect の判定対象を狭めも広げもしない。

---

## 参照解決順（`docs/**` / 導入先で必ずこの順に探す）

本ドキュメントが参照する `docs/**` は上流リポジトリ基準の相対パスであり、`install.sh --claude` / plugin（Claude marketplace）/ Codex の **3 経路とも配布対象外**（解決不可）。(1) 導入先リポジトリの同名パスを探す → (2) 見つからなければ **「正本 `<path>` を参照できなかった」と明示**し、本ドキュメント内の記述を代替正本として扱い、推測で内容を補わない。**plugin root 配下の探索は `docs/**` には適用しない**: plugin が配布するのは `agents` / `commands` / `skills` / `rules` 等の定義ディレクトリのみで `docs/` を配布対象として認識せず、plugin root 配下に相当する配布物が存在しないため、plugin root 段を置いても必ず空振りする（クラス A の rules 参照が plugin root 配下で解決できるのは `rules/` が実際に配布されるからであり、この非対称を `docs/**` に持ち込まない）。

---

## 1. 位置づけ — なぜ flow フェーズの「前」に置くか

flow-detect.md §2 の flow フェーズは「変更対象ファイルが低リスク帯か」を判定する。
これは**変更内容**に対する判定であり、**指示（プロンプト）そのものの停止可能性**は
判定していない。「完璧になるまで改善し続けろ」のような指示は、変更対象が
`boundary=clean` かつ `lite=true` であっても、flow に乗った後の反復（Generate →
Evaluate → Remember → Schedule → Optimize → Recurse サイクル）が終端に到達しない
リスクを持ち込む。

したがって本ゲートは flow-detect の判定軸を追加するのではなく、**flow に乗せる指示
自体の入場条件**として独立に置く:

```text
指示（プロンプト）
    ↓
[本書: loop-safety gates]  ← 非停止リスクの事前検出・再形成
    ↓ 通過
flow-detect.md §2 flow フェーズ（boundary / lite / class 判定）
    ↓
detect / escalate（既存）
```

いずれかのゲートで拒否された指示は、flow に進入させず「再形成された安全な指示」を
提案するか、feasibility 不能として人間に差し戻す（§3 参照）。

---

## 2. 危険パターン集

以下は非停止リスクを内包する典型的な指示パターンである。各パターンについて、
検出観点と再形成テンプレート（安全な書き換え）を定義する。

### P-1: 「完璧になるまで」型（無限改善）

- **例**: 「完璧になるまで改善して」「満足いくまで直して」
- **検出観点**: 終了条件が品質の絶対値（"完璧" "満足" 等の非測定可能語）にのみ
  依存し、反復回数・受入基準・時間の上限が明示されていない。
- **再形成テンプレート**:

  ```text
  最大 3 改善サイクルまで実行する。
  各サイクルで [具体的な受入基準] を満たすか判定する。
  3 サイクル後も未達なら停止し、未達項目・根本原因・次の選択肢を報告する。
  ```

### P-2: 「全可能性を列挙」型（組み合わせ爆発）

- **例**: 「全ての組み合わせを列挙して」「あらゆるケースを網羅して」
- **検出観点**: 列挙対象の母集団に上限が示されていない（無限または実質非有界）。
  探索対象（source 数・設計案数・レビュー観点数・調査対象ファイル数）が
  budget 化されていない。
- **再形成テンプレート**:

  ```text
  最大 5 件の情報源、3 件の設計案、7 件のレビュー観点までを対象とする。
  それ以上必要と判断した場合は、拡大理由を示した上で人間に budget 拡張を確認する。
  ```

### P-3: 「矛盾を認めず解消」型（偽の統合）

- **例**: 「矛盾する要件をすべて満たして」「制約を変えずに矛盾を解消して」
- **検出観点**: 提示された制約集合が論理的に同時充足不能、またはその可能性が
  事前に検証されていない。「矛盾を認めない」という指示自体が診断モードへの
  切り替えを禁止している。
- **再形成テンプレート**:

  ```text
  実行前に制約の同時充足可能性を検証する。
  矛盾が見つかった場合は実行せず、以下を報告する: 矛盾する制約の組・矛盾の理由・
  解消のための制約変更案（複数）。制約変更の採否は人間が判断する。
  ```

### P-4: 「通るまで最初から再試行」型（無制限リトライ）

- **例**: 「通るまで最初からやり直して」「パスするまで繰り返して」
- **検出観点**: リトライ回数の上限が明示されていない。失敗時に「同じアプローチの
  繰り返し」か「アプローチ変更」かが区別されていない（同一失敗の反復は非停止の
  典型形）。
- **再形成テンプレート**:

  ```text
  最大 2 リトライサイクルまでとする。
  1 回目と同じ失敗が再発した場合はアプローチを変更する。
  2 回目も失敗した場合は停止し、失敗理由と次の選択肢を報告する（同じ手順の
  3 回目の反復は行わない）。
  ```

### P-5: 「衝突する全制約を満たせ」型（実行不能な目標）

- **例**: 「予算・期限・品質のすべてを最大化して」「トレードオフなしで両立させて」
- **検出観点**: 目標が測定可能な単一（または優先順位付きの複数）の基準として
  定義されていない。トレードオフの存在自体を指示が否定している。
- **再形成テンプレート**:

  ```text
  目標に優先順位を付ける（例: 品質 > 期限 > 予算）。
  優先順位下位の基準が満たせない場合は、そのトレードオフを明示して報告し、
  人間の判断を仰ぐ（無条件の同時最大化は行わない）。
  ```

---

## 3. 5 ゲート

flow 進入前に、以下 5 ゲートをこの順で通過確認する。**いずれか 1 つでも
通過しない場合は flow に進入させず、再形成案または feasibility 不能報告を返す。**

### Gate 1: explicit stop condition（terminal state への到達可能性）

- **確認内容**: 指示（または生成した実行計画）が、[`decision-table.md`](./decision-table.md)
  の terminal state（`AUTO_APPROVED` / `HUMAN_ESCALATED` / `BLOCKED`）のいずれかに
  有限回の反復で到達できる終了条件を持つか。
- **判定不能時**: I-4（安全側デフォルト）に従い、到達可能性が確認できない場合は
  flow に進入させず human escalate 相当として扱う。

### Gate 2: feasibility check（制約矛盾の事前検出）

- **確認内容**: 提示された goal と制約が同時に充足可能か。
- **矛盾検出時の扱い**: **矛盾を解消しようとせず**、矛盾自体を人間に提示する
  （I-4 の安全側デフォルトと同様、AI が「矛盾を解消したことにする」ことを禁止する）。
  提示形式は §4 failure reporting format に従う。

### Gate 3: budget limit（ラウンド上限・探索資源の soft cap）

- **確認内容**: 反復回数・探索対象数に upper bound が設定されているか。
- **既存正本の参照（再定義しない）**: PR 後の指摘対応ループの対応ラウンド上限
  （**3 ラウンド**）は [`00_concept.md`](./00_concept.md) §「収束ルール」/
  [`adaptive-production-loop.md`](./adaptive-production-loop.md) の terminal state
  遷移表が正本。escalate 予算（severity 別の昇格上限・サーキットブレーカー連動）は
  [`arbiter-policy.md`](./arbiter-policy.md) §7 /
  [`decision-table.md`](./decision-table.md) §6 が正本。本ゲートはこれらの値を
  変更・再宣言せず、「budget が設定されていること」自体の存在確認のみ行う。
- **budget 未設定の指示**: §2 の再形成テンプレートに従い soft cap を注入して
  再提示する。

### Gate 4: contradiction detection（矛盾検出）

- **確認内容**: Gate 2 の feasibility check で検出された矛盾を、実行フェーズに
  持ち込む前に diagnosis mode（診断報告）へ切り替えているか。
- **禁止事項**: 「矛盾を認めない」「制約を変えずに解決する」という指示に従って
  fake な統合解を生成すること。矛盾があるにもかかわらず単一解を提示する出力は
  本ゲートの違反として扱う。

### Gate 5: failure reporting format（失敗報告の定型）

- **確認内容**: Gate 1〜4 のいずれかで停止・未達となった場合、報告が §4 の
  定型に従っているか（「未達 + 理由 + 次の選択肢」の欠落がないか）。

---

## 4. failure reporting format（定型）

Gate 1〜4 のいずれかで停止した場合、以下の定型で報告する。この定型は
`decision-table.md` の provenance 記録とは別レイヤー（loop-safety gate 自身の
出力形式）であり、provenance フィールドを再定義しない。

```text
[問題のある指示]: <元指示の該当部分>
[該当ゲート]: Gate 1-5 のいずれか
[未達/矛盾の内容]: <何が達成できないか、または何と何が矛盾するか>
[理由]: <なぜ非停止・実行不能と判定したか>
[安全な代替案]: <§2 の再形成テンプレートに基づく書き換え案>
[推奨される stop condition]: <最大反復回数・budget・判定基準>
```

---

## 5. unsafe → safe 変換の例

**unsafe（元指示）**:

> このコードが完璧になるまで改善し続けて。全部のエッジケースを考慮して、
> 矛盾する要求があっても両方満たすように何とかして。

**safe（変換後）**:

> 最大 3 改善サイクルまで実行する。各サイクルで [受入基準] を満たすか判定する。
> エッジケースは budget 上限 7 件までを対象とする。要求間に矛盾が見つかった場合は
> 解消しようとせず、矛盾する要求の組・理由・解消のための選択肢を報告し、
> 人間の判断を仰ぐ。3 サイクル後も未達なら停止し、未達項目と次の選択肢を報告する。

---

## 6. 既存正本との不整合防止（再定義しない事項の一覧）

本書は以下を**再定義しない**。値・機構の変更が必要になった場合は、当該正本の
版上げ手続き（[`design-philosophy.md`](./design-philosophy.md) §6.2）に従う。

| 事項                                           | 正本                                                                                                |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| 対応ラウンド上限（3 ラウンド）・terminal state | [`00_concept.md`](./00_concept.md) / [`adaptive-production-loop.md`](./adaptive-production-loop.md) |
| escalate 予算・severity 別の昇格上限           | [`arbiter-policy.md`](./arbiter-policy.md) §7                                        |
| サーキットブレーカー（CB-1〜CB-3）             | [`decision-table.md`](./decision-table.md) §6                                                       |
| boundary / lite / class 判定                   | [`flow-detect.md`](./flow-detect.md) §2                                                             |
| provenance スキーマ                            | [`decision-table.md`](./decision-table.md) §5                                                       |

---

## 7. 関連ドキュメント

- [`design-philosophy.md`](./design-philosophy.md) — I-6（本ゲートの思想的根拠）・§8 トリアージ（#728 の仕分け結果）
- [`flow-detect.md`](./flow-detect.md) — 本ゲートの直後に発火する flow フェーズ（参照のみ、変更なし）
- [`00_concept.md`](./00_concept.md) — 対応ラウンド上限・収束ルールの正本
- [`adaptive-production-loop.md`](./adaptive-production-loop.md) — 1 サイクル contract（Goal/Evaluate/Stop/Memory/Schedule/Boundary）
- [`arbiter-policy.md`](./arbiter-policy.md) — escalate 予算の正本
- [`decision-table.md`](./decision-table.md) — terminal state・サーキットブレーカーの正本
- [`stop-rollback.md`](./stop-rollback.md) — Gate 1〜5・対応ラウンド上限を「stop 条件」として横断集約し、AUTO_APPROVED 後の事後 reject 巻き戻し手順を扱う（EPIC #822 項目4。§6 と同じく本書は再定義しない）
- issue [#728](https://github.com/s977043/plangate/issues/728) — 本書の起源
