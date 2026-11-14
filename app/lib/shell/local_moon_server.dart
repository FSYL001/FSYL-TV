import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/shell/app_paths.dart';
import 'package:path/path.dart' as p;

class MovieSource {
  final String key;
  final String name;
  final String api;
  final String? detail;

  MovieSource({
    required this.key,
    required this.name,
    required this.api,
    this.detail,
  });

  factory MovieSource.fromJson(String key, Map<String, dynamic> json) {
    return MovieSource(
      key: key,
      name: json['name'] as String? ?? key,
      api: json['api'] as String? ?? '',
      detail: json['detail'] as String?,
    );
  }
}

/// 本地嵌入式 FSYL TV (MoonTV) 服务。
///
/// 在 Android 及移动端作为本地影视核心运行，无需外部 Node.js 进程。
/// 直接提供 PC 端 MoonTV 的全套静态页面与 API（豆瓣分类带降级、图片防盗链代理、聚合检索）。
class LocalMoonServer {
  LocalMoonServer._();
  static final LocalMoonServer instance = LocalMoonServer._();

  HttpServer? _server;
  int? _port;
  bool _starting = false;
  final List<MovieSource> _sources = [];

  static const List<String> _yellowWords = [
    '伦理片', '福利', '里番动漫', '门事件', '萝莉少女', '制服诱惑',
    '国产传媒', 'cosplay', '黑丝诱惑', '无码', '日本无码', '有码',
    '日本有码', 'SWAG', '网红主播', '色情片', '同性片', '福利视频',
    '福利片', '写真热舞',
  ];

  int? get port => _port;
  bool get isRunning => _server != null && _port != null;

  Future<int> start() async {
    if (isRunning) return _port!;
    if (_starting) {
      while (_starting) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (isRunning) return _port!;
    }
    _starting = true;

    try {
      await AppPaths.instance.init();
      final siteDir = p.join(AppPaths.instance.movieDir, 'site');

      // 提取本地静态站点包
      await _ensureSiteExtracted(siteDir);
      _loadSources(siteDir);

      // 优先绑定 3000 端口，若占用则自动分配空闲端口
      HttpServer? server;
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);
      } catch (_) {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      }

      _server = server;
      _port = server.port;

      server.listen(_handleRequest, onError: (e) {
        debugPrint('LocalMoonServer error: $e');
      });

