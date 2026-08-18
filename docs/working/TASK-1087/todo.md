# EXECUTION TODO — TASK-1087 (#1087)

Mode: **high-risk** / lite_eligible: **false**

## 🤖 Agent タスク

### 準備

- [x] T-01 `origin/main`(`387ea21`) から `fix/1087-distribution-checks` を作成
      — `rollback: git branch -D fix/1087-distribution-checks`
- [x] T-02 両検査の rc と CI 配線を再実測（issue の 2026-08-13 値を測り直す）
      — `rollback: 不要`（読取のみ）
- [x] T-03 46 件 / 7 件を **全件分類**し evidence 化 🚩
      — `rollback: 不要`（読取のみ）
- [x] T-04 `plugin/plangate/` の生成関係と `drift-check` job の担保範囲を確認
      — `rollback: 不要`（読取のみ）

### 実装

- [ ] T-05 `check-skill-name-collisions.py`: `Definition.root` 追加 + root 内相対パス取得
      — `rollback: git checkout origin/main -- scripts/check-skill-name-collisions.py`
- [ ] T-06 同上: `find_collisions` を「2 定義以上」へ変更（**同一 root 重複の検出追加**）
      — `rollback: 同上`
- [ ] T-07 同上: `is_export_mirror` 4 条件による分類 + 2 セクション印字 🚩
      — `rollback: 同上`
- [ ] T-08 同上: selftest に分類境界ケースを追加
      — `rollback: 同上`
- [ ] T-09 `check-stale-skill-refs.py`: コードスパンをマスクしてから `MD_LINK_RE` を適用
      — `rollback: git checkout origin/main -- scripts/check-stale-skill-refs.py`
- [ ] T-10 同上: `git check-ignore --stdin` バッチによる ignore 除外（git 不在時は除外なしへ縮退）🚩
      — `rollback: 同上`
- [ ] T-11 同上: selftest に上記 2 ケースを追加
      — `rollback: 同上`
- [ ] T-12 `.claude/skills/codex-multi-agent/SKILL.md` の例示パスをプレースホルダ化
      — `rollback: git checkout origin/main -- .claude/skills/codex-multi-agent/SKILL.md`
- [ ] T-13 `sh scripts/sync-plugin-plangate.sh` で `plugin/plangate/` を同期
      — `rollback: git checkout origin/main -- plugin/plangate/`

### 検証

- [ ] T-14 `python3 scripts/check-skill-name-collisions.py` → **rc=0** 🚩
      — `rollback: 不要`
- [ ] T-15 `python3 scripts/check-stale-skill-refs.py` → **rc=0** 🚩
      — `rollback: 不要`
- [ ] T-16 両 `--selftest` → rc=0
      — `rollback: 不要`
- [ ] T-17 `tests/extras/ta-69-distribution-checks.sh` を新規作成し standalone 実行
      — `rollback: rm tests/extras/ta-69-distribution-checks.sh`
- [ ] T-18 `ta-52` の TC-03 を真の衝突構成へ作り替え + ミラー非衝突 TC 追加、standalone 実行
      — `rollback: git checkout origin/main -- tests/extras/ta-52-doctor-skill-collision.sh`
- [ ] T-19 **真の衝突 / 真の stale を注入して rc=1 を実測** 🚩
      — `rollback: 不要`（サンドボックス内）
- [ ] T-20 **変異注入**: レーン全体 + レーン内部の 2 系統で kill を実証（空振りは正直に記録）🚩
      — `rollback: 不要`（変異は適用後に必ず復元）
- [ ] T-21 CI 配線 patch を作成し `git apply --check` rc=0 を確認（**適用しない**）🚩
      — `rollback: rm docs/working/TASK-1087/ci-wiring.patch`

### 完了

- [ ] T-22 `docs/ai/skill-collision-detection.md` / `docs/ai/stale-ref-detection.md` を追記
      — `rollback: git checkout origin/main -- docs/ai/`
- [ ] T-23 C-1 セルフレビュー（17 項目）を `review-self.md` に記録 🚩
      — `rollback: rm docs/working/TASK-1087/review-self.md`
- [ ] T-24 commit + push（**`c3.json` は発行しない**）🚩
      — `rollback: git reset --hard origin/main && git push --force-with-lease`

## 👤 Human タスク

- [ ] H-01 **C-3 人間レビュー**（high-risk のため autonomous APPROVE 不可）
- [ ] H-02 **CI 配線 patch の適用**（`.github/workflows/*` は Hardening Override = Human-owned）
- [ ] H-03 C-4 PR レビュー / merge

## ⚠️ 依存関係

- T-13 は T-12 の後（sync は正本を読む）
- T-14/T-15 は T-05〜T-13 の後
- T-19/T-20 は T-17/T-18 の後（TC が無いと kill を測れない）
- **H-01 → H-02**: C-3 未承認の patch を適用しない
- **H-02 は AI 実行不可**（責務 4 分類: Human-owned）
