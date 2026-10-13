import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'vgr_colors.dart';
import 'vgr_theme.dart';

/// The VGR symbol (decisions 261, 263): an arc that covers a lit dot,
/// someone keeping watch over the one kept safe. It is also the sign of
/// protection — there is no shield.
///
/// Drawn, not loaded: the geometry is `mark.py` of
/// `vgr-ai/docs/identidade-visual/v1b/gerador`, in the same 100-unit box,
/// so the app, the icons and the logo files stay one shape.
class VgrSymbol extends StatelessWidget {
  const VgrSymbol({super.key, this.height = 24, this.arc, this.dot, this.semanticLabel});

  /// Height of the symbol; the width follows its proportion.
  final double height;

  /// Defaults to the theme's brand navy and the gold drawn on its surfaces.
  final Color? arc;
  final Color? dot;

  /// Null when the symbol sits next to a text that already names it.
  final String? semanticLabel;

  /// Width ÷ height of the symbol's box.
  static const aspectRatio = _SymbolPainter.width / _SymbolPainter.height;

  @override
  Widget build(BuildContext context) {
    final colors = VgrColors.of(context);
    final paint = CustomPaint(
      size: Size(height * aspectRatio, height),
      painter: _SymbolPainter(arc ?? colors.brand, dot ?? colors.accentGraphic),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: paint)
        : Semantics(label: semanticLabel, image: true, child: paint);
  }
}

class _SymbolPainter extends CustomPainter {
  _SymbolPainter(this.arc, this.dot);

  final Color arc;
  final Color dot;

  // The 100-unit geometry (mark.py).
  static const _cx = 50.0, _cy = 50.0;
  static const _rOut = 42.0, _rIn = 23.5;
  static const _cut = 6.7; // the flat ends, this far below the centre
  static const _dotR = 12.7, _dotDy = 3.8;
  static const _soft = 2.4; // same-colour stroke that rounds the corners
  static const _left = _cx - _rOut - _soft / 2;
  static const _top = _cy - _rOut - _soft / 2;
  static const width = 2 * (_rOut + _soft / 2);
  static const height = _dotDy + _dotR - (_top - _cy);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / height;
    canvas
      ..scale(s)
      ..translate(-_left, -_top);

    final aOut = math.asin(_cut / _rOut);
    final aIn = math.asin(_cut / _rIn);
    final outer = Rect.fromCircle(center: const Offset(_cx, _cy), radius: _rOut);
    final inner = Rect.fromCircle(center: const Offset(_cx, _cy), radius: _rIn);
    final path = Path()
      ..moveTo(_cx - _rOut * math.cos(aOut), _cy + _cut)
      ..arcTo(outer, math.pi - aOut, math.pi + 2 * aOut, false)
      ..lineTo(_cx + _rIn * math.cos(aIn), _cy + _cut)
      ..arcTo(inner, aIn, -(math.pi + 2 * aIn), false)
      ..close();

    canvas
      ..drawPath(path, Paint()..color = arc)
      ..drawPath(
        path,
        Paint()
          ..color = arc
          ..style = PaintingStyle.stroke
          ..strokeWidth = _soft
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(const Offset(_cx, _cy + _dotDy), _dotR, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_SymbolPainter old) => old.arc != arc || old.dot != dot;
}

/// The VGR logo: the symbol, "VGR" and "Vigilância e Recompensa" (decision
/// 250), in the identity's font. The descriptor is set to the width of the
/// word, as in the vector files.
class VgrLogo extends StatelessWidget {
  const VgrLogo({super.key, this.height = 48, this.descriptor = 'Vigilância e Recompensa'});

  /// Roughly the height of the symbol; the word is set to match it.
  final double height;

  /// The line under "VGR". Kept in Portuguese in both languages: it is
  /// part of the mark, like the name.
  final String descriptor;

  // From mark.py: at a word size of 100 the descriptor that matches its
  // width is 18.74.
  static const _descriptorRatio = 0.1874;

  @override
  Widget build(BuildContext context) {
    final colors = VgrColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final size = height;
    const family = VgrTheme.fontFamily;
    const package = VgrTheme.fontPackage;
    return Semantics(
      label: 'VGR — $descriptor',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VgrSymbol(height: size * 0.98),
          SizedBox(width: size * 0.15),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VGR',
                style: TextStyle(
                  fontFamily: family,
                  package: package,
                  fontWeight: FontWeight.w800,
                  fontSize: size,
                  height: 1,
                  letterSpacing: size * 0.01,
                  color: dark ? colors.text : colors.brand,
                ),
              ),
              Text(
                descriptor,
                style: TextStyle(
                  fontFamily: family,
                  package: package,
                  fontSize: size * _descriptorRatio,
                  height: 1.4,
                  letterSpacing: size * _descriptorRatio * 0.005,
                  color: dark ? colors.muted : colors.brand,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The logo at the top of a screen outside the app proper (the login of
/// each app): centred, with room below it.
class VgrLogoHeader extends StatelessWidget {
  const VgrLogoHeader({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 28),
        child: Center(child: VgrLogo(height: 44)),
      );
}
