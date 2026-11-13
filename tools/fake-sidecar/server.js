#!/usr/bin/env node
'use strict';

// Minimal fake MoonTV sidecar used by stage-1 S3 verification.
// Contract: print FSYLTV_READY <port>, expose /api/health, exit on /__shutdown.

const http = require('http');

const port = Number.parseInt(process.env.PORT || '', 10);
if (!Number.isInteger(port)) {
  console.error('fake-sidecar: PORT missing');
  process.exit(2);
}

const server = http.createServer((req, res) => {
  if (req.url === '/api/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', fake: true }));
    return;
  }
  if (req.url === '/__shutdown' && req.method === 'POST') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ status: 'shutting-down' }));
    setTimeout(() => process.exit(0), 50);
    return;
  }
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
  res.end('<!doctype html><title>fake moon</title><h1>fake</h1>');
});

server.listen(port, '127.0.0.1', () => {
  process.stdout.write(`FSYLTV_READY ${port}\n`);
});

process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
