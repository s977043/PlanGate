# Session Retrospective — 2026-05-24 〜 2026-05-28 (11 PBI 完遂)

> 本セッション (TASK-0108〜0118 / 5 日間) の振り返り。
> 出力先: improvement-seeds 候補 + 次セッション plan 精度向上の教訓。
> 形式: TASK-0106 retrospective 準拠。

## 1. サマリ

| 指標 | 値 |
|------|---|
| 期間 | 2026-05-24 〜 2026-05-28 (5 日) |
| 生成 PBI | 11 件 (TASK-0108〜0118) |
| 完了 PBI | 11 件 (100%) |
| Closed issue | 8 件 (#295/#301/#310/#315/#351/#352/#354/#355) |
| Merged PR | 70 件 |
| 外部レビュー | Codex/Gemini 計 16+ ラウンド |
| INC | 1 件 (49448c5 main 直接 push) |

## 2. KPT

### Keep (続ける)

- **個別 C-2 proactive review (Codex+Gemini 並列)**: exec 前に R-NNN を潰すことで exec PR の Gemini bot 指摘が 0 件化 (TASK-0112/0113/0115/0116/0118 で実証)。**最大の品質ドライバ**
- **c3.json proxy 発行パターン** (`approved_by: human-...-via-claude-on-explicit-instruction-<date>`): Human の明示指示ごとに AI が file 作成、merge は Human-owned 維持。監査トレース性を保ちつつ高速化
- **T-01 read-only hard gate**: TASK-0109/0111 で「plan の前提が既に実装済 (CX-2 既達 / #356 先行)」を exec 前に発見、scope を縮小。**plan の前提崩れを早期検出**
- **Hardening Override path の AI 直接編集**: c3.json APPROVED + plan_hash 一致で EH-3 通過 (TASK-0112/0113/0115/0116)。maintenance window 不要と確認
- **branch verify 自己適用** (INC P-3 lesson): commit 前に `git rev-parse --abbrev-ref HEAD` 確認を全 PBI で実践、再発ゼロ

### Problem (課題)

- **INC-2026-05-26-001 (empty commit 49448c5 main 直接 push)**: `git checkout` 失敗の見落としで main 上 commit/push。**process drift の象徴**。→ P-1/P-2/P-3 で構造対策完了
- **claude-mem 自動挿入の実害**: PR #376/#383 で AGENTS.md / skip-decision-log が `git add -A` に巻き込まれた。→ TASK-0113 検知 hook + 根本削除で解消
- **plan の前提崩れ**: TASK-0109 (CX-2 既達)、TASK-0108 (#356 で 5 項目先行完了)、TASK-0112 (skill path `.claude/skills/` 誤認 → `.agents/skills/`)。**plan 生成時の実数検証不足** → TASK-0117 (事前メトリクス検証) で構造化
- **commit への noise 混入** (AGENTS.md / skip-decision-log / TASK-0059): `git add -A` の多用で複数回発生。→ 個別 `git add <path>` + `git restore --staged` で対処したが規律が緩んだ
- **gh アカウント切替の頻発**: GraphQL mutation / PR create で 別アカウント にスイッチ、権限エラー多発。→ 各操作前 `gh auth switch --user s977043` 必須化
- **PR 量産による Human gate bottleneck**: 一時 4+ PR 同時 open。Codex が複数回「process drift」「停止」を警告

### Try (次に試す)

- **`git add -A` 禁止 / 個別 add 徹底**: noise 混入の根本対策 (TASK-0113 検知 hook の install + pre-commit で補強)
- **plan 生成時の TASK-0117 事前メトリクス検証 mandatory 化**: 「全件 / 既存実装済」の実数確認で前提崩れを防ぐ (本セッションで skill 化済、次セッションから適用)
- **c3.json 発行と exec の同一セッション内連続化**: 本セッションで確立した「c3 PR → merge → exec PR → merge」の 2 段 flow を定型化
- **gh auth switch を bash helper 関数化**: 毎回手動 switch のミス防止 (settings に alias or wrapper)
- **PR 同時 open 数の上限自主規制**: Codex 推奨に従い 1-2 PR 完結を待ってから次着手

## 3. AI harness improvement (#200) 用の問い

- [x] **C-3 CONDITIONAL/REJECTED 増加要因**: 個別 C-2 で major を事前に潰したため exec 段階の reject は 0。C-2 review の前倒しが効いた
- [x] **C-4 REQUEST_CHANGES**: Gemini bot review が事実上の C-4 相当。c3 PR は 0 件、exec PR も C-2 済 PBI は 0 件、未 C-2 PBI (TASK-0114/0116 等) で発生 → C-2 の網羅性が品質を決める
- [x] **V-1 first pass rate**: 全 PBI で AC 全 PASS (first pass)。ta-NN 機械検証が効いた
- [x] **fix loop**: 各 exec PR で Gemini bot 1-3 件の medium fix loop。HIGH は TASK-0110 (raw-line silent failure) / TASK-0109 (macOS timeout) で発生 → 外部 reviewer の OS 互換・silent failure 検出力が高い
- [x] **hook violation 傾向**: EH-3 が HO path で正しく機能 (c3 APPROVED で通過、未 c3 で block)。誤検出なし
- [x] **Keep Rate**: c3.json proxy / T-01 hard gate / 個別 C-2 が高再利用
- [x] **次の harness improvement PBI 候補**:
  - `git add -A` 禁止の lint / hook 化
  - gh auth switch 自動化
  - TASK-0117 事前メトリクス検証の機械強制 (現状ソフトルール)
  - #353 (C-3 autonomous 判断基準) — Human 方針待ち

## 4. 次アクション

| アクション | Owner | 関連 |
|-----------|-------|------|
| #353 方針決定 (autonomous APPROVE 範囲) | **Human** | #353 |
| TASK-0113 hook install (`sh scripts/install-pre-commit.sh`) | Human (opt-in) | #355 |
| TASK-0114 hook install (`sh scripts/install-pre-push.sh`) | Human (opt-in) | INC P-1 |
| `git add -A` 禁止 lint | AI (新規 PBI 候補) | 本 retro Try |
| gh auth switch helper | AI (新規 PBI 候補) | 本 retro Try |

## 5. R-NNN / C-2 統計 (本セッション)

| PBI | C-2 reviewer | major 検出 | exec PR bot 指摘 |
|-----|-------------|-----------|-----------------|
| TASK-0108 | Codex+Gemini | 6 | (#356 先行で実質 0) |
| TASK-0109 | Codex+Gemini (CRITICAL R-005) | 10 | 2 HIGH (macOS/test) |
| TASK-0110 | Codex+Gemini | 6 | 3 (HIGH raw-line) |
| TASK-0111 | Codex+Gemini | 12 | 1 (wording) |
| TASK-0112 | Codex+Gemini | 7 | 0 |
| TASK-0113 | Codex+Gemini (CRITICAL R-007) | 10 | 0 |
| TASK-0114 | Codex+Gemini | 8 | 6 (2 PR) |
| TASK-0115 | Codex+Gemini | 8 | 0 (c2) / 3 (link) |
| TASK-0116 | Codex (Gemini quota) | 4 | 2 (TC ID) |
| TASK-0117 | Codex+Gemini | 7 (major 0) | 3 (grep exclude) |
| TASK-0118 | (review-self のみ) | — | 0 |

**洞察**: 個別 C-2 を完全実施した PBI (0112/0113) は exec PR bot 指摘 **0 件**。C-2 を省略した PBI (0118) や未完全 (0114) は exec で指摘発生。**C-2 投資が exec 品質に直結**。

## 6. Refs

- 本セッション全 PBI: TASK-0108〜0118 handoff
- INC: [docs/working/incidents/2026-05-26-empty-commit-direct-push.md](../incidents/2026-05-26-empty-commit-direct-push.md)
- 前 retro: [docs/working/TASK-0106/retrospective.md](../TASK-0106/retrospective.md)
- EPIC #193 (Harness Improvement Roadmap)
