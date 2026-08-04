import 'dart:io';

import 'package:flutter/material.dart';

import 'vgr_icon.dart';

/// Encapsulates [Image] (file-backed) for photo thumbnails (decision 133).
/// Dumb by design: the badge text and the remove action are the screen's
/// business — this widget only renders them.
class VgrPhotoThumb extends StatelessWidget {
  const VgrPhotoThumb({
    super.key,
    required this.imagePath,
    this.onRemove,
    this.onTap,
    this.badgeText,
    this.size = 96,
  });

  final String imagePath;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  /// Short label rendered over the bottom edge — "EXIF kept" is the case
  /// that forced it (decision 130).
  final String? badgeText;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InkWell(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  // A broken path must not take the form down with it.
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFFE0E0E0),
                    child: Center(child: VgrIcon(VgrIconName.image)),
                  ),
                ),
              ),
            ),
            if (badgeText != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      badgeText!,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ),
            if (onRemove != null)
              Positioned(
                top: 0,
                right: 0,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
