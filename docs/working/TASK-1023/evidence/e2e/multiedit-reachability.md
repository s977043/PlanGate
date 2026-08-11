# MultiEdit 到達性の実測（TC-21b / R-034 / G-9 分岐入力）

- 測定日: 2026-08-10（UTC）
- 測定環境: Claude Code **2.1.226**（`claude --version` 実測）/ macOS (Darwin 25.6.0)
- 測定者: exec ワーカー（fix/1023-exec / base `5e630f9`）

## 判定: **到達しない** → G-9 = (i)

現行の configured Claude Code（2.1.226）では **`MultiEdit` という tool 自体が存在しない**ため、
matcher `Edit|Write` の部分一致/完全一致以前に、PreToolUse hook へ到達する経路が無い。

## 実測証跡

1. **tool inventory（本セッション実測）**: Claude Code 2.1.226 のエージェントセッションで
   利用可能な tool 一覧（プライマリ + deferred の全列挙）に `MultiEdit` が**含まれない**。
   編集系は `Edit` / `Write` / `NotebookEdit` のみ。deferred 一覧（ToolSearch 対象）にも無い。
   存在しない tool は発行できず、PreToolUse イベント自体が発生しない。
2. **ローカル全セッションログの全数走査**: `~/.claude/projects/` 配下の全 `.jsonl` を
   `"type":"tool_use"` かつ `"name":"MultiEdit"` で走査 → **0 件**。
   `MultiEdit` の文字列出現はいずれも本文テキスト（ドキュメント引用）であり tool_use ではない。
3. **hook 監査ログ**: `docs/working/_audit/` に `MultiEdit` を含むイベント **0 件**。
4. **配線実測（read-only）**: 適用済み `/Users/user/Documents/GitHub/plangate/.claude/settings.json`
   の token guard 配線は `"matcher": "Edit|Write"`（L98）と `"matcher": "Bash"`（L107）の 2 本
   （plan の想定どおり）。`settings.example.json` も同一（L68/L78）。

## 限定条件（否定宣言に併記すべき事項）

- 本判定は **Claude Code 2.1.226（現行運用バージョン）に対する実測**。`MultiEdit` を持つ
  旧バージョン / 他ハーネスでは前提が変わる。そのため **script 側は G-8 裁定（固定 4 種）どおり
  `MultiEdit` を parsed-safe 集合に含めたまま**とし、payload が届いた場合の判定は保持する
  （script レベル TC-22a/22b/22c は維持）。
- matcher `Edit|Write` が `MultiEdit` 文字列にマッチするか（部分一致仕様か）は、tool が存在しない
  ため**本環境では検証不能**（未確定のまま。到達性の結論には影響しない）。

## G-9 分岐の帰結（(i)）

- AC-11 / TC-21 / T-09 の E2E 対象から `MultiEdit` を外す（E2E は Edit / Write / Bash の 3 surface）
- security closure の宣言は **Edit / Write / Bash の 3 surface**
- `MultiEdit` は否定宣言側（閉じない一覧）へ移す: 「現行 Claude Code 2.1.226 に tool 自体が
  存在せず経路なし。tool が存在する環境では script は対応済みだが、配線（matcher）は未検証」
- settings patch は**不要**（settings 不変・本 PBI 内で完結）
