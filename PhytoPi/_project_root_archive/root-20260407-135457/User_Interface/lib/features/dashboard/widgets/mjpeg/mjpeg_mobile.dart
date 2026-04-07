import 'package:flutter/material.dart';

Widget buildMjpegView(String url, BoxFit fit) {
  return Image.network(
    url,
    fit: fit,
    gaplessPlayback: true,
    errorBuilder: (context, error, stack) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              'Stream Error', 
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 8),
            Text(
              'Ensure URL is reachable',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
      );
    },
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) return child;
      return const Center(
        child: CircularProgressIndicator(),
      );
    },
  );
}

