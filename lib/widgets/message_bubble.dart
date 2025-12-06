import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/message.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final bool isDark;
  final VoidCallback onLongPress;
  final VoidCallback? onTapViewOnce;
  final VoidCallback? onTapImage;
  final VoidCallback? onTapDocument;
  final VoidCallback? onTapLocation;
  final bool isNew; // To trigger animation only for new messages if needed

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
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  Uint8List? _decodedImageBytes;

  @override
  void initState() {
    super.initState();
    _decodeImageIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.imageData != oldWidget.message.imageData) {
      _decodeImageIfNeeded();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = widget.message;
    final isMe = widget.isMe;
    final isDark = widget.isDark;

    Widget bubbleContent = Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: isMe
                ? LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isMe
                ? null
                : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
                _buildViewOnceContent(context, colorScheme)
              else if (message.type == 'image')
                _buildImageContent()
              else if (message.type == 'document')
                _buildDocumentContent(context, colorScheme)
              else if (message.type == 'location')
                _buildLocationContent(context, colorScheme)
              else
                Text(
                  message.content,
                  style: TextStyle(
                    color: isMe ? Colors.white : colorScheme.onSurface,
                    fontSize: 15, // Slightly larger for better readability
                    height: 1.3,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('h:mm a').format(message.timestamp.toDate()),
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      !message.isSynced
                          ? Icons.access_time_rounded
                          : (message.isViewed
                              ? Icons.done_all_rounded
                              : (message.isDelivered
                                  ? Icons.done_all_rounded
                                  : Icons.check_rounded)),
                      size: 14,
                      color: message.isViewed
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Only animate if it's considered 'new' (passed from parent) or simplistically animate all on load
    // For smoothness, we'll keep the simple fade-in but reduce duration/complexity
    return bubbleContent.animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0, duration: 200.ms);
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
