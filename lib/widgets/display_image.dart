import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class DisplayImage extends StatelessWidget {
  final String? path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final double radius;

  const DisplayImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.radius = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) {
      return _buildPlaceholder(context);
    }

    Widget imageWidget;
    if (path!.startsWith('http')) {
      imageWidget = Image.network(
        path!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoading(context);
        },
      );
    } else {
      try {
        // Assume Base64
        Uint8List bytes = base64Decode(path!);
        imageWidget = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
        );
      } catch (e) {
        return _buildPlaceholder(context);
      }
    }

    if (radius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(radius),
      ),
      child: placeholder ??
          Icon(Icons.image_not_supported, color: Colors.grey[500]),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

// Helper for CircleAvatar usage
ImageProvider? getAvatarImage(String? path) {
  if (path == null || path.isEmpty) {
    return null; // Return null to allow CircleAvatar to show backgroundColor and child (Text)
  }
  if (path.startsWith('http')) {
    return NetworkImage(path);
  }
  try {
    return MemoryImage(base64Decode(path));
  } catch (e) {
    return null;
  }
}
