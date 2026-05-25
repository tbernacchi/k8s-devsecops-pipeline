import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from 'https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js'

// Load test — golden signals: latency, traffic, errors, saturation
// Run after smoke passes: k6 run load.js
export const options = {
  stages: [
    { duration: '2m', target: 20  },  // ramp up
    { duration: '5m', target: 20  },  // steady state
    { duration: '2m', target: 50  },  // ramp up
    { duration: '5m', target: 50  },  // steady state
    { duration: '2m', target: 0   },  // ramp down
  ],
  thresholds: {
    // Latency — p95 < 2s, p99 < 5s
    http_req_duration:                        ['p(95)<2000', 'p(99)<5000'],
    // Error rate — < 1%
    http_req_failed:                          ['rate<0.01'],
    // Per-endpoint latency
    'http_req_duration{name:frontend-healthz}': ['p(95)<1000'],
    'http_req_duration{name:backend-healthz}':  ['p(95)<1000'],
  },
}

const BASE = __ENV.BASE_URL || 'https://traefik.mykubernetes.com'

const endpoints = [
  { name: 'frontend-healthz', url: `${BASE}/frontend/healthz` },
  { name: 'backend-healthz',  url: `${BASE}/backend/healthz`  },
]

export default function () {
  for (const ep of endpoints) {
    const res = http.get(ep.url, {
      tags: { name: ep.name },
      insecureSkipTLSVerify: true,
    })

    check(res, {
      [`${ep.name} status 200`]: (r) => r.status === 200,
      [`${ep.name} < 2000ms`]:   (r) => r.timings.duration < 2000,
    })
  }

  sleep(1)
}

export function handleSummary(data) {
  return { 'load-summary.html': htmlReport(data) }
}
