import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

void main() {
  group('_SessionsTable', () {
    testWidgets('shows an empty-state message when there are no sessions', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestMaterialApp(
          const SecuritySection(
            sessions: [],
            isSaving: false,
            onChangePassword: _onChangePassword,
          ),
        ),
      );

      expect(find.text('No active sessions found'), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
    });

    testWidgets('renders the sessions DataTable when sessions exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestMaterialApp(
          const SecuritySection(
            sessions: [
              SecuritySession(
                device: 'MacBook Pro',
                location: 'Lagos, NG',
                date: '19 Oct 2026',
                lastActive: '2h ago',
                status: 'active',
              ),
            ],
            isSaving: false,
            onChangePassword: _onChangePassword,
          ),
        ),
      );

      expect(find.text('MacBook Pro'), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
    });
  });
}

Future<void> _onChangePassword({
  required String currentPassword,
  required String newPassword,
}) async {}
