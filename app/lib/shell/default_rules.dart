import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kazumi/shell/app_paths.dart';

/// Seeds the rules the user imported before this build. The file is only a
/// first-run default: the rule shop / catalog remains responsible for updates,
/// and an existing plugins.json is never overwritten.
class DefaultRules {
  DefaultRules._();

  static Future<void> ensureSeeded() async {
    final directory = Directory('${AppPaths.instance.animeDir}/plugins/v2');
    await directory.create(recursive: true);
    final target = File('${directory.path}/plugins.json');
    if (await target.exists() && await target.length() > 2) return;
    final data = await rootBundle.loadString('assets/rules/plugins.json');
    await target.writeAsString(data, flush: true);
  }
}
