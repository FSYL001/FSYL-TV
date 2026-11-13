import 'dart:convert';
import 'dart:io';

import 'package:kazumi/shell/app_paths.dart';

/// 外壳配置：窗口几何 + 上次停留板块（SPEC §2 config 目录）。
class AppConfig {
  AppConfig({
    this.x = -1,
    this.y = -1,
    this.width = 1280,
    this.height = 860,
    this.maximized = false,
    this.lastModule = 'anime',
  });

  double x;
  double y;
  double width;
  double height;
  bool maximized;
  String lastModule;

  static Future<AppConfig> load() async {
    final config = AppConfig();
    await config._loadWindow();
    await config._loadApp();
    return config;
  }

  Future<void> _loadWindow() async {
    final file = File(AppPaths.instance.windowConfigFile);
    if (!file.existsSync()) return;
    try {
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      x = (map['x'] as num?)?.toDouble() ?? x;
      y = (map['y'] as num?)?.toDouble() ?? y;
      width = (map['width'] as num?)?.toDouble() ?? width;
      height = (map['height'] as num?)?.toDouble() ?? height;
      maximized = map['maximized'] as bool? ?? maximized;
    } catch (_) {
      // 配置损坏时回退默认值，不阻塞启动。
    }
  }

  Future<void> _loadApp() async {
    final file = File(AppPaths.instance.appConfigFile);
    if (!file.existsSync()) return;
    try {
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      lastModule = map['lastModule'] as String? ?? lastModule;
    } catch (_) {
      // 忽略损坏配置。
    }
  }

  Future<void> saveWindow() async {
    final map = {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'maximized': maximized,
    };
    await _writeAtomic(AppPaths.instance.windowConfigFile, map);
  }

  Future<void> saveApp() async {
    final map = {'lastModule': lastModule, 'schemaVersion': 1};
    await _writeAtomic(AppPaths.instance.appConfigFile, map);
  }

  Future<void> _writeAtomic(String path, Map<String, dynamic> map) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(map));
    if (file.existsSync()) await file.delete();
    await tmp.rename(path);
  }
}
