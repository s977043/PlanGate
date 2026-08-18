# C-1 再実行（簡易）— TASK-1087 (#1087)

> 実施日: 2026-08-18 / 契機: コーディネータ指摘 1〜4 への対応
> 初回 C-1（`review-self.md`）は**書き換えず保持**。本ファイルは差分レビュー。
> 対象 head: 指摘対応後（`185b463` からの追加コミット）

## 総合判定: **PASS**（WARN 2 / FAIL 0）

初回から **FAIL への降格なし**。指摘 1 は本 PR が持ち込んだ実害だったため
**初回 C-1 の見落とし**として下記に記録する。

---

## 指摘対応の検証

| 指摘 | 対応 | 検証 |
|------|------|------|
| **1**（critical 相当）4 root drift を新規に持ち込んだ | `.codex/skills/codex-multi-agent/SKILL.md` を正本 `.agents/skills` から追従 | `diff .codex/... .agents/...` → **rc=0（同一）** / `sh scripts/sync-plugin-plangate.sh --dry-run` → **rc=0（drift なし）** / 4 root blob: `.agents`=`.codex`=`plugin`=`cc2f6c9dbcad` |
| **2**（major）配布物検査が配布物を検査していない | **(b) を選択**。射程を明文化 + follow-up 起票内容を plan に記載 | `DEFAULT_TARGET_GLOBS` 直上コメント / `docs/ai/stale-ref-detection.md` §走査 root の射程 / `plan.md` §走査 root の射程 |
| **3**（minor）doctor 配線の主張が裏取りできない | **撤回せず、根拠を提示のうえ表現を精密化** | `pbi-input.md` に 5 行の実測表（下記） |
| **4** 4 root 追従漏れの検出可否 | **一般的検出は不可能と実測で結論**。固定リテラルの回帰ガード TC-R1 を追加 | TC-R1 が実際の退行を kill することを実証 |

---

## 指摘 3 の決着: 主張は成立。ただし当初の表現が不正確だった

**コーディネータの grep が実行されていなかった**ことを確認した:

```
$ grep -rn "check-skill-name-collisions" --include=*.sh --include=*.py .
(eval):1: no matches found: --include=*.sh
```

zsh が `--include=*.sh` を glob 展開しようとして失敗し、**grep 自体が起動していない**。
クォートして再実行すると `scripts/doctor_check.py` に 3 ヒットする。

> **これは #1087 が扱っている問題と同型である** — 「コマンドが失敗した」を
> 「ヒット 0 件」と読んでしまう構造。`--warn-only` で緑になる #1109、
> 存在確認だけで配線済みと判定する #1085 と同じクラス。

一方で **私の表現も不正確だった**:

| 私の記述 | 実態 |
|---------|------|
| 「wired into `doctor`」 | `scripts/doctor_check.py` に配線。**到達経路は `bin/plangate doctor --json` のみ**。プレーンな `bin/plangate doctor` では走らない（`\| grep -ci collision` → **0**） |
| （言及なし） | `bin/plangate` 自体に `collision` の文字列は無い（総称委譲）。**コーディネータが `bin/plangate` を grep して 0 件だったのは正しい観測** |

→ `pbi-input.md` を実測表付きの精密な記述に差し替え、
「`bin/plangate` の grep では確認できない」旨の注意書きを追加した。**撤回はしない。**

---

## 指摘 2 で (b) を選んだ理由（要約）

**実測**（2026-08-18）:

| root | 検出数 | 質 |
|------|-------|-----|
| `.agents/skills` | 6 | 大半が**真の stale**（`.agents/rules/` は存在せず `../../rules/*` が解決不能 / `scripts/arbiter.py` の実体は `scripts/ai-loop/arbiter.py`） |
| `plugin/plangate/skills` | 24 | **16 件が新規 FP クラス**（行範囲サフィックス `arbiter.py:909-965`） |
| `.codex/skills` | 6 | — |

