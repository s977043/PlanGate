#!/bin/sh
# TC-A6a: シンボル越境検査（AC-6）
# 使い方:
#   T-01（適用前・ゲート未作成）: sh tc-a6a.sh "421-521" "558-730"
#   T-02 以降（適用後）:          sh tc-a6a.sh "<動的導出A>" "<動的導出B>"
# 動的導出は plan「T-01 のシンボル越境検査の実装」の awk を使い、必ず本スクリプトの
# 内包アサーションを通す（awk 単体は桁 0 の `fi` で範囲を黙って打ち切る fail-open）。
F=tests/extras/ta-26-plugin-sync.sh
A="$1"; B="$2"

# ---- (1) 範囲の内包アサーション（C-2 R-002a）------------------------------
_in() { lo=${1%-*}; hi=${1#*-}; [ "$2" -ge "$lo" ] && [ "$2" -le "$hi" ]; }
miss=0
for pair in "A:$A:20 21 22 23 24 25" "B:$B:26 27 28 29 32 34 35 36"; do
  g=${pair%%:*}; rest=${pair#*:}; rng=${rest%%:*}; tcs=${rest#*:}
  for n in $tcs; do
    ln=$(grep -nE "^[[:space:]]*# TC-$n:" "$F" | head -1 | cut -d: -f1)
    if [ -z "$ln" ]; then echo "MISSING header TC-$n"; miss=$((miss + 1)); continue; fi
    _in "$rng" "$ln" || { echo "OUT-OF-RANGE gate $g: TC-$n at L$ln not in $rng"; miss=$((miss + 1)); }
  done
done

# ---- (1b) 範囲の排他アサーション（広がる側の fail-open / river-review major）--
for n in 30 33; do
  ln=$(grep -nE "^[[:space:]]*# TC-$n:" "$F" | head -1 | cut -d: -f1)
  if [ -z "$ln" ]; then echo "MISSING header TC-$n"; miss=$((miss + 1)); continue; fi
  for pair in "A:$A" "B:$B"; do
    g=${pair%%:*}; rng=${pair#*:}
    ! _in "$rng" "$ln" || { echo "IN-RANGE gate $g: TC-$n at L$ln is inside $rng (ゲート外に残すべき TC)"; miss=$((miss + 1)); }
  done
done

echo "containment_violations=$miss"
[ "$miss" -eq 0 ] || { echo "FAIL: ゲート範囲が期待 TC を内包していない / ゲート外に残すべき TC を飲み込んでいる"; exit 1; }

# ---- (2) 識別子収集 + (3) 範囲外参照の全数照合 -----------------------------
awk -v ranges="$A $B" '
  function inside(l,  i){ for(i=1;i<=nr;i++) if(l>=lo[i]&&l<=hi[i]) return 1; return 0 }
  BEGIN{
    nr=split(ranges,R,/ +/)
    for(i=1;i<=nr;i++){ split(R[i],P,"-"); lo[i]=P[1]+0; hi[i]=P[2]+0 }
  }
  { L[NR]=$0; IN[NR]=inside(NR) }
  END{
    ndef=0
    for(i=1;i<=NR;i++){
      if(!IN[i]) continue
      s=L[i]
      while(match(s,/(^|;|\|\||&&)[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=/)){
        tok=substr(s,RSTART,RLENGTH)
        sub(/^(;|\|\||&&)?[[:space:]]*/,"",tok); sub(/=$/,"",tok)
        if(tok!="" && !(tok in def)){ def[tok]=i; ndef++ }
        s=substr(s,RSTART+RLENGTH)
      }
      if(match(L[i],/^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*\(\)/)){
        fn=substr(L[i],RSTART,RLENGTH)
        sub(/^[[:space:]]*/,"",fn); sub(/\(\)$/,"",fn)
        if(!(fn in def)){ def[fn]=i; ndef++ }
        isfn[fn]=1
      }
    }
    hits=0
    for(k in def){
      for(i=1;i<=NR;i++){
        if(IN[i]) continue
        if(k in isfn) pat="(^|[^A-Za-z0-9_$])" k "([^A-Za-z0-9_]|$)"
        else          pat="\\$[{]?" k "([^A-Za-z0-9_]|$)"
        if(L[i] ~ pat){ printf "CROSS %s (def L%d) <- L%d: %s\n", k, def[k], i, L[i]; hits++ }
      }
    }
    printf "identifiers=%d crossings=%d\n", ndef, hits
    exit (hits>0)?1:0
  }
' "$F"
