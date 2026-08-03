import 'package:flutter/material.dart';

/// Encapsulates [CircularProgressIndicator] for a whole-screen wait.
class VgrLoading extends StatelessWidget {
  const VgrLoading({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// The small spinner that replaces a button label while it works — sized
/// once here so buttons never jump when they switch to the busy state.
class VgrInlineProgress extends StatelessWidget {
  const VgrInlineProgress({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
}
