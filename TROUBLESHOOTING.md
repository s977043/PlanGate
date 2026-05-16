# Troubleshooting

A diagnostic guide for common issues when installing and using PlanGate.

---

## Installation

### `.claude/` と plugin を二重インストールしてしまった

**症状**: コマンドが二重に実行される、または挙動が予期しない。

**原因**: Option A（plugin）と Option B（`.claude/` 直接配置）を両方適用している。

**対処**:

1. どちらを使うか決める（plugin 推奨）。
2. Option B を削除する場合: `rm -rf your-project/.claude/` で手動削除する。
3. Option A を削除する場合: Claude Code のプラグイン削除コマンドで plugin を登録解除する。

参照: [README.md — Plugin vs .claude/](README.md#plugin-vs-claude--which-to-use)

### plugin が反映されない・コマンドが認識されない

**症状**: `/working-context` や `/ai-dev-workflow` を実行しても "Unknown command" になる。

**確認手順**:

1. `plugin/plangate/README.md` の手順通りに plugin が登録されているか確認する。
2. Claude Code を再起動してから再度試す。
3. `.claude/commands/` を直接配置する Option B に切り替えることも検討する。

### plugin を更新しても変更が反映されない

**症状**: `git pull` 後も古い挙動になる。

**対処**:

1. Claude Code を完全に終了・再起動する。
2. それでも解決しない場合は、plugin を一度登録解除し、再登録する。

---

## Workflow

### `/working-context TASK-XXXX` が動かない

**症状**: コマンドを実行しても応答がない、またはエラーになる。

**確認手順**:

1. `docs/working/TASK-XXXX/` ディレクトリが存在するか確認する。
   存在しない場合、先にチケットディレクトリと `pbi-input.md` を作成する。
2. plugin または `.claude/commands/` が正しく配置されているか確認する（上記参照）。

### `/ai-dev-workflow plan` でエラーになる

**症状**: plan 生成時にエラーが出て途中で止まる。

**確認手順**:

1. `docs/working/TASK-XXXX/pbi-input.md` が存在し、Why / What / 受入基準のセクションが埋まっているか確認する。
2. Claude Code のモデルが利用可能な状態か確認する（API 障害等）。
3. それでも解決しない場合は Issue を開いてください。

---

## Gate

### C-3 承認なしで exec が走ってしまった場合の確認方法

**確認手順**:

1. `docs/working/TASK-XXXX/plan.md` の `status` frontmatter を確認する。`approved` になっているか。
2. `docs/working/TASK-XXXX/approvals/c3.json` が存在し、`"c3_status": "APPROVED"` になっているか。
3. exec 前に承認が取れていない場合、実装済みコードをレビューし、C-4 ゲートで対処する。

将来的に `approvals/c3.json` の存在チェックが exec フック（`pre-exec`）として自動化される予定です（Issue #77）。

### hook が効かない / ゲートが強制されない

**症状**: plan / approval / scope などの不変条件が検査されず、hook によるブロックが一切働かない。

**原因**: clone / plugin 導入直後で、`.claude/settings.json` に hook が配線されていない（PlanGate は `.claude/settings.example.json` を配るのみで、配線は手動）。

**確認手順**:

1. 配線状態を検査する（何も書き換えません）。

   ```bash
   bin/plangate doctor
   ```

   未配線の場合、`=== Hook Enforcement Wiring ===` セクションに `[FAIL] PlanGate hooks not wired` が出力されます。

2. 適用される変更を事前に確認する（任意、`--dry-run` は一切書き換えません）。

   ```bash
   bin/plangate doctor --fix --dry-run
   ```

3. hook 配線を修復する。

   ```bash
   bin/plangate doctor --fix --yes
   ```

   `.claude/settings.example.json` を正本に hooks を merge-only（既存キー温存）で適用し、EH-8 スクリプトへの実行ビット付与、`.gitignore` 追記、`docs/working/` 作成を行います。`--yes` は確認をスキップします（非対話環境では `--yes` 無しだと安全のため中断します）。

4. 再度検査して PASS を確認する。

   ```bash
   bin/plangate doctor
   ```

gh / codex は自動インストールされません。未導入時は案内のみ表示されます。

---

### 単独運用で必須レビューが回らずマージできない

**症状**: PR の CI は全 PASS だが `mergeStateStatus: BLOCKED` でマージできない。`reviewDecision` が空。

**原因**: ブランチ保護 ruleset（例「Protect default branch」）が PR 作者以外の承認レビューを必須にしているが、単独運用でレビュアーが不在。PR 作者は self-approve 不可。

**対処（リポジトリ管理者が GitHub Web で実施。agent はバイパスしない）**:

1. 即時マージ（設定変更なし）: PR 画面の **Merge without waiting for requirements to be met (administrators only)** で管理者マージ
2. 恒久対応（推奨）: Settings → Rules → Rulesets → 該当 ruleset → **Bypass list に Repository admin を追加** → Save。以降は通常マージ / auto-merge が機能（CI 等の他ガードは維持される）
3. 緩和: required approvals を 0 にする（CI 必須を残すなら 2 より弱いので非推奨）

> agent はマージブロック時に admin override / 別アカウント承認 / ruleset 改変を**行わない**（`AGENT_LEARNINGS.md` 2026-05-16）。状況を報告し、上記をユーザーに委ねる。

## Environment

### Claude Code と Codex CLI の両方が必要なケースの確認

PlanGate は **Claude Code のみ**でも利用可能です。Codex CLI は以下のケースで追加価値を提供します。

| ユースケース | Claude Code | Codex CLI |
| --- | --- | --- |
| plan / exec / PR | 必須 | 不要 |
| 外部レビュー（C-2 / V-3） | 不要 | 推奨 |
| 並列マルチエージェント実行 | 可 | 可 |

Codex CLI のセットアップ: <https://github.com/openai/codex>

---

## CI

### Markdown lint が失敗する場合の対処

**症状**: PR の CI チェック `Markdown lint` が失敗する。

**ローカルで確認する**:

```bash
npx markdownlint-cli2 "**/*.md" --ignore node_modules
```

**よくある原因と修正**:

| エラーコード | 原因 | 修正 |
| --- | --- | --- |
| MD013 | 行が長すぎる | `.markdownlint-cli2.jsonc` で `MD013: false` を確認（プロジェクト設定で無効化済み） |
| MD041 | ファイルの先頭が H1 でない | ファイルの先頭に `# タイトル` を追加する |
| MD022 | 見出しの前後に空行がない | 見出しの前後に空行を入れる |
| MD032 | リストの前後に空行がない | リストの前後に空行を入れる |

---

## Getting More Help

解決しない場合は [GitHub Issues](https://github.com/s977043/plangate/issues) を開いてください。
質問・相談は [GitHub Discussions](https://github.com/s977043/plangate/discussions) へ。
