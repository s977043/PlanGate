# AI-driven E2E Verification: 実行・証跡・判断の境界（#1430）

> Status: **proposed adoption guide**（非正本、設計と受入観点のみ。Runtime / CI / Gate の実装を追加しない）。
> 目的: AIによる探索的ブラウザ操作と、再実行できる決定論的なE2Eテストを区別し、既存のPlanGate検証フローへ安全に接続する。
> Issue: [#1430](https://github.com/s977043/PlanGate/issues/1430)。参考: [lackeyjb/playwright-skill](https://github.com/lackeyjb/playwright-skill)、[ai-agent-template PR #155](https://github.com/s977043/ai-agent-template/pull/155)（設計思想のみ。外部コード・Runner・依存は導入しない）。

## 1. 所有権と既存契約

| 判断すること | 既存の所有者・配置 | 追加しないもの |
| --- | --- | --- |
| Goal / Acceptance Criteria とテスト層選定 | Plan の Testing Strategy、`test-cases.md`、V-1 受入検査 | `gate_checks.test`、新 Test Gate |
| 品質コマンドと実行証跡 | [quality-command-evidence.md](quality-command-evidence.md) / evidence-ledger | 並列の Evidence Gate / 新スキーマ |
| 実行失敗時のRepair / Replan | [V2 North Star](ai-loop-v2/north-star.md) §2 / §9 | 既存 Lifecycle State に重なる状態機械 |
| Verifier の結果・Run全体の判断 | [artifact-responsibilities.md](ai-loop-v2/artifact-responsibilities.md) | BuilderやExplorerによる自律的な最終判定 |
| C-3 / C-4・Policy / Permission / HO / Merge | 既存のHuman-owned authority・監査証跡 | 自動承認・権限の暗黙委譲 |

[gate-checks.md](gate-checks.md) §2.2 / §2.3 は新たなEvidence Gate / Test Gateを不採用としている。**本ガイドはその判断を変更しない**。本文の「ゲート」は、導入先の既存required checksや検証契約を意味し、新しい共通必須ジョブを意味しない。

## 2. Agentic探索と決定論的E2Eを分離する

| Stage | 成果物 | 検証済みと言える範囲 | 誤用してはならない判断 |
| --- | --- | --- | --- |
| Discovery | 操作ログ、browser snapshot、画面観察、仮説 | 探索結果を観測した | 統合テストPASS / 修正完了 |
| Candidate | ACに結びついた`*.spec.ts`等のテスト候補 | 再実行可能な候補がある | テストが実行済み |
| Verified | 対象head SHA、実行コマンド、exit code、assertion、browser/version・環境、必要なartifact | **記録された条件と対象SHA**で検証した | 全ブラウザ・全環境・全ACで検証済み |
| Reviewed | 対象SHAに対する既存CI/ローカル代替証跡と独立レビューの結果 | 宣言された範囲のレビュー判断を材料付きで提示できる | Human C-4やマージ権限の自己発行 |

- スクリーンショット保存、`goto()`、クリック成功、AIの自然言語報告、Node.jsの`exit 0`だけでは**期待結果に対するassertion成功**を示さない。
- Agentic E2Eは原則 **Explorer / Discovery**。得られた再現手順を必要時だけ決定論的E2Eへ昇格する。探索結果の文章を、新しいblocking判定に直接渡さない。
- `unavailable` / `skipped` / `inconclusive` と `passed` を同一視しない。CI全体がgreenでも該当ジョブが未起動・skippedなら検証済みではない。
- Evidenceは対象commitを束縛する。古い`main`のCIをPR headの成功として再利用しない。ブラウザログや候補Evidenceを独立したVerifierの判定に昇格させない。

## 3. Self-Healingの範囲

| 変更候補 | Agent単独で提案・実装できる範囲 | 判定と条件 |
| --- | --- | --- |
| Locator / wait / fixture / navigation | **HOW**: 元のACと成功条件を維持した修復 | 同一の振る舞いを再検証し、旧/新テストの検出力を比較する |
| Test data / mock / setup | **HOW候補**: 隔離・決定性向上 | 本番状態や認可境界を変更せず、mockが契約違反を隠さないか確認 |
| Assertion削除、期待値緩和、ビジネスルール変更 | **WHAT**: 意味の変更 | Agentの自己修復では実施不可。Requirement/ACの正当な変更とReplan・Plan Verificationへ戻す |
| 権限、料金、決済、セキュリティ挙動、主要導線の削除 | 高影響・不可逆のWHAT | 既存Policyに沿ったHuman decisionが必要。単なるflaky修正として扱わない |

原因分類は **Implementation / Test / Environment / Requirement unclear** を初期仮説として使う。ログなどから裏付けが取れないうちは推定のまま残し、どの分類でもテストをskipして成功扱いしない。Repair反復予算は既存LoopContract/停止予算の所有者が決め、本ガイドが`MAX_REPAIR_ITERATIONS`の新しい固定値を規定しない。

## 4. 最も安い十分な検証レイヤを選ぶ

| 層 | 主な内容 | 推奨する例 |
| --- | --- | --- |
| L0 Static | format / lint / typecheck / schema | 静的契約・ビルド可能性 |
| L1 Logic | unit / property tests | 日付・計算・権限判定の純ロジック |
| L2 Boundary | integration / contract | API・DB・認可・外部サービス境界 |
| L3 Behavior | deterministic browser E2E | 主要なユーザー導線・クロスコンポーネントの重要操作 |

E2Eの対象候補: 事業価値・信頼・セキュリティに直結し、下位レイヤだけではユーザーの実際の振る舞いを保証できないシナリオ。画面があるだけでL3を必須化しない。ACと失敗モードから層を選定し、重複して高価なE2Eを増やさない。

## 5. CIの段階的な検証モデル（推奨パターンであり義務化ではない）

| 実行段階 | 主な目的 | 例 |
| --- | --- | --- |
| PR | 変更に対する速い・決定論的なフィードバック | lint / unit / contract / 変更に関連するcritical E2E |
| Merge / Release | 統合後の回帰とデプロイ準備 | full integration / 重要導線 / 対象browser / migration |
| Scheduled / Nightly | 高コスト・低頻度・発見型の検査 | 多ブラウザ探索 / visual diff / long E2E / agentic discovery |

既存CIの設定・Branch Protection・required checksは変更しない。runner未起動・予算不足・外部サービス障害でCIが使えない場合も **PASSを捏造しない**。導入先が認めるローカル等価検証のコマンド、環境、exit code、SHA、残るギャップを記録し、レビュー判断で扱う。

## 6. 実行・証跡の最低条件

- **Target**: repo、head SHA、テストファイル、該当AC。
- **Runner**: コマンド、開始時刻、exit code、ブラウザ/バージョン、viewport、locale、timezone、対象origin。
- **Result**: assertionと失敗箇所、テスト数、retryの有無、`skipped`・`unavailable`の明示、既知のflaky。
- **Artifact**: trace / screenshot / video / HTML reportの保存先と閲覧権限（PII、Cookie、storageState、トークンの持ち込み禁止または秘匿・除去）。
- **Isolation**: ローカル/許可済みstagingを基本とする。共有ログイン、本番への不可逆操作、任意CDP接続は行わない。
- **Verification**: Builderが生成した実行ログは自己申告ではなく **検証候補**。Verifierが対象SHA・コマンド・assertionを照合してはじめて確認結果となる。

PlanGate内部のChromium CDPテストは依存を増やさず実ブラウザで観測する実装であり、Playwrightを共通必須依存に置き換えない。CDP起動時のflake事例は [#1556](https://github.com/s977043/PlanGate/issues/1556) / [#1569](https://github.com/s977043/PlanGate/pull/1569) を参照。cold startの測定に基づいて待機時間を修正したのであり、全テストに一律長いtimeoutを設定する教訓ではない。

## 7. 導入前レビューと停止条件

以下を1件でも満たす場合、`Verified`の主張を取り下げて追加検証またはHuman判断へ戻す。

1. 実行記録のhead SHAと変更対象が一致しない。
2. screenshotまたは単発スクリプトのみで assertion がない。
3. テスト失敗を無条件retryやassertion削除で隠した。
4. browser E2Eがskip/未実行だが必須の検証としてPASSと記録した。
5. 本番データやシークレットの流出・不可逆操作・無許可の権限使用が起きた。
6. AC/期待結果を「テストを通すため」に変更し、既存のReplan/approvalを通していない。

導入先で先に観測するもの: 真の回帰検出率、再実行成功率、flaky率、実行時間、修復負荷、token/APIコスト。改善したと結論するのは比較実測後とする。

### Scope / Rollback / Detection

- この文書は **非HOドキュメントの提案** であり、既存規範・runtime・Hook・CI・approval・protected surfaceは変更しない。
- Rollback: 本変更をrevertし、従来の正本を参照する。
- Detection: 新旧のTest/Verification指示が矛盾していないか、意図せず新ゲートやCI追加を要求していないかをPRレビューで確認する。
- Observation window: ドキュメント変更単独ではランタイム観測なし。実際の導入効果は別途、導入先の評価で検証する。
