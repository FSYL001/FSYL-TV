import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/shell/app_paths.dart';
import 'package:kazumi/shell/app_config.dart';
import 'package:kazumi/shell/moon_sidecar.dart';
import 'package:webview_windows/webview_windows.dart';

/// 影视板块：本地 MoonTV sidecar + WebView2（Texture 渲染）。
///
/// 不使用 media_kit、不劫持视频流；播放器完全由 MoonTV 网页自带。
class MoviePage extends StatefulWidget {
  const MoviePage({
    super.key,
    required this.sidecar,
    required this.config,
  });

  final MoonSidecar sidecar;
  final AppConfig config;

  @override
  State<MoviePage> createState() => MoviePageState();
}

class MoviePageState extends State<MoviePage> with AutomaticKeepAliveClientMixin {
  WebviewController? _controller;
  bool _initializing = true;
  String? _webviewError;
  String? _lastLoadError;
  int? _loadedPort;
  bool _suspended = false;
  StreamSubscription? _loadingSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _titleSub;
  Timer? _s1Timer;
  String _title = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.sidecar.addListener(_onSidecarChanged);
    _initWebview();
    _startS1StatsIfNeeded();
  }

  void _startS1StatsIfNeeded() {
    if (Platform.environment['FSYLTV_S1'] != '1') return;
    _s1Timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_suspended) return;
      final raw = await evalScript(
        'JSON.stringify({s1: window.__s1||null, hidden: document.hidden, scrollY: window.scrollY})',
      );
      if (raw == null) return;
      try {
        final file = File('${AppPaths.instance.logsDir}/s1.log');
        await file.writeAsString(
          '${DateTime.now().toIso8601String()} $raw\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {}
    });
  }

  Future<void> _initWebview() async {
    if (!mounted) return;
    try {
      await AppPaths.instance.init();
      try {
        await WebviewController.initializeEnvironment(
          userDataPath: AppPaths.instance.movieDir,
        );
      } catch (_) {
        // 环境已由其他 WebView 初始化时忽略；数据目录以首次初始化为准。
      }
      if (!mounted) return;
      final controller = WebviewController();
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _loadingSub = controller.loadingState.listen((state) {
        if (mounted) setState(() {});
      });
      _errorSub = controller.onLoadError.listen((error) {
        if (!mounted) return;
        setState(() => _lastLoadError = '页面加载失败：$error');
      });
      _titleSub = controller.title.listen((value) {
        if (mounted) setState(() => _title = value);
      });
      setState(() {
        _controller = controller;
        _initializing = false;
        _webviewError = null;
      });
      _onSidecarChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _webviewError = 'WebView2 初始化失败：$e';
      });
    }
  }

  void _onSidecarChanged() {
    if (!mounted) return;
    if (widget.sidecar.isReady) {
      final port = widget.sidecar.port;
      if (port != null && port != _loadedPort) {
        _load(port);
      }
    }
    setState(() {});
  }

  Future<void> _load(int port) async {
    final controller = _controller;
    if (controller == null) return;
    _loadedPort = port;
    final override = Platform.environment['FSYLTV_MOVIE_URL'];
    final path = Platform.environment['FSYLTV_MOVIE_PATH'] ?? '/';
    final url = (override != null && override.isNotEmpty)
        ? override
        : 'http://127.0.0.1:$port$path';
    setState(() => _lastLoadError = null);
    try {
      await controller.loadUrl(url);
    } catch (e) {
      if (mounted) setState(() => _lastLoadError = '打开影视页面失败：$e');
    }
  }

  /// 切走时：暂停网页内所有音视频，把捕获帧率降到 1fps，但保留捕获会话与页面。
  ///
  /// 不使用 controller.suspend()：该插件的 suspend 会关闭 Graphics Capture
  /// item，resume() 后捕获不再恢复，画面会定格在最后一帧。
  Future<void> suspendAndPause() async {
    _suspended = true;
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.executeScript('''
        (function () {
          try {
            document.querySelectorAll('video,audio').forEach(function (el) {
              try { el.pause(); el.muted = true; } catch (e) {}
            });
          } catch (e) {}
        })();
      ''');
    } catch (_) {}
    try {
      await controller.setFpsLimit(1);
    } catch (_) {}
  }

  /// 切回时：恢复捕获帧率，不自动播放，停在原帧。
  Future<void> resumeRender() async {
    _suspended = false;
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.setFpsLimit(0);
    } catch (_) {}
  }

  Future<void> retry() async {
    setState(() {
      _webviewError = null;
      _lastLoadError = null;
    });
    if (_controller == null) {
      await _initWebview();
    }
    if (widget.sidecar.status == MoonStatus.failed ||
        widget.sidecar.status == MoonStatus.stopped) {
      await widget.sidecar.restart();
    } else if (_loadedPort != null) {
      await _load(_loadedPort!);
    }
  }

  Future<String?> evalScript(String script) async {
    try {
      final result = await _controller?.executeScript(script);
      return result?.toString();
    } catch (e) {
      return 'ERR: $e';
    }
  }

  /// Flutter-side fallback because the pinned webview_windows fork does not
  /// reliably deliver wheel input to the page under the cursor.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0) return;
    final x = event.localPosition.dx.toStringAsFixed(1);
    final y = event.localPosition.dy.toStringAsFixed(1);
    final delta = dy.toStringAsFixed(1);
    try {
      File('${AppPaths.instance.logsDir}/movie-scroll.log').writeAsStringSync(
        '${DateTime.now().toIso8601String()} x=$x y=$y dy=$delta\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
    final controller = _controller;
    if (controller == null) return;
    unawaited(controller.executeScript('''
(function () {
  const x = $x, y = $y, dy = $delta;
  let el = document.elementFromPoint(x, y);
  while (el) {
    const s = getComputedStyle(el);
    const scrollable = s.overflowY === 'auto' ||
      s.overflowY === 'scroll' || s.overflowY === 'overlay';
    if (scrollable && el.scrollHeight > el.clientHeight + 1) {
      el.scrollBy(0, dy);
      return;
    }
    el = el.parentElement;
  }
  window.scrollBy(0, dy);
})();
'''));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = _controller;
    final sidecarFailed = widget.sidecar.status == MoonStatus.failed;
    final sidecarStarting = widget.sidecar.status == MoonStatus.starting ||
        widget.sidecar.status == MoonStatus.stopping ||
        widget.sidecar.status == MoonStatus.stopped;

    return ColoredBox(
      color: const Color(0xFF101014),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: _onPointerSignal,
              child: Webview(controller, filterQuality: FilterQuality.low),
            )
          else
            const Center(child: CircularProgressIndicator()),
          if (_initializing)
            const _MovieOverlay(
              title: '正在准备影视模块',
              message: '初始化 WebView2…',
              showSpinner: true,
            ),
          if (!_initializing && sidecarStarting && controller != null)
            const _MovieOverlay(
              title: '正在启动影视服务',
              message: '本地 MoonTV 服务启动中，通常需要 1–3 秒。',
              showSpinner: true,
            ),
          if (sidecarFailed)
            _MovieOverlay(
              title: '影视模块启动失败',
              message: widget.sidecar.error ?? '未知错误',
              actionLabel: '重启影视模块',
              onAction: retry,
            ),
          if (_webviewError != null)
            _MovieOverlay(
              title: '影视模块不可用',
              message: _webviewError!,
              actionLabel: '重试',
              onAction: retry,
            ),
          if (_lastLoadError != null)
            _MovieOverlay(
              title: '页面加载失败',
              message: _lastLoadError!,
              actionLabel: '重试',
              onAction: retry,
            ),
          if (_title.isNotEmpty)
            Positioned(
              bottom: 8,
              right: 12,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _title,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
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
    _s1Timer?.cancel();
    widget.sidecar.removeListener(_onSidecarChanged);
    _loadingSub?.cancel();
    _errorSub?.cancel();
    _titleSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}

class _MovieOverlay extends StatelessWidget {
  const _MovieOverlay({
    required this.title,
    required this.message,
    this.showSpinner = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final bool showSpinner;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xF0101014),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSpinner) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => onAction!(),
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
