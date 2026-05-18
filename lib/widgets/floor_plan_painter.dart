import 'package:flutter/material.dart';
import '../models/wall.dart';

class FloorPlanPainter extends CustomPainter {
  final FloorPlan plan;
  final double pendingLengthMeters; // longitud "fantasma" antes de confirmar dirección
  final double pendingAngleDegrees;
  final bool showPending;

  FloorPlanPainter({
    required this.plan,
    this.pendingLengthMeters = 0,
    this.pendingAngleDegrees = 0,
    this.showPending = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calcular bounding box
    final pts = List<Offset>.from(plan.vertices);
    if (showPending && plan.walls.isNotEmpty || showPending) {
      final cursor = pts.isNotEmpty ? pts.last : const Offset(0, 0);
      final pending = Wall(
        lengthMeters: pendingLengthMeters,
        angleDegrees: pendingAngleDegrees,
      ).displacement;
      pts.add(cursor + pending);
    }

    if (pts.isEmpty) return;

    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final w = (maxX - minX);
    final h = (maxY - minY);
    final padding = 40.0;
    final scale = w == 0 && h == 0
        ? 50.0
        : (size.width - padding * 2) /
                (w == 0 ? 1 : w) <
            (size.height - padding * 2) / (h == 0 ? 1 : h)
            ? (size.width - padding * 2) / (w == 0 ? 1 : w)
            : (size.height - padding * 2) / (h == 0 ? 1 : h);

    final scaleClamped = scale.clamp(20.0, 200.0);

    Offset toScreen(Offset p) {
      // Centrar y voltear Y (en pantalla Y va hacia abajo)
      final cx = size.width / 2 - (minX + maxX) / 2 * scaleClamped;
      final cy = size.height / 2 + (minY + maxY) / 2 * scaleClamped;
      return Offset(p.dx * scaleClamped + cx, -p.dy * scaleClamped + cy);
    }

    // Cuadrícula
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;
    final gridStep = scaleClamped; // 1 metro
    for (double x = 0; x < size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Paredes confirmadas
    final wallPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final vertexPaint = Paint()..color = Colors.deepOrange;
    final labelStyle = const TextStyle(
      color: Colors.black87,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    final confirmedPts = plan.vertices;
    for (var i = 0; i < confirmedPts.length - 1; i++) {
      final a = toScreen(confirmedPts[i]);
      final b = toScreen(confirmedPts[i + 1]);
      canvas.drawLine(a, b, wallPaint);

      // Etiqueta con la longitud
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final wall = plan.walls[i];
      final tp = TextPainter(
        text: TextSpan(
          text: '${wall.lengthMeters.toStringAsFixed(2)} m',
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Fondo blanco semi para legibilidad
      final bg = Rect.fromCenter(
        center: mid,
        width: tp.width + 8,
        height: tp.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bg, const Radius.circular(4)),
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
      tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
    }

    // Vértices
    for (final p in confirmedPts) {
      canvas.drawCircle(toScreen(p), 4, vertexPaint);
    }

    // Pared "fantasma" (preview)
    if (showPending && pendingLengthMeters > 0) {
      final cursor = confirmedPts.isNotEmpty
          ? confirmedPts.last
          : const Offset(0, 0);
      final pending = Wall(
        lengthMeters: pendingLengthMeters,
        angleDegrees: pendingAngleDegrees,
      ).displacement;
      final end = cursor + pending;

      final dashPaint = Paint()
        ..color = Colors.deepOrange
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      _drawDashedLine(canvas, toScreen(cursor), toScreen(end), dashPaint);
    }

    // Origen
    if (confirmedPts.isNotEmpty) {
      final origin = toScreen(confirmedPts.first);
      canvas.drawCircle(origin, 6, Paint()..color = Colors.green);
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Inicio',
          style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, origin + const Offset(8, -6));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLen = 8.0;
    const gapLen = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    double drawn = 0;
    while (drawn < total) {
      final start = a + dir * drawn;
      final end = a + dir * (drawn + dashLen).clamp(0.0, total);
      canvas.drawLine(start, end, paint);
      drawn += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant FloorPlanPainter old) =>
      old.plan != plan ||
      old.pendingLengthMeters != pendingLengthMeters ||
      old.pendingAngleDegrees != pendingAngleDegrees ||
      old.showPending != showPending;
}
