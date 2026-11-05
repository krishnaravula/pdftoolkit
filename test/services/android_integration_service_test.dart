import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/services/platform/android_integration_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pdf_toolkit/android');

  test('cold and warm imports keep the same key across cache copies', () async {
    const readingKey = 'android-uri:document';
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'consumeInitialPdf');
      return {'path': '/cache/report.pdf', 'readingPositionKey': readingKey};
    });
    final service = AndroidIntegrationService(isAndroid: true);
    addTearDown(service.dispose);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final initial = await service.start();
    final next = service.openedPdfs.first;
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        const MethodCall('openPdf', {
          'path': '/cache/report_1.pdf',
          'readingPositionKey': readingKey,
        }),
      ),
      null,
    );
    final warm = await next;

    expect(initial?.path, '/cache/report.pdf');
    expect(warm.path, '/cache/report_1.pdf');
    expect(initial?.readingPositionKey, readingKey);
    expect(warm.readingPositionKey, readingKey);
    expect(await service.start(), isNull);
  });
}
