import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:kazumi/shell/app_paths.dart';

class ImageCacheService {
  Stream<File> _files() async* {
    final directory =
        Directory(p.join(AppPaths.instance.cacheDir, 'images', DefaultCacheManager.key));
    if (!await directory.exists()) return;
    yield* directory
        .list(recursive: true, followLinks: false)
        .where((entry) => entry is File)
        .cast<File>();
  }

  Future<int> sizeInBytes() async {
    var bytes = 0;
    await for (final file in _files()) {
      // Files may expire during enumeration.
      final stat = await file.stat();
      if (stat.type == FileSystemEntityType.file) bytes += stat.size;
    }
    return bytes;
  }

  Future<void> clear() async {
    // Include orphaned files, but leave images cached after this snapshot.
    final files = await _files().toList();
    await DefaultCacheManager().emptyCache();
    for (final file in files) {
      try {
        await file.delete();
      } on PathNotFoundException {
        // Already removed by the cache manager.
      }
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
