#!/usr/bin/env bash
# build.sh — compile oracle.cpp + OpenKey engine into a standalone CLI binary.
# Usage: bash scripts/openkey-oracle/build.sh
# Output: scripts/openkey-oracle/oracle  (not committed — see .gitignore)
set -euo pipefail
cd "$(dirname "$0")"

ENG="../../../mkey/Sources/Engine"

clang++ -std=c++17 -I"$ENG" -DNDEBUG \
  oracle.cpp \
  "$ENG/Engine.cpp" \
  "$ENG/Vietnamese.cpp" \
  "$ENG/Macro.cpp" \
  "$ENG/SmartSwitchKey.cpp" \
  "$ENG/ConvertTool.cpp" \
  -o oracle

echo "built ./oracle"

clang++ -std=c++17 -I"$ENG" -DNDEBUG \
  convert-oracle.cpp \
  "$ENG/Engine.cpp" \
  "$ENG/Vietnamese.cpp" \
  "$ENG/Macro.cpp" \
  "$ENG/SmartSwitchKey.cpp" \
  "$ENG/ConvertTool.cpp" \
  -o convert-oracle

echo "built ./convert-oracle"
