import 'package:kazumi/services/network/acceleration_mode.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/bangumi_mirror_credentials.dart';

enum BangumiAcceleration implements AccelerationMode {
  direct,
  ech,
  mirror;

  static BangumiAcceleration get current {
    final configured = values.asNameMap()[GStorage.getSetting(
          SettingsKeys.bangumiAcceleration,
        )] ??
        (GStorage.getSetting(SettingsKeys.enableBangumiProxy)
            ? mirror
            : direct);
    // The mirror requires KAZUMI_APPID/KAZUMI_KEY. Without them every search
    // returns 401; fall back to the public Bangumi API, which needs no key.
    if (configured == mirror &&
        (bangumiMirrorCredentials['id'] ?? '').isEmpty) {
      return direct;
    }
    return configured;
  }

  @override
  String get label => switch (this) {
    direct => '直连',
    ech => 'ECH',
    mirror => '镜像',
  };

  @override
  String get description => switch (this) {
    direct => '访问官方接口',
    ech => '启用加密握手',
    mirror => '镜像接口（默认）',
  };
}
