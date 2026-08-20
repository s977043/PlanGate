# lite-criteria — lite 判定基準

> 適用ドメイン（Phase 1）: ①plangate 本体 = docs/workflows/ai-loop/ 配下のみ（dogfooding 域・本番フロー WF-00〜07 非適用）
> ②導入先リポジトリ = ho-paths 確定 + LoopSpec scope.allowed_paths 宣言を前提に適用可
> lite 基準の制定・改版は policy 扱い（第0の承認境界 =
> [`arbiter-policy.md`](./arbiter-policy.md) §6、Human-owned 固定）。
> AI は基準改定の draft 提案までしか行えず、発行・適用は人間が行う

---

## 参照解決順（`docs/**` / 導入先で必ずこの順に探す）

本ドキュメントが参照する `docs/**` は上流リポジトリ基準の相対パスであり、`install.sh --claude` / plugin（Claude marketplace）/ Codex の **3 経路とも配布対象外**（解決不可）。(1) 導入先リポジトリの同名パスを探す → (2) 見つからなければ **「正本 `<path>` を参照できなかった」と明示**し、本ドキュメント内の記述を代替正本として扱い、推測で内容を補わない。**plugin root 配下の探索は `docs/**` には適用しない**: plugin が配布するのは `agents` / `commands` / `skills` / `rules` 等の定義ディレクトリのみで `docs/` を配布対象として認識せず、plugin root 配下に相当する配布物が存在しないため、plugin root 段を置いても必ず空振りする（クラス A の rules 参照が plugin root 配下で解決できるのは `rules/` が実際に配布されるからであり、この非対称を `docs/**` に持ち込まない）。

---

## 1. 目的

ai-loop-workflow の flow フェーズにおける `lite` 軸（[`decision-table.md`](./decision-table.md)
§2）の判定基準を具体化する。`mode-classification.md`
の `lite_eligible` 判定軸（PlanGate 本番向け）を継承しつつ、PoC 用に単純化し、
**可逆性要件**を追加する。

`docs/ai/ai-loop/phase3-impact-report.md` §d リスク 1・2 を解消する成果物。

### 導入先 auto-approve 方針の注記（Phase 1 / issue #807）

