#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/openkey-oracle/build.sh

INITIALS=( "" b c ch d dd g gh h kh l m n ng ngh nh ph qu r s t th tr v x )
VOWELS=( a aa aw e ee i o oo ow oa oe u uw uo uow uoi uyee ie ye )
TONES=( "" s f r x j )
FINALS=( "" c ch m n ng nh p t )

OUT=Tests/Fixtures/parity-corpus.json
{
  # build input list
  for ini in "${INITIALS[@]}"; do
    for v in "${VOWELS[@]}"; do
      for t in "${TONES[@]}"; do
        for fin in "${FINALS[@]}"; do
          printf '%s%s%s%s\n' "$ini" "$v" "$t" "$fin"
        done
      done
    done
  done
  # curated real words (Telex keystrokes)
  printf 'tieesng\nvieejt\nnguwowif\nddaay\nquoocs\nhojc\nthuyr\nchaof\nddoongf\n'
} | sort -u | scripts/openkey-oracle/oracle | python3 -c '
import sys, json
rows=[]
for line in sys.stdin:
    parts=line.rstrip("\n").split("\t")
    if len(parts)!=3: continue
    rows.append({"input":parts[0],"modern":parts[1],"classic":parts[2]})
json.dump(rows, open("'"$OUT"'","w"), ensure_ascii=False, indent=0)
print(f"wrote {len(rows)} rows to '"$OUT"'")
'
