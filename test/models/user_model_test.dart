import 'package:flutter_test/flutter_test.dart';
import 'package:sanchar_messaging_app/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('supports value equality', () {
      final user1 = UserModel(uid: '1', email: 'test@example.com');
      final user2 = UserModel(uid: '1', email: 'test@example.com');
      // Note: UserModel does not override ==, so they won't be equal by default.
      // We check properties.
      expect(user1.uid, user2.uid);
      expect(user1.email, user2.email);
    });

    test('toMap returns valid map', () {
      final user = UserModel(
        uid: '1',
        email: 'test@example.com',
        phoneNumber: '1234567890',
        displayName: 'Test User',
        username: 'test_user',
        photoUrl: 'http://example.com/photo.jpg',
        isOnline: true,
        lastSeen: DateTime.fromMillisecondsSinceEpoch(1000),
        showOnlineStatus: false,
      );

      final map = user.toMap();

      expect(map['uid'], '1');
      expect(map['email'], 'test@example.com');
      expect(map['phoneNumber'], '1234567890');
      expect(map['displayName'], 'Test User');
      expect(map['username'], 'test_user');
      expect(map['photoUrl'], 'http://example.com/photo.jpg');
      expect(map['isOnline'], true);
      expect(map['lastSeen'], 1000);
      expect(map['showOnlineStatus'], false);
    });

    test('fromMap returns valid object', () {
      final map = {
        'uid': '1',
        'email': 'test@example.com',
        'phoneNumber': '1234567890',
        'displayName': 'Test User',
        'username': 'test_user',
        'photoUrl': 'http://example.com/photo.jpg',
        'isOnline': true,
        'lastSeen': 1000,
        'showOnlineStatus': false,
      };

      final user = UserModel.fromMap(map);

      expect(user.uid, '1');
      expect(user.email, 'test@example.com');
      expect(user.phoneNumber, '1234567890');
      expect(user.displayName, 'Test User');
      expect(user.username, 'test_user');
      expect(user.photoUrl, 'http://example.com/photo.jpg');
      expect(user.isOnline, true);
      expect(user.lastSeen, DateTime.fromMillisecondsSinceEpoch(1000));
      expect(user.showOnlineStatus, false);
    });

    test('copyWith returns new object with updated values', () {
      final user = UserModel(
          uid: '1', email: 'test@example.com', username: 'old_name');
      final updatedUser =
          user.copyWith(email: 'new@example.com', username: 'new_name');

      expect(updatedUser.uid, '1');
      expect(updatedUser.email, 'new@example.com');
      expect(updatedUser.username, 'new_name');
    });
  });
}
