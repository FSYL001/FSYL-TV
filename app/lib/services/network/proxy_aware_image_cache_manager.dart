import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:kazumi/services/network/image_file_service.dart';
import 'package:kazumi/shell/app_paths.dart';

class ProxyAwareImageCacheManager extends CacheManager with ImageCacheManager {
  static final ProxyAwareImageCacheManager instance =
      ProxyAwareImageCacheManager._(ImageFileService());

  ProxyAwareImageCacheManager._(this._fileService)
      : super(Config(
          DefaultCacheManager.key,
          fileService: _fileService,
          fileSystem: IOFileSystem('${AppPaths.instance.cacheDir}/images'),
          repo: JsonCacheInfoRepository.withFile(
            File(
              '${AppPaths.instance.cacheDir}/images/'
              '${DefaultCacheManager.key}.json',
            ),
          ),
        )) {
    Directory('${AppPaths.instance.cacheDir}/images').createSync(
      recursive: true,
    );
  }

  final ImageFileService _fileService;

  @override
  Future<void> dispose() async {
    _fileService.close();
    await super.dispose();
  }
}
