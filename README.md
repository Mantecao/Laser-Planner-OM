# Laser Planner — App para dibujar plantas con medidor láser

App Flutter que se conecta por BLE al medidor láser **Mileseey M120-B / M130** y va dibujando una planta a medida que disparas el láser y le indicas la dirección de cada pared.

## Funcionalidades

- Conexión BLE automática al medidor (servicio `0000ffb0`, característica `0000ffb2`).
- Cada disparo del láser → diálogo emergente con rueda de direcciones (8 flechas cardinales + entrada manual de grados + giros relativos ±15° / ±90°).
- Canvas con cuadrícula a 1 m, paredes etiquetadas, vértices marcados, planta dibujada a escala.
- Estadísticas en vivo: número de paredes, perímetro, área (cuando hay ≥3 paredes), error de cierre.
- Deshacer última pared, borrar todo, medida manual (sin medidor).
- Exportación a **PNG, PDF (con tabla de medidas) y DXF** (abrible en AutoCAD, LibreCAD, SketchUp).
- Compartir directamente con cualquier app (WhatsApp, email, Drive...).

## Requisitos para compilar

1. **Flutter SDK** (≥ 3.0). Instalación: https://docs.flutter.dev/get-started/install
2. **Android Studio** o el SDK de Android por línea de comandos.
3. **JDK 17** (lo trae Android Studio).
4. Teléfono Android con **modo desarrollador y depuración USB** activados.

## Pasos para tener la app en el móvil

```bash
# 1. Descomprimir el zip y entrar en la carpeta
cd laser_planner

# 2. Crear la estructura Android nativa que Flutter necesita.
#    Esto regenera /android/* completo a partir del pubspec.
#    Los archivos lib/, pubspec.yaml y android/app/src/main/AndroidManifest.xml
#    se respetan; solo se generan los que faltan.
flutter create --platforms=android .

# 3. IMPORTANTE: tras el create, sustituir el AndroidManifest generado
#    por el que viene en este proyecto (ya está en android/app/src/main/
#    AndroidManifest.xml). Si Flutter lo sobrescribe, copialo de nuevo
#    desde el zip.

# 4. Descargar dependencias
flutter pub get

# 5. Conectar el móvil por USB y verificar que se detecta
flutter devices

# 6. Compilar e instalar en el móvil (la primera vez tarda 3-5 minutos)
flutter run

# Alternativa: generar un APK suelto para instalarlo a mano
flutter build apk --release
# El APK queda en: build/app/outputs/flutter-apk/app-release.apk
```

## Uso

1. Encender el M120-B y verificar que el icono Bluetooth aparece en su pantalla.
2. Abrir la app → tocar el icono Bluetooth de la esquina superior derecha → seleccionar "M130" en la lista.
3. Disparar el láser apuntando a la primera pared.
4. En el diálogo, elegir la dirección de la pared (E/N/O/S, diagonales, o grados manuales).
5. Repetir para cada pared.
6. Cuando termines, menú superior → **Exportar** → PNG/PDF/DXF.

## Protocolo BLE (documentado de la ingeniería inversa)

```
Servicio:            0000ffb0-0000-1000-8000-00805f9b34fb (FFB0)
Char info/firmware:  0000ffb1-...  (READ, devuelve "V1.1.2" en ASCII)
Char datos medidas:  0000ffb2-...  (NOTIFY)

Formato de notificación FFB2:
  bytes ASCII: "X.XXXm\r\n\0"
  Ej.: 32 2E 30 39 39 6D 0D 0A 00  =  "2.099m\r\n\0"  =  2.099 metros
```

El parser (en `lib/services/laser_ble.dart`) usa un regex simple `(\d+\.?\d*)\s*m` para extraer el float.

## Estructura del código

```
lib/
├── main.dart                          Punto de entrada
├── models/
│   └── wall.dart                      Modelo Wall + FloorPlan (área, perímetro, vertices)
├── services/
│   ├── laser_ble.dart                 Conexión BLE y parseado de medidas
│   └── exporter.dart                  Exportación a PNG/PDF/DXF
├── screens/
│   └── home_screen.dart               Pantalla principal con canvas y controles
└── widgets/
    ├── floor_plan_painter.dart        CustomPainter del canvas
    └── direction_picker.dart          Diálogo con brújula + flechas + entrada manual
```

## Si algo falla

**"No se encontró ningún medidor"**: comprobar que el icono BT está en la pantalla del medidor, que está a menos de 5 m, y que has aceptado los permisos de Bluetooth y ubicación cuando los pidió la app.

**Build falla con error de minSdkVersion**: editar `android/app/build.gradle` y poner `minSdkVersion 21` (o superior si flutter_blue_plus lo exige).

**Build falla con "Namespace not specified"**: editar `android/app/build.gradle` y añadir dentro del bloque `android { }`: `namespace "com.example.laser_planner"`.

## Mejoras futuras razonables

- Persistencia (guardar/cargar proyectos en SQLite).
- Modo "esquinas" en vez de paredes (medir las dos diagonales para determinar ángulos no ortogonales automáticamente).
- Captura de fotos con anotaciones por pared.
- Soporte para más medidores (Leica Disto, Bosch GLM): cada uno con su parser; la abstracción `LaserBleService` está lista para extenderse.
- iOS: Flutter compila igual, solo hay que añadir permisos en `Info.plist` y firmar con Apple Developer.
