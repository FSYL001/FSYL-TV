import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:kazumi/shell/account/dpapi.dart';
import 'package:kazumi/shell/app_paths.dart';
import 'package:path/path.dart' as p;

/// 账号骨架（SPEC §7）。
///
/// 本阶段只做本地持久化：登录态、DPAPI 加密 token、设备 ID、服务器地址。
/// 未登录时所有同步调用立即返回，不产生任何网络请求。
class AccountService extends ChangeNotifier {
  AccountService._();

  static final AccountService instance = AccountService._();

  bool _initialized = false;
  bool loggedIn = false;
  String serverUrl = '';
  String username = '';
  String deviceId = '';
  bool autoSync = false;
  bool backgroundSync = false;
  bool get initialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    await AppPaths.instance.init();
    await _loadDeviceId();
    await _loadProfile();
    _initialized = true;
  }

  String get _profileFile => p.join(AppPaths.instance.accountDir, 'account.json');
  String get _tokenFile => p.join(AppPaths.instance.accountDir, 'token.bin');

  Future<void> _loadDeviceId() async {
    final file = File(p.join(AppPaths.instance.configDir, 'device.json'));
    try {
      if (file.existsSync()) {
        final map = jsonDecode(await file.readAsString());
        final id = (map['deviceId'] as String?)?.trim() ?? '';
        if (id.isNotEmpty) {
          deviceId = id;
          return;
        }
      }
    } catch (_) {}
    deviceId = _randomUuid();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({
      'deviceId': deviceId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    }));
  }

  Future<void> _loadProfile() async {
    final file = File(_profileFile);
    if (!file.existsSync()) return;
    try {
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      serverUrl = map['serverUrl'] as String? ?? '';
      username = map['username'] as String? ?? '';
      autoSync = map['autoSync'] as bool? ?? false;
      backgroundSync = map['backgroundSync'] as bool? ?? false;
      loggedIn = map['loggedIn'] as bool? ?? false;
    } catch (_) {}
  }

  /// Stores the local profile. Never performs network I/O.
  Future<void> saveProfile({
    required String serverUrl,
    required String username,
    required String password,
    required bool autoSync,
    required bool backgroundSync,
  }) async {
    await init();
    this.serverUrl = serverUrl.trim();
    this.username = username.trim();
    this.autoSync = autoSync;
    this.backgroundSync = backgroundSync;
    await _saveJson();
    if (password.isNotEmpty) {
      final encrypted = Dpapi.protect(
        Uint8List.fromList(utf8.encode(password)),
      );
      await File(_tokenFile).writeAsBytes(encrypted, flush: true);
    }
    notifyListeners();
  }

  /// Skeleton login: cloud endpoints are not enabled yet, so this only persists
  /// the local profile and returns false. It must not create a network request.
  Future<bool> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    await saveProfile(
      serverUrl: serverUrl,
      username: username,
      password: password,
      autoSync: autoSync,
      backgroundSync: backgroundSync,
    );
    loggedIn = false;
    await _saveJson();
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    loggedIn = false;
    await _saveJson();
    try {
      final token = File(_tokenFile);
      if (token.existsSync()) await token.delete();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _saveJson() async {
    final file = File(_profileFile);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({
      'serverUrl': serverUrl,
      'username': username,
      'autoSync': autoSync,
      'backgroundSync': backgroundSync,
      'loggedIn': loggedIn,
      'schemaVersion': 1,
    }));
  }

  String _randomUuid() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
