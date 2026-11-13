import 'package:flutter/foundation.dart';

/// 外壳与动漫模块之间的最小桥接。
///
/// 动漫播放器只订阅 [animeActive]：切到影视时暂停播放，切回时不自动恢复。
/// 播放器、规则引擎与抓取逻辑本身不做任何修改。
class ShellBridge {
  ShellBridge._();

  static final ValueNotifier<bool> animeActive = ValueNotifier<bool>(true);
  static final ValueNotifier<String> activeModule =
      ValueNotifier<String>('launch');
}
