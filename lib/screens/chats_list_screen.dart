import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rxdart/rxdart.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import 'chat_screen.dart';
import 'select_contact_screen.dart';
import 'settings_screen.dart';
import '../providers/theme_provider.dart';
import '../widgets/display_image.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final BehaviorSubject<String> _searchSubject =
      BehaviorSubject<String>.seeded('');
  final DatabaseService databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchSubject.add(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchSubject.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentUserId = authProvider.user!.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Chats',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 28,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_rounded,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                themeProvider.themeMode == ThemeMode.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
              onPressed: () => themeProvider.toggleTheme(),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient for Light Mode
          if (!isDark)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 300,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFDCE8F5), // Soft Blue-Grey
                      const Color(0xFFF0F2F5).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),

          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 60),
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search conversations...',
                      hintStyle: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: colorScheme.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded,
                                  color:
                                      colorScheme.onSurface.withValues(alpha: 0.5)),
                              onPressed: () {
                                _searchController.clear();
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 20),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2, end: 0),

              // Content List
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    child: StreamBuilder<UserModel?>(
                      stream: databaseService.getUserStream(currentUserId),
                      builder: (context, currentUserSnapshot) {
                        final currentUser = currentUserSnapshot.data;
                        final canSeeOnlineStatus =
                            currentUser?.showOnlineStatus ?? true;

                        return StreamBuilder<String>(
                          stream: _searchSubject.stream
                              .debounceTime(const Duration(milliseconds: 300)),
                          builder: (context, searchSnapshot) {
                            final searchQuery = searchSnapshot.data ?? '';

                            if (searchQuery.isNotEmpty) {
                              // Show Search Results
                              return FutureBuilder<List<UserModel>>(
                                future:
                                    databaseService.searchUsers(searchQuery),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox.shrink();
                                  }
                                  final users = snapshot.data ?? [];
                                  final filteredUsers = users
                                      .where((u) => u.uid != currentUserId)
                                      .toList();

                                  if (filteredUsers.isEmpty) {
                                    return _buildEmptyState('No users found');
                                  }

                                  return ListView.builder(
                                    padding: const EdgeInsets.only(
                                        top: 20, bottom: 100),
                                    itemCount: filteredUsers.length,
                                    itemBuilder: (context, index) {
                                      final user = filteredUsers[index];
                                      return _buildUserListItem(context, user,
                                          index: index,
                                          currentUserId: currentUserId,
                                          canSeeOnlineStatus:
                                              canSeeOnlineStatus);
                                    },
                                  );
                                },
                              );
                            } else {
                              // Show Active Chat Rooms
                              return StreamBuilder<List<Map<String, dynamic>>>(
                                stream: databaseService
                                    .getChatRooms(currentUserId),
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) {
                                    return Center(
                                        child:
                                            Text('Error: ${snapshot.error}'));
                                  }
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox.shrink();
                                  }

                                  final rooms = snapshot.data ?? [];

                                  if (rooms.isEmpty) {
                                    return _buildEmptyState(
                                        'No active chats.\nSearch for a user to start chatting!');
                                  }

                                  return ListView.separated(
                                    padding: const EdgeInsets.only(
                                        top: 20, bottom: 100),
                                    itemCount: rooms.length,
                                    separatorBuilder: (ctx, i) => Divider(
                                        height: 1,
                                        indent: 80,
                                        endIndent: 20,
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.05)),
                                    itemBuilder: (context, index) {
                                      final room = rooms[index];
                                      final user = room['user'] as UserModel;
                                      final lastMessage =
                                          room['lastMessage'] as String?;
                                      final chatRoomId =
                                          room['chatRoomId'] as String;
                                      final lastMessageTime =
                                          room['lastMessageTime'] as DateTime?;

                                      // Mark messages as delivered when they appear in the list
                                      databaseService.markMessagesAsDelivered(
                                          chatRoomId, currentUserId);

                                      return _buildUserListItem(context, user,
                                          lastMessage: lastMessage,
                                          lastMessageTime: lastMessageTime,
                                          index: index,
                                          chatRoomId: chatRoomId,
                                          currentUserId: currentUserId,
                                          canSeeOnlineStatus:
                                              canSeeOnlineStatus);
                                    },
                                  );
                                },
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              ).animate().slideY(begin: 0.2, end: 0, delay: 300.ms),
            ],
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80), // Lift above custom nav bar
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SelectContactScreen(),
                ),
              );
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: const Icon(Icons.add_comment_rounded, color: Colors.white),
          ),
        ).animate().scale(delay: 400.ms),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Future<void> _deleteChat(String chatRoomId) async {
    try {
      await databaseService.deleteChatRoom(chatRoomId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting chat: $e')),
        );
      }
    }
  }

  void _showChatOptions(String chatRoomId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text('Delete Chat'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Chat?'),
                    content: const Text(
                        'Are you sure you want to delete this conversation? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteChat(chatRoomId);
                        },
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserListItem(BuildContext context, UserModel user,
      {String? lastMessage,
      DateTime? lastMessageTime,
      required int index,
      String? chatRoomId,
      required String currentUserId,
      bool canSeeOnlineStatus = true}) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<String?>(
      stream:
          databaseService.getContactNicknameStream(currentUserId, user.uid),
      builder: (context, snapshot) {
        final nickname = snapshot.data;
        final displayName = nickname ??
            user.displayName ??
            user.email ??
            user.phoneNumber ??
            'Unknown User';
        final initial =
            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                backgroundImage: getAvatarImage(user.photoUrl),
                child: user.photoUrl == null
                    ? Text(
                        initial,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              if (canSeeOnlineStatus && user.isOnline && user.showOnlineStatus)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            displayName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              lastMessage ?? 'Tap to start chatting',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: lastMessage != null
                    ? colorScheme.onSurface.withValues(alpha: 0.6)
                    : colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 14,
                fontWeight:
                    lastMessage != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                lastMessageTime != null
                    ? DateFormat('hh:mm a').format(lastMessageTime)
                    : '',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  receiverId: user.uid,
                  receiverName: displayName,
                ),
              ),
            );
          },
          onLongPress:
              chatRoomId != null ? () => _showChatOptions(chatRoomId) : null,
        );
      },
    ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1, end: 0);
  }
}
