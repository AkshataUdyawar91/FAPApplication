import 'package:flutter/material.dart';

/// Custom painter that draws the Bajaj Auto logo mark.
/// Two interlocking chevrons forming a zigzag "B" shape —
/// top chevron points right, bottom chevron points left.
class BajajLogoPainter extends CustomPainter {
  final Color color;

  BajajLogoPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Top chevron: points right (>)
    final topChevron = Path()
      ..moveTo(w * 0.10, 0)
      ..lineTo(w * 0.90, h * 0.25)
      ..lineTo(w * 0.10, h * 0.50)
      ..lineTo(w * 0.45, h * 0.25)
      ..close();

    // Bottom chevron: points left (<)
    final bottomChevron = Path()
      ..moveTo(w * 0.90, h * 0.50)
      ..lineTo(w * 0.10, h * 0.75)
      ..lineTo(w * 0.90, h * 1.00)
      ..lineTo(w * 0.55, h * 0.75)
      ..close();

    canvas.drawPath(topChevron, paint);
    canvas.drawPath(bottomChevron, paint);
  }

  @override
  bool shouldRepaint(covariant BajajLogoPainter oldDelegate) =>
      color != oldDelegate.color;
}
