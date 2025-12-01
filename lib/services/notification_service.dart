import 'package:awesome_notifications/awesome_notifications.dart';

class NotificationService {
  static bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Request Awesome Notifications Permission
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  Future<void> saveToken(String userId) async {
    // FCM is disabled as per user request.
    // If you need to save a token for another service, implement it here.
  }
}
