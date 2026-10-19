import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService api;
  late DmRepository repository;

  setUp(() {
    api = MockApiBaseService();
    repository = DmRepository(api);
  });

  group('DmRepository.sendMessage', () {
    Map<String, dynamic> sentBody() {
      final captured = verify(
        () => api.post<Map<String, dynamic>>(
          path: '/dms/channels/ch-1/threads',
          data: captureAny(named: 'data'),
        ),
      ).captured;
      return captured.single as Map<String, dynamic>;
    }

    void stubUploadAndSend() {
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/files/upload-files',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': [
              {'url': 'https://files.test/voice.m4a'},
            ],
          },
        ),
      );
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/dms/channels/ch-1/threads',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {},
        ),
      );
    }

    test('sends an empty paragraph for a voice note with no text', () async {
      stubUploadAndSend();

      await repository.sendMessage(
        'ch-1',
        '',
        media: [XFile.fromData(Uint8List(3), name: 'voice.m4a')],
      );

      expect(sentBody()['content'], '<p></p>');
    });

    test('keeps the typed text when media is attached', () async {
      stubUploadAndSend();

      await repository.sendMessage(
        'ch-1',
        'listen to this',
        media: [XFile.fromData(Uint8List(3), name: 'voice.m4a')],
      );

      expect(sentBody()['content'], 'listen to this');
    });

    test('leaves empty text alone when there is no media', () async {
      stubUploadAndSend();

      await repository.sendMessage('ch-1', '');

      expect(sentBody()['content'], '');
    });
  });

  group('DmRepository.openConversation', () {
    test('returns the channel and participant ids', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/organisations/org-1/dms',
          data: {'chat_type': 'user', 'participant_id': 'u-2'},
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {'channel_id': 'ch-9', 'participant_id': 'u-2'},
          },
        ),
      );

      final opened = await repository.openConversation(
        orgId: 'org-1',
        participantId: 'u-2',
      );

      expect(opened.channelId, 'ch-9');
      expect(opened.participantId, 'u-2');
    });

    test('rejects a response with an empty channel id', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/organisations/org-1/dms',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {'channel_id': '', 'participant_id': 'u-2'},
          },
        ),
      );

      expect(
        repository.openConversation(orgId: 'org-1', participantId: 'u-2'),
        throwsFormatException,
      );
    });
  });
}
