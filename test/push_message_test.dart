import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munib/data/services/push_notification_service.dart';

void main() {
  group('PushMessage', () {
    test('prefers notification title/body and parses destination', () {
      const remote = RemoteMessage(
        notification: RemoteNotification(
          title: '  تنبيه منيب  ',
          body: '  افتح النفحات  ',
        ),
        data: <String, dynamic>{
          'title': 'fallback title',
          'body': 'fallback body',
          'screen': 'nafahat',
        },
      );

      final push = PushMessage.fromRemoteMessage(remote);

      expect(push.title, 'تنبيه منيب');
      expect(push.body, 'افتح النفحات');
      expect(push.destination?.homeIndex, 2);
      expect(push.hasVisibleContent, isTrue);
    });

    test('uses data payload when notification payload is absent', () {
      const remote = RemoteMessage(
        data: <String, dynamic>{
          'title': '  Data title  ',
          'body': '  Data body  ',
          'screen': 'adhkar',
          'category': 'evening',
        },
      );

      final push = PushMessage.fromRemoteMessage(remote);

      expect(push.title, 'Data title');
      expect(push.body, 'Data body');
      expect(push.destination?.homeIndex, 1);
      expect(push.destination?.initialAzkarCategory, isNotNull);
    });

    test('ignores an empty invisible payload', () {
      const remote = RemoteMessage(data: <String, dynamic>{});
      final push = PushMessage.fromRemoteMessage(remote);

      expect(push.hasVisibleContent, isFalse);
      expect(push.destination, isNull);
    });
  });
}
