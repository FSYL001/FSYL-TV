import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kazumi/shell/app_paths.dart';
import 'package:kazumi/shell/job_object.dart';
import 'package:path/path.dart' as p;

enum MoonStatus { stopped, starting, ready, failed, stopping }

/// MoonTV sidecar 生命周期（SPEC §3 / 阶段 5）。
///
/// 探测空闲端口 -> 启动 node.exe server.js -> 读 `FSYLTV_READY <port>`
/// -> 健康检查；退出时先 POST /__shutdown，1.5 秒未退再 taskkill /T /F。
class MoonSidecar extends ChangeNotifier {
  Process? _process;
  int? _port;
  int? _pid;
  String? _error;
  bool _stopping = false;
  bool _starting = false;
  Timer? _readyTimer;
  IOSink? _logSink;
  final List<String> _recentLines = [];

  MoonStatus status = MoonStatus.stopped;
  int? get port => _port;
  int? get pid => _pid;
  String? get error => _error;
  List<String> get recentLines => List.unmodifiable(_recentLines);

  bool get isReady => status == MoonStatus.ready && _port != null;

  Future<void> start() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      _setStatus(MoonStatus.stopped);
      return;
    }
    if (_starting || status == MoonStatus.starting || isReady) return;
    _starting = true;
    _stopping = false;
    _error = null;
    _port = null;
    _setStatus(MoonStatus.starting);

    try {
      await AppPaths.instance.init();
      await _cleanupStalePid();

      final serverScript = AppPaths.instance.serverScript;
      final nodeExe = AppPaths.instance.nodeExe;
      if (!File(serverScript).existsSync()) {
        throw '找不到影视服务入口：$serverScript';
      }
      if (!File(nodeExe).existsSync()) {
        throw '找不到 node.exe：$nodeExe';
      }

      final port = await _findFreePort();
      _port = port;

      _logSink = File(AppPaths.instance.moonLogFile).openWrite(
        mode: FileMode.append,
        encoding: utf8,
      );
      _log('--- starting sidecar on port $port ---');

      final env = <String, String>{
        'PORT': '$port',
        'HOSTNAME': '127.0.0.1',
        'NEXT_PUBLIC_STORAGE_TYPE': 'localstorage',
        'NEXT_PUBLIC_SITE_NAME': 'FSYL TV',
        'SITE_NAME': 'FSYL TV',
        'FSYLTV_LOCAL_MODE': 'true',
        'NEXT_TELEMETRY_DISABLED': '1',
      };

      final process = await Process.start(
        nodeExe,
        ['server.js'],
        workingDirectory: p.dirname(serverScript),
        environment: env,
        includeParentEnvironment: true,
      );
      _process = process;
      _pid = process.pid;
      final assigned = JobObject.instance.assign(process.pid);
      _log('job object assign pid=${process.pid} ok=$assigned');
      await _writePidFile(process.pid, port);

      final readyCompleter = Completer<void>();
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _handleStdout(line);
        if (!readyCompleter.isCompleted && line.startsWith('FSYLTV_READY ')) {
          readyCompleter.complete();
        }
      });
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _log('stderr: $line');
      });

      _readyTimer = Timer(const Duration(seconds: 20), () {
        if (!readyCompleter.isCompleted) {
          readyCompleter.completeError(
            TimeoutException('影视服务 20 秒内未就绪', const Duration(seconds: 20)),
          );
        }
      });

      await readyCompleter.future;
      _readyTimer?.cancel();

      final healthy = await _checkHealth(port);
      if (!healthy) {
        throw '影视服务已启动，但 /api/health 未通过';
      }

      process.exitCode.then((code) {
        if (_stopping) return;
        if (status == MoonStatus.stopping || status == MoonStatus.stopped) return;
        _process = null;
        _pid = null;
        _port = null;
        _error = '影视模块已退出（exit code $code）';
        _log('unexpected exit code=$code');
        _setStatus(MoonStatus.failed);
        unawaited(_deletePidFile());
      });

      _setStatus(MoonStatus.ready);
    } catch (e) {
      _error = e.toString();
      _log('start failed: $e');
      await _killTree();
      _setStatus(MoonStatus.failed);
      await _deletePidFile();
    } finally {
      _starting = false;
    }
  }

  void _handleStdout(String line) {
    _log(line);
    if (line.startsWith('FSYLTV_READY ')) {
      final parsed = int.tryParse(line.substring('FSYLTV_READY '.length).trim());
      if (parsed != null) _port = parsed;
    }
  }

  Future<void> stop() async {
    if (status == MoonStatus.stopped) return;
    _stopping = true;
    _setStatus(MoonStatus.stopping);

    try {
      final port = _port;
      if (port != null) {
        await _postShutdown(port);
      }
      final process = _process;
      if (process != null) {
        final exited = await process.exitCode.timeout(
          const Duration(milliseconds: 1500),
          onTimeout: () => -1,
        );
        if (exited == -1) {
          await _killTree();
        }
      }
    } catch (e) {
      _log('stop error: $e');
      await _killTree();
    } finally {
      _readyTimer?.cancel();
      await _logSink?.flush();
      await _logSink?.close();
      _logSink = null;
      _process = null;
      _pid = null;
      _port = null;
      await _deletePidFile();
      _setStatus(MoonStatus.stopped);
      _stopping = false;
    }
  }

  Future<void> restart() async {
    await stop();
    await start();
  }

  Future<int> _findFreePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<bool> _checkHealth(int port) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final uri = Uri.parse('http://127.0.0.1:$port/api/health');
      final request = await client.getUrl(uri);
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _postShutdown(int port) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final uri = Uri.parse('http://127.0.0.1:$port/__shutdown');
      final request = await client.postUrl(uri);
      request.contentLength = 0;
      final response = await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      _log('shutdown response ${response.statusCode}');
    } catch (e) {
      _log('shutdown request failed: $e');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _killTree() async {
    final pid = _pid;
    if (pid == null) return;
    try {
      await Process.run('taskkill', ['/PID', '$pid', '/T', '/F']);
      _log('taskkill /PID $pid /T /F');
    } catch (e) {
      _log('taskkill failed: $e');
    }
  }

  Future<void> _writePidFile(int pid, int port) async {
    final map = {
      'pid': pid,
      'port': port,
      'startedAt': DateTime.now().toUtc().toIso8601String(),
      'commandLine':
          '${AppPaths.instance.nodeExe} ${AppPaths.instance.serverScript}',
    };
    final file = File(AppPaths.instance.moonPidFile);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(map));
  }

  Future<void> _deletePidFile() async {
    try {
      final file = File(AppPaths.instance.moonPidFile);
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  /// 启动时清理上次残留进程：PID + 启动时间 + 命令行三者吻合才清理（SPEC §3.3）。
  Future<void> _cleanupStalePid() async {
    final file = File(AppPaths.instance.moonPidFile);
    if (!file.existsSync()) return;
    try {
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final pid = (map['pid'] as num?)?.toInt();
      final startedAt = DateTime.tryParse(map['startedAt'] as String? ?? '');
      if (pid == null || startedAt == null) {
        await file.delete();
        return;
      }
      final info = await _queryProcess(pid);
      if (info == null) {
        await file.delete();
        return;
      }
      final created = DateTime.tryParse(info['created'] as String? ?? '');
      final cmd = info['cmd'] as String? ?? '';
      final looksLikeOurServer =
          cmd.contains('server.js') && cmd.toLowerCase().contains('moon');
      final closeInTime = created != null &&
          created.difference(startedAt).inSeconds.abs() <= 120;
      if (looksLikeOurServer && closeInTime) {
        await Process.run('taskkill', ['/PID', '$pid', '/T', '/F']);
        _log('cleaned stale sidecar pid=$pid');
      }
      await file.delete();
    } catch (e) {
      _log('stale pid cleanup skipped: $e');
    }
  }

  Future<Map<String, dynamic>?> _queryProcess(int pid) async {
    try {
      final script = '''
\$p = Get-CimInstance Win32_Process -Filter "ProcessId=$pid" -ErrorAction SilentlyContinue
if (\$p) { [pscustomobject]@{ pid = \$p.ProcessId; created = \$p.CreationDate.ToUniversalTime().ToString('o'); cmd = \$p.CommandLine } | ConvertTo-Json -Compress }
''';
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-WindowStyle',
          'Hidden',
          '-Command',
          script,
        ],
      ).timeout(const Duration(seconds: 8));
      final out = (result.stdout as String).trim();
      if (out.isEmpty) return null;
      return jsonDecode(out) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _setStatus(MoonStatus next) {
    status = next;
    notifyListeners();
  }

  void _log(String line) {
    final stamped = '${DateTime.now().toIso8601String()} $line';
    _recentLines.add(stamped);
    while (_recentLines.length > 200) {
      _recentLines.removeAt(0);
    }
    try {
      _logSink?.writeln(stamped);
    } catch (_) {}
    if (kDebugMode) {
      debugPrint('[moon] $line');
    }
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    _logSink?.close();
    super.dispose();
  }
}
