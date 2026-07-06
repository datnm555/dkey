#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/openkey-oracle/build.sh

# VNI đ initial is "d9" (d then the 9 key), not "dd9" (that yields literal d + đ).
INITIALS=( "" b c ch d d9 g gh h kh l m n ng ngh nh ph qu r s t th tr v x )
VOWELS=( a a6 a8 e e6 i o o6 o7 u u7 oa oe uo u7o7 u7o7i ie6 ye6 oo aa ee w uw uu )
TONES=( "" 1 2 3 4 5 )
FINALS=( "" c ch m n ng nh p t )

OUT=Tests/Fixtures/parity-corpus-vni.json
{
  for ini in "${INITIALS[@]}"; do
    for v in "${VOWELS[@]}"; do
      for t in "${TONES[@]}"; do
        for fin in "${FINALS[@]}"; do
          printf '%s%s%s%s\n' "$ini" "$v" "$t" "$fin"
        done
      done
    done
  done
} | sort -u | scripts/openkey-oracle/oracle vni | python3 -c '
import sys, json
rows=[]
for line in sys.stdin:
    parts=line.rstrip("\n").split("\t")
    if len(parts)!=3: continue
    rows.append({"input":parts[0],"modern":parts[1],"classic":parts[2]})
json.dump(rows, open("'"$OUT"'","w"), ensure_ascii=False, indent=0)
print(f"wrote {len(rows)} rows to '"$OUT"'")
'
