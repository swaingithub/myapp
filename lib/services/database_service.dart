import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/user_model.dart';
import '../models/message.dart';
import '../models/story.dart';
import 'encryption_service.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveUser(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  Future<void> updateUser(UserModel user) async {
    await saveUser(user);
  }

  // Search users by phone number or email
  Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    // Search by phone number
    final phoneQuery = await _firestore
        .collection('users')
        .where('phoneNumber', isGreaterThanOrEqualTo: query)
        .where('phoneNumber', isLessThan: '${query}z')
        .get();

    // Search by email
    final emailQuery = await _firestore
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: query)
        .where('email', isLessThan: '${query}z')
        .get();

    final users = <UserModel>[];
    for (var doc in phoneQuery.docs) {
      users.add(UserModel.fromMap(doc.data()));
    }
    for (var doc in emailQuery.docs) {
      // Avoid duplicates
      if (!users.any((u) => u.uid == doc.id)) {
        users.add(UserModel.fromMap(doc.data()));
      }
    }
    return users;
  }

  // Get all users (deprecated for main list, use getChatRooms instead)
  Stream<List<UserModel>> getAllUsers(String currentUserId) {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .where((user) => user.uid != currentUserId)
          .toList();
    });
  }

  // Get active chat rooms for the current user
  Stream<List<Map<String, dynamic>>> getChatRooms(String currentUserId) {
    return _firestore
        .collection('chat_rooms')
        .where('users', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final rooms = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final users = List<String>.from(data['users']);
        final otherUserId = users.firstWhere((id) => id != currentUserId);

        // Basic room data
        final roomData = {
          'chatRoomId': doc.id,
          'lastMessage': EncryptionService.decrypt(data['lastMessage'] ?? ''),
          'lastMessageTime': data['lastMessageTime'] != null
              ? (data['lastMessageTime'] is int
                  ? DateTime.fromMillisecondsSinceEpoch(data['lastMessageTime'])
                  : (data['lastMessageTime'] as dynamic).toDate())
              : null,
          'otherUserId': otherUserId,
          'unreadCount': 0,
        };

        try {
          DocumentSnapshot<Map<String, dynamic>> userDoc;
          try {
            // 1. Try Cache First
            userDoc = await _firestore
                .collection('users')
                .doc(otherUserId)
                .get(const GetOptions(source: Source.cache));

            if (!userDoc.exists) {
              // 2. If not in cache, try Server
              userDoc =
                  await _firestore.collection('users').doc(otherUserId).get();
            }
          } catch (e) {
            // Fallback to server if cache fails
            try {
              userDoc =
                  await _firestore.collection('users').doc(otherUserId).get();
            } catch (e) {
              // If server also fails (offline), create a dummy doc from cache even if empty/stale
              // or just fail gracefully
              userDoc = await _firestore
                  .collection('users')
                  .doc(otherUserId)
                  .get(const GetOptions(source: Source.cache));
            }
          }

          if (userDoc.exists) {
            roomData['user'] = UserModel.fromMap(userDoc.data()!);
          } else {
            roomData['user'] =
                UserModel(uid: otherUserId, displayName: 'User', email: '');
          }
        } catch (e) {
          // Absolute fallback
          roomData['user'] =
              UserModel(uid: otherUserId, displayName: 'User', email: '');
        }

        rooms.add(roomData);
      }
      return rooms;
    });
  }

  String getChatRoomId(String user1, String user2) {
    if (user1.hashCode <= user2.hashCode) {
      return '$user1-$user2';
    } else {
      return '$user2-$user1';
    }
  }

  Future<void> sendMessage(String chatRoomId, Message message) async {
    // Encrypt message content if it's text
    String contentToSend = message.content;
    if (message.type == 'text') {
      contentToSend = EncryptionService.encrypt(message.content);
    }

    final messageMap = message.toMap();
    messageMap['content'] = contentToSend;

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageMap);

    String lastMsg = contentToSend;
    if (message.type == 'view_once') {
      lastMsg = '📷 Photo';
    } else if (message.type == 'image') {
      lastMsg = '📷 Photo';
    } else if (message.type == 'document') {
      lastMsg = '📄 Document';
    } else if (message.type == 'location') {
      lastMsg = '📍 Location';
    }

    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'lastMessage': lastMsg,
      'lastMessageTime': message.timestamp,
      'users': [message.senderId, message.receiverId],
    }, SetOptions(merge: true));
  }

  Stream<List<Message>> getMessages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Decrypt content
        if (data['type'] == 'text' && data['content'] != null) {
          data['content'] = EncryptionService.decrypt(data['content']);
        }
        final message = Message.fromMap(data, id: doc.id);

        return message.copyWith(
          isSynced: !doc.metadata.hasPendingWrites,
        );
      }).toList();
    });
  }

  Future<void> markMessageAsViewed(String chatRoomId, String messageId) async {
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({
      'isViewed': true,
      'isDelivered': true, // Viewed implies delivered
      'imageData': FieldValue.delete(),
    });
  }

  Future<void> markMessagesAsDelivered(String chatRoomId, String userId) async {
    final query = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isDelivered', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in query.docs) {
      batch.update(doc.reference, {'isDelivered': true});
    }
    await batch.commit();
  }

  Future<void> updateMessage(
      String chatRoomId, String messageId, String newContent) async {
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({
      'content': newContent,
      'isEdited': true, // Optional: flag to show "edited" label
    });
  }

  Future<void> deleteMessage(String chatRoomId, String messageId) async {
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .delete();

    // Optional: Update last message if the deleted message was the last one
    // This is complex as we need to find the new last message.
    // For simplicity, we might leave it or update it to "Message deleted"
  }

  Future<void> deleteChatRoom(String chatRoomId) async {
    // Delete all messages first (batch delete)
    final messages = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (var doc in messages.docs) {
      batch.delete(doc.reference);
    }

    // Delete the chat room document
    batch.delete(_firestore.collection('chat_rooms').doc(chatRoomId));

    await batch.commit();
  }

  Future<void> clearChatMessages(String chatRoomId) async {
    final messages = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (var doc in messages.docs) {
      batch.delete(doc.reference);
    }

    // Update the chat room document to remove last message
    batch.update(_firestore.collection('chat_rooms').doc(chatRoomId), {
      'lastMessage': FieldValue.delete(),
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
  // --- Friend Request System ---

  // Send a friend request
  Future<void> sendFriendRequest(String senderId, String receiverId) async {
    await _firestore.collection('friend_requests').add({
      'senderId': senderId,
      'receiverId': receiverId,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  // Accept a friend request
  Future<void> acceptFriendRequest(
      String currentUserId, String otherUserId, String requestId) async {
    final batch = _firestore.batch();

    // 1. Add to current user's friends
    batch.set(
      _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(otherUserId),
      {'timestamp': FieldValue.serverTimestamp()},
    );

    // 2. Add to other user's friends
    batch.set(
      _firestore
          .collection('users')
          .doc(otherUserId)
          .collection('friends')
          .doc(currentUserId),
      {'timestamp': FieldValue.serverTimestamp()},
    );

    // 3. Delete the request
    batch.delete(_firestore.collection('friend_requests').doc(requestId));

    await batch.commit();
  }

  // Cancel or Reject a friend request
  Future<void> cancelFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).delete();
  }

  // Get the status of the relationship between two users
  // Returns: 'friend', 'sent', 'received', 'none'
  Stream<Map<String, dynamic>> getFriendStatus(
      String currentUserId, String otherUserId) {
    // This is a bit complex to stream efficiently for a list, but for individual items:

    // 1. Check if friend
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(otherUserId)
        .snapshots()
        .switchMap((friendDoc) {
      if (friendDoc.exists) {
        return Stream.value({'status': 'friend'});
      }

      // 2. Check if request sent
      return _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: otherUserId)
          .snapshots()
          .switchMap((sentSnapshot) {
        if (sentSnapshot.docs.isNotEmpty) {
          return Stream.value(
              {'status': 'sent', 'requestId': sentSnapshot.docs.first.id});
        }

        // 3. Check if request received
        return _firestore
            .collection('friend_requests')
            .where('senderId', isEqualTo: otherUserId)
            .where('receiverId', isEqualTo: currentUserId)
            .snapshots()
            .map((receivedSnapshot) {
          if (receivedSnapshot.docs.isNotEmpty) {
            return {
              'status': 'received',
              'requestId': receivedSnapshot.docs.first.id
            };
          }
          return {'status': 'none'};
        });
      });
    });
  }
  // --- Blocking System ---

  Future<void> blockUser(String currentUserId, String blockedUserId) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked_users')
        .doc(blockedUserId)
        .set({'timestamp': FieldValue.serverTimestamp()});
  }

  Future<void> unblockUser(String currentUserId, String blockedUserId) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked_users')
        .doc(blockedUserId)
        .delete();
  }

  Stream<bool> isUserBlocked(String currentUserId, String otherUserId) {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked_users')
        .doc(otherUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // --- Nickname System ---

  Future<void> saveContactNickname(
      String currentUserId, String contactId, String nickname) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('contacts')
        .doc(contactId)
        .set({'nickname': nickname}, SetOptions(merge: true));
  }

  Stream<String?> getContactNicknameStream(
      String currentUserId, String contactId) {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('contacts')
        .doc(contactId)
        .snapshots()
        .map((doc) => doc.data()?['nickname'] as String?);
  }

  // --- Notification System ---

  Future<void> saveUserToken(String userId, String token) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmToken': token,
    });
  }

  // --- Storage System (Replaced with Base64 for Free Tier) ---

  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      // Compress heavily to fit in Firestore (max 1MB doc limit)
      final Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 512,
        minHeight: 512,
        quality: 50,
      );

      if (compressedBytes == null) throw Exception('Image compression failed');
      return base64Encode(compressedBytes);
    } catch (e) {
      debugPrint('Error encoding profile image: $e');
      rethrow;
    }
  }

  Future<String> uploadFile(
      String chatRoomId, File file, String fileName) async {
    try {
      // Compress heavily to fit in Firestore
      final Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 800,
        minHeight: 800,
        quality: 50,
      );

      if (compressedBytes == null) throw Exception('File compression failed');
      return base64Encode(compressedBytes);
    } catch (e) {
      debugPrint('Error encoding file: $e');
      rethrow;
    }
  }

  // --- Presence System ---

  Future<void> updateUserPresence(String uid, bool isOnline) async {
    await _firestore.collection('users').doc(uid).set({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateShowOnlineStatus(String uid, bool show) async {
    await _firestore.collection('users').doc(uid).set({
      'showOnlineStatus': show,
    }, SetOptions(merge: true));
  }

  Stream<UserModel?> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    });
  }

  // --- Story System ---

  Future<List<String>> getFriendsIds(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<void> uploadStory(Story story) async {
    // Remove id from map as it's generated by Firestore
    final map = story.toMap();
    await _firestore.collection('stories').add(map);
  }

  Stream<List<Story>> getStories(List<String> userIds) {
    if (userIds.isEmpty) return Stream.value([]);

    final yesterday = DateTime.now().subtract(const Duration(hours: 24));

    // Note: Firestore 'in' query is limited to 10 items.
    // For a larger app, we would need a different approach.
    
    return _firestore
        .collection('stories')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Story.fromMap(doc.data(), doc.id))
          .where((story) => userIds.contains(story.uploaderId))
          .toList();
    });
  }

  Future<void> viewStory(String storyId, String userId) async {
    await _firestore.collection('stories').doc(storyId).update({
      'viewers': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> deleteStory(String storyId) async {
    await _firestore.collection('stories').doc(storyId).delete();
  }
}
