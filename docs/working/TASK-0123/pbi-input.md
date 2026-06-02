# TASK-0123 PBI INPUT PACKAGE

## Context / Why

EH-3（check-plan-hash.sh）の maintenance.json 受理ロジックは、ファイルの「中身（schema 準拠 + 時刻 + 署名者名）」のみを検証し、「発行元（誰がどの経路で書いたか）」を検証しない。

AI が `Bash` ツールや `Write` ツールで直接 maintenance.json を書き込んでも `approved_by` フィールドに任意の文字列を置けるため、承認なしに Hardening Override 以外のパスへの書き込みを通過させることができる。

同様に、`approvals/c3.json` などの承認トークン系ファイルへの AI 直接 Write/Edit を物理的に block する仕組みが存在しないため、AI が承認境界を自己完結で突破できる経路が残っている。

2026-05-31 セッションで上記が実害化したことを受け、本 PBI で二重防御を実装する：

1. maintenance.json への HMAC 署名必須化（発行元検証）
2. 承認トークン系 path への AI 直接 Write/Edit を決定論 PreToolUse ガードで block

### ビジネス価値

- 承認境界の核心的な迂回経路を閉じる
- AI が自ら承認トークンを書き換えて承認境界を突破することを構造的に不可能にする
- セキュリティ体制の信頼性・監査可能性を向上させる

---

## What (Scope)

### In scope

1. **maintenance.json HMAC 署名必須化**
   - `bin/plangate maintenance start` 時に `openssl dgst -hmac "$PLANGATE_MAINTENANCE_KEY"` で署名フィールド (`hmac_sha256`) を生成し JSON に付与
   - EH-3 (`scripts/hooks/check-plan-hash.sh`) が署名検証を実施。鍵未設定 or 署名なし or 不一致 = fail-closed（block）
   - 鍵は環境変数 `PLANGATE_MAINTENANCE_KEY`（git 非追跡・human が設定）
   - `schemas/maintenance.schema.json` に `hmac_sha256` フィールド追加（required）

2. **承認トークン系 path への AI 直接 Write/Edit block**
   - 新規 hook `scripts/hooks/check-approval-token-write.sh`（PreToolUse）
   - 対象 path パターン:
     - `docs/working/_maintenance/maintenance.json`
     - `**/approvals/*.json`（c3.json, c4.json 等）
   - path ベースで決定論 block（bypass なし・maintenance 窓でも block）

3. **CI 検出**
   - `.github/workflows/` に「AI プロセス系譜由来 / 自己署名の maintenance.json 検出」job を追加
   - 署名フィールド有無・鍵照合（CI 環境用シークレット）で fail

4. **テストスクリプト**
   - `tests/extras/ta-25-maintenance-hmac.sh`（HMAC 署名検証・block テスト）
   - `tests/extras/ta-26-approval-token-guard.sh`（承認トークン path block テスト）

5. **パッチスクリプト**（Human が apply）
   - `scripts/apply-task-0123-patches.sh`：全 HO ファイルへの変更を patch 形式で適用
   - `docs/working/TASK-0123/patches/` に個別 `.patch` ファイルを配置

6. **ドキュメント**（非 HO 部分）
   - `docs/working/TASK-0123/` 配下の計画・todo・テストケース

### Out of scope

- 既存承認境界（C-3 同期 / HO 9 カテゴリ）の緩和
- maintenance CLI の運用性仕様変更（window 時間上限・allowed_paths 仕様）
- L1〜L4 多層防御の仕様変更
- c3.json 以外の承認フロー変更
- HMAC 鍵のローテーション・配布基盤の整備

---

## 受入基準

