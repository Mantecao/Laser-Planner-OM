import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Una pared: tiene una longitud (en metros) y un ángulo (en grados, 0 = derecha, 90 = arriba).
class Wall {
  final double lengthMeters;
  final double angleDegrees; // 0=Este, 90=Norte, 180=Oeste, 270=Sur

  Wall({required this.lengthMeters, required this.angleDegrees});

  /// Devuelve el desplazamiento (dx, dy) en metros desde el punto de inicio
  /// hasta el punto final de esta pared. dy es positivo hacia arriba.
  Offset get displacement {
    final rad = angleDegrees * math.pi / 180;
    return Offset(
      lengthMeters * math.cos(rad),
      lengthMeters * math.sin(rad),
    );
  }

  Map<String, dynamic> toJson() => {
        'length': lengthMeters,
        'angle': angleDegrees,
      };
}

/// Una planta: conjunto de paredes empezando en el origen (0,0).
class FloorPlan {
  final List<Wall> walls = [];

  void addWall(Wall w) => walls.add(w);
  void removeLast() {
    if (walls.isNotEmpty) walls.removeLast();
  }

  void clear() => walls.clear();

  /// Calcula los vertices del polígono en coordenadas (metros).
  List<Offset> get vertices {
    final pts = <Offset>[const Offset(0, 0)];
    var cursor = const Offset(0, 0);
    for (final w in walls) {
      cursor += w.displacement;
      pts.add(cursor);
    }
    return pts;
  }

  /// Perímetro total en metros.
  double get perimeter =>
      walls.fold(0.0, (sum, w) => sum + w.lengthMeters);

  /// Área en m² usando la fórmula del cordón de zapato.
  /// Solo tiene sentido si el polígono está cerrado o casi cerrado.
  double get area {
    final pts = vertices;
    if (pts.length < 3) return 0;
    double sum = 0;
    for (var i = 0; i < pts.length; i++) {
      final p1 = pts[i];
      final p2 = pts[(i + 1) % pts.length];
      sum += (p1.dx * p2.dy) - (p2.dx * p1.dy);
    }
    return sum.abs() / 2;
  }

  /// Distancia entre el último punto y el primero (para mostrar "cierre").
  double get closureError {
    final pts = vertices;
    if (pts.length < 2) return 0;
    return (pts.last - pts.first).distance;
  }
}