issue [#782](https://github.com/s977043/plangate/issues/782) P1-2
（「実機能は常に escalate に帰結し auto-approve が実質到達不能」）への応答は、
Human 決定（issue [#807](https://github.com/s977043/plangate/issues/807)・
2026-07-10）により **「docs 級限定の明文化」案から「lite 全域（本ドキュメント
§2 の 4 軸を満たせば実機能も含む）」へ更新**された。`size_ok` の機械検証化
（issue [#780](https://github.com/s977043/plangate/issues/780) slice C で実装済み）は
「ファイル数閾値（`SIZE_OK_MAX_FILES`=2）と `changed_files` 実数の突合」という
最小形で実現された（当初想定した可逆性・パターン踏襲度を含む複合リスク
スコア化は見送り、申告制の保証を強化する最小の unlock に留めた。§2 の
「変更規模」欄・arbiter.py の `machine_size_check()` 参照）。他 3 軸
（新規設計の有無・既存パターン踏襲・可逆性）は引き続き申告制のまま。
AC-8 安全側（判定不能→false）・4 軸すべてを満たすことの要求は変更しない。

---

## 2. 判定軸

`lite=true` の候補となるには、以下 4 軸を**すべて**満たす必要がある。

| 軸 | lite=true 候補条件 | 継承元 |
| ---- | -------------------- | -------- |
| 変更規模 | `mode-classification.md` の light 相当以下（変更ファイル数 1〜2 目安）。**申告 `size_ok=true` は arbiter が `changed_files` 実数で機械検証する**（`SIZE_OK_MAX_FILES`=2 超過なら申告と実測の不一致として escalate。issue #780 slice C） | `mode-classification.md` 定量基準 |
| 新規設計の有無 | なし（既存構造の枠内） | `mode-classification.md` lite_eligible 判定軸 |
| 既存パターン踏襲 | あり（新規設計ゼロ・ミラー実装） | `mode-classification.md` lite_eligible 判定軸 |
| **可逆性** | 変更が可逆である（巻き戻し手順が機械的に実行可能。例: `git revert` 一発、ファイル単位の差し戻しで完全復元できる） | 本ドキュメントで新規追加（PoC 固有） |

### 可逆性要件の根拠

[`decision-table.md`](./decision-table.md) §6 CB-1（事後 reject）の巻き戻しは
「**可能な範囲で巻き戻し実行（不可逆操作を除く）**」と定義されている。

lite=true と判定された変更は flow フェーズを通過し、事前ブロックなしで
detect フェーズへ進む（[`00_concept.md`](./00_concept.md) の on-the-loop
モデル）。もし不可逆な変更が flow に流れ、後から人間が事後 reject した場合、
CB-1 の巻き戻しが「不可逆操作を除く」制約により**巻き戻せない**という
構造的な穴が生じる。

可逆性を lite=true の必須要件とすることで、この穴を構造的に排除する。
不可逆な変更は lite=false（human escalate）へ落ち、実行前承認（in-the-loop
相当）を経由するため、事後 reject 時の巻き戻し不能リスクを負わない。

**不可逆操作の例**（該当すれば可逆性要件を満たさない）:

- 外部公開操作（tag push・release publish・対外通知）
- データ削除・破壊的マイグレーション
- 課金・決済など外部システムへの副作用を伴う操作
- 一度公開すると取り消せない性質のもの（社外送信済みメール等）

---

## 3. AC-8 安全側（判定不能時の既定）

`mode-classification.md` の `lite_eligible` AC-8 安全側不変条件を継承する。

**いずれかの軸が判定不能・根拠不足・曖昧な場合は、必ず `lite=false`
（human escalate）とする。**

対象:

- 変更規模が light 相当か判定できない
- 新規設計の有無が曖昧
- 既存パターン踏襲の有無が判定できない
- **可逆性が判定できない、または巻き戻し手順が明示されていない**

lite は「証明可能なときだけの例外」であり既定ではない。判定不能を lite=true
側に倒すことは決して行わない。

---

## 4. 判定アルゴリズム

```pseudocode
入力: 変更内容（対象ファイルリスト・変更種別・巻き戻し手順の有無）
出力: lite = true | false

lite = true

// 軸1: 変更規模（申告 size_ok=true は arbiter.py が changed_files 実数で
// SIZE_OK_MAX_FILES=2 と機械突合する。申告と実測が不一致なら priority 1.9
// で human escalate — issue #780 slice C）
if not (変更規模 <= light相当):
    lite = false

// 軸2: 新規設計の有無
if 新規設計あり or 新規設計の有無が判定不能:
    lite = false

// 軸3: 既存パターン踏襲
if not 既存パターン踏襲 or 判定不能:
    lite = false

// 軸4: 可逆性（本ドキュメントで追加）
if not 可逆 or 巻き戻し手順が機械的に実行可能でない or 判定不能:
    lite = false

// AC-8 安全側: いずれかの軸が判定不能なら安全側(false)へ倒す
// （上記各分岐で既に判定不能ケースを false 側に含めている）

if lite == false:
    → human escalate（decision-table.md priority 2）
else:
    → class 判定へ進む（decision-table.md priority 3 以降）
```

---

## 5. 関連ドキュメント

- [`docs/workflows/ai-loop/decision-table.md`](./decision-table.md) — `lite` 軸を使う Decision table 本体
- [`docs/workflows/ai-loop/flow-detect.md`](./flow-detect.md) — flow フェーズでの `lite` 判定の位置づけ
- [`docs/ai/ai-loop/arbiter-policy.md`](./arbiter-policy.md) — §6 第0の承認境界（本基準の改版が Human-owned 固定である根拠）
- `phase3-impact-report.md` — §d リスク 1・2（本ドキュメントで解消）
- `mode-classification.md` — `lite_eligible` 判定軸・AC-8 安全側・AC-11 の継承元