      debugPrint('LocalMoonServer started on http://127.0.0.1:$_port');
      return _port!;
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }

  Future<void> _ensureSiteExtracted(String siteDir) async {
    final indexFile = File(p.join(siteDir, 'pages', 'index.html'));
    if (indexFile.existsSync() && indexFile.lengthSync() > 1000) {
      return;
    }

    try {
      debugPrint('Extracting FSYL TV local site bundle...');
      final byteData = await rootBundle.load('assets/moon/bundle.zip');
      final bytes = byteData.buffer.asUint8List();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name.replaceAll('\\', '/');
        if (filename.isEmpty || filename.endsWith('/')) {
          continue;
        }
        final outPath = p.join(siteDir, filename);
        final outFile = File(outPath);
        outFile.parent.createSync(recursive: true);
        if (file.isFile) {
          outFile.writeAsBytesSync(file.content as List<int>);
        }
      }
      debugPrint('FSYL TV site bundle extracted to $siteDir');
    } catch (e) {
      debugPrint('Failed to extract site bundle: $e');
    }
  }

  void _loadSources(String siteDir) {
    _sources.clear();
    final configFile = File(p.join(siteDir, 'config.json'));
    if (!configFile.existsSync()) return;

    try {
      final json = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      final apiSites = json['api_site'] as Map<String, dynamic>?;
      if (apiSites != null) {
        apiSites.forEach((k, v) {
          if (v is Map<String, dynamic>) {
            _sources.add(MovieSource.fromJson(k, v));
          }
        });
      }
      debugPrint('Loaded ${_sources.length} movie sources from config.json');
    } catch (e) {
      debugPrint('Failed to load sources from config.json: $e');
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final res = request.response;
    res.headers.set('Access-Control-Allow-Origin', '*');
    res.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.headers.set('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      res.statusCode = HttpStatus.noContent;
      await res.close();
      return;
    }

    final path = request.uri.path;
    final params = request.uri.queryParameters;

    try {
      if (path == '/api/health') {
        res.statusCode = HttpStatus.ok;
        res.headers.contentType = ContentType.json;
        res.write('{"status":"ok","name":"FSYL TV"}');
        await res.close();
        return;
      }

      if (path == '/api/server-config') {
        res.statusCode = HttpStatus.ok;
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode({
          'SiteName': 'FSYL TV',
          'StorageType': 'localstorage',
        }));
        await res.close();
        return;
      }

      if (path == '/api/douban/categories') {
        await _handleDoubanCategories(request, params);
        return;
      }

      if (path == '/api/image-proxy') {
        await _handleImageProxy(request, params);
        return;
      }

      if (path == '/api/search') {
        await _handleSearch(request, params);
        return;
      }

      if (path == '/api/search/one') {
        await _handleSearchOne(request, params);
        return;
      }

      if (path == '/api/detail') {
        await _handleDetail(request, params);
        return;
      }

      // 静态资源分发
      await _serveStaticFile(request);
    } catch (e) {
      try {
        res.statusCode = HttpStatus.internalServerError;
        res.write('Internal Server Error: $e');
        await res.close();
      } catch (_) {}
    }
  }

  String _wrapPosterUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('/api/image-proxy')) return raw;
    return '/api/image-proxy?url=${Uri.encodeComponent(raw)}';
  }

  Future<void> _handleDoubanCategories(
    HttpRequest request,
    Map<String, String> params,
  ) async {
    final kind = params['kind'] ?? 'movie';
    final category = params['category'] ?? '热门';
    final limit = int.tryParse(params['limit'] ?? '20') ?? 20;
    final start = int.tryParse(params['start'] ?? '0') ?? 0;

    final legacyTag = (kind == 'movie')
        ? category
        : (category == 'show' ? '综艺' : '热门');
    final legacyType = (kind == 'movie') ? 'movie' : 'tv';
    final legacyUrl =
        'https://movie.douban.com/j/search_subjects'
        '?type=$legacyType&tag=${Uri.encodeComponent(legacyTag)}'
        '&sort=recommend&page_limit=$limit&page_start=$start';

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    List<Map<String, dynamic>> items = [];

    // 1. 优先尝试 legacy 接口
    try {
      final req = await client.getUrl(Uri.parse(legacyUrl));
      req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/121.0.0.0 Safari/537.36');
      req.headers.set('Referer', 'https://movie.douban.com/');
      req.headers.set('Accept', 'application/json, text/plain, */*');
      final resp = await req.close();
      if (resp.statusCode == HttpStatus.ok) {
        final body = await utf8.decodeStream(resp);
        final data = jsonDecode(body) as Map<String, dynamic>;
        final subjects = data['subjects'] as List<dynamic>?;
        if (subjects != null && subjects.isNotEmpty) {
          items = subjects.map((s) {
            final rawId = s['id']?.toString() ?? '';
            final id = rawId.isNotEmpty
                ? rawId
                : RegExp(r'subject/(\d+)').firstMatch(s['url']?.toString() ?? '')?.group(1) ?? '';
            return {
              'id': id,
              'title': s['title']?.toString() ?? '',
              'poster': s['cover']?.toString() ?? '',
              'rate': s['rate']?.toString() ?? '',
              'year': '',
            };
          }).toList();
        }
      }
    } catch (_) {}

    // 2. 降级尝试 rexxar 接口
    if (items.isEmpty) {
      try {
        final type = params['type'] ?? '全部';
        final rexxarUrl =
            'https://m.douban.com/rexxar/api/v2/subject/recent_hot/$kind'
            '?start=$start&limit=$limit'
            '&category=${Uri.encodeComponent(category)}&type=${Uri.encodeComponent(type)}';
        final req = await client.getUrl(Uri.parse(rexxarUrl));
        req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/121.0.0.0 Safari/537.36');
        req.headers.set('Referer', 'https://movie.douban.com/');
        final resp = await req.close();
        if (resp.statusCode == HttpStatus.ok) {
          final body = await utf8.decodeStream(resp);
          final data = jsonDecode(body) as Map<String, dynamic>;
          final rawItems = data['items'] as List<dynamic>?;
          if (rawItems != null && rawItems.isNotEmpty) {
            items = rawItems.map((s) {
              final pic = s['pic'] as Map<String, dynamic>?;
              final rawCover = pic?['normal']?.toString() ?? pic?['large']?.toString() ?? '';
              final subtitle = s['card_subtitle']?.toString() ?? '';
              final yearMatch = RegExp(r'(\d{4})').firstMatch(subtitle);
              return {
                'id': s['id']?.toString() ?? '',
                'title': s['title']?.toString() ?? '',
                'poster': rawCover,
                'rate': s['rating']?['value']?.toString() ?? '',
                'year': yearMatch?.group(1) ?? '',
              };
            }).toList();
          }
        }
      } catch (_) {}
    }

    client.close();

    // 按照 MoonTV 规范，返回必须包含 code: 200 与 list
    final res = request.response;
    res.statusCode = HttpStatus.ok;
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode({
      'code': 200,
      'message': '获取成功',
      'list': items,
    }));
    await res.close();
  }

  Future<void> _handleImageProxy(
    HttpRequest request,
    Map<String, String> params,
  ) async {
    String target = params['url']?.trim() ?? '';
    final res = request.response;
    if (target.isEmpty) {
      res.statusCode = HttpStatus.badRequest;
      res.write('missing url');
      await res.close();
      return;
    }

    // 解除可能被前端重复编码或多重包装的代理前缀
    while (target.contains('url=')) {
      final idx = target.indexOf('url=');
      target = Uri.decodeComponent(target.substring(idx + 4));
    }

    final uri = Uri.tryParse(target);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      res.statusCode = HttpStatus.badRequest;
      res.write('invalid url: $target');
      await res.close();
      return;
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    try {
      final req = await client.getUrl(uri);
      req.followRedirects = true;
      req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36');
      req.headers.set('Accept', 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8');
      if (uri.host.contains('doubanio.com') || uri.host.contains('douban.com')) {
        req.headers.set('Referer', 'https://movie.douban.com/');
      }
      final upstream = await req.close();
      res.statusCode = upstream.statusCode;
      res.headers.set('Access-Control-Allow-Origin', '*');
      res.headers.set('Cache-Control', 'public, max-age=86400');
      if (upstream.headers.contentType != null) {
        res.headers.contentType = upstream.headers.contentType;
      } else {
        res.headers.contentType = ContentType('image', 'jpeg');
      }
      await upstream.pipe(res);
    } catch (e) {
      res.statusCode = HttpStatus.badGateway;
      res.write('Image Proxy Error: $e');
      await res.close();
    } finally {
      client.close();
    }
  }

  Future<void> _handleSearch(
    HttpRequest request,
    Map<String, String> params,
  ) async {
    final query = params['q']?.trim() ?? '';
    final res = request.response;
    if (query.isEmpty) {
      res.statusCode = HttpStatus.ok;
      res.headers.contentType = ContentType.json;
      res.write('{"results":[]}');
      await res.close();
      return;
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final futures = _sources.map((src) => _fetchSearchFromSource(client, src, query));
    final searchResults = await Future.wait(futures);
    client.close();

    final flattened = <Map<String, dynamic>>[];
    for (final list in searchResults) {
      flattened.addAll(list);
    }

    // 过滤词
    final filtered = flattened.where((r) {
      final typeName = (r['type_name'] as String? ?? '');
      final title = (r['title'] as String? ?? '');
      return !_yellowWords.any((w) => typeName.contains(w) || title.contains(w));
    }).toList();

    res.statusCode = HttpStatus.ok;
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode({'results': filtered}));
    await res.close();
  }

  Future<List<Map<String, dynamic>>> _fetchSearchFromSource(
    HttpClient client,
    MovieSource source,
    String query,
  ) async {
    try {
      final searchUrl = '${source.api}?wd=${Uri.encodeComponent(query)}';
      final req = await client.getUrl(Uri.parse(searchUrl));
      req.headers.set('User-Agent', 'Mozilla/5.0 FSYLTV/1.0');
      req.headers.set('Accept', 'application/json, text/plain, */*');
      final resp = await req.close().timeout(const Duration(seconds: 7));
      if (resp.statusCode != HttpStatus.ok) return [];

      final body = await utf8.decodeStream(resp);
      final json = jsonDecode(body) as Map<String, dynamic>;
      final list = json['list'] as List<dynamic>?;
      if (list == null) return [];

      return list.map((item) {
        final playUrl = item['vod_play_url']?.toString() ?? '';
        final episodes = _extractM3u8(playUrl);
        final rawPic = item['vod_pic']?.toString() ?? '';
        final poster = (rawPic.contains('doubanio.com') || rawPic.contains('douban.com'))
            ? _wrapPosterUrl(rawPic)
            : rawPic;
        return {
          'id': item['vod_id']?.toString() ?? '',
          'title': (item['vod_name']?.toString() ?? '').replaceAll(RegExp(r'\s+'), ' ').trim(),
          'poster': poster,
          'episodes': episodes,
          'source': source.key,
          'source_name': source.name,
          'class': item['vod_class']?.toString() ?? '',
          'year': item['vod_year']?.toString() ?? '',
          'desc': item['vod_content']?.toString() ?? '',
          'type_name': item['type_name']?.toString() ?? '',
          'douban_id': item['vod_douban_id'],
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _handleSearchOne(
    HttpRequest request,
    Map<String, String> params,
  ) async {
    final query = params['q']?.trim() ?? '';
    final resourceId = params['resourceId']?.trim() ?? '';
    final res = request.response;
    if (query.isEmpty || resourceId.isEmpty) {
      res.statusCode = HttpStatus.badRequest;
      res.headers.contentType = ContentType.json;
      res.write('{"error":"缺少必要参数: q 或 resourceId","result":null}');
      await res.close();
      return;
    }

    final target = _sources.firstWhere(
      (s) => s.key == resourceId,
      orElse: () => MovieSource(key: '', name: '', api: ''),
    );
    if (target.key.isEmpty) {
      res.statusCode = HttpStatus.notFound;
      res.headers.contentType = ContentType.json;
      res.write('{"error":"未找到指定的视频源","result":null}');
      await res.close();
      return;
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final results = await _fetchSearchFromSource(client, target, query);
    client.close();

    final matched = results.where((r) => r['title'] == query).toList();
    res.statusCode = HttpStatus.ok;
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode({'results': matched}));
    await res.close();
  }

  Future<void> _handleDetail(
    HttpRequest request,
    Map<String, String> params,
  ) async {
    final id = params['id']?.trim() ?? '';
    final sourceKey = params['source']?.trim() ?? '';
    final res = request.response;
    if (id.isEmpty || sourceKey.isEmpty) {
      res.statusCode = HttpStatus.badRequest;
      res.headers.contentType = ContentType.json;
      res.write('{"error":"缺少必要参数"}');
      await res.close();
      return;
    }

    final target = _sources.firstWhere(
      (s) => s.key == sourceKey,
      orElse: () => MovieSource(key: '', name: '', api: ''),
    );
    if (target.key.isEmpty) {
      res.statusCode = HttpStatus.notFound;
      res.headers.contentType = ContentType.json;
      res.write('{"error":"无效的API来源"}');
      await res.close();
      return;
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final detailUrl = '${target.api}?ac=detail&ids=$id';
      final req = await client.getUrl(Uri.parse(detailUrl));
      final resp = await req.close();
      final body = await utf8.decodeStream(resp);
      final json = jsonDecode(body) as Map<String, dynamic>;
      final list = json['list'] as List<dynamic>?;
      if (list != null && list.isNotEmpty) {
        final item = list[0] as Map<String, dynamic>;
        final playUrl = item['vod_play_url']?.toString() ?? '';
        final episodes = _extractM3u8(playUrl);
        final rawPic = item['vod_pic']?.toString() ?? '';
        final poster = (rawPic.contains('doubanio.com') || rawPic.contains('douban.com'))
            ? _wrapPosterUrl(rawPic)
            : rawPic;
        final result = {
          'id': item['vod_id']?.toString() ?? id,
          'title': item['vod_name']?.toString() ?? '',
          'poster': poster,
          'episodes': episodes,
          'source': target.key,
          'source_name': target.name,
          'class': item['vod_class']?.toString() ?? '',
          'year': item['vod_year']?.toString() ?? '',
          'desc': item['vod_content']?.toString() ?? '',
          'type_name': item['type_name']?.toString() ?? '',
        };
        res.statusCode = HttpStatus.ok;
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode(result));
        await res.close();
        return;
      }
    } catch (_) {} finally {
      client.close();
    }

    res.statusCode = HttpStatus.notFound;
    res.headers.contentType = ContentType.json;
    res.write('{"error":"未找到详情"}');
    await res.close();
  }

  List<String> _extractM3u8(String raw) {
    if (raw.isEmpty) return [];
    final regex = RegExp(r'\$(https?://[^"''\s]+?\.m3u8)');
    final parts = raw.split(r'$$$');
    List<String> episodes = [];
    for (final part in parts) {
      final matches = regex.allMatches(part).map((m) => m.group(1)!).toList();
      if (matches.length > episodes.length) {
        episodes = matches;
      }
    }
    return episodes.toSet().toList();
  }

  Future<void> _serveStaticFile(HttpRequest request) async {
    final siteDir = p.join(AppPaths.instance.movieDir, 'site');
    final rawPath = request.uri.path;
    final res = request.response;

    File? fileToServe;
    if (rawPath == '/' || rawPath.isEmpty) {
      fileToServe = File(p.join(siteDir, 'pages', 'index.html'));
    } else if (rawPath == '/play') {
      fileToServe = File(p.join(siteDir, 'pages', 'play.html'));
    } else if (rawPath == '/search') {
      fileToServe = File(p.join(siteDir, 'pages', 'search.html'));
    } else if (rawPath == '/douban') {
      fileToServe = File(p.join(siteDir, 'pages', 'douban.html'));
    } else if (rawPath == '/admin') {
      fileToServe = File(p.join(siteDir, 'pages', 'admin.html'));
    } else if (rawPath == '/login') {
      fileToServe = File(p.join(siteDir, 'pages', 'login.html'));
    } else if (rawPath.startsWith('/_next/static/')) {
      final sub = rawPath.substring('/_next/static/'.length);
      fileToServe = File(p.join(siteDir, '_next', 'static', sub));
    } else {
      // 检查 public 目录与根目录
      final publicFile = File(p.join(siteDir, 'public', rawPath.startsWith('/') ? rawPath.substring(1) : rawPath));
      if (publicFile.existsSync()) {
        fileToServe = publicFile;
      } else {
        final direct = File(p.join(siteDir, rawPath.startsWith('/') ? rawPath.substring(1) : rawPath));
        if (direct.existsSync()) {
          fileToServe = direct;
        }
      }
    }

    if (fileToServe != null && fileToServe.existsSync()) {
      final ext = p.extension(fileToServe.path).toLowerCase();
      res.statusCode = HttpStatus.ok;
      res.headers.set('Cache-Control', 'public, max-age=86400');
      switch (ext) {
        case '.html':
          res.headers.contentType = ContentType('text', 'html', charset: 'utf-8');
          break;
        case '.js':
          res.headers.contentType = ContentType('application', 'javascript', charset: 'utf-8');
          break;
        case '.css':
          res.headers.contentType = ContentType('text', 'css', charset: 'utf-8');
          break;
        case '.json':
        case '.webmanifest':
          res.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
          break;
        case '.png':
          res.headers.contentType = ContentType('image', 'png');
          break;
        case '.jpg':
        case '.jpeg':
          res.headers.contentType = ContentType('image', 'jpeg');
          break;
        case '.svg':
          res.headers.contentType = ContentType('image', 'svg+xml');
          break;
        case '.ico':
          res.headers.contentType = ContentType('image', 'x-icon');
          break;
        case '.woff2':
          res.headers.set('Content-Type', 'font/woff2');
          break;
        default:
          res.headers.contentType = ContentType.binary;
      }
      await fileToServe.openRead().pipe(res);
      return;
    }

    res.statusCode = HttpStatus.notFound;
    res.write('404 Not Found');
    await res.close();
  }
}
