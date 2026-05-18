import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Diálogo para escoger la dirección de una pared.
/// Devuelve el ángulo en grados (0=E, 90=N, 180=O, 270=S).
class DirectionPickerDialog extends StatefulWidget {
  final double initialAngle;
  final double lengthMeters;

  const DirectionPickerDialog({
    super.key,
    this.initialAngle = 0,
    required this.lengthMeters,
  });

  @override
  State<DirectionPickerDialog> createState() => _DirectionPickerDialogState();
}

class _DirectionPickerDialogState extends State<DirectionPickerDialog> {
  late double angle;
  late TextEditingController _manualCtrl;

  @override
  void initState() {
    super.initState();
    angle = widget.initialAngle;
    _manualCtrl = TextEditingController(text: angle.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  void _setAngle(double a) {
    setState(() {
      angle = a % 360;
      if (angle < 0) angle += 360;
      _manualCtrl.text = angle.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Pared de ${widget.lengthMeters.toStringAsFixed(3)} m'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Hacia dónde va la pared?',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 12),

            // Rueda visual con la dirección
            GestureDetector(
              onPanUpdate: (d) {
                final box = context.findRenderObject() as RenderBox;
                final local = box.globalToLocal(d.globalPosition);
                // El centro de la rueda; aproximamos al centro del diálogo
                // Mejor: calcular respecto del propio widget gestor
                _updateAngleFromTouch(local, box.size);
              },
              child: SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                  painter: _CompassPainter(angle),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Botones rápidos de ortogonales
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                _quickBtn('→ E', 0),
                _quickBtn('↗ NE', 45),
                _quickBtn('↑ N', 90),
                _quickBtn('↖ NO', 135),
                _quickBtn('← O', 180),
                _quickBtn('↙ SO', 225),
                _quickBtn('↓ S', 270),
                _quickBtn('↘ SE', 315),
              ],
            ),
            const SizedBox(height: 8),

            // Giros relativos respecto al ángulo actual
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '-90°',
                  onPressed: () => _setAngle(angle - 90),
                  icon: const Icon(Icons.rotate_left),
                ),
                IconButton(
                  tooltip: '-15°',
                  onPressed: () => _setAngle(angle - 15),
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  tooltip: '+15°',
                  onPressed: () => _setAngle(angle + 15),
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  tooltip: '+90°',
                  onPressed: () => _setAngle(angle + 90),
                  icon: const Icon(Icons.rotate_right),
                ),
              ],
            ),

            // Entrada manual
            Row(
              children: [
                const Text('Ángulo: '),
                Expanded(
                  child: TextField(
                    controller: _manualCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      suffixText: '°',
                      isDense: true,
                    ),
                    onSubmitted: (v) {
                      final n = double.tryParse(v);
                      if (n != null) _setAngle(n);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    final n = double.tryParse(_manualCtrl.text);
                    if (n != null) _setAngle(n);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(angle),
          child: const Text('Añadir pared'),
        ),
      ],
    );
  }

  Widget _quickBtn(String label, double a) {
    final selected = (angle - a).abs() < 0.5;
    return SizedBox(
      width: 64,
      child: OutlinedButton(
        onPressed: () => _setAngle(a),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          backgroundColor: selected ? Colors.deepOrange.shade50 : null,
          side: BorderSide(
            color: selected ? Colors.deepOrange : Colors.grey,
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  void _updateAngleFromTouch(Offset local, Size size) {
    // Esto es aproximado; lo dejo simple para no complicar el ejemplo.
    final cx = size.width / 2;
    final cy = size.height / 2;
    final dx = local.dx - cx;
    final dy = cy - local.dy; // y invertido (pantalla)
    final rad = math.atan2(dy, dx);
    final deg = rad * 180 / math.pi;
    _setAngle(deg);
  }
}

class _CompassPainter extends CustomPainter {
  final double angle;
  _CompassPainter(this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Círculo exterior
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Marcas cardinales
    final labels = {'E': 0.0, 'N': 90.0, 'O': 180.0, 'S': 270.0};
    labels.forEach((label, deg) {
      final rad = deg * math.pi / 180;
      final pos = Offset(
        center.dx + math.cos(rad) * (radius - 16),
        center.dy - math.sin(rad) * (radius - 16),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    });

    // Marcas cada 15°
    for (var d = 0; d < 360; d += 15) {
      final rad = d * math.pi / 180;
      final inner = d % 90 == 0 ? radius - 12 : radius - 6;
      final p1 = Offset(
        center.dx + math.cos(rad) * inner,
        center.dy - math.sin(rad) * inner,
      );
      final p2 = Offset(
        center.dx + math.cos(rad) * radius,
        center.dy - math.sin(rad) * radius,
      );
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = Colors.grey.shade400
          ..strokeWidth = d % 90 == 0 ? 2 : 1,
      );
    }

    // Flecha del ángulo actual
    final rad = angle * math.pi / 180;
    final tip = Offset(
      center.dx + math.cos(rad) * (radius - 4),
      center.dy - math.sin(rad) * (radius - 4),
    );
    final arrowPaint = Paint()
      ..color = Colors.deepOrange
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, arrowPaint);
    canvas.drawCircle(tip, 7, Paint()..color = Colors.deepOrange);
    canvas.drawCircle(center, 5, Paint()..color = Colors.deepOrange);

    // Texto central con el ángulo
    final tp = TextPainter(
      text: TextSpan(
        text: '${angle.toStringAsFixed(0)}°',
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center + Offset(-tp.width / 2, radius / 2));
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) => old.angle != angle;
}
