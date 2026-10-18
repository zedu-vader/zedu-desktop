import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../test/helpers/helpers.dart';

// Repro for: channel create/edit dialogs close before the request finishes
// and swallow failures. Failing repository -> dialog must stay open with a
// visible error. Currently it pops immediately with zero feedback.
class _FailingChannelRepository implements ChannelRepository {
  @override
  Future<Result<List<Channel>>> fetchChannels(String orgId) async {
    return const Failure<List<Channel>>(
      ApiFailure(message: 'offline', kind: ApiFailureKind.network),
    );
  }

  @override
  Future<Result<Channel>> createChannel({
    required String name,
    required String description,
    required String orgId,
    required String username,
    required bool isPrivate,
    String? topic,
  }) async {
    return const Failure<Channel>(
      ApiFailure(message: 'offline', kind: ApiFailureKind.network),
    );
  }

  @override
  Future<Result<void>> updateChannelTopicOrDescription({
    required String channelId,
    String? topic,
    String? description,
  }) async {
    return const Failure<void>(
      ApiFailure(message: 'offline', kind: ApiFailureKind.network),
    );
  }

  @override
  Future<Result<void>> archiveChannel(String channelId, bool archived) async {
    return const Failure<void>(
      ApiFailure(message: 'offline', kind: ApiFailureKind.network),
    );
  }
}

class _SeededWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() {
    return const WorkspaceState(
      workspaces: [
        Workspace(id: 'o1', name: 'Test Org', avatar: ''),
      ],
      selectedWorkspace: Workspace(id: 'o1', name: 'Test Org', avatar: ''),
    );
  }
}

class _SeededAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: User(
        id: 'u1',
        firstName: 'Test',
        lastName: 'User',
        email: 'test@example.com',
        phone: '',
        username: 'tester',
        isVerified: true,
        isOnboarded: true,
        createdAt: DateTime(2024),
        currentOrg: 'o1',
        currentOrganisationSlug: 'test',
        avatarUrl: '',
        defaultAvatarUrl: '',
      ),
    );
  }
}

List<Override> _reproOverrides() => [
      channelRepositoryProvider.overrideWithValue(_FailingChannelRepository()),
      workspaceProvider.overrideWith(
        _SeededWorkspaceNotifier.new,
      ),
      authNotifierProvider.overrideWith(
        _SeededAuthNotifier.new,
      ),
    ];

void main() {
  group('channel modal failure repro', () {
    testWidgets('failed create keeps dialog open with visible error',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _reproOverrides(),
          child: buildTestMaterialApp(const CreateChannelModal()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. plan-budget'),
        'offline-channel',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pumpAndSettle();

      // Bug: dialog pops immediately. Fixed behavior: still open + error shown.
      expect(
        find.widgetWithText(TextField, 'e.g. plan-budget'),
        findsOneWidget,
        reason: 'dialog must stay open on failure',
      );
      expect(
        find.textContaining(RegExp('fail|error|offline|try again',
            caseSensitive: false)),
        findsWidgets,
        reason: 'failure must be visible',
      );
    });

    testWidgets('failed edit keeps dialog open with visible error',
        (tester) async {
      final channel = Channel(
        id: 'c1',
        name: 'general',
        description: 'old',
        organisationId: 'o1',
        ownerId: 'u1',
        topic: 'old topic',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _reproOverrides(),
          child: buildTestMaterialApp(EditChannelModal(channel: channel)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Edit #general'),
        findsOneWidget,
        reason: 'dialog must stay open on failure',
      );
      expect(
        find.textContaining(RegExp('fail|error|offline|try again',
            caseSensitive: false)),
        findsWidgets,
        reason: 'failure must be visible',
      );
    });
  });
}
