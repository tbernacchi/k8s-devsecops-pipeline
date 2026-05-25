import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from 'https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js'

export const options = {
  vus: 1,
  duration: '1m',
  thresholds: {
    http_req_duration: ['p(95)<2000'],
    http_req_failed:   ['rate<0.01'],
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
      // skip TLS verify — self-signed cert on internal cluster
      insecureSkipTLSVerify: true,
    })

    check(res, {
      [`${ep.name} status 200`]: (r) => r.status === 200,
      [`${ep.name} < 1000ms`]:   (r) => r.timings.duration < 1000,
    })
  }

  sleep(1)
}

export function handleSummary(data) {
  return { 'smoke-summary.html': htmlReport(data) }
}
