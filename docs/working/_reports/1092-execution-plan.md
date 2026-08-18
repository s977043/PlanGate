# #1092 bugfix 優先計画 — 残作業の実行計画

> 測定基点: `origin/main` = `3812e19` / 2026-08-18
> 検証: **Codex による敵対的レビュー済み**（major 5 件を反映。うち 1 件は反証して不採用）
> ⚠️ **本計画も鮮度を持つ**。base が動けば判定は変わる。着手時に該当行を再実測すること。**件数を契約値にしない。**

## 結論先行

**Phase 0 は完了し、P0 = 0 が達成されています。** 台帳 33 件のうち **CLOSED 4 / open 29**。

open 29 件のうち **AI が単独で main まで到達できるのは 4 件**、**patch 適用待ちが 7 件**、**設計判断待ちが 4 件**、**`PLANGATE_HOOK_TASK` セッションが必要なのが 12 件**、**close 判定のみが 2 件**です。

**律速は「実装能力」ではなく「AI が到達できるパスの狭さ」です。**

---

## Phase 0 の完了確認（実測）

| # | 項目 | 状態 | 根拠 |
|---|---|---|---|
| 0-1 | #1089 の hook 適用 | ✅ | CLOSED。`tests/fixtures/eh3-known-gap-1089.flag` 不在 |
| 0-2 | #1045 を close | ✅ | CLOSED |
| 0-3 | #1058 を #978 の duplicate として close | ✅ | CLOSED |
| 0-4 | v8.19.0 milestone の再割当 | ✅ | open 0 件 |

→ **AC-1（P0 が 0 件）達成。**

---

## 台帳 33 件 — **1 issue 1 行**（Codex Finding 5 反映）

> 前版は分類の合計が台帳と合わず、**#982 を 2 か所に、#960 を 2 か所に重複計上**し、**#1087 を落としていました**。本版は全数を 1 行ずつ列挙します。

