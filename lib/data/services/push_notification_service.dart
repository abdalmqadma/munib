import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'push_navigation_service.dart';

class PushMessage {
  final String title;
  final String body;
  final PushDestination? destination;

  const PushMessage({
    required this.title,
    required this.body,
    required this.destination,
  });

  bool get hasVisibleContent => title.isNotEmpty || body.isNotEmpty;

  factory PushMessage.fromRemoteMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    return PushMessage(
      title: (notification?.title ?? data['title']?.toString() ?? '').trim(),
      body: (notification?.body ?? data['body']?.toString() ?? '').trim(),
      destination: PushNavigationService.destinationFromData(data),
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Notification payloads are displayed by Android/iOS while the app is in the
  // background. Data-only messages still reach this handler, but no UI work is
  // attempted here so Munib's existing local-notification system stays isolated.
  PushNavigationService.destinationFromData(message.data);
}

class PushNotificationService {
  const PushNotificationService._();

  static const generalTopic = 'munib_general';
  static const _maxTopicRetries = 6;

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final StreamController<PushMessage> _foregroundController =
      StreamController<PushMessage>.broadcast();
  static final StreamController<PushDestination> _openedController =
      StreamController<PushDestination>.broadcast();

  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static StreamSubscription<String>? _tokenSubscription;
  static Timer? _topicRetryTimer;
  static bool _initialized = false;
  static bool _topicSubscriptionInFlight = false;
  static int _topicRetryCount = 0;

  static Stream<PushMessage> get foregroundMessages =>
      _foregroundController.stream;
  static Stream<PushDestination> get openedDestinations =>
      _openedController.stream;

  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  static Future<void> init() async {
    if (_initialized) return;

    await _messaging.setAutoInitEnabled(true);

    // Munib presents foreground pushes inside the app instead of initializing a
    // second local-notifications callback, avoiding conflicts with prayer/adhkar
    // notification handling.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      final push = PushMessage.fromRemoteMessage(message);
      if (push.hasVisibleContent) {
        _foregroundController.add(push);
      }
    });

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final destination =
          PushNavigationService.destinationFromData(message.data);
      if (destination != null) {
        _openedController.add(destination);
      }
    });

    _tokenSubscription = _messaging.onTokenRefresh.listen((_) {
      _topicRetryCount = 0;
      unawaited(_subscribeToGeneralTopic());
    });

    final initialMessage = await _messaging.getInitialMessage();
    final initialDestination = initialMessage == null
        ? null
        : PushNavigationService.destinationFromData(initialMessage.data);
    if (initialDestination != null) {
      PushNavigationService.defer(initialDestination);
    }

    _initialized = true;
    unawaited(_subscribeToGeneralTopic());
  }

  static void deferDestination(PushDestination destination) {
    PushNavigationService.defer(destination);
  }

  static PushDestination? takeDeferredDestination() {
    return PushNavigationService.takePending();
  }

  static Future<void> _subscribeToGeneralTopic() async {
    if (_topicSubscriptionInFlight) return;
    _topicSubscriptionInFlight = true;

    try {
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          _scheduleTopicRetry();
          return;
        }
      }

      await _messaging.subscribeToTopic(generalTopic);
      _topicRetryCount = 0;
      _topicRetryTimer?.cancel();
      _topicRetryTimer = null;
    } catch (error) {
      debugPrint('FCM topic subscription deferred: $error');
      _scheduleTopicRetry();
    } finally {
      _topicSubscriptionInFlight = false;
    }
  }

  static void _scheduleTopicRetry() {
    if (_topicRetryCount >= _maxTopicRetries) return;
    _topicRetryCount += 1;
    _topicRetryTimer?.cancel();
    _topicRetryTimer = Timer(const Duration(seconds: 5), () {
      unawaited(_subscribeToGeneralTopic());
    });
  }
}
