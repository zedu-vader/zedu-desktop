import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

Widget buildComposerUnderTest() {
  return ProviderScope(
    child: buildTestMaterialApp(
      const Scaffold(
        body: DmMessageComposer(
          recipientName: 'Ada',
          channelId: 'channel-1',
          participants: [],
        ),
      ),
    ),
  );
}

TextEditingController composerController(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller;

Future<void> typeAndSelect(
  WidgetTester tester,
  String text, {
  TextSelection? selection,
}) async {
  await tester.tap(find.byType(TextField));
  await tester.enterText(find.byType(TextField), text);
  composerController(tester).selection =
      selection ?? TextSelection(baseOffset: 0, extentOffset: text.length);
  await tester.pump();
}

Future<void> pressShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  LogicalKeyboardKey modifier = LogicalKeyboardKey.controlLeft,
}) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

void main() {
  group('DmMessageComposer formatting shortcuts', () {
    testWidgets('Ctrl+B wraps the selected text in bold markers', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await typeAndSelect(tester, 'hello');

      await pressShortcut(tester, LogicalKeyboardKey.keyB);

      expect(composerController(tester).text, '**hello**');
    });

    testWidgets('Ctrl+I wraps the selected text in italic markers', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await typeAndSelect(tester, 'hello');

      await pressShortcut(tester, LogicalKeyboardKey.keyI);

      expect(composerController(tester).text, '*hello*');
    });

    testWidgets('Cmd+B works the same as Ctrl+B', (tester) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await typeAndSelect(tester, 'hello');

      await pressShortcut(
        tester,
        LogicalKeyboardKey.keyB,
        modifier: LogicalKeyboardKey.metaLeft,
      );

      expect(composerController(tester).text, '**hello**');
    });

    testWidgets('with no selection, inserts markers with cursor between', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await typeAndSelect(
        tester,
        'hi ',
        selection: const TextSelection.collapsed(offset: 3),
      );

      await pressShortcut(tester, LogicalKeyboardKey.keyB);

      final controller = composerController(tester);
      expect(controller.text, 'hi ****');
      expect(controller.selection, const TextSelection.collapsed(offset: 5));
    });
  });
}
