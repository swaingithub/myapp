import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String? id;
  final String senderId;
  final String receiverId;
  final String content;
  final Timestamp timestamp;
  final String type; // 'text' or 'view_once'
  final bool isViewed;
  final bool isDelivered;
  final String? fileName;
  final int? fileSize;
  final String? imageData;
  final bool isSynced;
  final Timestamp? unlockAt;
  final String? effect; // e.g., 'invisible_ink'

  Message({
    this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.type = 'text',
    this.isViewed = false,
    this.isDelivered = false,
    this.imageData,
    this.isSynced = true,
    this.fileName,
    this.fileSize,
    this.unlockAt,
    this.effect,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': timestamp,
      'type': type,
      'isViewed': isViewed,
      'isDelivered': isDelivered,
      'imageData': imageData,
      'fileName': fileName,
      'fileSize': fileSize,
      'unlockAt': unlockAt,
      'effect': effect,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map, {String? id}) {
    return Message(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      type: map['type'] ?? 'text',
      isViewed: map['isViewed'] ?? false,
      isDelivered: map['isDelivered'] ?? false,
      imageData: map['imageData'],
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      unlockAt: map['unlockAt'],
      effect: map['effect'],
    );
  }

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    Timestamp? timestamp,
    String? type,
    bool? isViewed,
    bool? isDelivered,
    String? imageData,
    bool? isSynced,
    String? fileName,
    int? fileSize,
    Timestamp? unlockAt,
    String? effect,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isViewed: isViewed ?? this.isViewed,
      isDelivered: isDelivered ?? this.isDelivered,
      imageData: imageData ?? this.imageData,
      isSynced: isSynced ?? this.isSynced,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      unlockAt: unlockAt ?? this.unlockAt,
      effect: effect ?? this.effect,
    );
  }
}
