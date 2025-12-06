import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchar_messaging_app/models/story.dart';

void main() {
  group('Story', () {
    test('toMap returns valid map', () {
      final timestamp = DateTime.now();
      final story = Story(
        id: '1',
        uploaderId: 'uploader',
        mediaUrl: 'http://example.com/media.jpg',
        mediaType: 'image',
        caption: 'caption',
        timestamp: timestamp,
        viewers: ['viewer1', 'viewer2'],
      );

      final map = story.toMap();

      expect(map['uploaderId'], 'uploader');
      expect(map['mediaUrl'], 'http://example.com/media.jpg');
      expect(map['mediaType'], 'image');
      expect(map['caption'], 'caption');
      // Timestamp comparison might need tolerance or exact type check
      expect((map['timestamp'] as Timestamp).toDate().millisecondsSinceEpoch, timestamp.millisecondsSinceEpoch);
      expect(map['viewers'], ['viewer1', 'viewer2']);
    });

    test('fromMap returns valid object', () {
      final timestamp = Timestamp.now();
      final map = {
        'uploaderId': 'uploader',
        'mediaUrl': 'http://example.com/media.jpg',
        'mediaType': 'image',
        'caption': 'caption',
        'timestamp': timestamp,
        'viewers': ['viewer1', 'viewer2'],
      };

      final story = Story.fromMap(map, '1');

      expect(story.id, '1');
      expect(story.uploaderId, 'uploader');
      expect(story.mediaUrl, 'http://example.com/media.jpg');
      expect(story.mediaType, 'image');
      expect(story.caption, 'caption');
      expect(story.timestamp.millisecondsSinceEpoch, timestamp.toDate().millisecondsSinceEpoch);
      expect(story.viewers, ['viewer1', 'viewer2']);
    });
  });
}
