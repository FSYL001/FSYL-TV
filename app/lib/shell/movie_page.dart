import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/shell/app_paths.dart';
import 'package:kazumi/shell/app_config.dart';
import 'package:kazumi/shell/moon_sidecar.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

/// 影视板块：
/// - Windows: 本地 MoonTV sidecar + WebView2（Texture 渲染）。
/// - Android: Android System WebView + 可配置 MoonTV 服务地址。
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
  WebviewController? _windowsController;
  PlatformInAppWebViewController? _androidController;

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
  String _currentAndroidUrl = '';
  bool _showConfigDialog = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      widget.sidecar.addListener(_onSidecarChanged);
      _initWindowsWebview();
      _startS1StatsIfNeeded();
    } else {
      _initAndroidWebview();
    }
  }

  void _initAndroidWebview() {
    final override = Platform.environment['FSYLTV_MOVIE_URL'];
    final configured = widget.config.movieUrl;
    if (override != null && override.isNotEmpty) {
      _currentAndroidUrl = override;
    } else if (configured.isNotEmpty) {
      _currentAndroidUrl = configured;
    } else {
      _currentAndroidUrl = '';
    }
    setState(() {
      _initializing = false;
      _webviewError = null;
    });
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

  Future<void> _initWindowsWebview() async {
    if (!mounted) return;
    try {
      await AppPaths.instance.init();
      try {
        await WebviewController.initializeEnvironment(
          userDataPath: AppPaths.instance.movieDir,
        );
      } catch (_) {}
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
        _windowsController = controller;
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
        _loadWindows(port);
      }
    }
    setState(() {});
  }

  Future<void> _loadWindows(int port) async {
    final controller = _windowsController;
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

  Future<void> suspendAndPause() async {
    _suspended = true;
    if (Platform.isWindows) {
      final controller = _windowsController;
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
    } else {
      try {
        await _androidController?.evaluateJavascript(source: '''
          (function () {
            try {
              document.querySelectorAll('video,audio').forEach(function (el) {
                try { el.pause(); el.muted = true; } catch (e) {}
              });
            } catch (e) {}
          })();
        ''');
      } catch (_) {}
    }
  }

  Future<void> resumeRender() async {
    _suspended = false;
    if (Platform.isWindows) {
      final controller = _windowsController;
      if (controller == null) return;
      try {
        await controller.setFpsLimit(0);
      } catch (_) {}
    }
  }

  Future<void> retry() async {
    setState(() {
      _webviewError = null;
      _lastLoadError = null;
    });
    if (Platform.isWindows) {
      if (_windowsController == null) {
        await _initWindowsWebview();
      }
      if (widget.sidecar.status == MoonStatus.failed ||
          widget.sidecar.status == MoonStatus.stopped) {
        await widget.sidecar.restart();
      } else if (_loadedPort != null) {
        await _loadWindows(_loadedPort!);
      }
    } else {
      if (_currentAndroidUrl.isNotEmpty && _androidController != null) {
        await _androidController!.loadUrl(
          urlRequest: URLRequest(url: WebUri(_currentAndroidUrl)),
        );
      }
    }
  }

  Future<String?> evalScript(String script) async {
    try {
      if (Platform.isWindows) {
        final result = await _windowsController?.executeScript(script);
        return result?.toString();
      } else {
        final result = await _androidController?.evaluateJavascript(source: script);
        return result?.toString();
      }
    } catch (e) {
      return 'ERR: $e';
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0) return;
    final x = event.localPosition.dx.toStringAsFixed(1);
    final y = event.localPosition.dy.toStringAsFixed(1);
    final delta = dy.toStringAsFixed(1);
    final controller = _windowsController;
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

  Widget _buildAndroidContent() {
    if (_currentAndroidUrl.isEmpty || _showConfigDialog) {
      return _buildServerConfigView();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PlatformInAppWebViewWidget(
          PlatformInAppWebViewWidgetCreationParams(
            controllerFromPlatform: (controller) {
              _androidController = controller;
            },
            initialSettings: InAppWebViewSettings(
              useWideViewPort: true,
              loadWithOverviewMode: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              javaScriptEnabled: true,
              cacheEnabled: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              useHybridComposition: true,
            ),
            initialUrlRequest: URLRequest(url: WebUri(_currentAndroidUrl)),
            onTitleChanged: (controller, title) {
              if (mounted && title != null) setState(() => _title = title);
            },
            onLoadError: (controller, url, code, message) {
              if (mounted) setState(() => _lastLoadError = '页面加载失败：$message');
            },
          ),
        ).build(context),
        Positioned(
          top: 10,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _showConfigDialog = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.settings, size: 14, color: Colors.white70),
                    SizedBox(width: 4),
                    Text(
                      '服务地址',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServerConfigView() {
    final textController = TextEditingController(text: _currentAndroidUrl);
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.movie_filter, color: Color(0xFF4C9EEB), size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'MoonTV 影视服务配置',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_currentAndroidUrl.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => setState(() => _showConfigDialog = false),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                '在移动端上，影视板块采用原生安全容器接入 MoonTV。\n请输入您的 MoonTV 服务端地址（如局域网地址 http://192.168.1.100:3000 或已部署的云端地址）：',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: textController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'http://192.168.1.100:3000',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF141418),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF4C9EEB)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4C9EEB),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    var input = textController.text.trim();
                    if (input.isNotEmpty && !input.startsWith('http://') && !input.startsWith('https://')) {
                      input = 'http://$input';
                    }
                    if (input.isNotEmpty) {
                      widget.config.movieUrl = input;
                      await widget.config.saveApp();
                      setState(() {
                        _currentAndroidUrl = input;
                        _showConfigDialog = false;
                      });
                      if (_androidController != null) {
                        await _androidController!.loadUrl(
                          urlRequest: URLRequest(url: WebUri(input)),
                        );
                      }
                    }
                  },
                  child: const Text('连接并进入', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!Platform.isWindows) {
      return ColoredBox(
        color: const Color(0xFF101014),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildAndroidContent(),
            if (_lastLoadError != null)
              _MovieOverlay(
                title: '页面加载失败',
                message: _lastLoadError!,
                actionLabel: '重试',
                onAction: retry,
              ),
          ],
        ),
      );
    }

    final controller = _windowsController;
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
    if (Platform.isWindows) {
      widget.sidecar.removeListener(_onSidecarChanged);
      _loadingSub?.cancel();
      _errorSub?.cancel();
      _titleSub?.cancel();
      _windowsController?.dispose();
    }
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
