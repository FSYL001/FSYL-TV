// FSYL TV build workaround for the pinned webview_windows fork.
// Its SendScroll() posts wheel input at (0,0), so MoonTV's sidebar consumes the
// event and the page under the cursor never scrolls. Use the last cursor point.
//
// This is a local pub-cache patch, not a dependency upgrade. Idempotent.

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const cache = process.env.PUB_CACHE || path.join(root, 'tools', '.cache', 'pub-cache');
const file = path.join(
  cache,
  'git',
  'flutter-webview-windows-2b3306d2bfb9f22cbb328743b60e547cf50f0c3c',
  'windows',
  'webview.cc'
);

if (!fs.existsSync(file)) {
  console.log(`[webview-scroll] not found, skip: ${file}`);
  process.exit(0);
}

let src = fs.readFileSync(file, 'utf8');
if (src.includes('FSYLTV_SCROLL_CURSOR_PATCH')) {
  console.log('[webview-scroll] already patched');
  process.exit(0);
}

const needle = /  POINT point;\r?\n  point\.x = 0;\r?\n  point\.y = 0;/;
if (!needle.test(src)) {
  console.log('[webview-scroll] scroll block not found, skip');
  process.exit(0);
}
src = src.replace(
  needle,
  `  // FSYLTV_SCROLL_CURSOR_PATCH: target the element under the cursor.
  POINT point = last_cursor_pos_;`
);
fs.writeFileSync(file, src, 'utf8');
console.log(`[webview-scroll] patched ${file}`);
