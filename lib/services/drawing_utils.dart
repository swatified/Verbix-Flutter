import 'package:flutter/material.dart';

class DrawingArea {
  Offset point;
  Paint areaPaint;

  DrawingArea({required this.point, required this.areaPaint});
}

class MyCustomPainter extends CustomPainter {
  final List<DrawingArea?> points;

  MyCustomPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    Paint background =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, background);

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
          points[i]!.point,
          points[i + 1]!.point,
          points[i]!.areaPaint,
        );
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawCircle(
          points[i]!.point,
          points[i]!.areaPaint.strokeWidth / 2,
          points[i]!.areaPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(MyCustomPainter oldDelegate) {
    return true;
  }
}
