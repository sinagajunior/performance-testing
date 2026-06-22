# PetStore Catalog Load Test (k6)

k6 equivalent of the JMeter test in `../test-plans/petstore-catalog.jmx`, hitting
the OctoPerf JPetStore catalog at
`https://petstore.octoperf.com/actions/Catalog.action`.

## Layout

```
k6/
├── petstore-catalog.js     k6 test script
├── scripts/run-test.bat    Windows runner
├── scripts/run-test.sh     POSIX / CI runner
└── results/                Run output (HTML report + summary.json), gitignored
```

## Prerequisites

- **k6 >= 0.49** on `PATH` (the runners use k6's built-in web dashboard to export
  a static HTML report). Install:
  - Windows: `winget install k6 --source winget` or `choco install k6`
  - macOS: `brew install k6`
  - Linux: see <https://grafana.com/docs/k6/latest/set-up/install-k6/>
- Override the binary location with the `K6_BIN` env var if k6 isn't on `PATH`.

## Scenario (matches the JMeter plan)

Executor `per-vu-iterations` — each VU runs `LOOPS` iterations:

1. **Once per VU** — `GET /actions/Catalog.action` (landing). The landing fires
   only on a VU's first iteration (module scope is per-VU in k6), matching
   JMeter's Once Only Controller.
2. **Per loop** — `GET …?viewCategory=&categoryId=FISH`
3. **Per loop** — `GET …?viewProduct=&productId=FI-SW-01`

So each VU issues `1 + 2 × LOOPS` = **21 requests** at the default loop count.
`Total samples = USERS × 21`.

Throughput is paced with `sleep(PACING)` after each request. k6 has no exact
analog of JMeter's Constant Throughput Timer, so pacing approximates the target
TPS (both approaches are approximate).

## Load levels

| Level | VUs | Loops | PACING | Target TPS | Total samples |
|-------|-----|-------|--------|------------|---------------|
| 30    | 30  | 10    | 60s    | ~0.50      | 630           |
| 40    | 40  | 10    | 57s    | ~0.70      | 840           |
| 50    | 50  | 10    | 62s    | ~0.80      | 1050          |
| 70    | 70  | 10    | 58s    | ~1.20      | 1470          |

> Because the target TPS is low, a full level run is paced to ~20 minutes.

## Running

Windows:

```bat
scripts\run-test.bat 30      :: 630 samples,  ~0.5 TPS
scripts\run-test.bat all     :: 30, 40, 50, 70 back to back
scripts\run-test.bat 30 1    :: quick smoke: 1 loop (30*3 samples)
```

POSIX / Git Bash:

```bash
scripts/run-test.sh 30
scripts/run-test.sh all
scripts/run-test.sh 30 1     # quick smoke
```

Arguments: `<level> [loops]` — level is `30|40|50|70|all`, loops defaults to `10`.

## Output

Each run writes a timestamped folder under `results/`, e.g.
`results/30users-20260622-150000/`, containing:

- `report.html` — k6 web-dashboard HTML report
- `summary.json` — end-of-test metrics (from `handleSummary`)

> Note: k6 skips the HTML export for very short runs ("not enough data").
> The runner scripts pace every run to several minutes, so this only happens
> if you invoke k6 directly with a tiny `PACING`. `summary.json` is always written.

## Thresholds

The script fails the run (non-zero exit) if either:

- `http_req_failed` rate ≥ 1% (baseline was ~0.41%), or
- `checks` pass rate ≤ 99% (status-200 checks on all three requests).

The runners still emit the HTML report on a threshold breach.

## Direct invocation (override any parameter)

```bash
k6 run petstore-catalog.js \
  -e USERS=50 -e LOOPS=10 -e PACING=62 -e HOST=petstore.octoperf.com -e PROTOCOL=https
```

| Env var    | Default               | Meaning                              |
|------------|-----------------------|--------------------------------------|
| `USERS`    | 30                    | Concurrent VUs                       |
| `LOOPS`    | 10                    | Iterations per VU                    |
| `PACING`   | 60                    | Seconds slept after each request     |
| `HOST`     | petstore.octoperf.com | Target host                          |
| `PROTOCOL` | https                 | Target protocol                      |
| `OUT_DIR`  | results               | Directory for `summary.json`         |
