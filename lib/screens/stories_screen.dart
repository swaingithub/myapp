import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../models/story.dart';
import 'create_story_screen.dart';
import 'story_view_screen.dart';

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({super.key});

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  List<String> _friendIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user != null) {
      final friends = await DatabaseService().getFriendsIds(user.uid);
      if (mounted) {
        setState(() {
          _friendIds = friends;
          _friendIds.add(user.uid); // Add self
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Removed unused authProvider
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final databaseService = DatabaseService(); // Renamed variable

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Stories',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 28,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3), // Fixed deprecations
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.camera_alt_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CreateStoryScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // My Status Section
                  _buildMyStatusTile(context, isDark),

                  const SizedBox(height: 24),

                  Text(
                    'Recent Updates',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface.withValues(alpha: 0.6), // Fixed deprecation
                    ),
                  ).animate().fadeIn().slideX(),

                  const SizedBox(height: 16),

                  // Stories List
                  StreamBuilder<List<Story>>(
                    stream: databaseService.getStories(_friendIds), // Updated variable name
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final stories = snapshot.data ?? [];

                      if (stories.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Text(
                              'No recent updates',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        );
                      }

                      // Group stories by user
                      final Map<String, List<Story>> userStories = {};
                      for (var story in stories) {
                        if (!userStories.containsKey(story.uploaderId)) {
                          userStories[story.uploaderId] = [];
                        }
                        userStories[story.uploaderId]!.add(story);
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: userStories.length,
                        itemBuilder: (context, index) {
                          final uploaderId = userStories.keys.elementAt(index);
                          final storiesList = userStories[uploaderId]!;
                          
                          return FutureBuilder<UserModel?>(
                            future: databaseService.getUser(uploaderId), // Updated variable name
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) return const SizedBox();
                              final user = userSnapshot.data!;
                              return _buildStoryTile(
                                  context, user, storiesList, index);
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMyStatusTile(BuildContext context, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), // Fixed deprecation
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.surfaceContainerHighest, // Fixed deprecation
              child: Icon(Icons.person, color: colorScheme.onSurfaceVariant),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Theme.of(context).cardColor, width: 2),
                ),
                child: const Icon(Icons.add, size: 12, color: Colors.white),
              ),
            ),
          ],
        ),
        title: const Text(
          'My Status',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Tap to add status update'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateStoryScreen()),
          );
        },
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  Widget _buildStoryTile(BuildContext context, UserModel user,
      List<Story> stories, int index) {
    final displayName = user.displayName ?? user.email ?? 'User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final colorScheme = Theme.of(context).colorScheme;
    final latestStory = stories.first; // Stories are ordered descending

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), // Fixed deprecation
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.purple, colorScheme.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.1), // Fixed deprecation
              backgroundImage:
                  user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null
                  ? Text(
                      initial,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${stories.length} new stories',
          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)), // Fixed deprecation
        ),
        onTap: () {
          // Open story viewer
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoryViewScreen(
                story: latestStory,
                user: user,
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(delay: (50 * index).ms).slideX();
  }
}
