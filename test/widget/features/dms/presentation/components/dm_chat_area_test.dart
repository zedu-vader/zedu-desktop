import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockDmRepository extends Mock implements DmRepository {}

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'user-1',
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      phone: '',
      username: 'testuser',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'test-org',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

void main() {
  group('DmChatArea message text', () {
    Future<void> pumpChat(
      WidgetTester tester,
      List<Map<String, dynamic>> messages,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MockDmRepository();
      when(
        () => repository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer((_) async => messages);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dmRepositoryProvider.overrideWithValue(repository),
            authNotifierProvider.overrideWith(FakeAuthNotifier.new),
          ],
          child: buildTestMaterialApp(
            Scaffold(
              body: DmChatArea(
                conversation: DmConversation(
                  channelId: 'ch-1',
                  username: 'Ada Lovelace',
                  participantId: 'u-2',
                  previewMessage: '',
                  unreadCount: 0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Map<String, dynamic> message(String id, String content) => {
      'id': id,
      'content': content,
      'user_id': 'u-2',
      'created_at': '2026-10-17T08:00:00Z',
    };

    testWidgets('shows no text for a message with an empty paragraph', (
      tester,
    ) async {
      await pumpChat(tester, [message('m1', '<p></p>')]);

      expect(find.text('<p></p>', findRichText: true), findsNothing);
    });

    testWidgets('still shows the text of a normal message', (tester) async {
      await pumpChat(tester, [message('m1', 'hello there')]);

      expect(find.text('hello there', findRichText: true), findsOneWidget);
    });
  });
}
