import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/core/di/providers.dart';
import 'package:pdf_toolkit/domain/entities/scan_page.dart';

void main() {
  ScanPage page(String id) => ScanPage(id: id, imagePath: '/tmp/$id.jpg');

  test('reorder moves item to the destination index', () {
    final notifier = ScanSessionNotifier();
    notifier.setPages([page('a'), page('b'), page('c')]);

    // ReorderableListView's onReorderItem already adjusts the destination
    // index, so the notifier performs a plain remove/insert.
    notifier.reorder(0, 2);

    expect(notifier.state.map((e) => e.id).toList(), ['b', 'c', 'a']);
  });

  test('removeAt removes the selected index', () {
    final notifier = ScanSessionNotifier();
    notifier.setPages([page('a'), page('b')]);

    notifier.removeAt(0);

    expect(notifier.state.map((e) => e.id).toList(), ['b']);
  });

  test('updatePage replaces a single page in state', () {
    final notifier = ScanSessionNotifier();
    notifier.setPages([page('a')]);
    final updated = ScanPage(
      id: 'a',
      imagePath: '/tmp/a-edited.jpg',
      enhancement: ScanEnhancementMode.blackAndWhite,
    );

    notifier.updatePage(0, updated);

    expect(notifier.state.single.imagePath, '/tmp/a-edited.jpg');
    expect(
      notifier.state.single.enhancement,
      ScanEnhancementMode.blackAndWhite,
    );
  });

  test('clear resets state to empty list', () {
    final notifier = ScanSessionNotifier();
    notifier.setPages([page('a')]);

    notifier.clear();

    expect(notifier.state, isEmpty);
  });
}
