#!/usr/bin/env node
'use strict';

/*
 * Build-environment workaround for ech_http 0.2.4 on MSVC.
 *
 * The package embeds its CA bundle as ONE raw string literal (~200 KB), which
 * exceeds MSVC's per-literal limit and fails with C2026. MSVC does concatenate
 * adjacent string literals, so splitting the raw literal at certificate
 * boundaries keeps the runtime bytes identical while satisfying the compiler.
 *
 * This patches the checked-out package in the local pub cache only. It does not
 * change the dependency version, lockfile, or any file in this repository.
 * Idempotent. Run before `flutter build windows`.
 */
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const cacheRoot = path.join(root, 'tools', '.cache', 'pub-cache', 'hosted', 'pub.dev');

if (!fs.existsSync(cacheRoot)) {
  console.error('pub cache not found:', cacheRoot);
  process.exit(1);
}

const pkg = fs
  .readdirSync(cacheRoot, { withFileTypes: true })
  .filter((d) => d.isDirectory() && d.name.startsWith('ech_http-'))
  .map((d) => d.name)
  .sort()
  .pop();
if (!pkg) {
  console.error('ech_http package not found in pub cache');
  process.exit(1);
}

const cmakePath = path.join(cacheRoot, pkg, 'src', 'CMakeLists.txt');
let cmake = fs.readFileSync(cmakePath, 'utf8');
const marker = '# FSYLTV_CA_BUNDLE_SPLIT';

const anchor = 'file(READ "${CMAKE_CURRENT_SOURCE_DIR}/cacert.pem" EH_CA_PEM)';
if (!cmake.includes(anchor)) {
  console.error('anchor not found in', cmakePath);
  process.exit(2);
}

// Normalize any previous (possibly broken) patch attempt.
const blockStart = cmake.indexOf('\n# FSYLTV: split');
if (blockStart >= 0) {
  const blockEndMarker = 'EH_CA_PEM "${EH_CA_PEM}")';
  const blockEnd = cmake.indexOf(blockEndMarker, blockStart);
  if (blockEnd >= 0) {
    cmake =
      cmake.slice(0, blockStart) +
      cmake.slice(blockEnd + blockEndMarker.length);
  }
}

const split =
  '\n' +
  '# FSYLTV: split the CA bundle at certificate boundaries for MSVC (C2026).\n' +
  marker +
  '\n' +
  'string(REPLACE "-----BEGIN CERTIFICATE-----" ' +
  '")ECH_CA_BUNDLE\\" R\\"ECH_CA_BUNDLE(-----BEGIN CERTIFICATE-----" ' +
  'EH_CA_PEM "${EH_CA_PEM}")';

cmake = cmake.replace(anchor, anchor + split);
fs.writeFileSync(cmakePath, cmake, 'utf8');
console.log('patched:', cmakePath);
