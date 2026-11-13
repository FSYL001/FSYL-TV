import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/bangumi_mirror_credentials.dart';
import 'package:kazumi/utils/dandan_credentials.dart';

String generateDandanSignature(String path, int timestamp) {
  final storedId = GStorage.getSetting(SettingsKeys.dandanAppId).trim();
  final storedKey = GStorage.getSetting(SettingsKeys.dandanAppKey).trim();
  final id = storedId.isNotEmpty ? storedId : dandanCredentials['id']!;
  final value = storedKey.isNotEmpty ? storedKey : dandanCredentials['value']!;
  final data = id + timestamp.toString() + path + value;
  final bytes = utf8.encode(data);
  final digest = sha256.convert(bytes);
  return base64Encode(digest.bytes);
}

String generateBangumiMirrorSearchSignature({
  required String method,
  required String path,
  required String body,
  required int timestamp,
}) {
  final id = bangumiMirrorCredentials['id']!;
  final value = bangumiMirrorCredentials['value']!;
  final bodyDigest = sha256.convert(utf8.encode(body)).toString();
  final data = id + timestamp.toString() + method + path + bodyDigest + value;
  final digest = sha256.convert(utf8.encode(data));
  return base64Encode(digest.bytes);
}

Future<String> calculateFileHash(File file) async {
  final bytes = await file.readAsBytes();
  final digest = sha256.convert(bytes);
  return digest.toString();
}
