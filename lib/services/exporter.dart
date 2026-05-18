import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/wall.dart';
import '../widgets/floor_plan_painter.dart';

class Exporter {
  /// Captura el canvas como PNG y lo guarda en almacenamiento temporal.
  static Future<File> exportPng(FloorPlan plan) async {
    final recorder = ui.PictureRecorder();
    const size = Size(1200, 1200);
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    final painter = FloorPlanPainter(plan: plan);
    painter.paint(canvas, size);

    final pic = recorder.endRecording();
    final img = await pic.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/planta_$ts.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<File> exportPdf(FloorPlan plan) async {
    final pngFile = await exportPng(plan);
    final pngBytes = await pngFile.readAsBytes();

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Planta medida con láser',
                  style: pw.TextStyle(
                      fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generado: ${DateTime.now().toString().substring(0, 16)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                height: 360,
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5),
                ),
                child: pw.Image(pw.MemoryImage(pngBytes), fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _stat('Perímetro',
                        '${plan.perimeter.toStringAsFixed(3)} m'),
                  ),
                  pw.Expanded(
                    child: _stat(
                        'Área (cerrada)', '${plan.area.toStringAsFixed(3)} m²'),
                  ),
                  pw.Expanded(
                    child: _stat('Error cierre',
                        '${plan.closureError.toStringAsFixed(3)} m'),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Text('Paredes',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['#', 'Longitud (m)', 'Ángulo (°)'],
                data: [
                  for (var i = 0; i < plan.walls.length; i++)
                    [
                      '${i + 1}',
                      plan.walls[i].lengthMeters.toStringAsFixed(3),
                      plan.walls[i].angleDegrees.toStringAsFixed(1),
                    ]
                ],
                cellStyle: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/planta_$ts.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _stat(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(value,
            style:
                pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  /// Exporta a DXF minimal (R12 ASCII) — abrible en AutoCAD, LibreCAD, QCAD, SketchUp...
  static Future<File> exportDxf(FloorPlan plan) async {
    final pts = plan.vertices;
    final sb = StringBuffer();
    sb.writeln('0\nSECTION\n2\nENTITIES');

    // LWPOLYLINE no está en R12; usamos LINE entity por simplicidad y máxima compatibilidad
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      sb.writeln('0\nLINE');
      sb.writeln('8\nPAREDES'); // layer
      sb.writeln('10\n${a.dx}');
      sb.writeln('20\n${a.dy}');
      sb.writeln('30\n0.0');
      sb.writeln('11\n${b.dx}');
      sb.writeln('21\n${b.dy}');
      sb.writeln('31\n0.0');
    }
    sb.writeln('0\nENDSEC\n0\nEOF');

    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/planta_$ts.dxf');
    await file.writeAsString(sb.toString());
    return file;
  }

  /// Comparte un archivo usando el menú de compartir del sistema.
  static Future<void> share(File file, {String? text}) async {
    await Share.shareXFiles([XFile(file.path)], text: text);
  }
}
