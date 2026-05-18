import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// UUIDs del medidor Mileseey M120-B / M130.
/// Confirmados via nRF Connect el 18/05/2026.
class LaserUuids {
  static final Guid service = Guid('0000ffb0-0000-1000-8000-00805f9b34fb');
  static final Guid dataChar = Guid('0000ffb2-0000-1000-8000-00805f9b34fb');
  static final Guid infoChar = Guid('0000ffb1-0000-1000-8000-00805f9b34fb');
}

/// Estados del servicio BLE.
enum LaserConnState { idle, scanning, connecting, connected, error }

/// Servicio que se conecta al medidor y emite distancias parseadas.
class LaserBleService {
  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _notifSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  /// Distancias recibidas (en metros).
  final _distanceCtrl = StreamController<double>.broadcast();
  Stream<double> get distances => _distanceCtrl.stream;

  /// Estado de conexión.
  final _stateCtrl = StreamController<LaserConnState>.broadcast();
  Stream<LaserConnState> get state => _stateCtrl.stream;

  LaserConnState _currentState = LaserConnState.idle;
  LaserConnState get currentState => _currentState;

  String? _firmware;
  String? get firmware => _firmware;

  void _setState(LaserConnState s) {
    _currentState = s;
    _stateCtrl.add(s);
  }

  /// Escanea dispositivos BLE durante [timeout] segundos.
  /// Devuelve una lista de dispositivos encontrados que se llaman M130 o M120.
  Future<List<ScanResult>> scan({int timeoutSeconds = 8}) async {
    _setState(LaserConnState.scanning);
    final results = <String, ScanResult>{};

    await FlutterBluePlus.startScan(
      timeout: Duration(seconds: timeoutSeconds),
      androidUsesFineLocation: true,
    );

    final sub = FlutterBluePlus.scanResults.listen((scanResults) {
      for (final r in scanResults) {
        final name = r.device.platformName.toUpperCase();
        if (name.contains('M130') ||
            name.contains('M120') ||
            name.contains('MILESEEY')) {
          results[r.device.remoteId.str] = r;
        }
      }
    });

    await FlutterBluePlus.isScanning
        .where((scanning) => scanning == false)
        .first;
    await sub.cancel();
    _setState(LaserConnState.idle);
    return results.values.toList();
  }

  /// Conecta a un dispositivo y se suscribe a la característica de medidas.
  Future<void> connect(BluetoothDevice device) async {
    try {
      _setState(LaserConnState.connecting);
      _device = device;

      // Cancelar suscripciones previas
      await _notifSub?.cancel();
      await _connSub?.cancel();

      // Escuchar cambios de conexión
      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _setState(LaserConnState.idle);
        }
      });

      await device.connect(autoConnect: false, timeout: const Duration(seconds: 12));
      final services = await device.discoverServices();

      // Buscar nuestro servicio FFB0
      final service = services.firstWhere(
        (s) => s.uuid == LaserUuids.service,
        orElse: () => throw Exception('Servicio FFB0 no encontrado'),
      );

      // Leer firmware (opcional, para mostrar info)
      try {
        final infoChar = service.characteristics
            .firstWhere((c) => c.uuid == LaserUuids.infoChar);
        final fwBytes = await infoChar.read();
        _firmware = String.fromCharCodes(fwBytes).trim();
      } catch (_) {}

      // Suscribirse a la característica de datos FFB2
      final dataChar = service.characteristics
          .firstWhere((c) => c.uuid == LaserUuids.dataChar);
      await dataChar.setNotifyValue(true);

      _notifSub = dataChar.lastValueStream.listen(_onData);

      _setState(LaserConnState.connected);
    } catch (e) {
      _setState(LaserConnState.error);
      rethrow;
    }
  }

  /// Parsea un frame del medidor.
  /// Formato confirmado: ASCII "X.XXXm\r\n\0" (ej. "2.099m\r\n")
  void _onData(List<int> bytes) {
    if (bytes.isEmpty) return;
    final raw = String.fromCharCodes(bytes);
    final match = RegExp(r'(\d+\.?\d*)\s*m').firstMatch(raw);
    if (match != null) {
      final value = double.tryParse(match.group(1)!);
      if (value != null && value > 0 && value < 100) {
        _distanceCtrl.add(value);
      }
    }
  }

  Future<void> disconnect() async {
    await _notifSub?.cancel();
    await _connSub?.cancel();
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    _setState(LaserConnState.idle);
  }

  void dispose() {
    _notifSub?.cancel();
    _connSub?.cancel();
    _distanceCtrl.close();
    _stateCtrl.close();
  }
}
