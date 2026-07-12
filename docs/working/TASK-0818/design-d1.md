# TASK-0818 D-1 設計: ai-loop Triage discovery（HOTL 化の最後の一手）

> 親: #822（HITL→HOTL EPIC）/ #818。承認済み範囲: D-3 Gate 接続まで（Human 決定 2026-07-11）。
> 不変条件: discovery は**候補提示まで**・着手は必ず既存 Gate を通す（bypass しない）。merge/HO/重大は Human。

## Goal

issue キューを走査して「ai-loop で自動着手してよい低リスク候補」を**スコアリングして提示**する。
着手の実行判断は既存 arbiter/品質ゲート（#817/#820/#813）が行う（discovery は選別のみ）。

## 段階（承認済み D-3 まで）

| Slice | 内容 | 自律度 |
|---|---|---|
| **D-1** | 本設計（IF・スコア基準・Gate 接続点・安全境界） | doc のみ |
| **D-2** | `discovery.py`（read-only 候補提示 CLI）。issue データ → スコア → 候補リスト。**着手しない** | 提示のみ |
| **D-3** | 候補 → 既存 Gate 接続（top 候補を ai-loop cycle へ。lite/clean は AUTO_APPROVED まで） | Gate 経由 |

## D-2 の設計（read-only・純関数・テスト可能）

### 入力（ネットワーク非依存・テスト可能にするため issue データを input で受ける）

```
python3 scripts/ai-loop/discovery.py --issues <path.json> [--label ai-loop-auto] [--format md|json] [--ho-paths <path>]
```
`--issues` は issue 配列 JSON（`gh issue list --json number,title,labels,body` 相当）。gh 直叩きは薄い wrapper に分離（discovery.py 自体は入力を受けるだけ＝決定論・テスト可能）。

### スコアリング基準（すべて判定可能な形）

各 issue を候補として評価。**opt-in ラベル必須**（無ければ候補外）:

| 基準 | 候補条件 | 根拠 |
|---|---|---|
| opt-in ラベル | 指定ラベル（既定 `ai-loop-auto`）を持つ | 明示 opt-in のみ自動対象（暴走防止） |
| HO 非接触見込み | issue body/title が HO パス（ho-paths.md）を示唆しない | 承認境界は自動着手しない |
| 規模見込み | body に「小」「1 ファイル」等の lite シグナル / 大規模語（アーキ変更・横断）が無い | lite 帯のみ |
| 依存解決 | body に「blocked」「depends on #」の未解決依存が無い | 着手可能なもののみ |

- スコアは各基準の bool を集約（全満たし=candidate / 一部欠落=excluded・理由付き）
- **無言除外禁止**: 除外 issue も理由付きで出力（監査可能性）
- **stop 条件**: candidate ゼロなら「候補なし」を出力し exit 0（無限探索しない）

### 出力（md/json 両形式）

- candidates: [{number, title, score_reasons, recommended_next}]（recommended_next は「ai-loop cycle へ / human triage へ」の提案のみ・**実行しない**）
- excluded: [{number, reason}]（無言除外禁止）
- summary: candidate 数 / excluded 数 / opt-in ラベル無し数

### 安全不変条件（D-2）

- **read-only**: git 操作・exec・issue 変更を一切しない（提示のみ）
- discovery は Gate を bypass しない（着手判断は D-3 で既存 arbiter に委ねる）
- opt-in ラベルの無い issue は候補にしない（既定で全 issue を対象にしない）

## D-3（後続）: Gate 接続

top candidate を ai-loop cycle（execution-runbook）へ渡す。arbiter が touches-HO/lite 不適合/品質ゲート未充足なら escalate。**discovery が escalate を skip する権限は持たない**。AUTO_APPROVED は MERGE_READY まで、merge は Human。

## Testing（D-2）

- opt-in ラベル有り + lite シグナル + HO 非接触 + 依存解決 → candidate
- ラベル無し → 候補外（excluded 理由=no-optin-label）
- HO 示唆（body に scripts/hooks 等）→ excluded 理由=ho-risk
- 大規模語（アーキ変更）→ excluded 理由=not-lite
- 未解決依存（depends on #123 が open）→ excluded 理由=dependency
- candidate ゼロ → 「候補なし」exit 0
- excluded が理由付きで全件出力される（無言除外なし）

## Mode

D-2 = standard（新規 read-only script・ファイル 2）。承認境界非接触。
