class UserModel {
  final String uid;
  final String? email;
  final String? phoneNumber;
  final String? displayName;
  final String? photoUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final bool showOnlineStatus;

  UserModel({
    required this.uid,
    this.email,
    this.phoneNumber,
    this.displayName,
    this.photoUrl,
    this.isOnline = false,
    this.lastSeen,
    this.showOnlineStatus = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.millisecondsSinceEpoch,
      'showOnlineStatus': showOnlineStatus,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'],
      phoneNumber: map['phoneNumber'],
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['lastSeen'])
              : (map['lastSeen'] as dynamic).toDate())
          : null,
      showOnlineStatus: map['showOnlineStatus'] ?? true,
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    String? displayName,
    String? photoUrl,
    bool? isOnline,
    DateTime? lastSeen,
    bool? showOnlineStatus,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
    );
  }
}
