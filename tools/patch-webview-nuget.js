// FSYL TV build workaround: webview_windows runs `nuget install` on every
// build. Under the restricted build account NuGet's config/lock files are not
// readable, but the packages are already restored under build\windows\x64.
// Skip the custom command when both packages are present.
//
// This is a local pub-cache patch, not a dependency upgrade. Idempotent.

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const cache = process.env.PUB_CACHE || path.join(root, 'tools', '.cache', 'pub-cache');
const plugin = path.join(
  cache,
  'git',
  'flutter-webview-windows-2b3306d2bfb9f22cbb328743b60e547cf50f0c3c',
  'windows',
  'CMakeLists.txt'
);

if (!fs.existsSync(plugin)) {
  console.log(`[webview-nuget] not found, skip: ${plugin}`);
  process.exit(0);
}

let src = fs.readFileSync(plugin, 'utf8');
if (src.includes('FSYLTV_NUGET_PATCH')) {
  console.log('[webview-nuget] already patched');
  process.exit(0);
}

const target =
  /add_custom_target\(\$\{PROJECT_NAME\}_DEPENDENCIES_DOWNLOAD ALL\)\r?\nadd_custom_command\(/;
if (!target.test(src)) {
  console.log('[webview-nuget] target block not found, skip');
  process.exit(0);
}

src = src.replace(
  target,
  'add_custom_target(${PROJECT_NAME}_DEPENDENCIES_DOWNLOAD ALL)\n' +
    '# FSYLTV_NUGET_PATCH: skip restore when packages already exist.\n' +
    'if (NOT EXISTS "${CMAKE_BINARY_DIR}/packages/Microsoft.Web.WebView2/WebView2.idl")\n' +
    'add_custom_command('
);

const depends = /  DEPENDS \$\{NUGET\}\r?\n\)\r?\n\r?\nadd_library\(/;
if (!depends.test(src)) {
  console.log('[webview-nuget] DEPENDS block not found, skip');
  process.exit(0);
}
src = src.replace(
  depends,
  '  DEPENDS ${NUGET}\n)\nendif()\n\nadd_library('
);

fs.writeFileSync(plugin, src, 'utf8');
console.log(`[webview-nuget] patched ${plugin}`);
