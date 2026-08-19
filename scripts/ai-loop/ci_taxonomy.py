#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
# sh はこのファイルの module docstring を二重引用符文字列として読むため、
# docstring 内のバッククォートがコマンド置換として評価され、repo を書き換える
# 副作用が起きる。python3 以外のインタプリタでは何も評価する前にここで止める。
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

from __future__ import annotations

__doc__ = """ci_taxonomy.py — snapshot の `ci_failure_taxonomy` の**供給主体**（TASK-0917 / #917 AC-8）。

契約正本: docs/working/TASK-0917/plan.md 論点 D3 `ci_failure_taxonomy` 行。

なぜ「読むだけ + 狭い allowlist」なのか（設計理由の要約）:
実 CI（`.github/workflows/ci.yml` / `test.yml`）は全ジョブが単発 shell 実行で
retry / JUnit 構造化出力 / flaky マーカーを持たないため、`code` / `flaky` /
`environment` を機械が判別する信号が事実上ない。したがって

  1. **既定は manual entry を読むだけ**（`record.jsonl` に人間 or 別層が明示した
     `kind="ci_taxonomy"` / `source="manual"` の entry を正とする）
  2. **補助的に狭い allowlist 自動分類**（既知の環境要因パターンに一致した時のみ
     `environment`）
  3. **`code` を機械が積極的に断定しない**（自動分類の値域は `environment` のみ）
  4. **未該当は taxonomy を出力しない** → `delivery.py` の既存 fail-closed
     （`ci_failure_taxonomy` がキー欠落 / enum 外 → `HUMAN_ESCALATED`）に委ねる

設計原則（delivery.py / plan_package.py と同型）:
- 決定論: 同一入力 → 同一出力。now() も乱数も参照しない
- fail-closed: 判定不能・enum 外・head 不一致・改竄兆候は**出力しない / 例外**
- **外部作用ゼロ**: ネットワーク・プロセス起動を一切行わない（`record.jsonl` の
  読み取りのみ。`check_exec_boundary.py` の検査対象）

AC-8 のモジュール境界（供給主体として機械的に特定できる関数）:
    load_record_entries() / manual_taxonomy() / classify_log() /
    resolve_taxonomy() / apply_to_snapshot()
"""

import pathlib
import sys
from typing import NamedTuple

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import delivery  # noqa: E402  taxonomy enum と record 契約の単一定義（再実装しない）

#: 供給主体の自己申告（doc / 監査から機械的に辿るためのアンカー）。
SUPPLIER_MODULE = "scripts/ai-loop/ci_taxonomy.py"

#: 出力しうる値。**`delivery.py` の enum を単一ソースとして再利用**する
#: （ここで独自定義すると enum drift で `HUMAN_ESCALATED` が恒久化する）。
VALID_TAXONOMY = delivery.VALID_TAXONOMY_REPAIR

#: snapshot 上のキー名（欠落 = 「出力しない」）。
SNAPSHOT_KEY = "ci_failure_taxonomy"

#: manual entry の contract（`record.jsonl` の 1 行）。
#: `{"kind": "ci_taxonomy", "source": "manual", "pr_number": int,
#:   "head_sha": str, "taxonomy": "code"|"flaky"|"environment"}`
MANUAL_ENTRY_KIND = "ci_taxonomy"
MANUAL_SOURCE = "manual"


class AutoRule(NamedTuple):
    """自動分類ルール 1 件。`pattern` は**小文字**の部分一致キーワード。"""

    pattern: str
    taxonomy: str


#: 狭い自動分類 allowlist。**値域は `environment` のみ**（`code` / `flaky` を
#: 機械が断定しない）。拡張する場合も environment 以外を足さないこと
#: （`test_ci_taxonomy.py` が値域を固定している）。
AUTO_RULES: tuple[AutoRule, ...] = (
    AutoRule("rate limit", "environment"),
    AutoRule("econnreset", "environment"),
    AutoRule("runner has received a shutdown signal", "environment"),
)


