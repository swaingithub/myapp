import 'package:cloud_firestore/cloud_firestore.dart';

class Story {
  final String id;
  final String uploaderId;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String? caption;
  final DateTime timestamp;
  final List<String> viewers;

  Story({
    required this.id,
    required this.uploaderId,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    required this.timestamp,
    required this.viewers,
  });

  Map<String, dynamic> toMap() {
    return {
      'uploaderId': uploaderId,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'caption': caption,
      'timestamp': Timestamp.fromDate(timestamp),
      'viewers': viewers,
    };
  }

  factory Story.fromMap(Map<String, dynamic> map, String id) {
    return Story(
      id: id,
      uploaderId: map['uploaderId'] ?? '',
      mediaUrl: map['mediaUrl'] ?? '',
      mediaType: map['mediaType'] ?? 'image',
      caption: map['caption'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      viewers: List<String>.from(map['viewers'] ?? []),
    );
  }
}