| # | 区分 | ownership | 状態 / 次の 1 手 |
|---|---|---|---|
| 1045 | Phase 0 | — | ✅ CLOSED |
| 1058 | Phase 0 | — | ✅ CLOSED（#978 の duplicate） |
| 1089 | Phase 0 | — | ✅ CLOSED |
| 1079 | Phase 5 | — | ✅ CLOSED |
| **960** | 単発 | **分割** | 非 HO 分 ✅ 完了（#1118 / PR #1138）／**HO 11 ファイルは #1119 patch の適用待ち** |
| **954** | Phase 5 | **AI** | クラス C 是正済（`fix/954-class-c`）。**`references/*.md` に 2 件残るため close 条件から外す**（後述） |
| **982** | 単発 | **判断→AI** | 案 A/B/C の選択待ち。**案 B なら AI 完結可**（判断は Human） |
| **956** | Phase 5 | **判断→AI** | drift が **2 → 4 件に悪化**。`.codex` 独自節の去就判断が先 |
| 990 | Phase 4 | Human | patch `990-multibyte-var-patch.md`（PR #1128） |
| 1011 | Phase 3 | Human | patch `1011-v304-fail-open-patch.md`（PR #1129） |
| 997 | 単発 | Human | patch `997-947c-porcelain-patch.md`（PR #1130） |
| 984 | Phase 2 | Human | patch `984-wiring-check-gap-patch.md`（PR #1131） |
| 937 | Phase 2 | Human | patch `937-942-unwired-guard-patch.md`（PR #1132） |
| 1021 | Phase 4 | Human | patch `1021-ta09-isolation-patch.md`（PR #1133） |
| 1102 | 新規 | Human | patch `1102-1018-blocked-oneline-patch.md`（PR #1134） |
| 1018 | 単発 | Human | 同上 |
| **942** | Phase 2 | **判断** | **patch は存在しない。** 文書は「**前提の再検討が必要**」と結論しており、適用対象が無い |
| **1104** | 新規 | **判断** | 設計 3 点（PR #1136）。fail-open/closed ほか |
| **1101** | 新規 | **判断** | 是正案が **O(n²) でハングする**（未解決）。`feat/1101-ho-normalization` は未マージ |
| **1105** | 新規 | **判断** | 古い版の plan へ APPROVED を発行できる |
| 921 | Phase 4 | HOOK_TASK | `tests/extras/*.sh` ×45 |
| 947 | Phase 4 | HOOK_TASK | `tests/extras/` ta-42 / ta-25 / ta-54 |
| 975 | 単発 | HOOK_TASK | `apply-claude-settings.sh` |
| 978 | Phase 1 | HOOK_TASK | `arbiter.py`（統合先 #916） |
| 991 | Phase 3 | HOOK_TASK | `sync-plugin-plangate.sh` |
| 994 | Phase 3 | HOOK_TASK | `ta-26` |
| 1004 | Phase 3 | HOOK_TASK | `tests/extras/README.md` + 抽出規則 |
| 1009 | Phase 3 | HOOK_TASK | `sync-plugin-plangate.sh:380` 未 quote |
| 1010 | Phase 3 | HOOK_TASK | 経路1 guard の変異 2 種 |
| 1044 | Phase 4 | HOOK_TASK | **plan APPROVED 済・exec 未着手＝最低コスト** |
| 1057 | Phase 5 | HOOK_TASK | `marketplace.json` |
| 1086 | Phase 5 | HOOK_TASK | `.gitignore` |
| **1087** | Phase 2 | HOOK_TASK | 配布物検査 3 本が CI 未配線・2 本が rc=1（**前版で欠落**） |
| **863** | Phase 5 | **close 判定** | 項目 1/2/3 は #1122 で解消。項目 4（HO）のみ残 |
| **866** | Phase 5 | **close 判定** | 4 root × 2 skill が **byte 同一**。#1126/#1127 で解消済 |
| 963 | Phase 5 | close 判定 | #1123/#1125/#1126/#1127 で対応済（要確認） |
| 1081 | Phase 5 | HOOK_TASK | Slice 1（`commands/*.md` の skill 化 = HO） |

**合計 37 行 = 台帳 33 + 新規 4（#1101 / #1102 / #1104 / #1105）。**

---

## 新規に発見した事実

### 1. #960 は是正の **16 分後**に退行していた

```
88145a3e  09:13:37  #1118  是正 — 測定時点で 0 件
6640cdd   09:29:26  #1122  新節追加 → 「17 項目」が復活
```

**再導入を止める機械検査がありません。** 再発防止 patch を `960-recurrence-guard-patch.md` に提示しました。**その設計過程で最初の検査案が変異注入に失敗し、作り直しています**（詳細は同文書）。

### 2. #956 の drift が **2 件 → 4 件に悪化**

`.codex/skills/` は `sync-plugin-plangate.sh` の対象外で、**CI 配線が 0 件**のため増えても誰も気づきません。**単純な再同期は `.codex` 独自節を消すため不可**（#1118 も同じ理由で回避）。

### 3. #942 には **patch が存在しない**（Codex Finding 3）

`937-942-unwired-guard-patch.md` の表題自体が「**#942 は前提の再検討が必要**」です。**前版で「patch 適用待ち」に分類したのは誤り**でした。

### 4. #1101 の性能問題は **是正案の側**にある（Codex Finding 2 / **私の誤りの訂正**）

前版に書いた「現行実装が 4,000 文字で 59 秒（案 A で 94ms）」は **一次ソースが存在しない誤った数字**でした。実測では現行 main は約 23ms です。

一次記録（未マージの `8b604fe`）が示すのは逆で、**#1101 の是正案が導入する `_pg_fold_tolower` が O(n²)**です:

```
250 seg 大文字 (len=3009)    base 81ms  / patched 13,135ms
1 seg × 20,000 文字 大文字   base 97ms  / patched 10 分枠内で未完
```

