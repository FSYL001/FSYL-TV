import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/shell/app_paths.dart';
import 'package:kazumi/shell/moon_sidecar.dart';

void main() {
  test('fake sidecar: start -> READY -> health -> clean shutdown', () async {
    await AppPaths.instance.init();
    expect(AppPaths.instance.moonDir, isNotEmpty);

    final sidecar = MoonSidecar();
    await sidecar.start();

    expect(sidecar.status, MoonStatus.ready,
        reason: 'sidecar error: ${sidecar.error}');
    expect(sidecar.port, isNotNull);
    final pid = sidecar.pid!;
    expect(pid, greaterThan(0));

    final client = HttpClient();
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${sidecar.port}/api/health'),
    );
    final response = await request.close();
    expect(response.statusCode, 200);
    await response.drain<void>();
    client.close(force: true);

    await sidecar.stop();
    expect(sidecar.status, MoonStatus.stopped);
    expect(sidecar.pid, isNull);

    final result = await Process.run(
      'tasklist',
      ['/FI', 'PID eq $pid', '/FO', 'CSV', '/NH'],
    );
    final output = (result.stdout as String).trim();
    expect(output.contains('"$pid"'), isFalse,
        reason: 'process $pid still listed: $output');

    sidecar.dispose();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
