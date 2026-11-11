import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Full-screen image preview with pinch-to-zoom and pan support
class ImagePreviewDialog extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const ImagePreviewDialog({
    super.key,
    required this.imageUrl,
    this.title,
  });

  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
    String? title,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ImagePreviewDialog(
          imageUrl: imageUrl,
          title: title,
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (imageUrl.startsWith('data:image')) {
      final raw = imageUrl.contains(',') ? imageUrl.split(',').last : imageUrl;
      try {
        return Image.memory(
          base64Decode(raw),
          fit: BoxFit.contain,
          errorBuilder: (_, error, _) => const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
              SizedBox(height: 12),
              Text(
                'Failed to load full image',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
      } catch (_) {
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
            SizedBox(height: 12),
            Text(
              'Failed to load full image',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        );
      }
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        final total = loadingProgress.expectedTotalBytes;
        final loaded = loadingProgress.cumulativeBytesLoaded;
        return Center(
          child: CircularProgressIndicator(
            value: total != null ? loaded / total : null,
            color: AppPalette.champagneGold,
          ),
        );
      },
      errorBuilder: (_, error, _) => const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
          SizedBox(height: 12),
          Text(
            'Failed to load full image',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title ?? 'Attached Photo',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.8,
          maxScale: 4.0,
          child: _buildImage(),
        ),
      ),
    );
  }
}
