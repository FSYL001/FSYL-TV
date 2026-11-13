import 'dart:io';

import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/shell/app_paths.dart';
import 'package:kazumi/shell/app_version.dart';

/// Applies a downloaded FSYLTV-windows-portable.zip after the running process
/// exits. The updater itself is a detached PowerShell script so the app can
/// release its exe/DLL locks before files are replaced.
class WindowsPortableUpdate {
  WindowsPortableUpdate._();

  static Future<bool> install(String zipPath) async {
    if (!Platform.isWindows) return false;
    try {
      final cache = Directory('${AppPaths.instance.cacheDir}/update');
      await cache.create(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final extractDir = Directory('${cache.path}/extract-$stamp');
      await extractDir.create(recursive: true);

      final escapedZip = zipPath.replaceAll("'", "''");
      final escapedDir = extractDir.path.replaceAll("'", "''");
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        "Expand-Archive -LiteralPath '$escapedZip' "
            "-DestinationPath '$escapedDir' -Force",
      ]);
      if (result.exitCode != 0) {
        KazumiLogger().e('Update: expand failed: ${result.stderr}');
        return false;
      }

      final exe = _findExe(extractDir);
      if (exe == null) {
        KazumiLogger().e('Update: fsyl_tv.exe not found in archive');
        return false;
      }
      final payload = exe.parent.path;
      final appDir = File(Platform.resolvedExecutable).parent.path;
      final script = File('${cache.path}/apply-fsyl-update.ps1');
      await script.writeAsString('''
param([int]\$WaitPid,[string]\$Source,[string]\$Target,[string]\$Exe)
\$ErrorActionPreference = 'SilentlyContinue'
while (Get-Process -Id \$WaitPid -ErrorAction SilentlyContinue) {
  Start-Sleep -Milliseconds 300
}
Start-Sleep -Milliseconds 500
robocopy \$Source \$Target /E /NFL /NDL /NJH /NJS /NP | Out-Null
Start-Process -FilePath \$Exe -WorkingDirectory \$Target
''', flush: true);

      await Process.start(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          script.path,
          pid.toString(),
          payload,
          appDir,
          exe.path,
        ],
        mode: ProcessStartMode.detached,
      );
      KazumiLogger().i(
        'Update: apply script started (${AppVersion.current} -> zip)',
      );
      return true;
    } catch (e, st) {
      KazumiLogger().e('Update: portable apply failed', error: e, stackTrace: st);
      return false;
    }
  }

  static File? _findExe(Directory dir) {
    try {
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('fsyl_tv.exe')) {
          return entity;
        }
      }
    } catch (_) {}
    return null;
  }
}
