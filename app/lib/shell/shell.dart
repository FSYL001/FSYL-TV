import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kazumi/shell/app_config.dart';
import 'package:kazumi/shell/app_paths.dart';
import 'package:kazumi/shell/moon_sidecar.dart';
import 'package:kazumi/shell/movie_page.dart';
import 'package:kazumi/shell/shell_bridge.dart';
import 'package:window_manager/window_manager.dart';

const double _titleBarHeight = 40;

/// 单窗口外壳：启动页 + 常驻 IndexedStack + 顶部胶囊切换器 + 自绘标题栏。
class FsylShell extends StatefulWidget {
  const FsylShell({super.key, required this.animeChild});

  final Widget? animeChild;

  @override
  State<FsylShell> createState() => _FsylShellState();
}

class _FsylShellState extends State<FsylShell>
    with WindowListener, SingleTickerProviderStateMixin {
  final MoonSidecar _sidecar = MoonSidecar();
  final GlobalKey<MoviePageState> _movieKey = GlobalKey<MoviePageState>();

  AppConfig _config = AppConfig();
  bool _configLoaded = false;
  bool _entered = false;
  bool _showLaunch = true;
  bool _movieCreated = false;
  int _index = 0;
  Timer? _saveTimer;
  Timer? _launchFadeTimer;

  late final AnimationController _switchFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await AppPaths.instance.init();
    final config = await AppConfig.load();
    if (!mounted) return;
    setState(() {
      _config = config;
      _configLoaded = true;
    });
    await _applyWindowBounds();
    _maybeRunDebugPlan();
  }

  void _maybeRunDebugPlan() {
    final auto = Platform.environment['FSYLTV_AUTOSTART'];
    if (auto == 'movie') {
      _enterModule(1);
    } else if (auto == 'anime') {
      _enterModule(0);
    }

    final switchAfter =
        int.tryParse(Platform.environment['FSYLTV_SWITCH_TO_ANIME_AFTER'] ?? '');
    if (switchAfter != null && switchAfter > 0) {
      Timer(Duration(seconds: switchAfter), () {
        if (!mounted) return;
        _debugLog('debug: auto switch to anime after ${switchAfter}s');
        _switchTo(0);
      });
    }

    final backAfter =
        int.tryParse(Platform.environment['FSYLTV_SWITCH_BACK_AFTER'] ?? '');
    if (backAfter != null && backAfter > 0) {
      Timer(Duration(seconds: backAfter), () {
        if (!mounted) return;
        _debugLog('debug: auto switch back to movie after ${backAfter}s');
        _switchTo(1);
      });
    }

    if (Platform.environment['FSYLTV_S2'] == '1') {
      unawaited(_runS2Debug());
    }
  }

  Future<void> _runS2Debug() async {
    await Future<void>.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    if (!_entered) _enterModule(1);
    _debugLog('S2 start index=$_index sidecar=${_sidecar.status}');
    await Future<void>.delayed(const Duration(seconds: 3));
    await _movieKey.currentState?.evalScript('window.scrollTo(0, 420); window.scrollY');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    for (var cycle = 1; cycle <= 20; cycle++) {
      final before =
          await _movieKey.currentState?.evalScript('String(window.scrollY)');
      _switchTo(0);
      await Future<void>.delayed(const Duration(milliseconds: 330));
      final animeLogged = true;
      _switchTo(1);
      await Future<void>.delayed(const Duration(milliseconds: 520));
      final after =
          await _movieKey.currentState?.evalScript('String(window.scrollY)');
      _debugLog(
        'S2 cycle=$cycle anime_ok=$animeLogged scroll_before=$before scroll_after=$after',
      );
    }

    _debugLog('S2 done');
    if (Platform.environment['FSYLTV_EXIT_AFTER_DEBUG'] == '1') {
      await Future<void>.delayed(const Duration(seconds: 3));
      await _sidecar.stop();
      exit(0);
    }
  }

  void _debugLog(String message) {
    final line = '${DateTime.now().toIso8601String()} $message';
    try {
      File('${AppPaths.instance.logsDir}/shell.log').writeAsStringSync(
        '$line\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  Future<void> _applyWindowBounds() async {
    if (!Platform.isWindows) return;
    try {
      if (_config.maximized) {
        await windowManager.maximize();
      } else if (_config.width >= 640 && _config.height >= 480) {
        final bounds = Rect.fromLTWH(
          _config.x >= 0 ? _config.x : 120,
          _config.y >= 0 ? _config.y : 80,
          _config.width,
          _config.height,
        );
        await windowManager.setBounds(bounds);
      }
    } catch (_) {}
  }

  void _enterModule(int index) {
    if (_entered) return;
    setState(() {
      _entered = true;
      _index = index;
    });
    _applyModuleState(previous: -1);
    _updateShellBridge();
    _config.lastModule = index == 0 ? 'anime' : 'movie';
    _scheduleSave();
    _launchFadeTimer = Timer(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _showLaunch = false);
    });
  }

  void _switchTo(int index) {
    if (!_entered || index == _index) return;
    final previous = _index;
    setState(() => _index = index);
    _applyModuleState(previous: previous);
    _updateShellBridge();
    _config.lastModule = index == 0 ? 'anime' : 'movie';
    _scheduleSave();
    _switchFade.forward(from: 0.0);
  }

  void _applyModuleState({required int previous}) {
    if (!_entered) {
      ShellBridge.animeActive.value = false;
      return;
    }
    if (previous == 0) {
      // 离开动漫：通知播放器暂停（切回不自动恢复）。
      ShellBridge.animeActive.value = false;
    }
    if (previous == 1) {
      _movieKey.currentState?.suspendAndPause();
    }
    if (_index == 1) {
      ShellBridge.animeActive.value = false;
      _ensureMovie();
      _movieKey.currentState?.resumeRender();
    } else {
      ShellBridge.animeActive.value = true;
    }
  }

  void _ensureMovie() {
    if (_movieCreated) return;
    _movieCreated = true;
    unawaited(_sidecar.start());
    setState(() {});
  }

  void _updateShellBridge() {
    ShellBridge.activeModule.value = _index == 0 ? 'anime' : 'movie';
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () async {
      await _config.saveApp();
      await _config.saveWindow();
    });
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  void onWindowResize() => _captureBounds();

  @override
  void onWindowMove() => _captureBounds();

  Future<void> _captureBounds() async {
    if (!_configLoaded) return;
    try {
      final maximized = await windowManager.isMaximized();
      if (maximized) {
        _config.maximized = true;
      } else {
        final bounds = await windowManager.getBounds();
        _config
          ..maximized = false
          ..x = bounds.left
          ..y = bounds.top
          ..width = bounds.width
          ..height = bounds.height;
      }
      _scheduleSave();
    } catch (_) {}
  }

  List<Widget> _buildChildren() {
    final anime = widget.animeChild ?? const SizedBox.shrink();
    if (_movieCreated) {
      return [
        anime,
        MoviePage(key: _movieKey, sidecar: _sidecar, config: _config),
      ];
    }
    return [anime, const SizedBox.shrink()];
  }

  @override
  Widget build(BuildContext context) {
    if (!_configLoaded) {
      return const ColoredBox(
        color: Color(0xFF101014),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      body: Stack(
        children: [
          Positioned.fill(
            child: _entered
                ? Padding(
                    padding: const EdgeInsets.only(top: _titleBarHeight),
                    child: FadeTransition(
                      opacity: Tween<double>(begin: 0.72, end: 1).animate(
                        CurvedAnimation(
                          parent: _switchFade,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: IndexedStack(
                        index: _index,
                        children: _buildChildren(),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (_entered)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: _titleBarHeight,
              child: _TitleBar(
                activeIndex: _index,
                onSwitch: _switchTo,
                onMinimizeToTray: () => windowManager.hide(),
                onMinimize: () => windowManager.minimize(),
                onMaximize: _toggleMaximize,
                onClose: () => windowManager.close(),
              ),
            ),
          if (_showLaunch)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _entered,
                child: AnimatedOpacity(
                  opacity: _entered ? 0 : 1,
                  duration: const Duration(milliseconds: 240),
                  child: _LaunchPage(
                    lastModule: _config.lastModule,
                    onSelect: _enterModule,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _launchFadeTimer?.cancel();
    _switchFade.dispose();
    windowManager.removeListener(this);
    unawaited(_sidecar.stop());
    _sidecar.dispose();
    super.dispose();
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.activeIndex,
    required this.onSwitch,
    required this.onMinimizeToTray,
    required this.onMinimize,
    required this.onMaximize,
    required this.onClose,
  });

  final int activeIndex;
  final ValueChanged<int> onSwitch;
  final VoidCallback onMinimizeToTray;
  final VoidCallback onMinimize;
  final VoidCallback onMaximize;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF17171C),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: onMaximize,
              child: Container(
                height: _titleBarHeight,
                padding: const EdgeInsets.only(left: 12),
                alignment: Alignment.centerLeft,
                child: const Row(
                  children: [
                    _BrandMark(size: 16),
                    SizedBox(width: 8),
                    Text(
                      'FSYL TV',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _CapsuleSwitcher(activeIndex: activeIndex, onSwitch: onSwitch),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: onMaximize,
              child: Container(height: _titleBarHeight),
            ),
          ),
          _WindowButton(
            icon: Icons.vertical_align_bottom,
            tooltip: '隐藏到托盘',
            onTap: onMinimizeToTray,
          ),
          _WindowButton(
            icon: Icons.remove,
            tooltip: '最小化',
            onTap: onMinimize,
          ),
          _WindowButton(
            icon: Icons.crop_square,
            tooltip: '最大化/还原',
            onTap: onMaximize,
          ),
          _WindowButton(
            icon: Icons.close,
            tooltip: '关闭',
            onTap: onClose,
            isClose: true,
          ),
        ],
      ),
    );
  }
}

class _CapsuleSwitcher extends StatelessWidget {
  const _CapsuleSwitcher({required this.activeIndex, required this.onSwitch});

  final int activeIndex;
  final ValueChanged<int> onSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 176,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF26262E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF35353F)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: activeIndex == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: activeIndex == 0
                      ? const Color(0xFF35C7B2)
                      : const Color(0xFFF0A23C),
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _CapsuleItem(
                label: '动漫',
                active: activeIndex == 0,
                onTap: () => onSwitch(0),
              ),
              _CapsuleItem(
                label: '影视',
                active: activeIndex == 1,
                onTap: () => onSwitch(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapsuleItem extends StatelessWidget {
  const _CapsuleItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: active ? const Color(0xFF101014) : const Color(0xFFB8B8C2),
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isClose = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isClose;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: 42,
            height: _titleBarHeight,
            color: _hover
                ? (widget.isClose
                    ? const Color(0xFFD64545)
                    : const Color(0xFF2A2A33))
                : Colors.transparent,
            child: Icon(
              widget.icon,
              size: 16,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/images/logo/logo_rounded.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _LaunchPage extends StatelessWidget {
  const _LaunchPage({required this.lastModule, required this.onSelect});

  final String lastModule;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.1,
          colors: [Color(0xFF1D1D24), Color(0xFF0D0D11)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BrandMark(size: 44),
              SizedBox(width: 16),
              Text(
                'FSYL TV',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '本地单窗口影视客户端',
            style: TextStyle(color: Color(0xFF8D8D99), fontSize: 13),
          ),
          const SizedBox(height: 44),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LaunchCard(
                title: '影视',
                subtitle: 'MoonTV · 本地服务',
                icon: Icons.movie_outlined,
                accent: const Color(0xFFF0A23C),
                highlight: lastModule == 'movie',
                onTap: () => onSelect(1),
              ),
              const SizedBox(width: 24),
              _LaunchCard(
                title: '动漫',
                subtitle: '动漫 · 规则采集',
                icon: Icons.auto_awesome_motion_outlined,
                accent: const Color(0xFF35C7B2),
                highlight: lastModule == 'anime',
                onTap: () => onSelect(0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LaunchCard extends StatefulWidget {
  const _LaunchCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.highlight,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool highlight;
  final VoidCallback onTap;

  @override
  State<_LaunchCard> createState() => _LaunchCardState();
}

class _LaunchCardState extends State<_LaunchCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 230,
          height: 260,
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFF22222B) : const Color(0xFF1A1A21),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hover
                  ? widget.accent.withValues(alpha: 0.8)
                  : widget.accent.withValues(alpha: 0.28),
              width: _hover ? 1.4 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.16),
                      blurRadius: 26,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accent.withValues(alpha: 0.12),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 30),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  color: Color(0xFF8D8D99),
                  fontSize: 11,
                ),
              ),
              if (widget.highlight) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '上次停留',
                    style: TextStyle(color: widget.accent, fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
