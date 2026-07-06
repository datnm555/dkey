#!/usr/bin/env bash
# gen-convert-corpus.sh — generate Tests/Fixtures/convert-corpus.json
# using the OpenKey convert-oracle in lower case-mode.
#
# Each input word gets a trailing space so no Vietnamese character is ever last
# (avoids OpenKey's last-char two-byte-split bug).
# Oracle runs with convertToolToAllNonCaps=true (lower mode).
# Only encode direction: from=0 (Unicode) → to ∈ {1,2,3,4}.
#
# Usage: bash scripts/gen-convert-corpus.sh
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/openkey-oracle/build.sh

# Vietnamese syllable corpus — covers all vowel+tone+mark combinations
# (lowercase; upper-case parity is not tested here — see Task 3 note).
WORDS=$(cat Tests/Fixtures/vietnamese-words.txt 2>/dev/null || printf \
'tiếng\nviệt\nđồng\nxin chào\nngôn ngữ\nphát triển\nnhững\nương\nquốc\nhoà\n'\
'ân\nân đức\nbác\nbàn\nbằng\nbề\nbếp\nbị\nbộ\nbởi\n'\
'cả\ncần\ncất\ncầu\ncây\ncố\ncổ\ncổ phần\ncột\ncùng\n'\
'dài\ndạy\ndiệt\ndiều\ndù\ndưới\nđã\nđất\nđầu\nđình\n'\
'đô\nđồ\nđủ\nđức\nđường\ngiá\ngiải\ngiọng\ngiống\ngiúp\n'\
'hà\nhành\nhẹ\nhết\nhình\nhò\nhỏ\nhọc\nhồ\nhổ\n'\
'già\ngiàu\nkể\nkhó\nkhỏe\nkhổ\nkhỗ\nkhởi\nkhống\nkhuôn\n'\
'là\nlành\nlần\nlặng\nlắm\nlẽ\nlề\nlệ\nlề lối\nlịch\n'\
'mà\nmặc\nmạnh\nmắt\nmẫu\nmề\nmẹ\nmọi\nmổ\nmột\n'\
'nào\nnặng\nnắng\nnếu\nngã\nnhà\nnhề\nnhư\nnữa\nnước\n'\
'ồn\nổn\nổng\nơi\nơn\nớn\nướt\nướng\nười\nường\n'\
'phải\nphần\nphố\nquả\nquan\nquân\nquè\nrẽ\nrề\nrộng\n'\
'sách\nsẽ\nsiêu\nsợ\nsứ\ntài\ntặng\ntất\ntầm\ntế\n'\
'thà\nthấy\nthề\nthế\nthể\nthị\nthọ\nthổ\nthời\nthuần\n'\
'trà\ntránh\ntrị\ntriều\ntróc\ntrộm\ntừ\ntứ\ntường\nưa\n'\
'vài\nvẫn\nvề\nvẽ\nvị\nvồ\nvợ\nvội\nvùng\nvưng\n'\
'xã\nxảy\nxem\nxế\nxiêu\nxin\nxổ\nxứng\nyên\nýu\n'\
'âm\nâu\nầu\nầm\nấm\nấn\nẩm\nẩn\nẫu\nận\n'\
'ê\nêm\nếm\nềm\nểm\nễm\nệm\nôm\nốm\nồm\n'\
'ổm\nỗm\nộm\nơm\nớm\nờm\nởm\nỡm\nợm\núm\n'\
'ùm\nủm\nũm\nụm\nưm\nứm\nừm\nửm\nữm\nựm\n'\
'ia\niên\niếng\niệng\nưa\nươi\nương\nướng\nướt\nước\n'\
'oa\noam\noàn\noảnh\noãn\noan\noán\noằng\nwang\nwoan\n')

OUT=Tests/Fixtures/convert-corpus.json
{
  while IFS= read -r w; do
    [ -z "$w" ] && continue
    for to in 1 2 3 4; do
      # NOTE: trailing space after $w so no Vietnamese char is last
      printf '%s\t%s\t%s \n' "0" "$to" "$w"
    done
  done <<< "$WORDS"
} | scripts/openkey-oracle/convert-oracle | python3 -c '
import sys, json
rows=[]
for line in sys.stdin:
    p=line.rstrip("\n").split("\t")
    if len(p)!=4: continue
    rows.append({"from":int(p[0]),"to":int(p[1]),"text":p[2],"expected":p[3]})
json.dump(rows, open("'"$OUT"'","w"), ensure_ascii=False, indent=0)
print(f"wrote {len(rows)} rows to '"$OUT"'")
'
