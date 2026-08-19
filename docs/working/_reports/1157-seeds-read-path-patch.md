# #1157 improvement-seeds 読み出し導線 — patch 設計書

> 対象 issue: [#1157](https://github.com/s977043/plangate/issues/1157)
> 種別: **設計書のみ**（実装・適用は含まない）
> 起点: `origin/main` = `4a625c1` / ブランチ `docs/1157-seeds-read-path`
> 測定日: 2026-08-19

---

## 0. 結論（先に）

| 項目 | 結論 |
| --- | --- |
| **推奨案** | **C 案（`improvement-digest.md` を L0 に置く）** を主、**D 案（hook）は AC-1 実測専用の Phase 2**、**B 案（L1）は補助** |
| **C 案は新規実装か** | **新規実装ではない**。`docs/ai/seeds-hygiene.md`（#754 正本、2026-07-07）§還流 が **既に**「WF-01 context bootstrap のセッション開始時 Progressive Disclosure で参照できるようにする」と規定済み。**正本に書かれた還流経路が `working-context.md` 側に未配線**なだけ |
| **最大の設計上の発見** | **read-path を今そのまま繋ぐと、#1104 のガバナンス違反（EH-3 の Bash/Python 迂回）を全セッションの初期条件として配布することになる**。digest #001 は当該迂回を「**恒常運用へ昇格すべき候補**」として明示的に昇格させている。**自浄（AC-3）は read-path の後続改善ではなく、read-path 開通の前提条件** |
| **自浄の設計** | seeds 本体は**一切触らない**。派生層（digest）に **`superseded` マーク**を新設し、既存 `resolved` と区別する。判定 = AI-owned / 確定 = Human-owned（digest PR の C-4）。append-only 不変条件の既存検証コマンドがそのまま通る |
| **責務** | `.claude/rules/working-context.md` は HO パス → **AI は patch 提示まで・適用は Human**。ミラー `plugin/plangate/rules/working-context.md` も同時適用が必要（実測: 現状 diff 0） |

---

## 1. `improvement-digest.md` の現状（実測）

### 1.1 実測コマンドと結果

| 問い | コマンド | 結果 |
| --- | --- | --- |
| 実体はあるか | `wc -lc docs/working/improvement-digest.md` | **71 行 / 4620 バイト** |
| 生成スクリプトはあるか | `git grep -ln 'improvement-digest' -- scripts bin .github tests` | **0 件**（`improvement-seeds` でのヒットは `scripts/apply-quality-command-gate.sh` のみで、これは `working-context.md` の節見出しを**アンカー文字列として使っているだけ**。digest 生成とは無関係） |
| CLI 経路はあるか | `grep -c 'digest' bin/plangate` | **0** |
| skill はあるか | `ls .claude/skills/ \| grep -i 'seed\|hygiene\|digest'` | **0 件**（rc=1） |
| いつ・誰が | `git log --format='%h %ad %an %s' --date=short -- docs/working/improvement-digest.md` | **`8d1fed1` / 2026-07-07 / mine_take / `docs(#754): Run-013 — improvement-seeds hygiene 仕様正本化 + digest サンプル #001 (#761)`**。**以降 更新 0 回** |
| seeds 側の更新 | 同上 seeds | `863b7b9`(2026-06-10) / `f1fadb3`(2026-06-25) / **`d0299f5`(2026-08-05, #1006)** |

### 1.2 確定した事実

1. **生成主体 = AI の手動生成**。生成スクリプト・CLI サブコマンド・skill のいずれも**存在しない**。digest は ai-loop Run-013（#754 / PR #761）で AI が 1 回だけ書き、PR で入れた **サンプル成果物**である（digest 本文にも「本 digest は仕様（#754）に基づく**サンプル生成物**」と自称）。
2. **正本仕様は既にある**: `docs/ai/seeds-hygiene.md`（129 行 / 8339 バイト）。入力・処理（重複統合 / 矛盾検出 / 陳腐化判定）・出力・還流・責務分類・実行トリガーまで規定済み。
3. **正本仕様が宣言したトリガーが未実装**: seeds-hygiene §実行トリガー は「**v1 = 手動起動のみ。skill もしくは `bin/plangate` サブコマンド経由で人間が明示的に起動する**」と書くが、**その skill も subcommand も実在しない**（上表）。＝ *「設定の存在は効いている証拠でない」型のギャップが hygiene 側にも既にある*。
4. **正本関係（AC-4 の答え）**:

   | | `improvement-seeds.md` | `improvement-digest.md` |
   | --- | --- | --- |
   | 位置づけ | **正本**（append-only / human confirm 必須） | **派生・参照入力**（非正本） |
   | スキーマ正本 | `docs/ai/retro-phase.md` §2 | `docs/ai/seeds-hygiene.md` |
   | 生成 | WF-06 Retro（opt-in・既定 OFF）＋人間 confirm | AI が seeds を読んで生成（**現状は手動 1 回のみ**） |
   | 書き換え | **不可**（既存編集・削除しない） | **上書き再生成してよい**（seeds-hygiene §出力） |
   | 採用 | 人間 confirm | **Human-owned（PR の C-4）** |
   | 使い方の制約 | — | **plan 生成・C-3 承認の自動判断材料にしてはならない**（seeds-hygiene §還流） |

5. **鮮度は stale**: digest の「対象エントリ」は 2 件（2026-06-07 / 2026-06-25）。seeds は現在 **3 エントリ**で、**2026-08-05 のエントリ（#1006）が digest に未反映**。digest 生成（07-07）から seeds 追記（08-05）まで **未取り込みのまま 14 日以上放置**（測定日基準では 45 日）。
6. **中身は「要約」になっているか → なっていない**（後述 §2.2 の実測サイズ）。構成は seeds-hygiene の処理 3 種に沿っており（対象エントリ / 統合知見 / 陳腐化判定 / 現役知見 / 矛盾検出 / 還流先）**形式は仕様準拠**だが、**圧縮されていない**。

### 1.3 read-path 側の決定的な実測（issue の前提を 1 つ補正する）

`docs/ai/seeds-hygiene.md` §還流 は既に次を規定している:

> - **WF-01 context bootstrap**: セッション開始時の Progressive Disclosure
>   （`working-context.md`）で、過去の教訓を圧縮した形で参照できるようにする。

つまり **「digest を Progressive Disclosure に載せる」は 2026-07-07 時点で正本に書かれている**。#1157 で欠けているのは設計判断ではなく **`working-context.md` L0〜L3 表への 1 行の配線**である。issue の C 案「新規実装ではない可能性」は **正しい**。

- `git grep -n 'improvement-digest' -- .claude` → **0 件**（`working-context.md` は digest を一切知らない）
- `.claude/rules/working-context.md:137-144` の言及は **seeds の説明のみ**で、digest への言及も読む指示もない

---

## 2. トークン予算（AC-2）

### 2.1 実測サイズ

| ファイル | 行 | バイト | 備考 |
| --- | --- | --- | --- |
| `docs/working/improvement-seeds.md` | 32 | **8759** | 3 run 分 |
| `docs/working/improvement-digest.md` | 71 | **4620** | 2 run 分（stale） |
| （参考）`CLAUDE.md` | — | 6572 | 常時読み込み |
| （参考）`.claude/rules/working-context.md` | — | 25089 | 常時読み込み |

エントリ別サイズ（`awk` で見出し行（`##` 始まり）区切り集計）:

| エントリ | バイト |
| --- | --- |
| 2026-06-07 v8.12.0 run | 2221 |
| 2026-06-25 TASK-0143 run | 1863 |
| **2026-08-05 v8.18.0 + #914 run** | **4341** |

→ 平均 **2808 バイト/run**、かつ **最新エントリが最大**（1 run の記述量は増加傾向。粒度が細かくなっている）。

### 2.2 「digest ならトークン効率が良い」は現状**成立していない**

- digest が対象とした 2 エントリの原文合計 = 2221 + 1863 = **4084 バイト**
- 現行 digest = **4620 バイト**
- → **圧縮率 113%（＝ 13% 増えている）**。現行 digest は要約ではなく「解説付き再構成」。

**したがって C 案の長所（トークン効率）は、digest にサイズ規約を課さない限り実現しない。** これは issue の案比較表の前提に対する実測での補正である。

### 2.3 上限方針（append-only で必ず増えることへの対処）

seeds 本体は **L0 に載せない**（A 案却下の主因）。実測から外挿すると:

| run 数 | seeds 推定サイズ | L0 常読の妥当性 |
| --- | --- | --- |
| 3（現在） | 8.8 KB | ぎりぎり許容 |
| 20 | ≒ 56 KB | 不可 |
| 100 | ≒ 280 KB | 論外 |

**digest 側に hard cap を規約化する**（`seeds-hygiene.md` への追記事項。非 HO）:

| 規約 | 値 | 検証コマンド |
| --- | --- | --- |
| digest 総サイズ上限 | **6144 バイト（6 KiB）** | `test "$(wc -c < docs/working/improvement-digest.md)" -le 6144` |
| 「現役知見」項目数上限 | **12 項目** | 目視 + 生成時の自己申告 |
| 1 項目の長さ | **2 行以内** | 同上 |
| 超過時の落とし方 | ① `resolved` 済み → 落とす ② `superseded` → 1 行に圧縮 ③ 古い run 由来の重複 → 統合 | — |
| seeds 本体 | **上限なし・不変** | `git diff --quiet origin/main -- docs/working/improvement-seeds.md` |

6 KiB の根拠: 現行 digest 4620 B に対し、未反映の 2026-08-05 エントリ（4341 B）から現役知見を数項目取り込んでも収まる幅として設定。日本語主体のため概算 **1.5〜2.5 K tokens**。L0 に既にある `CLAUDE.md`(6.5 KB) と同オーダーで、L0 の増分としては約 +25%。

**上限に達したら「seeds を消す」のではなく「digest を絞る」**——これが append-only を破らないための構造的な要点。

---

## 3. 4 案比較（issue 本文 A/B/C/D）

### 3.1 一覧

| 案 | 内容 | 新規実装 or 既存再利用 | 触る HO パス | 判定 |
| --- | --- | --- | --- | --- |
| **A** | seeds を L0 に追加 | 既存再利用（表 1 行） | `.claude/rules/*.md` ×1 | **却下** |
| **B** | L1（plan / exec）に追加 | 既存再利用（表 1 行） | 同上 | **補助として採用** |
| **C** | digest を L0 に置く | **既存機構の再利用**（正本 `seeds-hygiene.md` + digest 実体 + 還流規定が既存） | 同上 | **推奨（主）** |
| **D** | SessionStart hook で直近 N 件注入 | **新規実装** | `.claude/settings*.json` + `scripts/*.sh` ×2 カテゴリ | **Phase 2 / AC-1 実測専用に限定採用** |

### 3.2 各案の実測に基づく長所・短所

#### A 案 — seeds を L0

- 長所: 配線 1 行で最短。**正本そのもの**を読むので伝言ゲームがない。
- 短所①（実測）: **8759 バイトが無条件で全セッションに乗る**。append-only なので **平均 +2808 B/run で単調増加**し、上限方針を書ける場所がない（seeds 本体は不変が規約）。
- 短所②（実測・致命的）: seeds 原文には **2026-06-25 の「EH-3 が .sh をブロックするためファイル作成は Python 経由」がそのまま載っている**。これは #1104（OPEN / `bug(governance)`）で「Bash 経由の書き込みで HO / plan.md / forbidden_files / C-3 ゲートを全部迂回できる」と起票された迂回そのもの。**A 案は無フィルタなので、この迂回を全セッションに配布する**。
- 短所③: 自浄経路を置く場所がない（seeds は編集不可）。
- → **却下**。

#### B 案 — L1（plan / exec フェーズ）

- 長所: 使う場面でだけ読む。plan の Work Breakdown / Risks に直結（seeds-hygiene §還流の 2 番目「plan 生成時（フェーズ B）」に一致）。
- 短所①（issue 記載どおり）: **実装 phase より前の判断に効かない**。#1157 の実害 1 件目（「修正にも次のレビューラウンドを当てる」を 7 巡かけて再発見）は **レビュー/修正ループ中**の判断であり、plan フェーズの読み込みでは間に合わない。
- 短所②: L1 は「フェーズに応じて」の記述で **発火条件が曖昧**。AC-1 の「読まれたことの実測」を取りにくい（どのセッションで読まれるべきだったかが定義できない）。
- → 単独では不十分。**C 案の補助**として、plan フェーズに「digest + 関連 seeds 原文」を明示する形で併用する。

#### C 案 — digest を L0（**推奨**）

- 長所①: **既存機構の再利用**。正本（`seeds-hygiene.md`）・実体（`improvement-digest.md`）・還流先の規定（§還流に「Progressive Disclosure で参照」と明記）が **すべて既存**。追加するのは **`working-context.md` の表 1 行 + 運用規約**のみ。
- 長所②: **自浄を置ける唯一の層**。seeds は不変、digest は上書き再生成可（seeds-hygiene §出力）。AC-3 の superseded は digest にしか書けない。
- 長所③: サイズを規約で縛れる（§2.3）。seeds が 100 run 分に育っても L0 は 6 KiB 固定。
- 短所①（実測）: **鮮度管理が要る**。現行 digest は 2026-08-05 エントリ未取り込み。しかも **生成トリガー（skill / subcommand）が未実装**なので、放置すれば必ず stale になる。
- 短所②（実測）: **現状の digest は圧縮されていない**（§2.2、113%）。上限規約を同時に入れないと A 案に対する優位が出ない。
- 短所③（**最重要**）: **現行 digest #001 は誤った知見を「昇格」させている**（§4.1）。**中身を是正しないまま L0 に載せてはならない**。

#### D 案 — SessionStart hook で注入

- 実測: `.claude/settings.example.json` の `hooks` キーは `SessionStart` / `PreToolUse` / `PostToolUse` / `Stop`。`SessionStart` には既に 1 本（`scripts/gh-pin-account.sh`、#171）が配線済み → **追加自体は構造的に可能**。
- 長所: **AC-1（実際に読まれた）を機械的に満たせる唯一の案**。hook 側で「注入した」証跡を `docs/working/_audit/` に残せる。トークン量も N 件で制御できる。
- 短所①: **HO が 2 カテゴリ**（`.claude/settings*.json` + `scripts/hooks/*.sh` または `scripts/*.sh`）。適用が Human-owned で、apply script + dry-run + 再検証のサイクルが必要。
- 短所②（実測）: 既存 SessionStart hook は `_comment_` に「**失敗しても session は継続（exit code は無視される）**」と明記。**silent failure が構造化されている** → 「hook を置いた＝効いている」の誤認リスクが高い（メモリの「設定の存在は効いている証拠でない」に直撃）。
- 短所③: 注入内容が context の先頭に固定で入るため、digest 側のサイズ規約と二重管理になる。
- → **本文注入には使わない**。Phase 2 で **「読め」の 1 行 + 監査ログ追記**に限定し、**AC-1 の実測手段**として採る。

### 3.3 推奨構成

```text
Phase 1（本 issue の主スコープ / docs + HO patch 提示）
  C 案: L0 に improvement-digest.md を追加
      + digest サイズ hard cap 規約（seeds-hygiene.md 追記・非 HO）
      + superseded 自浄経路（同上）
  B 案: L1 plan フェーズに digest、L2 に seeds 原文（根拠確認時）
  前提条件: digest #001 の再生成（#4.4）— 別 PBI

Phase 2（follow-up / HO 2 カテゴリ）
  D 案: SessionStart hook で「digest 読み込み指示 + 監査ログ追記」
      → AC-1 の (b)(c) 実測を自動化
```

---

## 4. 自浄経路の設計（AC-3 / 最重要）

### 4.1 何が壊れているかの実測

issue は「append-only なので誤った知見が残り続ける」と書くが、**実測するとより悪い**:

| 段階 | 実測 |
| --- | --- |
| 2026-06-25 | seeds に「① **EH-3 が .sh 含む非 .md ファイルをブロックするためファイル作成は Python 経由**（`PLANGATE_HOOK_TASK` 設定）」を「次回再利用すべき判断」として記録 |
| 2026-07-07 | **digest #001 の「統合知見」節が、これを 2 エントリ横断の同一原因として統合し「恒常運用へ昇格すべき候補」と明記**。さらに「EH-3 対象ファイルへの書き込みは…**Python 経由…を初手の手順として選ぶ**」と手順化 |
| 同上 | **同 digest の「矛盾検出」節は「相反する判断は検出されなかった」と結論** |
| 2026-08-18 | 同じ迂回が **#1104**（OPEN / `bug(governance)`）として起票。**#833**（CLOSED）は既にこの迂回 3 件の再発防止 doc を入れていた |

→ **既存の hygiene（矛盾検出）は機能しなかった**。原因は「照合相手が seeds ↔ seeds に限られている」こと。**2 つの seeds エントリが同じ迂回を書いていれば、hygiene はそれを「矛盾」ではなく「頻出＝昇格候補」と読む。** 誤った知見ほど重複しやすいので、**現行 hygiene は誤りを増幅する向きにバイアスしている**。

**結論**: 自浄の欠落は「導線が無いから誰も気づかない」ではなく、**照合軸の欠落**である。そして **read-path を開通させると、この増幅済みの誤りが全セッションの初期条件になる** → **AC-3 は AC-1 の後続ではなく前提条件**。

### 4.2 設計（append-only を破らない）

**原則: 無効化は派生層（digest）にのみ書く。seeds 本体には 1 バイトも書かない。**

#### (1) 矛盾検出を 2 軸へ拡張（`seeds-hygiene.md` §処理 2 の追記 / 非 HO）

| 軸 | 照合相手 | 検出できるもの | 現状 |
| --- | --- | --- | --- |
| 軸 1 | seeds ↔ seeds | 異なる run が同一論点で相反する判断を書いた | **既存** |
| **軸 2** | **seeds ↔ 現行ガバナンス正本** | **知見が後にガバナンス違反 / 仕様変更で無効になった** | **新設** |

軸 2 の照合対象（すべて既存アーティファクト・追加実装不要）:

- HO 9 カテゴリの正本（`.claude/rules/mode-classification.md` の override ブロック）
- `docs/ai/*.md`（`hook-enforcement.md` / `settings-wiring-contract.md` / `project-rules.md` 等）
- **OPEN な `bug(governance)` / `governance` ラベル issue**（#1104 のように「知見が違反として起票された」ケース）
- `docs/working/incidents/`

#### (2) `superseded` マークの新設（既存 `resolved` と区別）

| マーク | 意味 | 判定基準 | 既存/新設 |
| --- | --- | --- | --- |
| `resolved` | **摩擦点**が仕組み（hook / script / 設定）で解消された | seeds-hygiene §処理 3 の (a)(b) | 既存 |
| **`superseded`** | **判断そのものが誤り**、または現行正本・ガバナンスに反する | 軸 2 で反証根拠（issue 番号 / 正本パス / commit）を 1 件以上特定できる | **新設** |

- `resolved` は「もう困らない」、`superseded` は「**やってはいけない**」。混同すると前者として黙って落ちるので、**明示的に別マークにする**。
- digest の構成に **「無効化済み知見（superseded）」節を新設**し、`現役知見` から外して**理由 + 反証根拠付きで残す**（削除しない = 監査性・再発時の照合可能性）。

digest の superseded エントリ形式（案）:

```text
### superseded: <知見の要約>
- 出典: improvement-seeds.md <日付エントリ> 「次回再利用すべき判断」①
- 無効化理由: <1〜2 行>
- 反証根拠: <issue / 正本パス / commit>
- 代替: <現行の正規経路。無ければ「代替なし（当該行為を行わない）」>
```

#### (3) 誰が無効化を判断するか

`seeds-hygiene.md` §責務分類 をそのまま踏襲し、**変更しない**:

| 作業 | 分類 |
| --- | --- |
| superseded 候補の検出・反証根拠の収集・digest への記述 | **AI-owned** |
| append-only 不変の機械検証 | **AI-owned** |
| **superseded の確定（＝ digest の採用 / PR マージ）** | **Human-owned（C-4）** |

→ **human confirm は必要**。ただし WF-06 の seeds 追記 confirm とは別物で、**digest PR の C-4 が兼ねる**（seeds-hygiene が既にそう定義済み）。**新しい承認境界を作らない**。

#### (4) append-only 規約との両立（検証）

`seeds-hygiene.md` §出力 が既に定めている不変検証コマンドが**そのまま通る**:

```sh
git diff --quiet origin/main -- docs/working/improvement-seeds.md
```

exit 0 = seeds 本体に差分なし。superseded は digest にしか書かないので、**本設計は append-only 規約を一切変更しない**（`retro-phase.md` §2「追記のみ・既存編集/削除しない」/ §4「人間 confirm でのみ追記」も不変）。

#### (5) 読み手側の優先順位規約（再汚染の防止）

無効化しても原文は seeds に残るため、**読み手が原文を先に読むと再汚染する**。よって:

- **L0 で読むのは digest のみ**。seeds 原文は **L2（根拠確認時）**。
- **digest の `superseded` が seeds 原文に優先する**（原文の日付が新しく見えても）。
- L0 の 1 行にこの優先関係を明記する（§6 の patch 本文に含む）。

#### (6) 初回適用対象（本設計書のスコープ外・別 PBI）

- 2026-06-25 エントリ ①（EH-3 → Python 経由）を **`superseded`**（反証根拠 **#1104 / #833**）
- digest #001「統合知見」の「恒常運用へ昇格すべき候補」を **撤回**
- 2026-08-05 エントリ（未取り込み）を digest に反映
- → **digest 再生成 PR**（`improvement-seeds.md` は不変）。#1157 の受入前提として先行またはセットで実施。

---

## 5. 受入基準の具体化（issue AC-1〜AC-5）

### AC-1: 「実際に読まれる」ことの実測（3 段・(a) だけでは不合格）

| 段 | 測るもの | 手段 | 合格条件 |
| --- | --- | --- | --- |
| **(a) 静的** | プロトコルに載ったか | `grep -qF 'improvement-digest.md' .claude/rules/working-context.md` | exit 0（**これ単独では AC-1 不合格**） |
| **(b) 実走** | セッションが**ファイルを開いたか** | セッションログ `~/.claude/projects/-Users-user-Documents-GitHub-plangate/<sessionId>.jsonl`（**実在確認済み**）に対し `grep -c 'improvement-digest'` | **新規セッション 3 本連続で ≥ 1** |
| **(c) canary** | **内容が文脈に入ったか** | digest 冒頭に読み取り確認トークン（例 `DIGEST-CANARY-<nnn>`）を置き、`working-context.md` L0 で「セッション最初の応答に canary ID を含める」ことを要求。同 jsonl を canary ID で grep | **3 本中 3 本で assistant 応答側にヒット** |

- **(b) と (c) の両方 PASS を AC-1 の合格条件とする。** (b) だけだと「開いたが読み飛ばした」を通してしまう。
- canary は **digest 再生成のたびに更新**する。これにより **stale digest を読んでいるセッション**も検出できる（古い canary が出たら digest が更新されていない or context が古い）。
- 測定は **Human 側の新規セッションで行う**（AI が自分のセッションで自作自演しない）。測定手順は `docs/working/_reports/` に測定ログとして残す。

### AC-2: トークン予算

| 項目 | 値 | 検証 |
| --- | --- | --- |
| 追加読み込み量（実測） | **現行 digest 4620 バイト**（L0 既存 `CLAUDE.md` 6572 B に対し +70%、`working-context.md` 25089 B に対し +18%） | `wc -c docs/working/improvement-digest.md` |
| 上限方針 | **6144 バイト hard cap** / 現役知見 12 項目 / 1 項目 2 行 | `test "$(wc -c < docs/working/improvement-digest.md)" -le 6144` |
| seeds 本体 | **L0 に載せない**（3 run で 8759 B、平均 +2808 B/run で単調増加） | — |

### AC-3: 自浄

| 検証 | コマンド / 手順 |
| --- | --- |
| `superseded` 節の仕様が正本にある | `grep -qF 'superseded' docs/ai/seeds-hygiene.md` |
| 矛盾検出 軸 2 が正本にある | `grep -qF 'ガバナンス' docs/ai/seeds-hygiene.md`（追記後） |
| 初回 1 件が処理されている | digest に EH-3 迂回の superseded エントリ（反証 #1104）が存在 |
| **append-only 不変** | `git diff --quiet origin/main -- docs/working/improvement-seeds.md` → **exit 0** |
| 承認境界不変 | `retro-phase.md` §1/§4 に差分なし（`git diff --quiet origin/main -- docs/ai/retro-phase.md`） |

### AC-4: digest と seeds の関係の明確化

- digest 冒頭に **「正本 = `improvement-seeds.md` / 本書 = 派生・参照入力 / 生成 = 手動（トリガー実装は未）/ 採用 = Human-owned（C-4）」** を定型ヘッダとして明記（§1.2-4 の表の内容）。
- `working-context.md` の seeds 節（`:137-144`）に digest への相互参照を 1 行追加（§6 patch）。
- **既知ギャップとして起票推奨**: seeds-hygiene §実行トリガーが宣言する skill / `bin/plangate` サブコマンドが**未実装**（§1.2-3）。本 issue のスコープ外だが、鮮度管理（C 案の主な短所）の根本原因なのでフォローアップ issue にする。

### AC-5: テスト

- `sh tests/run-tests.sh` の **baseline を着手時に再測定**し、**新規 FAIL 0** で判定。
- **絶対件数を契約値にしない**（成長するディレクトリへの assertEqual を置かない）。
- 本設計書自体は `docs/working/_reports/` 配下の新規 1 ファイルのみで、テスト対象コードに触れない。

---

## 6. 提示する差分（patch）— **適用は Human**

### 6.1 対象ファイルと責務

| ファイル | HO | 責務 |
| --- | --- | --- |
| `.claude/rules/working-context.md` | **YES**（`.claude/rules/*.md`） | **AI は patch 提示まで / 適用は Human** |
| `plugin/plangate/rules/working-context.md` | NO（ただし**ミラー**） | 同時適用が必要。**実測: 現状 `diff` 結果 0 = 完全一致**。`scripts/sync-plugin-plangate.sh:144` が `agents / rules / commands` を同期対象にしているため、**片側だけ変えるとミラーが drift する** |
| `docs/ai/seeds-hygiene.md` | NO | AI-owned（サイズ規約 / superseded / 軸 2 の追記） |
| `docs/working/improvement-digest.md` | NO | AI-owned 生成 / **採用は Human-owned（C-4）** |
| `docs/working/improvement-seeds.md` | — | **触らない**（append-only 正本） |

### 6.2 `working-context.md` L0 表の差分（before / after）

**before**（`:87-89`）:

```text
| Level | 対象ファイル | 読み込みタイミング |
|-------|------------|-----------------|
| **L0**（常に読む） | INDEX.md → current-state.md | セッション開始時に最初に読む |
```

**after**:

```text
| Level | 対象ファイル | 読み込みタイミング |
|-------|------------|-----------------|
| **L0**（常に読む） | INDEX.md → current-state.md → `docs/working/improvement-digest.md` | セッション開始時に最初に読む |
```

**L1 行への追記**（B 案・補助）:

```text
| | plan → pbi-input.md, `docs/working/improvement-digest.md`（現役知見 / Risks 参考） | plan フェーズで読む |
```

**L2 行への追記**（根拠確認時のみ原文）:

```text
| **L2**（根拠が必要な時のみ） | evidence/{該当ディレクトリ}, decision-log.jsonl, `docs/working/improvement-seeds.md`（digest の根拠原文） | レビュー根拠の確認・振返り時 |
```

**「セッション開始時」手順への追記**（`:297-299` の直後）:

```text
5. `docs/working/improvement-digest.md`（過去 run の現役知見）を読む（L0）。
   本 digest は派生物で、正本は `docs/working/improvement-seeds.md`（append-only）。
   **`superseded` とマークされた知見は無効**であり、seeds 原文の記述より digest の
   superseded 判定が優先する。digest は参照入力であり、C-3 / C-4 の承認境界を
   緩和する根拠にはしない（`docs/ai/seeds-hygiene.md` §還流）。
```

**seeds 節（`:137-144`）末尾への 1 行**:

```text
統合（重複統合 / 矛盾検出 / 陳腐化判定）と読み出し用の圧縮版は
`docs/working/improvement-digest.md`（正本仕様 `docs/ai/seeds-hygiene.md`）。
```

> 既存の `scripts/apply-quality-command-gate.sh` は `### improvement-seeds.md（WF-06 Retro / opt-in・append-only）` を**アンカー文字列として使用中**。**この見出し行は変更しないこと**（変更するとアンカー不一致で当該 script が `ERROR: アンカー ... が見つかりません` で失敗する）。上記は節**末尾への追記**なので見出しは不変。

### 6.3 適用スクリプトの設計

既存パターン（`scripts/apply-quality-command-gate.sh`）を踏襲する:

- 名前: `scripts/apply-seeds-read-path.sh`（**AI が作成、Human が実行**）
- 引数: `--dry-run` | `--apply`（両方必須指定・既存と同一 UX）
- `--apply` 時は「Human-owned 操作」警告を stderr に出す
- **冪等**: `grep -qF 'improvement-digest.md' "$TARGET"` で適用済みなら `SKIP` して exit 0
- **アンカー検証**: L0 表の行 `| **L0**（常に読む） | INDEX.md → current-state.md |` を `grep -qF` で確認し、無ければ「構造変更の可能性」として exit 1（**行番号でアンカーしない** — 行番号アンカーは実装移動で黙って別ブロックを指す）
- **2 ターゲット同時適用**: `.claude/rules/working-context.md` と `plugin/plangate/rules/working-context.md` を両方処理し、片側だけ成功して終わらない（どちらかがアンカー不一致なら**両方とも書かずに** exit 1）
- 適用後の再検証: `diff .claude/rules/working-context.md plugin/plangate/rules/working-context.md` が exit 0

### 6.4 Mode / ゲート

- **Mode: standard**。ただし HO パス（`.claude/rules/*.md`）に触れるため
  **`lite_eligible=false` / Standard・同期 C-3 固定**（`mode-classification.md`「承認境界周辺の変更 → 最低 high」/ `working-context.md` AC-10 Hardening Override）。
- **doc-light は適用不可**（`.claude/rules/*.md` は HO 対象の `.md` → 除外条件に該当）。
- Phase 2（D 案）は `.claude/settings*.json` に触れるため **別 PBI**（self-mod guard / apply script + doctor 再検証）。

---

## 7. リスクと未解決事項

| # | 内容 | 深刻度 | 対応 |
| --- | --- | --- | --- |
| R-1 | **digest #001 が誤った知見（EH-3 迂回 = #1104）を「昇格候補」として含む**。是正前に L0 へ載せると全セッションに配布される | **critical** | **digest 再生成を #1157 の受入前提にする**（§4.6）。read-path 開通と同一 PR かその前 |
| R-2 | digest の生成トリガー（skill / `bin/plangate` サブコマンド）が seeds-hygiene で宣言されているのに**未実装** → 鮮度が構造的に劣化する（実測: 45 日 stale） | major | フォローアップ issue（AC-4 の「既知ギャップ」）。canary（AC-1 (c)）が stale 検出を兼ねる |
| R-3 | 現行 digest は**圧縮されていない**（113%）ため、上限規約なしでは C 案の利点が出ない | major | §2.3 の hard cap を `seeds-hygiene.md` に追記（非 HO） |
| R-4 | ミラー `plugin/plangate/rules/working-context.md` の drift。**parity を強制する test は存在しない**（`git grep -ln 'plugin/plangate/rules' -- tests scripts .github` → apply script 2 本のみ、tests は 0 件） | minor | apply script で 2 ターゲット同時適用 + 適用後 `diff` 検証（§6.3） |
| R-5 | D 案の SessionStart hook は **exit code が無視される**設計（既存 hook の `_comment_` に明記）→ silent failure | minor | Phase 2 で採る場合は hook 自身に監査ログ追記を持たせ、**ログの有無**で発火を判定する（hook の存在で判定しない） |
| R-6 | superseded 判定が過剰だと、正しい知見まで落ちる | minor | superseded は **反証根拠（issue / 正本パス / commit）必須**。根拠を示せないものは「現役」のまま残す（seeds-hygiene §処理 3 の安全側と同じ扱い） |

---

## 8. スコープ外（本設計書では手を出さない）

- `docs/working/improvement-seeds.md` への追記・編集（human confirm 必須の append-only 資産）
- `.claude/rules/` / `.claude/settings*.json` の実適用（**Human-owned**）
- digest の再生成そのもの（別 PBI。本書は要件と前提条件を定義するのみ）
- WF-06 の opt-in / 既定 OFF / human confirm（issue の Out of scope）
- seeds-hygiene のトリガー実装（skill / CLI サブコマンド）

---

## 9. 実測コマンド一覧（再現用）

```sh
wc -lc docs/working/improvement-seeds.md docs/working/improvement-digest.md
git log --format='%h %ad %an %s' --date=short -- docs/working/improvement-digest.md
git log --format='%h %ad %an %s' --date=short -- docs/working/improvement-seeds.md
git grep -ln 'improvement-seeds\|improvement-digest\|seeds-hygiene' -- scripts bin .github tests
grep -c 'digest' bin/plangate
git grep -n 'improvement-digest' -- .claude
diff .claude/rules/working-context.md plugin/plangate/rules/working-context.md
awk '/^## /{n++} {if(n>0) b[n]+=length($0)+1} END{for(i=1;i<=n;i++) printf "entry%d bytes=%d\n", i, b[i]}' docs/working/improvement-seeds.md
ls -d ~/.claude/projects/*plangate*
```

## 10. 関連

- issue: #1157 / #754（seeds-hygiene 起源）/ #1104・#833（EH-3 迂回）/ #1006（最新 seeds 追記）/ #200 / #228 / #231 / #235 / #1035 / #1135
- 正本: `docs/ai/seeds-hygiene.md` / `docs/ai/retro-phase.md` / `docs/workflows/06_retro.md` / `.claude/rules/working-context.md` / `.claude/rules/responsibility-classes.md` / `.claude/rules/mode-classification.md`
