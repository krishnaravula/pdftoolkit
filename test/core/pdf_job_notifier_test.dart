import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/core/di/providers.dart';
import 'package:pdf_toolkit/domain/entities/pdf_job.dart';
import 'package:pdf_toolkit/services/pdf/pdf_job_runner.dart';

void main() {
  test('execute rethrows unrelated StateErrors', () async {
    final notifier = PdfJobNotifier(PdfJobRunner());
    addTearDown(notifier.dispose);

    await expectLater(
      notifier.execute<String>((_) async => throw StateError('boom')),
      throwsA(isA<StateError>()),
    );
    expect(notifier.state.status, PdfJobStatus.failure);
  });

  test('execute maps cancellation StateError to cancelled', () async {
    final notifier = PdfJobNotifier(PdfJobRunner());
    addTearDown(notifier.dispose);

    final result = await notifier.execute<String>(
      (_) async => throw StateError('cancelled'),
    );

    expect(result, isNull);
    expect(notifier.state.status, PdfJobStatus.cancelled);
  });
}
