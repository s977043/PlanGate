#!/bin/sh
# TASK-0134(#571): bin/plangate に並列レビュー --progress ライブ進捗を追加
# HO 対象(bin/plangate)のため AI は本 script を生成のみ。適用は人間。冪等。
set -e
cd "$(git rev-parse --show-toplevel)"
F="${1:-bin/plangate}"
if grep -q '_rp_progress' "$F"; then echo "already applied: $F"; exit 0; fi
python3 - "$F" <<'INNER'
import sys
f = sys.argv[1]
s = open(f, encoding="utf-8").read()

PROG = '''  if [ "$_rp_progress" = "1" ]; then
    _rp_seen_count=0
    _rp_printed_count=0
    while [ "$_rp_seen_count" -lt "$_rp_count" ]; do
      _rp_seen_count=0
      _rp_pi=0
      while [ "$_rp_pi" -lt "$_rp_count" ]; do
        if [ -f "$_rp_tmpdir/done_$(printf '%03d' "$_rp_pi")" ]; then
          _rp_seen_count=$((_rp_seen_count + 1))
          if [ ! -f "$_rp_tmpdir/seen_$(printf '%03d' "$_rp_pi")" ]; then
            : > "$_rp_tmpdir/seen_$(printf '%03d' "$_rp_pi")"
            _rp_printed_count=$((_rp_printed_count + 1))
            _rp_pstat=$(cat "$_rp_tmpdir/status_$(printf '%03d' "$_rp_pi")" 2>/dev/null || echo 1)
            _rp_pprov=""
            [ -f "$_rp_tmpdir/spec_$(printf '%03d' "$_rp_pi")" ] && _rp_pprov=$(sed -n 's/^provider=//p' "$_rp_tmpdir/spec_$(printf '%03d' "$_rp_pi")")
            if [ "$_rp_pstat" = "0" ]; then _rp_pres="ok"; else _rp_pres="failed"; fi
            printf '[done %s/%s] %s %s\\n' "$_rp_printed_count" "$_rp_count" "$_rp_pprov" "$_rp_pres"
          fi
        fi
        _rp_pi=$((_rp_pi + 1))
      done
      [ "$_rp_seen_count" -lt "$_rp_count" ] && sleep 1
    done
  fi

'''

reps = [
  # R1: cmd_review に progress フラグ初期化
  ('  phase="c2"\n  while [ $# -gt 0 ]; do',
   '  phase="c2"\n  _review_progress=0\n  while [ $# -gt 0 ]; do'),
  # R2: --progress 引数解析（--file の後・esac の前）
  ('''      --file)
        shift
        ;;  # --file is accepted but unused in this version; kept for future use
    esac''',
   '''      --file)
        shift
        ;;  # --file is accepted but unused in this version; kept for future use
      --progress)
        _review_progress=1
        ;;
    esac'''),
  # R3: _review_parallel 冒頭で progress フラグを参照（引数シグネチャ不変）
  ('  _rp_reviewers_yaml=$5\n',
   '  _rp_reviewers_yaml=$5\n  _rp_progress="${_review_progress:-0}"\n'),
  # R4: 子プロセス完了 sentinel（done_NNN）— R-001 未完了/完了後欠落の区別
  ('      (eval "$command" > "$_rp_out_file" 2>&1; echo $? > "$_rp_status_file") &',
   '      (eval "$command" > "$_rp_out_file" 2>&1; echo $? > "$_rp_status_file"; : > "$_rp_tmpdir/done_$(printf \'%03d\' "$_rp_idx")") &'),
  # R5: wait 前にライブ進捗ポーリング
  ('    _rp_idx=$((_rp_idx + 1))\n  done\n\n  wait\n',
   '    _rp_idx=$((_rp_idx + 1))\n  done\n\n' + PROG + '  wait\n'),
]

for old, new in reps:
    assert old in s, "anchor not found: " + repr(old[:60])
    assert s.count(old) == 1, "ambiguous (%d): %s" % (s.count(old), repr(old[:60]))
    s = s.replace(old, new)

open(f, "w", encoding="utf-8").write(s)
print("applied --progress to", f)
INNER
echo "DONE. git diff bin/plangate で確認し、TASK-0134 ブランチにコミットしてください。"
