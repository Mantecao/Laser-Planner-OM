import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/wall.dart';
import '../services/laser_ble.dart';
import '../services/exporter.dart';
import '../widgets/floor_plan_painter.dart';
import '../widgets/direction_picker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ble = LaserBleService();
  final _plan = FloorPlan();

  double _lastAngle = 0; // recuerda el último ángulo para sugerirlo
  double? _lastDistance;
  StreamSubscription<double>? _distSub;
  StreamSubscription<LaserConnState>? _stateSub;
  LaserConnState _bleState = LaserConnState.idle;

  @override
  void initState() {
    super.initState();
    _distSub = _ble.distances.listen(_onDistance);
    _stateSub = _ble.state.listen((s) => setState(() => _bleState = s));
  }

  @override
  void dispose() {
    _distSub?.cancel();
    _stateSub?.cancel();
    _ble.dispose();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    final perms = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return perms.values.every((s) => s.isGranted);
  }

  Future<void> _scanAndConnect() async {
    if (!await _requestPermissions()) {
      _toast('Permisos de Bluetooth denegados');
      return;
    }
    try {
      final results = await _ble.scan();
      if (!mounted) return;
      if (results.isEmpty) {
        _toast('No se encontró ningún medidor. Asegúrate de que el M120-B tiene el Bluetooth activo.');
        return;
      }
      final picked = await showModalBottomSheet<ScanResult>(
        context: context,
        builder: (ctx) => _DeviceSheet(results: results),
      );
      if (picked == null) return;
      await _ble.connect(picked.device);
      _toast('Conectado a ${picked.device.platformName}');
    } catch (e) {
      _toast('Error: $e');
    }
  }

  void _onDistance(double meters) async {
    setState(() => _lastDistance = meters);

    final angle = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DirectionPickerDialog(
        initialAngle: _lastAngle,
        lengthMeters: meters,
      ),
    );
    if (angle == null) return; // cancelado
    setState(() {
      _plan.addWall(Wall(lengthMeters: meters, angleDegrees: angle));
      _lastAngle = angle;
    });
  }

  void _manualEntry() async {
    final ctrl = TextEditingController();
    final meters = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Introducir distancia manual'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            suffixText: 'm',
            hintText: 'Ej: 3.45',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.pop(ctx, v);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (meters != null && meters > 0) _onDistance(meters);
  }

  void _undo() {
    setState(() => _plan.removeLast());
  }

  void _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Empezar de cero?'),
        content: const Text('Se borrarán todas las paredes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (ok == true) setState(() => _plan.clear());
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _showExportMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Exportar como PNG'),
              onTap: () => Navigator.pop(ctx, 'png'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Exportar como PDF'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.architecture),
              title: const Text('Exportar como DXF (CAD)'),
              onTap: () => Navigator.pop(ctx, 'dxf'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    try {
      final file = switch (choice) {
        'png' => await Exporter.exportPng(_plan),
        'pdf' => await Exporter.exportPdf(_plan),
        'dxf' => await Exporter.exportDxf(_plan),
        _ => null,
      };
      if (file != null) {
        await Exporter.share(file, text: 'Planta medida con láser');
      }
    } catch (e) {
      _toast('Error exportando: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laser Planner'),
        actions: [
          IconButton(
            tooltip: _bleState == LaserConnState.connected
                ? 'Conectado'
                : 'Conectar medidor',
            icon: Icon(
              _bleState == LaserConnState.connected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_searching,
              color: _bleState == LaserConnState.connected
                  ? Colors.lightGreenAccent
                  : null,
            ),
            onPressed: _scanAndConnect,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'manual':
                  _manualEntry();
                  break;
                case 'export':
                  _showExportMenu();
                  break;
                case 'clear':
                  _clearAll();
                  break;
                case 'disconnect':
                  _ble.disconnect();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'manual',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Medida manual'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Exportar'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_forever),
                  title: Text('Borrar todo'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'disconnect',
                child: ListTile(
                  leading: Icon(Icons.link_off),
                  title: Text('Desconectar'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de estado
          _StatusBar(
            bleState: _bleState,
            lastDistance: _lastDistance,
            walls: _plan.walls.length,
            perimeter: _plan.perimeter,
            area: _plan.area,
          ),

          // Canvas
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: CustomPaint(
                painter: FloorPlanPainter(plan: _plan),
                size: Size.infinite,
              ),
            ),
          ),

          // Controles inferiores
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _plan.walls.isEmpty ? null : _undo,
                      icon: const Icon(Icons.undo),
                      label: const Text('Deshacer'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _manualEntry,
                      icon: const Icon(Icons.edit),
                      label: const Text('Medida manual'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _plan.walls.isEmpty ? null : _showExportMenu,
                      icon: const Icon(Icons.share),
                      label: const Text('Exportar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final LaserConnState bleState;
  final double? lastDistance;
  final int walls;
  final double perimeter;
  final double area;

  const _StatusBar({
    required this.bleState,
    required this.lastDistance,
    required this.walls,
    required this.perimeter,
    required this.area,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          _chip(
            icon: bleState == LaserConnState.connected
                ? Icons.bluetooth_connected
                : Icons.bluetooth_disabled,
            label: switch (bleState) {
              LaserConnState.connected => 'Conectado',
              LaserConnState.connecting => 'Conectando...',
              LaserConnState.scanning => 'Buscando...',
              LaserConnState.error => 'Error',
              _ => 'Sin conectar',
            },
            color: bleState == LaserConnState.connected
                ? Colors.green
                : Colors.grey,
          ),
          const SizedBox(width: 8),
          if (lastDistance != null)
            _chip(
              icon: Icons.straighten,
              label: '${lastDistance!.toStringAsFixed(3)} m',
              color: Colors.deepOrange,
            ),
          const Spacer(),
          Text('$walls paredes  ·  ${perimeter.toStringAsFixed(2)} m'
              '${walls >= 3 ? '  ·  ${area.toStringAsFixed(2)} m²' : ''}',
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _chip(
      {required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _DeviceSheet extends StatelessWidget {
  final List<ScanResult> results;
  const _DeviceSheet({required this.results});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Selecciona el medidor',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ...results.map((r) => ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(r.device.platformName.isEmpty
                    ? '(sin nombre)'
                    : r.device.platformName),
                subtitle: Text(
                    '${r.device.remoteId.str}  ·  ${r.rssi} dBm'),
                onTap: () => Navigator.pop(context, r),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