# ---------------------------------------------------------------------------
# record.jsonl 読み取り（delivery の record 契約を再利用）
# ---------------------------------------------------------------------------

def load_record_entries(path) -> list:
    """`record.jsonl` を読む。存在しなければ空リスト。

    破損行 / `entry_id` 改竄は `delivery.RecordError` を**そのまま伝播**する
    （黙って「taxonomy なし」に潰すと改竄兆候が消えるため。呼び出し側
    Collector が `escalation_flags` に理由コードを積む）。
    """
    return delivery.load_entries(path)


# ---------------------------------------------------------------------------
# manual entry（既定経路）
# ---------------------------------------------------------------------------

def manual_taxonomy(entries, pr_number, head_sha):
    """当該 PR / head に束縛された manual taxonomy entry を返す（無ければ None）。

    受理条件（すべて満たすときのみ）:
    - `kind == "ci_taxonomy"` かつ `source == "manual"`
      （機械が書いた entry を manual 経路で受理しない = `code` の機械断定を防ぐ）
    - `pr_number` / `head_sha` が現在の評価対象と一致（旧 head の流用を防ぐ）
    - `taxonomy` が `VALID_TAXONOMY` の 3 値
    複数該当する場合は **file 順で最後**（＝最新の追記）を採用する。
    """
    found = None
    for e in entries or ():
        if not isinstance(e, dict):
            continue
        if e.get("kind") != MANUAL_ENTRY_KIND or e.get("source") != MANUAL_SOURCE:
            continue
        if e.get("pr_number") != pr_number or e.get("head_sha") != head_sha:
            continue
        tax = e.get("taxonomy")
        if tax in VALID_TAXONOMY and isinstance(tax, str):
            found = tax
    return found


# ---------------------------------------------------------------------------
# 自動分類（補助経路・狭い allowlist）
# ---------------------------------------------------------------------------

def classify_log(log_text, rules=None):
    """CI ログ本文から `environment` を判定する（該当なしは None）。

    `rules` を渡すと allowlist を差し替えられる（テストの変異注入用）。
    """
    if rules is None:
        rules = AUTO_RULES
    if not isinstance(log_text, str) or not log_text:
        return None
    lowered = log_text.lower()
    for rule in rules:
        if rule.pattern in lowered:
            return rule.taxonomy
    return None


# ---------------------------------------------------------------------------
# 供給本体
# ---------------------------------------------------------------------------

def resolve_taxonomy(*, pr_number, head_sha, entries=(), log_text="", rules=None):
    """`ci_failure_taxonomy` を決める（manual 優先 → 自動 allowlist → None）。

    None は「分類できなかった」を意味し、**snapshot に載せない**のが正しい扱い
    （`apply_to_snapshot()` 参照）。`delivery.py` はキー欠落を repair 対象外と
    して `HUMAN_ESCALATED` に倒す（既存 fail-closed）。
    """
    manual = manual_taxonomy(entries, pr_number, head_sha)
    if manual is not None:
        return manual
    return classify_log(log_text, rules=rules)


def apply_to_snapshot(snapshot, taxonomy):
    """snapshot の複製に taxonomy を載せて返す（`None` のときは**キーを作らない**）。

    入力 snapshot は変更しない（純関数）。enum 外の値は `ValueError`
    （`delivery.py` が未知値として escalate する前に供給側で止める）。
    """
    out = dict(snapshot)
    if taxonomy is None:
        out.pop(SNAPSHOT_KEY, None)
        return out
    if taxonomy not in VALID_TAXONOMY:
        raise ValueError(
            f"{SNAPSHOT_KEY} が enum 外: {taxonomy!r}（許容: {tuple(VALID_TAXONOMY)}）")
    out[SNAPSHOT_KEY] = taxonomy
    return out
