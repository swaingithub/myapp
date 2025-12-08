import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/message.dart';

class MessageBubble extends StatefulWidget {


  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.onLongPress,
    this.onTapViewOnce,
    this.onTapImage,
    this.onTapDocument,
    this.onTapLocation,
    this.isNew = false,
    this.bubbleAvatarUrl,
    this.seenAvatarUrl,
  });

  final Message message;
  final bool isMe;
  final bool isDark;
  final VoidCallback onLongPress;
  final VoidCallback? onTapViewOnce;
  final VoidCallback? onTapImage;
  final VoidCallback? onTapDocument;
  final VoidCallback? onTapLocation;
  final bool isNew;
  final String? bubbleAvatarUrl;
  final String? seenAvatarUrl;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with TickerProviderStateMixin {
  Uint8List? _decodedImageBytes;
  Timer? _unlockTimer;
  late AnimationController _avatarAnimController;
  late AnimationController _statusAnimController;

  Timer? _syncTimer;
  bool _showPendingIcon = false;

  @override
  void initState() {
    super.initState();
    _setupSyncTimer();
    _decodeImageIfNeeded();
    _setupUnlockTimer();
    _avatarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _statusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    if (widget.message.isViewed) {
      _statusAnimController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.isSynced != oldWidget.message.isSynced) {
      _setupSyncTimer();
    }
    if (widget.message.imageData != oldWidget.message.imageData) {
      _decodeImageIfNeeded();
    }
    if (widget.message.unlockAt != oldWidget.message.unlockAt) {
      _setupUnlockTimer();
    }
    if (widget.message.isViewed && !oldWidget.message.isViewed) {
      _statusAnimController.forward();
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _hideTimer?.cancel();
    _unlockTimer?.cancel();
    _avatarAnimController.dispose();
    _statusAnimController.dispose();
    super.dispose();
  }

  void _setupSyncTimer() {
    _syncTimer?.cancel();
    if (widget.message.isSynced) return;

    final timeSince = DateTime.now().difference(widget.message.timestamp.toDate());
    if (timeSince.inMilliseconds > 500) {
      _showPendingIcon = true;
    } else {
      _showPendingIcon = false;
      _syncTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _showPendingIcon = true);
      });
    }
  }

  void _setupUnlockTimer() {
    _unlockTimer?.cancel();
    final unlockAt = widget.message.unlockAt?.toDate();
    if (unlockAt != null && unlockAt.isAfter(DateTime.now())) {
      final duration = unlockAt.difference(DateTime.now());
      _unlockTimer = Timer(duration, () {
        if (mounted) setState(() {});
      });
    }
  }



  void _decodeImageIfNeeded() {
    if (widget.message.type == 'image' && widget.message.imageData != null) {
      try {
        _decodedImageBytes = base64Decode(widget.message.imageData!);
      } catch (e) {
        debugPrint('Error decoding image in bubble: $e');
      }
    } else {
      _decodedImageBytes = null;
    }
  }

  bool _isRevealed = false;
  Timer? _hideTimer;



  void _revealEffect() {
    if (_isRevealed) return;
    setState(() {
      _isRevealed = true;
    });
    // Auto hide after 5 seconds
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isRevealed = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = widget.message;
    final isMe = widget.isMe;
    final isDark = widget.isDark;

    // Check time capsule lock
    final bool isLocked = message.unlockAt != null &&
        message.unlockAt!.toDate().isAfter(DateTime.now());

    // Effect Logic
    final bool hasInvisibleInk = message.effect == 'invisible_ink';

    Widget bubbleContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[

          ],
          Flexible(
            child: GestureDetector(
              onLongPress: widget.onLongPress,
              onTap: hasInvisibleInk ? _revealEffect : null,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.70,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe
                      ? (isDark ? const Color(0xFF4338CA) : const Color(0xFFE0E7FF)) // Indigo 700 (Dark), Indigo 100 (Light)
                      : (isDark ? const Color(0xFF334155) : Colors.white), // Slate 700 (Dark), White (Light)
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
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
                    // 1. Time Capsule Logic
                    if (isLocked) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_clock_rounded,
                              color: colorScheme.onSurface, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Time Capsule",
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  "Opens at ${DateFormat('MMM d, h:mm a').format(message.unlockAt!.toDate())}",
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withOpacity(0.7),
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ]
                    // 2. Normal Content + Effects
                    else ...[
                      if (message.type == 'view_once')
                        _buildViewOnceContent(context, colorScheme)
                      else if (message.type == 'image')
                        _buildImageContent()
                      else if (message.type == 'document')
                        _buildDocumentContent(context, colorScheme)
                      else if (message.type == 'location')
                        _buildLocationContent(context, colorScheme)
                      else
                        // Text Content with Invisible Ink Support
                        Stack(
                          children: [
                            Text(
                              message.content,
                              style: TextStyle(
                                color: isMe ? (isDark ? Colors.white : Colors.black) : colorScheme.onSurface,
                                fontSize: 15,
                                height: 1.3,
                              ),
                            ),
                            if (hasInvisibleInk && !_isRevealed)
                              Positioned.fill(
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                    child: Container(
                                      color: (isMe
                                              ? Colors.white
                                              : colorScheme.onSurface)
                                          .withOpacity(0.2),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.visibility_off_rounded,
                                        color: (isMe
                                                ? Colors.white
                                                : colorScheme.onSurface)
                                            .withOpacity(0.5),
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      if (isLocked && isMe) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline,
                                color: isMe ? (isDark ? Colors.white70 : Colors.black54) : colorScheme.onSurface.withOpacity(0.6), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              "Locked until ${DateFormat('MMM d, h:mm a').format(message.unlockAt!.toDate())}",
                                  style: TextStyle(
                                  color: isMe ? (isDark ? Colors.white70 : Colors.black54) : colorScheme.onSurface.withOpacity(0.6), fontSize: 10),
                            ),
                          ],
                        )
                      ],
                    ],
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (hasInvisibleInk) ...[
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 10,
                            color: isMe
                                ? (isDark ? Colors.white70 : Colors.black54)
                                : colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          DateFormat('h:mm a').format(message.timestamp.toDate()),
                          style: TextStyle(
                            color: isMe
                                ? (isDark ? Colors.white70 : Colors.black54)
                                : colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Builder(
                            builder: (context) {
                              final isImage = message.type == 'image' ||
                                  message.type == 'view_once';
                              final IconData sentIcon = Icons.check;
                              final IconData readIcon = Icons.done_all;
                              // Telegram Check Colors
                              final Color checkColor = isDark ? const Color(0xFF50A7EA) : const Color(0xFF5DAC86);
                              final Color pendingColor = isDark ? Colors.white54 : Colors.black45;

                              if (!message.isSynced) {
                                if (_showPendingIcon) {
                                  return Icon(Icons.access_time_rounded,
                                      size: 12,
                                      color: pendingColor);
                                }
                                return const Icon(Icons.check,
                                    size: 16, color: Colors.transparent);
                              } else if (message.isViewed) {
                                if (widget.seenAvatarUrl != null) {
                                     return Padding(
                                       padding: const EdgeInsets.only(left: 2),
                                       child: ScaleTransition(
                                         scale: CurvedAnimation(
                                           parent: _statusAnimController,
                                           curve: Curves.elasticOut,
                                         ),
                                         child: CircleAvatar(
                                           radius: 8, 
                                           backgroundImage: NetworkImage(widget.seenAvatarUrl!),
                                         ),
                                       ),
                                     );
                                }
                                return Icon(readIcon,
                                    size: 16, color: checkColor);
                              } else {
                                return Icon(sentIcon,
                                    size: 16, color: checkColor);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
              ),
            ),
          ),
        ),
        if (isMe) ...[

          ],
        ],
      ),
    );

    // Removed animation for seamless scrolling experience as per user request
    return bubbleContent;
  }

  Widget _buildViewOnceContent(BuildContext context, ColorScheme colorScheme) {
    final bool isTimeExpired = DateTime.now().difference(widget.message.timestamp.toDate()).inHours >= 24;
    final bool isExpired = widget.message.isViewed || isTimeExpired;
    final bool canView = !isExpired && !widget.isMe;

    return GestureDetector(
      onTap: canView ? widget.onTapViewOnce : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.2)
                    : (isExpired
                        ? Colors.grey.withValues(alpha: 0.1)
                        : colorScheme.primary.withValues(alpha: 0.1)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExpired ? Icons.timer_off_outlined : Icons.filter_1_outlined,
                color: widget.isMe
                    ? Colors.white
                    : (isExpired ? Colors.grey : colorScheme.primary),
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired ? 'Expired' : 'View Once',
                  style: TextStyle(
                    color: widget.isMe ? Colors.white : colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  isExpired ? 'Photo' : 'Tap to view',
                  style: TextStyle(
                    color: widget.isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    if (_decodedImageBytes == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: widget.onTapImage,
      child: Hero( 
        tag: 'img_${widget.message.id}', // Add Hero for smooth transition
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            _decodedImageBytes!,
            width: 220, // Slightly larger default
            height: 220,
            fit: BoxFit.cover,
            gaplessPlayback: true, // Prevents flickering when scrolling
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentContent(BuildContext context, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: widget.onTapDocument,
      child: Container(
        padding: const EdgeInsets.all(10), // Increased padding
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.2)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_rounded,
                size: 28,
                color: widget.isMe ? Colors.white : colorScheme.onSurface),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.message.fileName ?? 'Document',
                    style: TextStyle(
                      color: widget.isMe ? Colors.white : colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.message.fileSize != null)
                    Text(
                      '${(widget.message.fileSize! / 1024).toStringAsFixed(1)} KB',
                      style: TextStyle(
                        color: widget.isMe
                            ? Colors.white.withValues(alpha: 0.7)
                            : colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationContent(BuildContext context, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: widget.onTapLocation,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.2)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_rounded,
                size: 28,
                color: widget.isMe ? Colors.white : Colors.red),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Location',
                  style: TextStyle(
                    color: widget.isMe ? Colors.white : colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Tap to view on map',
                  style: TextStyle(
                    color: widget.isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : colorScheme.onSurface.withValues(alpha: 0.6),
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
