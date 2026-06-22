#!/usr/bin/env bash
# ============================================================
#  PetStore Catalog load test runner (POSIX / CI)
#
#  Usage:
#    ./run-test.sh <level> [loops] [rampup]
#      <level>  = 30 | 40 | 50 | 70 | all   (required)
#      [loops]  = loop count          (default 10)
#      [rampup] = ramp-up seconds      (default 30)
#
#  Examples:
#    ./run-test.sh 30          Full 30-user run (630 samples, ~0.5 TPS)
#    ./run-test.sh 70          Full 70-user run (1470 samples, ~1.2 TPS)
#    ./run-test.sh 30 1 5      Quick smoke (1 loop, 5s ramp = 30*3 samples)
#    ./run-test.sh all         Run 30, 40, 50, 70 back to back
#
#  Level -> users / tpm (throughput in samples/MINUTE = TPS * 60):
#    30 -> users=30 tpm=30 (~0.5 TPS)
#    40 -> users=40 tpm=42 (~0.7 TPS)
#    50 -> users=50 tpm=48 (~0.8 TPS)
#    70 -> users=70 tpm=72 (~1.2 TPS)
#
#  Override JMeter location with JMETER_HOME env var if needed.
# ============================================================
set -euo pipefail

JMETER_HOME="${JMETER_HOME:-/c/Users/roy.a.sinaga/application/apache-jmeter-5.6.3/apache-jmeter-5.6.3}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN="$REPO_ROOT/test-plans/petstore-catalog.jmx"

LEVEL="${1:-}"
LOOPS="${2:-10}"
RAMPUP="${3:-30}"

if [[ -z "$LEVEL" ]]; then
  echo "ERROR: missing level argument. Use 30|40|50|70|all" >&2
  exit 1
fi

JMETER_BIN="$JMETER_HOME/bin/jmeter"
if [[ ! -x "$JMETER_BIN" && ! -f "$JMETER_BIN" ]]; then
  echo "ERROR: JMeter not found at '$JMETER_BIN'. Set JMETER_HOME." >&2
  exit 1
fi

run() {
  local lvl="$1" users tpm
  case "$lvl" in
    30) users=30; tpm=30 ;;
    40) users=40; tpm=42 ;;
    50) users=50; tpm=48 ;;
    70) users=70; tpm=72 ;;
    *) echo "ERROR: unknown level '$lvl'. Use 30|40|50|70|all" >&2; return 1 ;;
  esac

  local ts outdir
  ts="$(date +%Y%m%d-%H%M%S)"
  outdir="$REPO_ROOT/results/${lvl}users-${ts}"
  mkdir -p "$outdir"

  echo ""
  echo "=== Running level $lvl: users=$users loops=$LOOPS tpm=$tpm rampup=$RAMPUP ==="
  echo "=== Output: $outdir ==="

  "$JMETER_BIN" -n -t "$PLAN" \
    -Jusers="$users" -Jloops="$LOOPS" -Jtpm="$tpm" -Jrampup="$RAMPUP" \
    -Jjtl="$outdir/result.jtl" \
    -l "$outdir/result.jtl" \
    -e -o "$outdir/html" \
    -j "$outdir/jmeter.log"

  echo "Level $lvl done. Report: $outdir/html/index.html"
}

if [[ "$LEVEL" == "all" ]]; then
  for l in 30 40 50 70; do run "$l"; done
  echo "All levels complete."
else
  run "$LEVEL"
fi
