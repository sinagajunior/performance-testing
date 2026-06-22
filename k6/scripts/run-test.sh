#!/usr/bin/env bash
# ============================================================
#  PetStore Catalog load test runner - k6 (POSIX / CI)
#
#  Usage:
#    ./run-test.sh <level> [loops]
#      <level> = 30 | 40 | 50 | 70 | all   (required)
#      [loops] = iterations per VU         (default 10)
#
#  Examples:
#    ./run-test.sh 30        Full 30-VU run (630 samples, ~0.5 TPS)
#    ./run-test.sh 70        1470 samples, ~1.2 TPS
#    ./run-test.sh all       Run 30, 40, 50, 70 back to back
#    ./run-test.sh 30 1      Quick smoke (1 loop = 30*3 samples)
#
#  Level -> VUs / PACING seconds (pacing approximates the target TPS):
#    30 -> USERS=30 PACING=60 (~0.5 TPS)
#    40 -> USERS=40 PACING=57 (~0.7 TPS)
#    50 -> USERS=50 PACING=62 (~0.8 TPS)
#    70 -> USERS=70 PACING=58 (~1.2 TPS)
#
#  Requires k6 >= 0.49 on PATH (built-in web dashboard HTML export).
#  Override the binary with the K6_BIN env var if needed.
# ============================================================
set -euo pipefail

K6_BIN="${K6_BIN:-k6}"

if ! "$K6_BIN" version >/dev/null 2>&1; then
  echo "ERROR: k6 not found on PATH." >&2
  echo "Install it with one of:" >&2
  echo "    winget install k6 --source winget   # Windows" >&2
  echo "    brew install k6                       # macOS" >&2
  echo "    sudo apt-get install k6               # Debian/Ubuntu (k6 apt repo)" >&2
  echo "Then re-run, or set K6_BIN to the k6 binary path." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K6_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN="$K6_ROOT/petstore-catalog.js"

LEVEL="${1:-}"
LOOPS="${2:-10}"
if [[ -z "$LEVEL" ]]; then
  echo "ERROR: missing level argument. Use 30|40|50|70|all" >&2
  exit 1
fi

run() {
  local lvl="$1" users pacing
  case "$lvl" in
    30) users=30; pacing=60 ;;
    40) users=40; pacing=57 ;;
    50) users=50; pacing=62 ;;
    70) users=70; pacing=58 ;;
    *) echo "ERROR: unknown level '$lvl'. Use 30|40|50|70|all" >&2; return 1 ;;
  esac

  local ts outdir
  ts="$(date +%Y%m%d-%H%M%S)"
  outdir="$K6_ROOT/results/${lvl}users-${ts}"
  mkdir -p "$outdir"

  echo ""
  echo "=== Running level $lvl: USERS=$users LOOPS=$LOOPS PACING=${pacing}s ==="
  echo "=== Output: $outdir ==="

  # k6 exits non-zero on threshold breach; don't let that abort the 'all' loop.
  K6_WEB_DASHBOARD=true \
  K6_WEB_DASHBOARD_EXPORT="$outdir/report.html" \
  "$K6_BIN" run "$PLAN" \
    -e USERS="$users" -e LOOPS="$LOOPS" -e PACING="$pacing" \
    -e OUT_DIR="$outdir" || echo "(k6 returned non-zero - likely a threshold breach; report still generated)"

  if [[ ! -f "$outdir/report.html" ]]; then
    echo "Level $lvl produced no HTML report." >&2
    return 1
  fi
  echo "Level $lvl done. Report: $outdir/report.html"
}

if [[ "$LEVEL" == "all" ]]; then
  for l in 30 40 50 70; do run "$l"; done
  echo "All levels complete."
else
  run "$LEVEL"
fi
