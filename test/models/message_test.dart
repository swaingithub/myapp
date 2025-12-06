import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchar_messaging_app/models/message.dart';

void main() {
  group('Message', () {
    test('toMap returns valid map', () {
      final timestamp = Timestamp.now();
      final message = Message(
        id: '1',
        senderId: 'sender',
        receiverId: 'receiver',
        content: 'hello',
        timestamp: timestamp,
        type: 'text',
        isViewed: true,
        isDelivered: true,
        imageData: 'base64image',
        fileName: 'file.txt',
        fileSize: 1024,
      );

      final map = message.toMap();

      expect(map['senderId'], 'sender');
      expect(map['receiverId'], 'receiver');
      expect(map['content'], 'hello');
      expect(map['timestamp'], timestamp);
      expect(map['type'], 'text');
      expect(map['isViewed'], true);
      expect(map['isDelivered'], true);
      expect(map['imageData'], 'base64image');
      expect(map['fileName'], 'file.txt');
      expect(map['fileSize'], 1024);
    });

    test('fromMap returns valid object', () {
      final timestamp = Timestamp.now();
      final map = {
        'senderId': 'sender',
        'receiverId': 'receiver',
        'content': 'hello',
        'timestamp': timestamp,
        'type': 'text',
        'isViewed': true,
        'isDelivered': true,
        'imageData': 'base64image',
        'fileName': 'file.txt',
        'fileSize': 1024,
      };

      final message = Message.fromMap(map, id: '1');

      expect(message.id, '1');
      expect(message.senderId, 'sender');
      expect(message.receiverId, 'receiver');
      expect(message.content, 'hello');
      expect(message.timestamp, timestamp);
      expect(message.type, 'text');
      expect(message.isViewed, true);
      expect(message.isDelivered, true);
      expect(message.imageData, 'base64image');
      expect(message.fileName, 'file.txt');
      expect(message.fileSize, 1024);
    });

    test('copyWith returns new object with updated values', () {
      final message = Message(
        senderId: 'sender',
        receiverId: 'receiver',
        content: 'hello',
        timestamp: Timestamp.now(),
      );
      final updatedMessage = message.copyWith(content: 'world');

      expect(updatedMessage.senderId, 'sender');
      expect(updatedMessage.content, 'world');
    });
  });
}