**EH-3 に timeout が無いため、暴走は block ではなくハングになります。**

---

## 提案する着手順

```
【いま動かせる — AI-owned】
  #954（PR 準備中）→ #982 案 B（判断後）→ #956 drift（判断後）
      ↓
【Human 1 手で 7 件が閉じる — 他と独立に進められる】
  patch 7 本の適用（#1119 / #1128〜#1131 / #1133 / #1134）
      ↓
【境界を固める】
  #1101 の O(n²) 解消  →  #1104（Bash 経路）
      ↓
【レーンを広げる】
  #1135（AI-owned レーン）
      ↓
【HOOK_TASK 帯 12 件が AI-owned になる】
  #1044（plan APPROVED 済・最低コスト）から順に
```

### 根拠（**前版から変更**）

1. **#1101 → #1104**: 前版は「現行が遅いから」としましたが**誤りでした**。正しくは **「#1101 の是正案に未解決のハングがあり、それを Bash 全経路へ配線してはいけない」**。依存の向きは同じですが理由が違います。
2. **#1104 → #1135**: **境界を固めてからレーンを広げる。** 逆順だと穴が開いたまま可動域だけが広がります。
3. **patch 適用は他と独立**。7 件を一括で閉じられる唯一の手です。

> ⚠️ **1 と 2 は「必須の直列」ではなく「提案順」です**（Codex Finding 2）。#1104 の設計自体は #1101 と独立に進められ、**配線の実施のみ**が #1101 に依存します。

---

## 判断していただきたいこと（4 件）

| # | 判断 | 選択肢 |
|---|---|---|
| **#982** | `ai-loop` を CLI の正式サブコマンドにする予定はあるか | ある→案 A（HO patch）／ない→案 B（docs を実体へ）／保留→案 B 暫定形（**乖離を明記**。AI 完結可） |
| **#956** | `.codex/skills/plan-review-gate/SKILL.md` の独自節 36 行を `.agents` 正本へ昇格させるか、破棄するか | 昇格／破棄 |
| **#942** | patch が存在しない。前提（`fetch-depth` 指定なし）の再検討をどう扱うか | issue を書き直す／close する／そのまま |
| **#1104** | 抽出不能コマンドを fail-open / fail-closed どちらにするか他 2 点 | PR #1136 参照 |

### #982 で失うものの明示（Codex Finding 6 反映）

**案 B は単なる文言整合ではなく、「CLI 正式入口を作らない」という設計判断を docs 側で既成事実化します。**

#872 / #889 / #895 で Plan-first 束縛を **CLI 前提**で設計してきた経緯があります。案 B で失うのは:

- **正式入口としての UX**（`arbiter.py` の手動 JSON 組み立てが正規手順になる）
- **将来の契約点**（CLI があれば引数検証・Plan Package 束縛を CLI 側で強制できる）
- **導入先での再現性**（`scripts/` は配布対象外のため、導入先には手順しか届かない）

**「今 AI が書けるから案 B」は選定根拠として不適切です。** 到達可能性が設計判断を駆動する前例を作らないため、**案 A/C の棄却根拠を HO コスト以外で示せない場合は、案 B 暫定形（乖離の明記）を推奨します。**

---

## 本計画で意図的に扱わないもの

- **#1032（close 側の統制の機械化）の実装** — #866 が「直っているのに open」の実例を追加したが、実装は #1032 側
- **個別 issue の AC 変更** — 統合時の移管は Phase 内で扱う
- **`docs/working/TASK-*` / `discussions/` / `CHANGELOG` の記述** — 完了済みアーカイブであり遡及修正しない

## Codex の指摘で**採用しなかった**もの

**Finding 7（測定基点が古い）** — 反証しました。Codex は `origin/main` を `3cff485` と読みましたが、**それは本セッションで作った PR ブランチ `docs/960-regression-1122` の head** です。`origin/main` は `3812e19` で、本計画の基点と一致します。

Refs #1092
