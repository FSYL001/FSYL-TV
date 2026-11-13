import 'package:kazumi/shell/account/account_service.dart';

/// 同步变更对象（SPEC §6）。本阶段只定义，不发请求。
class SyncChange {
  const SyncChange({
    required this.module,
    required this.type,
    required this.key,
    required this.payload,
    required this.updatedAt,
    this.isDeleted = false,
    this.dirty = true,
    this.schemaVersion = 1,
  });

  final String module; // 'anime' | 'movie'
  final String type; // 'history' | 'favorite' | 'source'
  final String key;
  final Object? payload;
  final int updatedAt;
  final bool isDeleted;
  final bool dirty;
  final int schemaVersion;

  Map<String, dynamic> toJson() => {
        'module': module,
        'type': type,
        'key': key,
        'payload': payload,
        'updatedAt': updatedAt,
        'isDeleted': isDeleted,
        'dirty': dirty,
        'schemaVersion': schemaVersion,
      };
}

/// 两个模块各一个空实现。未登录时立即返回空结果，不产生网络请求。
abstract class SyncAdapter {
  Future<List<SyncChange>> pull(int sinceMs);
  Future<void> push(List<SyncChange> changes);
}

class AnimeSyncAdapter extends SyncAdapter {
  @override
  Future<List<SyncChange>> pull(int sinceMs) async {
    if (!AccountService.instance.loggedIn) return const [];
    return const [];
  }

  @override
  Future<void> push(List<SyncChange> changes) async {
    if (!AccountService.instance.loggedIn) return;
  }
}

class MovieSyncAdapter extends SyncAdapter {
  @override
  Future<List<SyncChange>> pull(int sinceMs) async {
    if (!AccountService.instance.loggedIn) return const [];
    return const [];
  }

  @override
  Future<void> push(List<SyncChange> changes) async {
    if (!AccountService.instance.loggedIn) return;
  }
}

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  final AnimeSyncAdapter anime = AnimeSyncAdapter();
  final MovieSyncAdapter movie = MovieSyncAdapter();

  bool get enabled => AccountService.instance.loggedIn;

  Future<void> syncAll({int? sinceMs}) async {
    if (!enabled) return;
    final since = sinceMs ?? 0;
    await anime.pull(since);
    await movie.pull(since);
  }
}
