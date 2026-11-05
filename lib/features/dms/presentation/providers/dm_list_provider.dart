import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final currentOrgIdProvider = Provider<String>((ref) {
  final workspace = ref.watch(workspaceProvider).selectedWorkspace;
  return workspace?.id ?? '';
});

final dmListProvider =
    AsyncNotifierProvider<DmListNotifier, List<DmConversation>>(() {
      return DmListNotifier();
    });

class SelectedDmNotifier extends Notifier<DmConversation?> {
  @override
  DmConversation? build() => null;

  void select(DmConversation? conversation) {
    state = conversation;
  }
}

final selectedDmProvider =
    NotifierProvider<SelectedDmNotifier, DmConversation?>(
      SelectedDmNotifier.new,
    );

class DmConversationActions {
  final Set<String> pinnedIds;
  final Set<String> deletedIds;

  const DmConversationActions({
    this.pinnedIds = const {},
    this.deletedIds = const {},
  });

  DmConversationActions copyWith({
    Set<String>? pinnedIds,
    Set<String>? deletedIds,
  }) => DmConversationActions(
    pinnedIds: pinnedIds ?? this.pinnedIds,
    deletedIds: deletedIds ?? this.deletedIds,
  );
}

class DmConversationActionsNotifier extends Notifier<DmConversationActions> {
  /// Where this user's pins are remembered (null while signed out).
  String? _pinnedKey;

  @override
  DmConversationActions build() {
    // Rebuilt for each signed-in user, so one account never sees another's pins.
    final userId = dmPreferencesUserId(ref);
    _pinnedKey = userId == null || userId.isEmpty
        ? null
        : DmPreferencesStore.pinnedKey(userId);
    final key = _pinnedKey;
    if (key != null) _restorePinned(key);
    return const DmConversationActions();
  }

  Future<void> _restorePinned(String key) async {
    final saved = await ref.read(dmPreferencesStoreProvider).read(key);
    if (!ref.mounted || _pinnedKey != key || saved.isEmpty) return;
    // Keep anything pinned while the saved list was loading.
    state = state.copyWith(pinnedIds: {...saved, ...state.pinnedIds});
  }

  void togglePinned(String channelId) {
    final ids = Set<String>.from(state.pinnedIds);
    ids.contains(channelId) ? ids.remove(channelId) : ids.add(channelId);
    state = state.copyWith(pinnedIds: ids);
    final key = _pinnedKey;
    if (key != null) {
      unawaited(ref.read(dmPreferencesStoreProvider).write(key, ids));
    }
  }

  /// Deletes the conversation on the server, then hides it from the list
  /// until the next refresh drops it and discards its draft. Closes it only
  /// if it's still the open DM. Returns false if the request failed.
  Future<bool> delete(String channelId) async {
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return false;
    try {
      await ref
          .read(dmRepositoryProvider)
          .deleteConversation(orgId: orgId, channelId: channelId);
    } catch (_) {
      return false;
    }
    state = state.copyWith(deletedIds: {...state.deletedIds, channelId});
    ref.read(dmDraftStoreProvider).clear(channelId);
    if (ref.read(selectedDmProvider)?.channelId == channelId) {
      ref.read(selectedDmProvider.notifier).select(null);
    }
    return true;
  }
}

final dmConversationActionsProvider =
    NotifierProvider<DmConversationActionsNotifier, DmConversationActions>(
      DmConversationActionsNotifier.new,
    );

class DmListNotifier extends AsyncNotifier<List<DmConversation>> {
  int _currentPage = 1;
  bool _hasMore = true;

  /// Changes on every reload, so a page still in flight from before can be
  /// dropped.
  int _listVersion = 0;

  static const _pollInterval = Duration(seconds: 10);

  Timer? _pollTimer;
  bool _polling = false;
  bool _seeded = false;
  final Set<String> _seenThreadIds = {};

  bool get hasMore => _hasMore;

  @override
  Future<List<DmConversation>> build() async {
    final orgId = ref.watch(currentOrgIdProvider);
    _listVersion++;
    _stopPolling();
    _seenThreadIds.clear();
    _seeded = false;
    ref.onDispose(_stopPolling);
    if (orgId.isEmpty) return const [];

    _currentPage = 1;
    _hasMore = true;
    final conversations = await _fetchPage(orgId, 1);
    if (!ref.mounted) return conversations;

    _seedSeen(conversations);
    _startPolling();
    return conversations;
  }

  void _seedSeen(List<DmConversation> conversations) {
    for (final conversation in conversations) {
      for (final thread in conversation.previewThreads) {
        _seenThreadIds.add(thread.threadId);
      }
    }
    _seeded = true;
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(pollNewMessages()),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Refreshes the first page and notifies for messages that arrived in a DM
  /// nobody has open. An open chat has its own poller (ChatHistoryNotifier).
  Future<void> pollNewMessages() async {
    if (_polling) return;
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return;

    _polling = true;
    final version = _listVersion;
    try {
      final fresh = await ref
          .read(dmRepositoryProvider)
          .getConversations(orgId: orgId, page: 1);
      if (!ref.mounted || version != _listVersion) return;

      if (!_seeded) {
        _seedSeen(fresh);
        return;
      }
      _notifyNewThreads(fresh);
      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(_merge(current, fresh));
      }
    } catch (_) {
      // A failed poll leaves the list as it was; the next tick tries again.
    } finally {
      _polling = false;
    }
  }

  void _notifyNewThreads(List<DmConversation> conversations) {
    for (final conversation in conversations) {
      if (conversation.previewThreads.isEmpty) continue;
      // Only the newest preview is announced; earlier ones arrive with it.
      final thread = conversation.previewThreads.first;
      if (!_seenThreadIds.add(thread.threadId)) continue;
      unawaited(
        ref
            .read(notificationServiceProvider)
            .handleIncomingMessage(
              {
                'id': thread.threadId,
                'user_id': thread.userId,
                'content': thread.message,
              },
              conversation.channelId,
              thread.username,
            ),
      );
    }
  }

  List<DmConversation> _merge(
    List<DmConversation> current,
    List<DmConversation> fresh,
  ) {
    final byChannel = {for (final c in fresh) c.channelId: c};
    final merged = [
      for (final c in current) byChannel.remove(c.channelId) ?? c,
      ...byChannel.values,
    ];
    merged.sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    return merged;
  }

  Future<List<DmConversation>> _fetchPage(String orgId, int page) async {
    final repository = ref.read(dmRepositoryProvider);
    final version = _listVersion;
    final results = await repository.getConversations(orgId: orgId, page: page);
    if (version == _listVersion && results.length < DmRepository.pageSize) {
      _hasMore = false;
    }
    return results;
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return;

    final current = state.value ?? [];
    final version = _listVersion;
    // Only count the page once it has loaded, so a failed load is asked for
    // again on the next scroll instead of being skipped.
    final page = _currentPage + 1;
    final next = await _fetchPage(orgId, page);
    if (version != _listVersion) return;
    _currentPage = page;
    state = AsyncValue.data([...current, ...next]);
  }

  Future<void> refresh() async {
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return;

    _listVersion++;
    _currentPage = 1;
    _hasMore = true;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchPage(orgId, 1));
  }
}
