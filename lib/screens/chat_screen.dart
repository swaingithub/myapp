import 'dart:convert';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:screen_protector/screen_protector.dart';
import '../models/message.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../providers/auth_provider.dart';
import '../screens/user_profile_screen.dart';
import '../utils/ui_helpers.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isSendingImage = false;
  bool _showScrollToBottom = false;
  bool _isSearching = false;
  String _searchQuery = '';

  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final isNotAtBottom = _scrollController.position.pixels <
          _scrollController.position.maxScrollExtent - 100;
      if (isNotAtBottom != _showScrollToBottom) {
        setState(() {
          _showScrollToBottom = isNotAtBottom;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user!.uid;
      final chatRoomId =
          _databaseService.getChatRoomId(currentUserId, widget.receiverId);

      if (_editingMessageId != null) {
        // Update existing message
        try {
          await _databaseService.updateMessage(
              chatRoomId, _editingMessageId!, text);
          _cancelEdit();
        } catch (e) {
          debugPrint("Error updating message: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating message: $e')),
          );
        }
      } else {
        // Send new message
        _messageController.clear(); // Instant clear for seamless feel

        Message message = Message(
          senderId: currentUserId,
          receiverId: widget.receiverId,
          content: text,
          timestamp: Timestamp.now(),
        );

        try {
          await _databaseService.sendMessage(chatRoomId, message);
          _scrollToBottom();
        } catch (e) {
          debugPrint("Error sending message: $e");
        }
      }
    }
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _messageController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _showMessageOptions(BuildContext context, Message message, bool isMe) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user!.uid;
    final chatRoomId =
        _databaseService.getChatRoomId(currentUserId, widget.receiverId);

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
            if (isMe &&
                message.type == 'text') // Only allow editing text messages
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Colors.blue),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _editingMessageId = message.id;
                    _messageController.text = message.content;
                  });
                  FocusScope.of(context).requestFocus();
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Message?'),
                    content: const Text(
                        'Are you sure you want to delete this message?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _databaseService.deleteMessage(
                              chatRoomId, message.id!);
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

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() {
        _isSendingImage = true;
      });

      // Compress image
      final Uint8List? compressedBytes =
          await FlutterImageCompress.compressWithFile(
        pickedFile.path,
        minWidth: 800,
        minHeight: 800,
        quality: 50,
      );

      if (compressedBytes == null) {
        throw Exception('Image compression failed');
      }

      // Convert to Base64
      final String base64Image = base64Encode(compressedBytes);

      if (base64Image.length > 1024 * 1024) {
        throw Exception('Image too large even after compression');
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user!.uid;
      final chatRoomId =
          _databaseService.getChatRoomId(currentUserId, widget.receiverId);

      Message message = Message(
        senderId: currentUserId,
        receiverId: widget.receiverId,
        content: '📷 Photo',
        timestamp: Timestamp.now(),
        type: 'image',
        isViewed: false,
        imageData: base64Image,
      );

      await _databaseService.sendMessage(chatRoomId, message);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingImage = false;
        });
      }
    }
  }

  void _showViewOnceImage(Message message, String chatRoomId) async {
    if (message.imageData == null) return;

    // Enable secure mode to prevent screenshots
    try {
      await ScreenProtector.preventScreenshotOn();
    } catch (e) {
      debugPrint('Error enabling secure mode: $e');
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.memory(
                    base64Decode(message.imageData!),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              Positioned(
                top: 50, // Adjusted for status bar
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Text(
                  'This photo will disappear when you close this.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Disable secure mode
    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      debugPrint('Error disabling secure mode: $e');
    }

    if (message.id != null) {
      _databaseService.markMessageAsViewed(chatRoomId, message.id!);
    }
  }

  void _clearChat(String chatRoomId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat?'),
        content: const Text(
            'Are you sure you want to clear this chat? All messages will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _databaseService.clearChatMessages(chatRoomId);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleBlock(bool isBlocked, String currentUserId) {
    if (isBlocked) {
      _databaseService.unblockUser(currentUserId, widget.receiverId);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Block User?'),
          content: const Text(
              'Blocked users will not be able to call you or send you messages.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _databaseService.blockUser(currentUserId, widget.receiverId);
              },
              child: const Text('Block', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }

  void _showAttachmentOptions(BuildContext context) {
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
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.pink),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library_rounded, color: Colors.purple),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.location_on_rounded, color: Colors.green),
              title: const Text('Location'),
              onTap: () {
                Navigator.pop(context);
                showUnderConstructionDialog(context, 'Location Sharing');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_rounded, color: Colors.blue),
              title: const Text('Contact'),
              onTap: () {
                Navigator.pop(context);
                showUnderConstructionDialog(context, 'Contact Sharing');
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_rounded,
                  color: Colors.orange),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                showUnderConstructionDialog(context, 'Document Sharing');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.user!.uid;
    final chatRoomId =
        _databaseService.getChatRoomId(currentUserId, widget.receiverId);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<bool>(
      stream: _databaseService.isUserBlocked(currentUserId, widget.receiverId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final isBlocked = snapshot.data ?? false;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: StreamBuilder<String?>(
              stream: _databaseService.getContactNicknameStream(
                  currentUserId, widget.receiverId),
              builder: (context, nicknameSnapshot) {
                final nickname = nicknameSnapshot.data;
                final displayName = nickname ?? widget.receiverName;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreen(
                          user: UserModel(
                            uid: widget.receiverId,
                            displayName: widget.receiverName,
                          ),
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: colorScheme.primary,
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Online', // Placeholder for online status
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.normal),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              if (_isSearching)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _isSearching = false;
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                )
              else ...[
                IconButton(
                  icon: Icon(Icons.search_rounded, color: colorScheme.primary),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
                IconButton(
                  icon:
                      Icon(Icons.videocam_rounded, color: colorScheme.primary),
                  onPressed: () {
                    showUnderConstructionDialog(context, 'Video Call');
                  },
                ),
                IconButton(
                  icon: Icon(Icons.call_rounded, color: colorScheme.primary),
                  onPressed: () {
                    showUnderConstructionDialog(context, 'Voice Call');
                  },
                ),
                PopupMenuButton<String>(
                  icon:
                      Icon(Icons.more_vert_rounded, color: colorScheme.primary),
                  onSelected: (value) {
                    if (value == 'block') {
                      _toggleBlock(isBlocked, currentUserId);
                    } else if (value == 'clear_chat') {
                      _clearChat(chatRoomId);
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      PopupMenuItem<String>(
                        value: 'block',
                        child: Text(isBlocked ? 'Unblock' : 'Block'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'clear_chat',
                        child: Text('Clear Chat'),
                      ),
                    ];
                  },
                ),
              ],
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1A1A1A), const Color(0xFF0D0D0D)]
                    : [const Color(0xFFF0F2F5), const Color(0xFFE1E5EA)],
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: StreamBuilder<List<Message>>(
                        stream: _databaseService.getMessages(chatRoomId),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                                child: Text('Error: ${snapshot.error}'));
                          }
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          var messages = snapshot.data ?? [];

                          // Filter blocked messages
                          if (isBlocked) {
                            messages = messages
                                .where((m) => m.senderId != widget.receiverId)
                                .toList();
                          }

                          if (_searchQuery.isNotEmpty) {
                            messages = messages
                                .where((m) => m.content
                                    .toLowerCase()
                                    .contains(_searchQuery.toLowerCase()))
                                .toList();
                          }

                          if (_searchQuery.isEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_scrollController.hasClients &&
                                  !_showScrollToBottom) {
                                _scrollController.jumpTo(
                                    _scrollController.position.maxScrollExtent);
                              }
                            });
                          }

                          return ListView.builder(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            itemCount: messages.length,
                            padding: const EdgeInsets.only(
                                top: kToolbarHeight + 20,
                                bottom: 90,
                                left: 12,
                                right: 12),
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isMe = message.senderId == currentUserId;

                              // Mark as viewed (excluding view_once messages)
                              if (!isMe &&
                                  !message.isViewed &&
                                  message.type != 'view_once') {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  _databaseService.markMessageAsViewed(
                                      chatRoomId, message.id!);
                                });
                              }

                              final showTime = index == 0 ||
                                  messages[index].timestamp.toDate().difference(
                                          messages[index - 1]
                                              .timestamp
                                              .toDate()) >
                                      const Duration(minutes: 5);

                              return Column(
                                children: [
                                  if (showTime)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Text(
                                        DateFormat('MMM d, h:mm a')
                                            .format(message.timestamp.toDate()),
                                        style: TextStyle(
                                          color: colorScheme.onSurface
                                              .withOpacity(0.4),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  _buildMessageBubble(
                                      context, message, isMe, isDark),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // Loading Overlay
                if (_isSendingImage)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Sending...',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Floating Input Area (Hide when searching)
                if (!_isSearching)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withOpacity(0.8),
                            border: Border(
                              top: BorderSide(
                                color: colorScheme.onSurface.withOpacity(0.05),
                              ),
                            ),
                          ),
                          child: isBlocked
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  alignment: Alignment.center,
                                  child: Column(
                                    children: [
                                      Text(
                                        'You blocked this contact',
                                        style: TextStyle(
                                            color: colorScheme.onSurface),
                                      ),
                                      TextButton(
                                        onPressed: () => _toggleBlock(
                                            isBlocked, currentUserId),
                                        child: const Text('Tap to unblock'),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_editingMessageId != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit,
                                                size: 16,
                                                color: colorScheme.primary),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Editing message',
                                                style: TextStyle(
                                                    color: colorScheme.primary,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close,
                                                  size: 16),
                                              onPressed: _cancelEdit,
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: colorScheme.surface,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: colorScheme.onSurface
                                                  .withOpacity(0.1),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(Icons.add_rounded,
                                                    color: colorScheme.primary),
                                                onPressed: () {
                                                  _showAttachmentOptions(
                                                      context);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: colorScheme.surface,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: colorScheme.onSurface
                                                    .withOpacity(0.1),
                                              ),
                                            ),
                                            child: TextField(
                                              controller: _messageController,
                                              style: TextStyle(
                                                  color: colorScheme.onSurface,
                                                  fontSize: 14),
                                              decoration: InputDecoration(
                                                hintText: 'Type a message...',
                                                hintStyle: TextStyle(
                                                  color: colorScheme.onSurface
                                                      .withOpacity(0.4),
                                                  fontSize: 14,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 8,
                                                ),
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                      Icons
                                                          .emoji_emotions_outlined,
                                                      color: colorScheme
                                                          .onSurface
                                                          .withOpacity(0.4)),
                                                  onPressed: () {
                                                    showUnderConstructionDialog(
                                                        context,
                                                        'Emoji Picker');
                                                  },
                                                ),
                                              ),
                                              minLines: 1,
                                              maxLines: 4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                colorScheme.primary,
                                                colorScheme.secondary,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: colorScheme.primary
                                                    .withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: IconButton(
                                            icon: Icon(
                                                _editingMessageId != null
                                                    ? Icons.check_rounded
                                                    : Icons.send_rounded,
                                                color: Colors.white,
                                                size: 20),
                                            onPressed: _sendMessage,
                                          ),
                                        ).animate().scale(
                                            duration: 200.ms,
                                            curve: Curves.easeOutBack),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),

                // Scroll to Bottom Button
                if (_showScrollToBottom && !_isSearching)
                  Positioned(
                    right: 16,
                    bottom: 90,
                    child: FloatingActionButton.small(
                      onPressed: _scrollToBottom,
                      backgroundColor: colorScheme.surface,
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: colorScheme.primary),
                    ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(
      BuildContext context, Message message, bool isMe, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(context, message, isMe),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2), // Reduced margin
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8), // Reduced padding
          decoration: BoxDecoration(
            gradient: isMe
                ? LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color:
                isMe ? null : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight:
                  isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.type == 'view_once')
                _buildViewOnceContent(context, message, isMe, isDark)
              else
                Text(
                  message.content,
                  style: TextStyle(
                    color: isMe ? Colors.white : colorScheme.onSurface,
                    fontSize: 14.5, // Reduced font size
                  ),
                ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('h:mm a').format(message.timestamp.toDate()),
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withOpacity(0.7)
                          : colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 9, // Reduced font size
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      !message.isSynced
                          ? Icons.access_time_rounded // Clock (Pending Sync)
                          : (message.isViewed
                              ? Icons
                                  .done_all_rounded // Blue Double Tick (Read)
                              : (message.isDelivered
                                  ? Icons
                                      .done_all_rounded // Grey Double Tick (Delivered)
                                  : Icons
                                      .check_rounded)), // Grey Single Tick (Sent)
                      size: 14, // Reduced icon size
                      color: message.isViewed
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildViewOnceContent(
      BuildContext context, Message message, bool isMe, bool isDark) {
    final bool isTimeExpired =
        DateTime.now().difference(message.timestamp.toDate()).inHours >= 24;
    final bool isExpired = message.isViewed || isTimeExpired;
    final bool canView = !isExpired && !isMe;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: canView
          ? () => _showViewOnceImage(
              message,
              _databaseService.getChatRoomId(
                  message.senderId, message.receiverId))
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withOpacity(0.2)
                    : (isExpired
                        ? Colors.grey.withOpacity(0.1)
                        : colorScheme.primary.withOpacity(0.1)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExpired ? Icons.timer_off_outlined : Icons.filter_1_outlined,
                color: isMe
                    ? Colors.white
                    : (isExpired ? Colors.grey : colorScheme.primary),
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired ? 'Expired' : 'View Once',
                  style: TextStyle(
                    color: isMe ? Colors.white : colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  isExpired ? 'Photo' : 'Tap to view',
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withOpacity(0.7)
                        : colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