| # | 条件 | 検証方法 |
|---|------|---------|
| AC-1 | AI が Bash で直接書いた maintenance.json（`hmac_sha256` フィールドなし / 鍵不一致）が EH-3 で exit 2 となり block される | `tests/extras/ta-25-maintenance-hmac.sh` |
| AC-2 | `bin/plangate maintenance start`（人間 TTY 経由 + 鍵設定済み）が発行したトークンは EH-3 を通過する（既存正規フロー不変） | `tests/extras/ta-25-maintenance-hmac.sh` |
| AC-3 | `docs/working/_maintenance/maintenance.json` および `**/approvals/*.json` への Write/Edit ツール呼び出しが `check-approval-token-write.sh` により exit 2 で block される | `tests/extras/ta-26-approval-token-guard.sh` |
| AC-4 | CI workflow が AI 系譜由来 / 自己署名（`hmac_sha256` なし）の maintenance.json を含む commit で fail する | GitHub Actions workflow で確認 |
| AC-5 | 既存の正規フロー（人間 c3.json 発行・人間 maintenance 窓）に回帰がない（`ta-12-maintenance.sh` の全 PASS が維持される） | `tests/run-tests.sh` |
| AC-6 | hook / CLI 判定にユニットテストがあり `sh tests/run-tests.sh` で検証可能 | `tests/run-tests.sh` 全件 PASS |

---

## Notes from Refinement

- HMAC 方式選定理由: `openssl dgst -hmac` は macOS/Linux 標準で依存追加ゼロ。鍵を env に持ち git 非追跡とすることで AI はキー情報を持てない。
- 鍵なし = fail-closed: `PLANGATE_MAINTENANCE_KEY` 未設定の場合は署名不可として EH-3 が block する（鍵設定済み = maintenance 使用意図明示）。
- PreToolUse ガードは maintenance 窓でも block: 承認トークン系 path は maintenance 窓の適用外。HO 対象と同等に扱う。
- パッチ方式採用: 全実装対象ファイルが HO カテゴリのため AI は直接 Edit/Write 不可。AI がパッチファイルを生成し Human が `sh scripts/apply-task-0123-patches.sh` で適用する方式を採用。
- CI シークレット: `PLANGATE_MAINTENANCE_KEY_CI` を GitHub Secrets に登録し CI 専用鍵で検証する。本番鍵と分離。

---

## Estimation Evidence

### Risks

| ID | リスク | 影響 | 対策 |
|----|--------|------|------|
| R-1 | HMAC 署名導入で既存 maintenance.json（v1/v2）が全て無効化される | 既存 maintenance 窓が突然利用不能に | スキーマ追加前は `hmac_sha256` を optional・EH-3 は鍵設定済みの場合のみ署名検証を有効化（段階移行） |
| R-2 | `PLANGATE_MAINTENANCE_KEY` 未設定の環境でテストが失敗する | CI/ローカルで偽陰性が発生 | テスト内で `PLANGATE_FAKE_KEY` env で鍵をモック注入（既存 L3 の `PLANGATE_FAKE_PPID_COMM` パターンを踏襲） |
| R-3 | `check-approval-token-write.sh` の path pattern が既存 hook と干渉する | 正規操作が誤 block される | path パターンを最小化・テストで正規フロー確認を AC-5 に含める |
| R-4 | パッチ適用時の手順ミスで既存 hook が破壊される | EH-3 が動作不全になりセキュリティ低下 | patch ファイルに apply 前後の検証ステップを含める・tests/run-tests.sh で PASS 確認を前提条件とする |

### Unknowns

- `openssl dgst -hmac` の出力形式（macOS vs Linux の差異）を事前に確認する必要がある
- GitHub Actions の secrets 設定タイミング（PR 段階 vs マージ後）

### Assumptions

- `PLANGATE_MAINTENANCE_KEY` は human が `.env.local` 等で管理し、git に commit しない
- CI には `PLANGATE_MAINTENANCE_KEY_CI` シークレットが事前に登録される
- `openssl` コマンドは macOS / Ubuntu CI の両方で利用可能
- 既存 ta-12-maintenance.sh の全テストは TASK-0123 実装後も PASS を維持する（回帰なし）
- patch apply 操作は Human が行い、AI は patch ファイル生成のみを担う
