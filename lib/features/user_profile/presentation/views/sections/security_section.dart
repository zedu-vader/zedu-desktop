import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class SecuritySection extends StatelessWidget {
  const SecuritySection({
    super.key,
    required this.sessions,
    required this.isSaving,
    required this.onChangePassword,
  });

  final List<SecuritySession> sessions;
  final bool isSaving;
  final Future<void> Function({
    required String currentPassword,
    required String newPassword,
  })
  onChangePassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionHeader(
          title: 'Your Account Security',
          subtitle: 'Keeping your data secure by staying in-the-know',
          trailing: AppButton.outlined(
            label: 'Change password',
            expand: false,
            height: 44,
            loading: isSaving,
            onPressed: () =>
                showChangePasswordDialog(context, onChangePassword),
          ),
        ),
        const SizedBox(height: 28),
        _SessionsTable(sessions: sessions),
      ],
    );
  }
}

class _SessionsTable extends StatelessWidget {
  const _SessionsTable({required this.sessions});

  final List<SecuritySession> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return ProfileCard(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: _SessionsEmptyState(),
        ),
      );
    }

    return ProfileCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 800),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFFAFAFA)),
            columns: const [
              DataColumn(label: Text('Device')),
              DataColumn(label: Text('Location')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Last active')),
              DataColumn(label: Text('Status')),
            ],
            rows: sessions.map((session) {
              return DataRow(
                cells: [
                  DataCell(Text(session.device)),
                  DataCell(Text(session.location)),
                  DataCell(Text(session.date)),
                  DataCell(Text(session.lastActive)),
                  DataCell(ProfileStatusPill(status: session.status)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _SessionsEmptyState extends StatelessWidget {
  const _SessionsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFFF3F4F6),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.device_unknown,
              size: 28,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No active sessions found',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            'You have no active sessions on any device.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }
}
