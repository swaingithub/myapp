import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import 'chat_screen.dart';

class SelectContactScreen extends StatelessWidget {
  const SelectContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final databaseService = DatabaseService();
    final currentUserId = authProvider.user!.uid;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Contact',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Find friends to chat with',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: databaseService.getAllUsers(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off_rounded,
                    size: 60,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No other users found',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _UserListItem(
                user: user,
                currentUserId: currentUserId,
                databaseService: databaseService,
                index: index,
              );
            },
          );
        },
      ),
    );
  }
}

class _UserListItem extends StatelessWidget {
  final UserModel user;
  final String currentUserId;
  final DatabaseService databaseService;
  final int index;

  const _UserListItem({
    required this.user,
    required this.currentUserId,
    required this.databaseService,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final displayName =
        user.displayName ?? user.email ?? user.phoneNumber ?? 'Unknown User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<Map<String, dynamic>>(
      stream: databaseService.getFriendStatus(currentUserId, user.uid),
      builder: (context, snapshot) {
        final statusData = snapshot.data ?? {'status': 'loading'};
        final status = statusData['status'] as String;
        final requestId = statusData['requestId'] as String?;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(
              radius: 20, // Smaller radius
              backgroundColor: colorScheme.primary.withOpacity(0.1),
              backgroundImage:
                  user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null
                  ? Text(
                      initial,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
            title: StreamBuilder<String?>(
              stream: databaseService.getContactNicknameStream(
                  currentUserId, user.uid),
              builder: (context, nicknameSnapshot) {
                final nickname = nicknameSnapshot.data;
                return Text(
                  nickname ?? displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                );
              },
            ),
            subtitle: Text(
              user.phoneNumber != null ? 'Mobile' : 'Email',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            trailing: _buildActionButton(context, status, requestId),
            onTap: status == 'friend'
                ? () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          receiverId: user.uid,
                          receiverName: displayName,
                        ),
                      ),
                    );
                  }
                : null,
          ),
        ).animate().fadeIn(delay: (30 * index).ms).slideX(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildActionButton(
      BuildContext context, String status, String? requestId) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (status) {
      case 'friend':
        return IconButton(
          icon: Icon(Icons.chat_bubble_outline_rounded,
              color: colorScheme.primary),
          onPressed: () {
            // Handled by ListTile onTap
          },
        );
      case 'sent':
        return TextButton(
          onPressed: () {
            if (requestId != null) {
              databaseService.cancelFriendRequest(requestId);
            }
          },
          child: Text(
            'Requested',
            style: TextStyle(color: Colors.grey[500]),
          ),
        );
      case 'received':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.green),
              onPressed: () {
                if (requestId != null) {
                  databaseService.acceptFriendRequest(
                      currentUserId, user.uid, requestId);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              onPressed: () {
                if (requestId != null) {
                  databaseService.cancelFriendRequest(requestId);
                }
              },
            ),
          ],
        );
      case 'loading':
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      default: // 'none'
        return TextButton(
          onPressed: () {
            databaseService.sendFriendRequest(currentUserId, user.uid);
          },
          style: TextButton.styleFrom(
            backgroundColor: colorScheme.primary.withOpacity(0.1),
            foregroundColor: colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text('Add'),
        );
    }
  }
}
