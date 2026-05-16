---
task_id: TASK-0071
artifact_type: design-note
schema_version: 1
status: draft
scope: S3a
---

# S3a 設計 note — EH-3 バイパス不要化（C-3 D-2 別途承認対象）

> 目的: heredoc 回避を「正当な作業手段」化する。SKIP/メンテは新バイパス経路に
> しない。plan.md の C-3 ハッシュ強制（最重要不変条件）は一切弱めない。

## 1. 課題再確認

EH-3 は TASK 文脈なしで Edit を阻む（P4(d) で plan.md 以外は SKIP に緩和済）。
だが「TASK 文脈を持てない正当な保守作業」（例: hook 自体の修正、settings
適用前の整備）では依然 heredoc 等の回避が誘発される。Gemini 指摘: 監査だけでは
AI が"正当に見える理由"を生成し回避継続 → バイパス自体を不要化する設計が必要。

## 2. 設計案（3 案比較）

| 案 | 概要 | 長所 | 短所/リスク |
|----|------|------|------------|
| **A 有効期限付きメンテモード** | `PLANGATE_MAINTENANCE_UNTIL=<epoch>` が未来かつ監査記録ありで EH-3 を SKIP（plan.md は除外＝常に BLOCK） | 時間境界が明確、自動失効、bypass と別系統 | 期限延長の濫用。付与権限の管理が必要 |
| **B ハッシュ除外タグ** | 対象ファイル先頭に `# plangate:hash-exempt TASK-XXXX 理由` がある場合のみ SKIP | ファイル単位で粒度細かい、理由が diff に残る | タグ自体を AI が付け回避し得る。除外乱用 |
| **C SKIP_REASON 必須 + 事後追認のみ** | メンテ概念なし。SKIP 時 reason 強制記述→C-3/C-4 で人間追認 | 最小実装・低リスク | heredoc 不要化は部分的（依然ブロックされる場面が残る） |

## 3-bis. C-2 外部レビュー反映（Codex+Gemini critical、必須修正）

> review-external.md 参照。現案 A+C の方向は妥当だが、以下を反映しないと
> 「heredoc 回避」を「env による正規バイパス」に置換するだけになる。

- **CR-1 メンテ付与は env 廃止 → 検証可能な承認アーティファクト**:
  `PLANGATE_MAINTENANCE_UNTIL` env は使わない。人間が手動生成する承認ファイル
  （例: `docs/working/TASK-XXXX/approvals/maintenance.json`、構造化:
  `{task_id, scope, until(epoch UTC), reason, approved_by}`）を doctor/CI が
  検証。AI が当該ファイルを生成・改変する行為自体を EH/doctor でブロック。
- **CR-2 bypass 降格 + SKIP は記録のみ**: plan.md 保護では `PLANGATE_BYPASS_HOOK`
  を無効化 or CI required failure。SKIP_REASON は hook 側では machine-readable
  event を残すだけ。人間の署名追認まで CI を green にしない外部承認を強制。
- 正規化（大小文字/末尾空白/`./`/JSON decoy）を **メンテ判定の前**に適用。
- メンテ失効はソフトランディング（進行 turn 猶予・新規 turn 禁止・5分前警告）。
- drift check は値 + 権限(chmod)/所有者も対象。

これにより当初の「優先順 bypass>メンテ>通常」と「env でメンテ成立」「reason
文字列で SKIP 成立」は **撤回**。承認アーティファクト方式へ置換する。

## 3. 推奨（C-2 反映後）

**A（メンテモード）+ C（SKIP_REASON 必須）の併用**。B は除外タグ自体が
AI 自己付与で回避経路化するため不採用（Gemini「バイパス不要化」の趣旨に反する）。

- **A の安全条件（必須）**:
  - 対象が `*/plan.md`/`plan.md` の場合はメンテモードでも **必ず BLOCK**（E1 不変条件）
  - `PLANGATE_BYPASS_HOOK` > メンテモード > 通常強制 の優先順（E2）
  - 既定有効期限: **30 分**（短く。延長は再付与で監査が増える設計）
  - 付与権限: 人間が settings 適用と同じ Human-owned 操作として実行（AI は要求 only）
  - メンテ突入/失効/SKIP を `_audit` に machine-readable イベントで記録
- **C の条件**: SKIP 時 `SKIP_REASON` 環境変数 or todo.md 記述が空なら SKIP せず停止。
  reason は decision-log.jsonl に append、C-3/C-4 で人間が追認した証跡を必須化。

## 4. C-3 で確定が必要な事項（D-2 / C-2 収束見解付き）

C-2（Codex+Gemini）の収束した推奨回答:
1. 既定30分=可。**最大30分・延長は別承認・同一理由連続延長は警告/失敗**
2. メンテ付与は Human-owned 固定 + **env 廃止し検証可能な承認ファイル方式**、CI 自動付与禁止
3. **SKIP_REASON 未追認 PR は required failure（必須）**

人間は上記 3 点を承認 / 修正する形で C-3 を確定する。

### 旧 質問（参考・C-2 で方向確定済み）

1. 既定有効期限 30 分で可か（延長運用の許容範囲）
2. メンテ付与権限の主体（Human-owned 固定でよいか／CI からの自動付与は禁止か）
3. SKIP_REASON 未追認のまま PR を出した場合の CI 挙動（required failure とするか）

## 5. テスト方針（S3b で実装）

- TC-8/9（メンテ有効/失効）, TC-10/11（SKIP_REASON 強制）に加え:
  - メンテモード中でも plan.md は BLOCK（E1 回帰）
  - bypass > メンテ > 通常 の優先順（E2 回帰）
  - 失効後に監査ログへ EXPIRE イベントが残る

## 6. 関連

- 親 plan: docs/working/TASK-0071/plan.md（S3）
- 方針出典: docs/working/TASK-0070/direction-codex-gemini.md（G2/G4）
