import 'dart:convert';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../models/message.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../providers/auth_provider.dart';
import '../screens/user_profile_screen.dart';
import '../utils/ui_helpers.dart';
import '../widgets/display_image.dart';
import '../widgets/message_bubble.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;

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
  final DatabaseService databaseService = DatabaseService();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isSendingImage = false;
  bool _showScrollToBottom = false;
  bool _isSearching = false;
  String _searchQuery = '';

  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();

  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
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
        databaseService.getChatRoomId(currentUserId, widget.receiverId);

      if (_editingMessageId != null) {
        // Update existing message
        try {
          await databaseService.updateMessage(
              chatRoomId, _editingMessageId!, text);
          _cancelEdit();
        } catch (e) {
          debugPrint("Error updating message: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error updating message: $e')),
            );
          }
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
          await databaseService.sendMessage(chatRoomId, message);
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
        databaseService.getChatRoomId(currentUserId, widget.receiverId);

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
                          await databaseService.deleteMessage(
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

      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user!.uid;
      final chatRoomId =
        databaseService.getChatRoomId(currentUserId, widget.receiverId);

      Message message = Message(
        senderId: currentUserId,
        receiverId: widget.receiverId,
        content: '📷 Photo',
        timestamp: Timestamp.now(),
        type: 'image', // Changed from view_once to image for persistent storage
        isViewed: false,
        imageData: base64Image,
      );

      await databaseService.sendMessage(chatRoomId, message);
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

  Future<void> _pickAndSendDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;
        int fileSize = result.files.single.size;

        setState(() {
          _isSendingImage = true;
        });

        if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUserId = authProvider.user!.uid;
        final chatRoomId =
          databaseService.getChatRoomId(currentUserId, widget.receiverId);

        String fileUrl =
            await databaseService.uploadFile(chatRoomId, file, fileName);

        Message message = Message(
          senderId: currentUserId,
          receiverId: widget.receiverId,
          content: fileUrl,
          timestamp: Timestamp.now(),
          type: 'document',
          isViewed: false,
          fileName: fileName,
          fileSize: fileSize,
        );

        await databaseService.sendMessage(chatRoomId, message);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending document: $e')),
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

  Future<void> _sendLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Location permissions are denied')));
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Location permissions are permanently denied, we cannot request permissions.')));
        }
        return;
      }

      setState(() {
        _isSendingImage = true;
      });

      Position position = await Geolocator.getCurrentPosition();
      String locationUrl =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user!.uid;
      final chatRoomId =
        databaseService.getChatRoomId(currentUserId, widget.receiverId);

      Message message = Message(
        senderId: currentUserId,
        receiverId: widget.receiverId,
        content: locationUrl,
        timestamp: Timestamp.now(),
        type: 'location',
        isViewed: false,
      );

      await databaseService.sendMessage(chatRoomId, message);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending location: $e')),
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
                  child: DisplayImage(
                    path: message.imageData,
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
      databaseService.markMessageAsViewed(chatRoomId, message.id!);
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
              databaseService.clearChatMessages(chatRoomId);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleBlock(bool isBlocked, String currentUserId) {
    if (isBlocked) {
      databaseService.unblockUser(currentUserId, widget.receiverId);
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
                databaseService.blockUser(currentUserId, widget.receiverId);
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
                _sendLocation();
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
                _pickAndSendDocument();
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
        databaseService.getChatRoomId(currentUserId, widget.receiverId);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<bool>(
      stream: databaseService.isUserBlocked(currentUserId, widget.receiverId),
      builder: (context, snapshot) {
          // Don't show full screen loader, just default to false (not blocked) while loading
          // to prevent screen flicker. The stream will update quickly anyway.
          // return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final isBlocked = snapshot.data ?? false;

        return PopScope(
          canPop: !_showEmojiPicker,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            setState(() {
              _showEmojiPicker = false;
            });
          },
          child: Scaffold(
            appBar: AppBar(
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            elevation: 0.5,
            shadowColor: Colors.black.withValues(alpha: 0.05),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            titleSpacing: 0,
            title: StreamBuilder<String?>(
              stream: databaseService.getContactNicknameStream(
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
                      Hero(
                        tag: 'avatar_${widget.receiverId}',
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface),
                            ),
                            StreamBuilder<UserModel?>(
                              stream: databaseService
                                  .getUserStream(authProvider.user!.uid),
                              builder: (context, currentUserSnapshot) {
                                final currentUser = currentUserSnapshot.data;
                                final canSeeOnlineStatus =
                                    currentUser?.showOnlineStatus ?? true;

                                if (!canSeeOnlineStatus) {
                                  return const SizedBox.shrink();
                                }

                                return StreamBuilder<UserModel?>(
                                  stream: databaseService
                                      .getUserStream(widget.receiverId),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const SizedBox.shrink();
                                    }
                                    final user = snapshot.data!;
                                    if (!user.showOnlineStatus) {
                                      return const SizedBox.shrink();
                                    }
                                    if (user.isOnline) {
                                      return const Text(
                                        'Online',
                                        style: TextStyle(
                                            color: Colors.green, fontSize: 12),
                                      );
                                    }
                                    if (user.lastSeen != null) {
                                      return Text(
                                        'Last seen ${DateFormat('h:mm a').format(user.lastSeen!)}',
                                        style: TextStyle(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                            fontSize: 12),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                );
                              },
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
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(color: colorScheme.onSurface),
                        cursorColor: colorScheme.primary,
                        decoration: InputDecoration(
                          hintText: 'Search in chat...',
                          hintStyle: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.5)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.close,
                                color: colorScheme.onSurface.withValues(alpha: 0.6)),
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
                  ),
                )
              else ...[
                IconButton(
                  icon: Icon(Icons.videocam_outlined,
                      color: colorScheme.onSurface),
                  onPressed: () {
                    showUnderConstructionDialog(context, 'Video Call');
                  },
                ),
                IconButton(
                  icon: Icon(Icons.call_outlined, color: colorScheme.onSurface),
                  onPressed: () {
                    showUnderConstructionDialog(context, 'Voice Call');
                  },
                ),
                IconButton(
                  icon:
                      Icon(Icons.search_rounded, color: colorScheme.onSurface),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: colorScheme.onSurface),
                  color: colorScheme.surface,
                  surfaceTintColor: colorScheme.surface,
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
                        stream: databaseService.getMessages(chatRoomId),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                                child: Text('Error: ${snapshot.error}'));
                          }
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox.shrink();
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
                            padding: EdgeInsets.only(
                                top: kToolbarHeight + 20,
                                bottom: 90 + (_showEmojiPicker ? 250 : 0),
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
                                  databaseService.markMessageAsViewed(
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
                                              .withValues(alpha: 0.4),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    _buildMessageBubble(context, message, isMe, isDark, chatRoomId),
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
                            color: colorScheme.surface.withValues(alpha: 0.8),
                            border: Border(
                              top: BorderSide(
                                color: colorScheme.onSurface.withValues(alpha: 0.05),
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
                                              .withValues(alpha: 0.1),
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
                                                  .withValues(alpha: 0.1),
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
                                                    .withValues(alpha: 0.1),
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
                                                      .withValues(alpha: 0.4),
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
                                                          .withValues(alpha: 0.4)),
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
                                                    .withValues(alpha: 0.3),
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
                // Floating Input Area (Hide when searching)
                if (!_isSearching)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: EdgeInsets.fromLTRB(
                                  12, 8, 12, _showEmojiPicker ? 8 : 20),
                              decoration: BoxDecoration(
                                color: colorScheme.surface.withValues(alpha: 0.8),
                                border: Border(
                                  top: BorderSide(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.05),
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
                                            margin: const EdgeInsets.only(
                                                bottom: 8),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.1),
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
                                                        color: colorScheme
                                                            .primary,
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
                                                      .withValues(alpha: 0.1),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                        Icons.add_rounded,
                                                        color: colorScheme
                                                            .primary),
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
                                                        .withValues(alpha: 0.1),
                                                  ),
                                                ),
                                                child: TextField(
                                                  controller:
                                                      _messageController,
                                                  focusNode: _focusNode,
                                                  style: TextStyle(
                                                      color: colorScheme
                                                          .onSurface,
                                                      fontSize: 14),
                                                  decoration: InputDecoration(
                                                    hintText: 'Type a message...',
                                                    hintStyle: TextStyle(
                                                      color: colorScheme
                                                          .onSurface
                                                          .withValues(alpha: 0.4),
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
                                                          _showEmojiPicker
                                                              ? Icons
                                                                  .keyboard_rounded
                                                              : Icons
                                                                  .emoji_emotions_outlined,
                                                          color: colorScheme
                                                              .onSurface
                                                              .withValues(alpha: 0.4)),
                                                      onPressed: () {
                                                        setState(() {
                                                          _showEmojiPicker =
                                                              !_showEmojiPicker;
                                                          if (_showEmojiPicker) {
                                                            _focusNode
                                                                .unfocus();
                                                          } else {
                                                            _focusNode
                                                                .requestFocus();
                                                          }
                                                        });
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
                                                        .withValues(alpha: 0.3),
                                                    blurRadius: 8,
                                                    offset:
                                                        const Offset(0, 4),
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
                        if (_showEmojiPicker)
                          SizedBox(
                            height: 250,
                            child: EmojiPicker(
                              textEditingController: _messageController,
                              config: Config(
                                height: 250,
                                checkPlatformCompatibility: false, // Set to false to avoid MissingPluginException before rebuild
                                emojiViewConfig: EmojiViewConfig(
                                  backgroundColor: colorScheme.surface,
                                  columns: 7,
                                  emojiSizeMax: 28 *
                                      (foundation.defaultTargetPlatform ==
                                              TargetPlatform.iOS
                                          ? 1.2
                                          : 1.0),
                                ),
                                categoryViewConfig: CategoryViewConfig(
                                  initCategory: Category.RECENT,
                                  backgroundColor: colorScheme.surface,
                                  tabIndicatorAnimDuration: kTabScrollDuration,
                                  categoryIcons: const CategoryIcons(
                                    recentIcon: Icons.access_time_rounded,
                                    smileyIcon: Icons.emoji_emotions_rounded,
                                    animalIcon: Icons.pets_rounded,
                                    foodIcon: Icons.fastfood_rounded,
                                    activityIcon: Icons.sports_soccer_rounded,
                                    travelIcon: Icons.flight_rounded,
                                    objectIcon: Icons.lightbulb_rounded,
                                    symbolIcon: Icons.emoji_symbols_rounded,
                                    flagIcon: Icons.flag_rounded,
                                  ),
                                  dividerColor: colorScheme.onSurface.withValues(alpha: 0.1),
                                  indicatorColor: colorScheme.primary,
                                  iconColor: colorScheme.onSurface.withValues(alpha: 0.5),
                                  iconColorSelected: colorScheme.primary,
                                  backspaceColor: colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildMessageBubble(BuildContext context, Message message, bool isMe,
      bool isDark, String chatRoomId) {
    return MessageBubble(
      message: message,
      isMe: isMe,
      isDark: isDark,
      onLongPress: () => _showMessageOptions(context, message, isMe),
      onTapViewOnce: () => _showViewOnceImage(message, chatRoomId),
      onTapImage: () {
        if (message.imageData == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: Center(
                child: InteractiveViewer(
                  child: Hero(
                    tag: 'img_${message.id}',
                    child: DisplayImage(
                      path: message.imageData,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      onTapDocument: () async {
        try {
          final Uri url = Uri.parse(message.content);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open document')));
            }
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error opening document: $e')));
          }
        }
      },
      onTapLocation: () async {
        final Uri url = Uri.parse(message.content);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}