(a) を採るには **FP ガード新設 + ai-loop レーンの真の stale 是正 + #1086 の裁定待ち**が
同時に必要で、「検知器を直す」本 PBI と「検知器が見つけたものを直す」別作業の混在になる。
rc=1 のまま配線すれば #1087 が防ごうとしている状態そのものを再生産する。

**検査しない範囲を明示した**（配布 root の stale 参照 / 配布 root 固有の参照崩れ）。

---

## 指摘 4 の結論: 内容一致による一般検出は成立しない

| 比較 | 共通 | 一致 | **正当に相違** |
|------|-----|------|--------------|
| `.agents` vs `plugin` | 39 | **39** | 0（`sync` + `drift-check` が担保する既存の不変条件） |
| `.agents` vs `.codex` | 39 | 13 | **26** |
| `.agents` vs `.claude` | 24 | 16 | **8** |

**`.codex` は `.agents` の byte copy ではない**（39 中 26 が相違）。
`codex-multi-agent` はたまたま一致する 13 件の側だった。
よって「4 root 一致」assert は 26 件の正当な相違で即落ちる。
root ごとの skill 数（39/29/39/39）も増減するため件数 assert は時限爆弾。

→ **固定リテラルのゼロ集合 assert（TC-R1）**を採用。母集団の増減に依存しない。
存在しない root はスキップするため #1086 の untrack でも壊れない。

---

## 差分に対する C-1 チェック（変更のあった項目のみ）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準の網羅性 | PASS | 射程（何を検査しないか）を AC 相当として plan に明文化 |
| C1-PLAN-03 | スコープ制御 | PASS | (b) 選択により配布 root 拡張を follow-up へ分離。起票内容を plan に記載済 |
| C1-TODO-04 | Iron Law 遵守 | PASS | `.github/workflows/` 未編集（`git status .github/` clean）/ `c3.json` 未発行 / 他ワーカー担当ファイル未変更 |
| C1-TC-02 | Edge case 網羅 | PASS | TC-R1 に「root 不在時はスキップ」を実装（#1086 での untrack に耐える） |
| C1-TC-04 | 負側 TC の本番経路 | PASS | TC-R1 は本番ツリーの実 root を走査。**実際の退行で kill 実証済み** |
| C1-TC-05 | 件数 assert の不在 | PASS | TC-R1 はゼロ集合 assert。4 root の件数・一致率を assert していない |

---

## 指摘事項

### WARN-1（新規・初回 C-1 の見落とし）: 検知器の PBI が自ら drift を持ち込んだ

`.claude/skills` を編集した際、**追従先 root を機械的に列挙せず**
`.agents` と `plugin` だけを更新して `.codex` を落とした。
初回 C-1 の 17 項目には「編集した skill の**全配布 root への追従**」を
確認する観点が無く、**検出できなかった**。

- **構造原因**: 追従漏れを検出する仕組みが存在しない
  （stale-refs は `.claude/**` のみ / 内容一致 assert は成立しない）
- **本 PR での対応**: TC-R1（固定リテラルのゼロ集合）で当該クラスを回帰ガード
- **残る限界**: TC-R1 は**今回移行したリテラルに固有**であり、
  将来の別の編集に対する一般的な追従漏れ検出にはならない。
  一般解は follow-up（配布 root 走査）側に属する

> **象徴的な失敗として記録する。** 「配布物の検知器を立てる」PBI が
> 自ら配布 drift を持ち込み、自分の検査で緑だった。
> 検査の射程外は**実際に事故が起きる**ことの実例。

### WARN-2（継続）: `--strict` 未配線 / skill レーンの parity 未担保

初回 C-1 から変更なし。いずれも別 PBI 送り（`status.md` の BLOCKED 表参照）。

---

## exec 可否

**C-1 PASS（再実行）。** Mode = `high-risk` のため **C-3 は人間必須**。
`c3.json` は発行しない。
