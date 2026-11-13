import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/update/auto_updater.dart';
import 'package:kazumi/utils/version.dart';

void main() {
  test('GitHub release asset matching uses the portable asset only', () {
    final assets = [
      {
        'name': 'FSYLTV-windows-setup.zip',
        'browser_download_url': 'https://example/FSYLTV-windows-setup.zip',
      },
      {
        'name': 'FSYLTV-windows-portable.zip',
        'browser_download_url': 'https://example/FSYLTV-windows-portable.zip',
      },
    ];
    final asset = getUpdateAssetForType(assets, InstallationType.windowsPortable);
    expect(asset, isNotNull);
    expect(asset!['name'], 'FSYLTV-windows-portable.zip');
  });

  test('version comparison accepts v-prefixed release tags', () {
    expect(needUpdate('1.0.0', 'v1.0.1'), isTrue);
    expect(needUpdate('1.0.0', 'v1.0.0'), isFalse);
    expect(needUpdate('1.0.1', 'v1.0.0'), isFalse);
  });
}
