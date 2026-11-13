import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/shell/account/account_service.dart';
import 'package:kazumi/shell/account/dpapi.dart';
import 'package:kazumi/shell/app_paths.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('account skeleton persists device id and DPAPI-encrypted token', () async {
    await AppPaths.instance.init();
    final service = AccountService.instance;
    await service.init();

    expect(service.deviceId, isNotEmpty);
    expect(
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
          .hasMatch(service.deviceId),
      isTrue,
      reason: 'device id should be a UUID v4: ${service.deviceId}',
    );

    await service.saveProfile(
      serverUrl: 'https://example.invalid',
      username: 'tester',
      password: 'p@ssw0rd-秘密',
      autoSync: true,
      backgroundSync: false,
    );

    final profile = File(AppPaths.instance.accountDir + '/account.json');
    expect(profile.existsSync(), isTrue);
    final profileMap =
        jsonDecode(await profile.readAsString()) as Map<String, dynamic>;
    expect(profileMap['serverUrl'], 'https://example.invalid');
    expect(profileMap['autoSync'], true);
    expect(profileMap['loggedIn'], false);

    final token = File(AppPaths.instance.accountDir + '/token.bin');
    expect(token.existsSync(), isTrue);
    final encrypted = await token.readAsBytes();
    expect(utf8.decode(encrypted, allowMalformed: true).contains('p@ssw0rd'),
        isFalse);

    final decrypted = utf8.decode(Dpapi.unprotect(encrypted));
    expect(decrypted, 'p@ssw0rd-秘密');

    final loggedIn = await service.login(
      serverUrl: 'https://example.invalid',
      username: 'tester',
      password: 'p@ssw0rd-秘密',
    );
    expect(loggedIn, isFalse);
    expect(service.loggedIn, isFalse);
  });
}
