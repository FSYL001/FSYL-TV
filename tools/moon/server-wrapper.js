#!/usr/bin/env node
'use strict';

/*
 * FSYL TV MoonTV sidecar entry.
 *
 * The Next.js standalone build emits `server.js`; the packaging step renames it
 * to `next-server.js` and installs this wrapper as `server.js`. The wrapper:
 *   - requires PORT (provided by the shell) and HOSTNAME (default 127.0.0.1);
 *   - starts the unmodified Next standalone server;
 *   - polls /api/health and prints "FSYLTV_READY <port>" once it is reachable;
 *   - maps SIGTERM/SIGINT to a clean exit.
 *
 * The process tree is owned by the shell (Job Object + taskkill fallback).
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const port = Number.parseInt(process.env.PORT || '', 10);
if (!Number.isInteger(port) || port < 1 || port > 65535) {
  console.error('FSYLTV: PORT missing or invalid');
  process.exit(2);
}

process.env.HOSTNAME = process.env.HOSTNAME || '127.0.0.1';
process.env.HOST = process.env.HOST || process.env.HOSTNAME;
process.env.NODE_ENV = 'production';
// Local single-user mode: the shell only exposes the server on loopback.
process.env.FSYLTV_LOCAL_MODE = process.env.FSYLTV_LOCAL_MODE || 'true';
process.chdir(__dirname);

const healthPath = '/api/health';

function checkHealth() {
  return new Promise((resolve) => {
    const req = http.get(
      { host: '127.0.0.1', port, path: healthPath, timeout: 1000 },
      (res) => {
        res.resume();
        resolve(res.statusCode === 200);
      }
    );
    req.on('timeout', () => {
      req.destroy();
      resolve(false);
    });
    req.on('error', () => resolve(false));
  });
}

const nextServer = path.join(__dirname, 'next-server.js');
if (!fs.existsSync(nextServer)) {
  console.error('FSYLTV: next-server.js not found');
  process.exit(3);
}

try {
  require(nextServer);
} catch (err) {
  console.error('FSYLTV: failed to start Next server:', err);
  process.exit(4);
}

let attempts = 0;
let readySent = false;
const maxAttempts = 200; // ~20 seconds
const timer = setInterval(async () => {
  attempts += 1;
  if (readySent) return;
  if (await checkHealth()) {
    if (readySent) return;
    readySent = true;
    clearInterval(timer);
    process.stdout.write(`FSYLTV_READY ${port}\n`);
    return;
  }
  if (attempts >= maxAttempts) {
    clearInterval(timer);
    console.error('FSYLTV: health check timed out');
    process.exit(5);
  }
}, 100);

function shutdown(signal) {
  console.error(`FSYLTV: received ${signal}, exiting`);
  process.exit(0);
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
