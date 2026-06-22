// PetStore Catalog load test — k6 equivalent of test-plans/petstore-catalog.jmx
//
// Mirrors the JMeter browse flow against the OctoPerf JPetStore catalog:
//   1) Once per VU : GET /actions/Catalog.action                       (landing/home)
//   2) Per loop    : GET /actions/Catalog.action?viewCategory&categoryId=FISH
//   3) Per loop    : GET /actions/Catalog.action?viewProduct&productId=FI-SW-01
//
// Each VU therefore issues  1 + 2*LOOPS  requests = 21 when LOOPS=10.
// Total samples = USERS * 21  (630 / 840 / 1050 / 1470 for 30/40/50/70 users).
//
// Throughput is paced by PACING seconds of sleep after each request, so the
// aggregate TPS lands near the target for each level (k6 has no exact
// equivalent of JMeter's Constant Throughput Timer; pacing approximates it,
// just as the timer does).
//
// Config via env vars (mirrors the JMeter -J properties):
//   USERS    concurrent VUs            (default 30)
//   LOOPS    iterations per VU         (default 10)
//   PACING   seconds slept per request (default 60  -> ~0.5 TPS at 30 VUs)
//   HOST     target host               (default petstore.octoperf.com)
//   PROTOCOL http|https                (default https)
//   OUT_DIR  dir for summary.json      (default results)

import http from 'k6/http';
import { check, sleep } from 'k6';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.1/index.js';

const USERS = Number(__ENV.USERS || 30);
const LOOPS = Number(__ENV.LOOPS || 10);
const PACING = Number(__ENV.PACING || 60);
const HOST = __ENV.HOST || 'petstore.octoperf.com';
const PROTOCOL = __ENV.PROTOCOL || 'https';
const OUT_DIR = __ENV.OUT_DIR || 'results';

const BASE = `${PROTOCOL}://${HOST}/actions/Catalog.action`;

const params = {
  headers: {
    'User-Agent': 'k6-loadtest/1.0 (PetStore Catalog)',
    Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  },
};

export const options = {
  scenarios: {
    catalog_browse: {
      executor: 'per-vu-iterations',
      vus: USERS,
      iterations: LOOPS,
      maxDuration: '60m',
      gracefulStop: '30s',
    },
  },
  thresholds: {
    // Baseline error rate was ~0.41% (6 timeouts in the 70-user run); allow <1%.
    http_req_failed: ['rate<0.01'],
    checks: ['rate>0.99'],
  },
  noConnectionReuse: false,
};

// Module scope is per-VU in k6, so this flag makes the landing request fire
// exactly once per VU (its first iteration), matching JMeter's Once Only Controller.
let landed = false;

export default function () {
  if (!landed) {
    const home = http.get(BASE, Object.assign({ tags: { name: 'Home - Catalog' } }, params));
    check(home, { 'home status 200': (r) => r.status === 200 });
    landed = true;
    sleep(PACING);
  }

  const category = http.get(
    `${BASE}?viewCategory=&categoryId=FISH`,
    Object.assign({ tags: { name: 'View Category (FISH)' } }, params)
  );
  check(category, { 'category status 200': (r) => r.status === 200 });
  sleep(PACING);

  const product = http.get(
    `${BASE}?viewProduct=&productId=FI-SW-01`,
    Object.assign({ tags: { name: 'View Product (FI-SW-01)' } }, params)
  );
  check(product, { 'product status 200': (r) => r.status === 200 });
  sleep(PACING);
}

export function handleSummary(data) {
  const out = {};
  out['stdout'] = textSummary(data, { indent: ' ', enableColors: true });
  out[`${OUT_DIR}/summary.json`] = JSON.stringify(data, null, 2);
  return out;
}
