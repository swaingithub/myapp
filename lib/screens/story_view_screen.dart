import 'package:flutter/material.dart';
import '../models/story.dart';
import '../models/user_model.dart';
import '../widgets/display_image.dart';

class StoryViewScreen extends StatelessWidget {
  final Story story;
  final UserModel user;

  const StoryViewScreen({super.key, required this.story, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: DisplayImage(
                path: story.mediaUrl,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: getAvatarImage(user.photoUrl),
                    child: user.photoUrl == null
                        ? Text(user.displayName?[0] ?? '?')
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    user.displayName ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            if (story.caption != null && story.caption!.isNotEmpty)
              Positioned(
                bottom: 32,
                left: 16,
                right: 16,
                child: Text(
                  story.caption!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black,
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
