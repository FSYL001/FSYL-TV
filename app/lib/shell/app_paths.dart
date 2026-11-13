import 'dart:io';

import 'package:path/path.dart' as p;

/// 全应用唯一的路径入口（SPEC §2）。
///
/// 生产布局：
///   %LOCALAPPDATA%\FSYLTV\app\   程序
///   %LOCALAPPDATA%\FSYLTV\data\ 唯一可写区
///
/// 开发布局（从 app\build\windows\... 运行）：
///   仓库根\build\dev-data\      数据
///   仓库根\build\moon-sidecar\  MoonTV sidecar
///
/// 可用环境变量覆盖（仅用于开发与验收）：
///   FSYLTV_DATA_ROOT, FSYLTV_MOON_DIR, FSYLTV_NODE_EXE
class AppPaths {
  AppPaths._();

  static final AppPaths instance = AppPaths._();

  bool _initialized = false;
  bool usedFallback = false;
  String? initNote;

  String dataRoot = '';
  String configDir = '';
  String accountDir = '';
  String animeDir = '';
  String movieDir = '';
  String cacheDir = '';
  String logsDir = '';

  String appDir = '';
  String moonDir = '';
  String nodeExe = '';
  String serverScript = '';

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    final exe = Platform.resolvedExecutable;
    final exeDir = p.dirname(exe);
    final repo = _findRepoRoot(exeDir);

    appDir = exeDir;

    final envData = Platform.environment['FSYLTV_DATA_ROOT'];
    final envMoon = Platform.environment['FSYLTV_MOON_DIR'];
    final envNode = Platform.environment['FSYLTV_NODE_EXE'];

    // 影视 sidecar 位置：环境变量 > 开发构建产物 > 安装目录 app\moon
    if (envMoon != null && envMoon.isNotEmpty) {
      moonDir = p.normalize(p.absolute(envMoon));
    } else if (repo != null &&
        _looksLikeDevBuild(exeDir) &&
        File(p.join(repo.path, 'build', 'moon-sidecar', 'server.js'))
            .existsSync()) {
      moonDir = p.join(repo.path, 'build', 'moon-sidecar');
    } else {
      moonDir = p.join(appDir, 'moon');
    }
    final packagedServer = p.join(moonDir, 'server', 'server.js');
    serverScript = File(packagedServer).existsSync()
        ? packagedServer
        : p.join(moonDir, 'server.js');
    if (envNode != null && envNode.isNotEmpty) {
      nodeExe = p.normalize(p.absolute(envNode));
    } else if (File(p.join(moonDir, 'node.exe')).existsSync()) {
      nodeExe = p.join(moonDir, 'node.exe');
    } else {
      nodeExe = p.join(appDir, 'moon', 'node.exe');
    }

    // 数据根：环境变量 > 开发数据目录 > %LOCALAPPDATA%
    if (envData != null && envData.isNotEmpty) {
      dataRoot = p.normalize(p.absolute(envData));
    } else if (repo != null && _looksLikeDevBuild(exeDir)) {
      dataRoot = p.join(repo.path, 'build', 'dev-data');
    } else {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      dataRoot = localAppData == null || localAppData.isEmpty
          ? p.join(Directory.systemTemp.path, 'FSYLTV', 'data')
          : p.join(localAppData, 'FSYLTV', 'data');
    }

    _setChildDirs();

    try {
      _createDirs();
    } on FileSystemException catch (e) {
      // SPEC §2：数据目录不可写时回退到临时目录，并在界面提示。
      usedFallback = true;
      initNote = '数据目录不可写，已回退到临时目录：$e';
      dataRoot = p.join(Directory.systemTemp.path, 'FSYLTV', 'data');
      _setChildDirs();
      _createDirs();
    }

    _initialized = true;
  }

  void _setChildDirs() {
    configDir = p.join(dataRoot, 'config');
    accountDir = p.join(dataRoot, 'account');
    animeDir = p.join(dataRoot, 'anime');
    movieDir = p.join(dataRoot, 'movie');
    cacheDir = p.join(dataRoot, 'cache');
    logsDir = p.join(dataRoot, 'logs');
  }

  void _createDirs() {
    for (final dir in [
      dataRoot,
      configDir,
      accountDir,
      animeDir,
      movieDir,
      cacheDir,
      logsDir,
    ]) {
      Directory(dir).createSync(recursive: true);
    }
  }

  String get windowConfigFile => p.join(configDir, 'window.json');
  String get appConfigFile => p.join(configDir, 'app.json');
  String get moonPidFile => p.join(configDir, 'moon.pid.json');
  String get moonLogFile => p.join(logsDir, 'moon.log');
  String get shellLogFile => p.join(logsDir, 'shell.log');

  bool _looksLikeDevBuild(String dir) {
    final lower = dir.toLowerCase();
    return lower.contains(r'\app\build\windows\');
  }

  Directory? _findRepoRoot(String start) {
    Directory? dir = Directory(start);
    for (var i = 0; i < 10; i++) {
      if (File(p.join(dir!.path, 'SPEC.md')).existsSync() &&
          Directory(p.join(dir.path, 'moonserver')).existsSync()) {
        return dir;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    // 从 app 目录运行 flutter 时的兜底
    Directory cwd = Directory.current;
    for (var i = 0; i < 6; i++) {
      if (File(p.join(cwd.path, 'SPEC.md')).existsSync() &&
          Directory(p.join(cwd.path, 'moonserver')).existsSync()) {
        return cwd;
      }
      final parent = cwd.parent;
      if (parent.path == cwd.path) break;
      cwd = parent;
    }
    return null;
  }
}
