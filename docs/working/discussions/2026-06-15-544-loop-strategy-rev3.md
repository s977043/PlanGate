# #544 Loop 安全制御 — 戦略 rev.3 ドラフト（3者レビュー反映）

> **Status**: rev.3 **ドラフト**（2026-06-15）。正本 [`2026-06-12-544-loop-safety-controls.md`](./2026-06-12-544-loop-safety-controls.md)（rev.2・マージ済）を**置き換えるものではなく、次回改訂の入力**。
> **基づく入力**: 3者レビュー = Claude セルフレビュー + Codex(gpt-5.5) + Gemini。
> **対象 issue**: [#544](https://github.com/s977043/plangate/issues/544) / 関連 #543 / #487 / #493 / #529

---

## 0. この rev.3 が追加する核心

rev.2 は「何を取り込むか（Verification / Stop / Replan）と責務分離」を確立した。
rev.3 は3者レビューで一致した**2つの急所**を埋める:

1. **Phase 1 単独は「制御の実装」でなく「制御点の明文化」**（過大評価の禁止）
2. **暴走検知を AI の自己申告に置かない**（機械トリガーの併用）

> Gemini: 「AI が"今まさに発散している最中"にそれを論理的に認識するのはハルシネーションの一種」。
> Codex: 「Critical-1/2 は #544 の成否を分ける論点」。

---

## 1. 3者レビュー 収束サマリ

| 指摘 | Claude | Codex | Gemini | 収束 |
|------|--------|-------|--------|------|
| Phase 1 はソフト強制＝過大評価リスク | 🔴 | ✅ | ✅ | **完了定義を弱め honest framing** |
| Replan trigger 自己申告の限界 | 🔴 | ✅最重要 | ✅最重要 | **機械トリガー併用（実行層で監視）** |
| Loop Log が実は中核 | 🟠 | ✅ | ✅ | **Phase 1 に最小ログを繰り上げ** |
| Loop の定義が暗黙 | 🟠 | ✅ | — | **§2.1 で定義** |
| Verification 強化の具体未決 | 🟡 | ✅ | ✅ | **追加検証項目まで落とす** |
| 成功指標なし | 🟡 | — | ✅(コスト) | **#529 計測 + コスト指標** |
| **Resume Condition（新）** | — | ✅ | — | **停止後の再開条件を追加** |
| **Revert 手順（新）** | — | — | ✅ | **停止後の戻し基準を追加** |
| **経済的ガードレール（新）** | — | — | ✅ | **token 発散をコスト面でも防ぐ** |

---

## 2. rev.2 からの変更点

### 2.1 Loop の定義（Major-2 / 新設）

本戦略が制御対象とする "Loop" を明示する:

> **制御対象の Loop** = 単一 PBI の exec フェーズ内で発生する **(a) 検証失敗 → 自己修正の反復**、
> および **(b) autonomous 実行下での plan 逸脱の累積**。
> 複数 PBI をまたぐ自律マルチタスクの反復予算は **#487（Risk Budget）** の領域とし、本戦略は単一 PBI 内に限定する。

### 2.2 Phase 1 の honest framing（Critical-1）

- ❌「Loop 安全制御を導入」
- ⭕「Loop 安全制御に必要な **plan 記述欄と記入チェック**を導入」（強制は Phase 2 / #543）
- Phase 1 の成果物に **`Phase2 Gate化 #543 に接続済`** を必須記載
- #543 に **owner / milestone / strict 化対象** を確定（宙づり防止）

### 2.3 機械トリガー（Critical-2 / 新設）

Replan / 停止判断を **AI の内省に依存させず**、実行層（`scripts/codex-guarded.sh` / `bin/plangate doctor` 相当）で観測可能な**機械トリガー**を併用する。最小セット:

| トリガー | 閾値（既定・plan で上書き可） |
|---------|------------------------------|
| 変更ファイル数の超過 | plan 想定の **2倍** または **+5 files** |
| 同一検証コマンドの連続失敗 | **3 回** |
| 同一ファイルへの修正反復 | **3 回** |
| plan 外ディレクトリへの波及 | 1 件でも検知 |
| AC / verification コマンドの変更 | 検知時 |

- Phase 1 では hard gate でなく **「Replan 必須表示」または「C-1 チェック失敗」** として作用（強制化は Phase 2）。
- 閾値は plan の `Replan Triggers` に**定量記述**し、バリデータが読める形式にする（Gemini: 物理バリデータが読み取れる Markdown 属性等）。

### 2.4 Loop Log を Phase 1 へ（Major-1）

Phase 3 を待たず、**最小ログ欄**を Phase 1 の plan / status に含める（「同じ失敗を N 回」検知の前提）:

```md
Loop Attempts:
- attempt:
- changed:
- verification:
- result:
- next decision: continue / replan / stop
```

接続先（status.md 逐次記録 vs decision-log 拡張）の確定は Phase 3 だが、**欄の存在**は Phase 1 で導入。

### 2.5 Resume Condition（Codex / 新設）

Stop Condition だけでは「停止後、何を満たせば再開できるか」が曖昧。1行で補う:

```md
Resume Condition: stop 後に再開するには、原因・修正方針・検証手順を plan に追記し、Replan 判定を通す。
```

### 2.6 Revert 手順（Gemini / 新設）

停止後の「どこまで戻すか」を定義（今日の作業ツリー後片付け規範と整合）:

```md
Revert Policy: 停止時、Scope 外へ波及した変更は revert する。汚染ワークツリーは
`git stash`/`git checkout -- <path>` でクリーン化し、Scope 内の検証済み変更のみ残す。
（破棄前に「自分が作った/名指しされた変更か」を確認＝既存の破棄前チェックリスト準拠）
```

### 2.7 経済的ガードレール（Gemini / 新設）

Loop 発散は token 課金急増を招く。安全制御を**コストガードレール**としても位置づけ、機械トリガー（特に連続失敗・反復回数）超過時は**停止を既定**とする。成功指標（§4）に token / turn 消費を含める。

---

## 3. 更新後の plan 記述スキーマ（Phase 1）

```md
## Testing Strategy
### Verification Automation
（実行コマンド。プロジェクト固有値は各 CLAUDE.md が注入 / Rule 4）

## Loop Scope        ← 新（§2.1：制御対象の Loop を1文で）
## Stop Condition    （rev.2 既存）
## Resume Condition  ← 新（§2.5）
## Replan Triggers   ← 機械トリガーを定量記述（§2.3）
## Revert Policy     ← 新（§2.6）

Loop Attempts:       ← 最小ログ欄（§2.4）
```

C-1 拡張: 空欄チェックに加え、**`Replan Triggers` に機械トリガーが1つ以上記入されているか**を必須化。

---

## 4. 更新後の段階導入

| Phase | 内容 | 担当 | rev.3 変更点 |
|-------|------|------|-------------|
| **Phase 1** | plan 記述欄（Loop Scope/Stop/Resume/Replan Triggers(機械値)/Revert/Loop Attempts 最小ログ）+ C-1 記入&機械トリガー記入チェック | #544 | **Loop Log 最小版を繰上げ・機械トリガー定量化・honest framing** |
| **Phase 2** | 未記入/閾値超で承認不可（strict Gate）+ 実行層監視（codex-guarded.sh / doctor） | **#543** | **owner/milestone 確定を前提条件化** |
| **Phase 3** | Loop Log 接続先の確定・拡充 | 別 issue | （欄自体は Phase 1 済） |
| **Phase 4** | Risk Budget・自律度・複数 PBI 反復予算 | **#487** | Loop 定義の境界（§2.1）と接続 |

**成功指標（§2.7 / #529 dogfooding 接続）**: replan 発火回数 / scope 逸脱検知数 / 連続失敗回数 / 1 PBI あたり token・turn 消費。

---

## 5. 未決事項（rev.3 更新）

- [ ] 機械トリガーの実装先確定: `codex-guarded.sh`（exec ラッパ）か `bin/plangate doctor` 拡張か、両方か
- [ ] 閾値の既定値（2倍/+5/3回）の妥当性を dogfooding で校正
- [ ] Loop Attempts ログの接続先（status.md 逐次 vs decision-log 拡張・append-only schema 制約）
- [ ] #543 の owner / milestone（Phase 2 強制化の責任者）
- [ ] mode 判定: working-context.md(HO) を編集対象に含むため **lite_eligible=false + Standard 同期 C-3 固定**（rev.2 と不変）

---

## 6. 反映フロー

本ドラフトは**討議メモ**。正本 rev.2 への rev.3 マージは、内容合意後に別 PR で実施（編集対象に working-context.md(HO) を含むため Standard 同期 C-3 固定）。

## 7. 一行サマリ

> rev.3 = rev.2 に **「Phase 1 は明文化であって強制でない」** と **「暴走検知は機械トリガー併用（自己申告に頼らない）」** を足し、
> Loop 定義・最小 Loop Log・Resume/Revert/コストガードレールを追加。強制化（#543 owner 確定）と機械トリガー実装先が次の論点。
