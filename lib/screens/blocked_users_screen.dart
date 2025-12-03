import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../widgets/display_image.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.user!.uid;
    final DatabaseService databaseService = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('blocked_users')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No blocked users'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final blockedUserId = snapshot.data!.docs[index].id;

              return FutureBuilder<UserModel?>(
                future: databaseService.getUser(blockedUserId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) return const SizedBox();
                  final user = userSnapshot.data!;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: getAvatarImage(user.photoUrl),
                      child: user.photoUrl == null
                          ? Text(user.displayName?[0] ?? '?')
                          : null,
                    ),
                    title: Text(user.displayName ?? 'User'),
                    subtitle: Text(user.email ?? ''),
                    trailing: TextButton(
                      child: const Text('Unblock', style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        databaseService.unblockUser(currentUserId, blockedUserId);
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
