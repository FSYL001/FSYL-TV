#!/usr/bin/env node
// Minimal HTTPS downloader used by FSYL TV build scripts.
// Usage: node tools/download.js <url> <dest> [expectedSha256]
// Node's TLS stack is used because schannel-backed PowerShell clients can fail
// in restricted environments. Supports redirects and prints progress to stderr.
'use strict';

const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const url = process.argv[2];
const dest = process.argv[3];
const expectedSha = (process.argv[4] || '').toLowerCase();

if (!url || !dest) {
  console.error('usage: node tools/download.js <url> <dest> [sha256]');
  process.exit(2);
}

fs.mkdirSync(path.dirname(path.resolve(dest)), { recursive: true });

function get(targetUrl, redirects = 0) {
  if (redirects > 10) throw new Error('too many redirects');
  const mod = targetUrl.startsWith('http:') ? http : https;
  return new Promise((resolve, reject) => {
    const req = mod.get(targetUrl, {
      headers: { 'user-agent': 'FSYLTV-build/1.0', 'accept': '*/*' },
      timeout: 60000,
    }, (res) => {
      const { statusCode, headers } = res;
      if ([301, 302, 303, 307, 308].includes(statusCode) && headers.location) {
        res.resume();
        const next = new URL(headers.location, targetUrl).toString();
        return resolve(get(next, redirects + 1));
      }
      if (statusCode !== 200) {
        res.resume();
        return reject(new Error(`HTTP ${statusCode} for ${targetUrl}`));
      }
      resolve({ res, finalUrl: targetUrl, total: Number(headers['content-length'] || 0) });
    });
    req.on('timeout', () => req.destroy(new Error('request timeout')));
    req.on('error', reject);
  });
}

(async () => {
  console.log(`GET ${url}`);
  const { res, total } = await get(url);
  const part = dest + '.part';
  const hash = crypto.createHash('sha256');
  let received = 0;
  let lastPct = -1;
  await new Promise((resolve, reject) => {
    const out = fs.createWriteStream(part);
    res.on('data', (chunk) => {
      received += chunk.length;
      hash.update(chunk);
      if (total) {
        const pct = Math.floor((received / total) * 100);
        if (pct >= lastPct + 5 || pct === 100) {
          lastPct = pct;
          console.error(`  ${pct}% (${(received / 1048576).toFixed(1)} / ${(total / 1048576).toFixed(1)} MiB)`);
        }
      }
    });
    res.on('error', reject);
    out.on('error', reject);
    out.on('finish', resolve);
    res.pipe(out);
  });
  const actual = hash.digest('hex');
  if (expectedSha && actual !== expectedSha) {
    fs.rmSync(part, { force: true });
    throw new Error(`sha256 mismatch: expected ${expectedSha}, got ${actual}`);
  }
  fs.renameSync(part, dest);
  console.log(`OK ${dest} (${(received / 1048576).toFixed(1)} MiB) sha256=${actual}`);
})().catch((err) => {
  console.error('DOWNLOAD FAILED:', err.message);
  process.exit(1);
});
