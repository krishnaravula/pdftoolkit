import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/core/errors/app_exception.dart';
import 'package:pdf_toolkit/domain/entities/pdf_job.dart';
import 'package:pdf_toolkit/services/pdf/pdf_job_runner.dart';

void main() {
  test('run emits running then success states', () async {
    final runner = PdfJobRunner();
    final controller = StreamController<PdfJobProgress>();
    final events = <PdfJobProgress>[];
    final sub = controller.stream.listen(events.add);

    final result = await runner.run<String>(
      progress: controller,
      task: (reporter) async {
        reporter.update(1, 2, 'working');
        return 'done';
      },
    );

    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    await controller.close();

    expect(result, 'done');
    expect(events.first.status, PdfJobStatus.running);
    expect(events.last.status, PdfJobStatus.success);
  });

  test('run emits cancelled when cancel is triggered during task', () async {
    final runner = PdfJobRunner();
    final controller = StreamController<PdfJobProgress>();
    final events = <PdfJobProgress>[];
    final sub = controller.stream.listen(events.add);

    await expectLater(
      () => runner.run<void>(
        progress: controller,
        task: (reporter) async {
          runner.cancel();
        },
      ),
      throwsA(isA<PdfOperationCancelledException>()),
    );

    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    await controller.close();

    expect(events.any((e) => e.status == PdfJobStatus.cancelled), isTrue);
  });

  test('run emits failure when task throws', () async {
    final runner = PdfJobRunner();
    final controller = StreamController<PdfJobProgress>();
    final events = <PdfJobProgress>[];
    final sub = controller.stream.listen(events.add);

    await expectLater(
      () => runner.run<void>(
        progress: controller,
        task: (_) async => throw StateError('boom'),
      ),
      throwsA(isA<StateError>()),
    );

    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    await controller.close();

    expect(events.last.status, PdfJobStatus.failure);
    expect(events.last.error, contains('boom'));
  });

  test(
    'reporter cancellation checkpoints stop the task with cancelled status',
    () async {
      final runner = PdfJobRunner();
      final controller = StreamController<PdfJobProgress>();
      final events = <PdfJobProgress>[];
      final sub = controller.stream.listen(events.add);

      await expectLater(
        () => runner.run<void>(
          progress: controller,
          task: (reporter) async {
            runner.cancel();
            reporter.checkCancelled();
          },
        ),
        throwsA(isA<PdfOperationCancelledException>()),
      );

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await controller.close();
      expect(events.last.status, PdfJobStatus.cancelled);
    },
  );
}
