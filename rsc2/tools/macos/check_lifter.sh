#!/bin/sh
# Lift the synthetic XBE (no game data) with the toolkit, build the C for
# this host and run it against the same five functions written in C.
# Needs the recompiler's venv at <repo>/.venv (capstone pefile numpy).
#   rsc2/tools/macos/check_lifter.sh [work dir]
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
WORK="${1:-${TMPDIR:-/tmp}/rsc2-lift-check}"
PY="$ROOT/.venv/bin/python"
mkdir -p "$WORK/gen"
cd "$ROOT/xboxrecomp"
"$PY" tools/conformance/mkxbe.py "$WORK/test.xbe" >/dev/null
"$PY" -m tools.xbe_parser "$WORK/test.xbe" --json "$WORK/test_analysis.json" >/dev/null
"$PY" -m tools.disasm "$WORK/test.xbe" >/dev/null
"$PY" -m tools.func_id "$WORK/test.xbe" >/dev/null
"$PY" -m tools.abi_analysis "$WORK/test.xbe" >/dev/null
"$PY" -m tools.recomp "$WORK/test.xbe" --all --split 250 --gen-dir "$WORK/gen" >/dev/null
cmake -S "$HERE/lift_check" -B "$WORK/build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DGEN_DIR="$WORK/gen" >/dev/null
ninja -C "$WORK/build" lift_check >/dev/null
"$WORK/build/lift_check" "$WORK/test.xbe" 2>&1 | grep -v -e "^  " -e "^xbox_Memory"
