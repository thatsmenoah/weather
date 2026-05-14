import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:ui' as ui;

/// Усиленный прогрев шейдеров специально для Impeller
class ShaderWarmUp {
  static bool _isWarmedUp = false;

  static void enableShaderCapture() {
    if (kDebugMode) {
      PaintingBinding.instance.imageCache.maximumSizeBytes = 256 << 20; // 256 MB
    }
  }

  static Future<void> warmUpEssentialShaders(BuildContext context) async {
    if (_isWarmedUp) return;
    _isWarmedUp = true;

    await SchedulerBinding.instance.endOfFrame;
    if (!context.mounted) return;

    final overlay = Overlay.of(context);

    // 1. Базовые Material виджеты
    await _warmUpWidgets(overlay, context);

    // 2. Специфичный Impeller-прогрев (градиенты, тени, blur)
    await _warmUpImpellerSpecifics();

    // 3. Прогрев через SceneBuilder (самый низкоуровневый)
    await _warmUpSceneBuilder();
  }

  static Future<void> _warmUpWidgets(OverlayState overlay, BuildContext context) async {
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -2000,
        top: -2000,
        child: Opacity(
          opacity: 0.0,
          child: Material(
            child: SizedBox(
              width: 400,
              height: 400,
              child: Column(
                children: [
                  // Текст с тенями (буквы - сложный шейдер)
                  Text('Warming Up', style: Theme.of(context).textTheme.headlineSmall),
                  Text('Temperature 24°C', style: Theme.of(context).textTheme.titleLarge),
                  
                  // Иконки + градиент
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny, size: 40, color: Colors.orange),
                      const Icon(Icons.cloud, size: 40, color: Colors.blueGrey),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.blue, Colors.purple, Colors.red],
                            stops: [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // LinearProgressIndicator (использует сложный градиентный шейдер)
                  const SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(value: 0.7),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // CircularProgressIndicator (вращение + градиент)
                  const SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // ClipRRect + ImageFilter (Blur) - самое тяжелое для Impeller
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        width: 100,
                        height: 50,
                        color: Colors.teal.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    await Future.delayed(const Duration(milliseconds: 200));
    overlayEntry.remove();
  }

  /// Специфичные вещи, которые Impeller компилирует медленно
  static Future<void> _warmUpImpellerSpecifics() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(300, 300);

    // 1. Градиент с прозрачностью (Impeller долго компилирует alpha gradients)
    final gradientPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.transparent, Colors.blue, Colors.purple],
        stops: [0.0, 0.5, 1.0],
      ).createShader(const Rect.fromLTWH(0, 0, 300, 300));
    
    canvas.drawRect(const Rect.fromLTWH(0, 0, 300, 300), gradientPaint);

    // 2. Тень от сложного пути (Path shadow)
    final shadowPath = Path()
      ..moveTo(50, 150)
      ..quadraticBezierTo(150, 50, 250, 150)
      ..quadraticBezierTo(150, 250, 50, 150);
    
    canvas.drawShadow(shadowPath, Colors.black, 15.0, true);

    // 3. Размытый круг (blur filter)
    final blurPaint = Paint()
      ..color = Colors.orange
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    
    canvas.drawCircle(const Offset(150, 150), 60, blurPaint);

    // 4. SaveLayer (Impeller создает отдельный offscreen слой)
    canvas.saveLayer(const Rect.fromLTWH(0, 0, 300, 300), Paint());
    canvas.drawRect(const Rect.fromLTWH(50, 50, 100, 100), Paint()..color = Colors.red);
    canvas.drawRect(const Rect.fromLTWH(100, 100, 100, 100), Paint()..color = Colors.blue.withValues(alpha: 0.5));
    canvas.restore();

    final picture = recorder.endRecording();
    await picture.toImage(size.width.toInt(), size.height.toInt());
    picture.dispose();
  }

  /// Самый низкоуровневый прогрев через SceneBuilder
  static Future<void> _warmUpSceneBuilder() async {
    final sceneBuilder = ui.SceneBuilder();
    
    // Рисуем сложную иконку погоды
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    canvas.drawCircle(const Offset(50, 50), 30, Paint()..color = Colors.orange);
    canvas.drawPath(
      Path()
        ..moveTo(20, 80)
        ..quadraticBezierTo(50, 60, 80, 80),
      Paint()
        ..color = Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    
    final picture = recorder.endRecording();
    
    // Строим сцену с трансформациями
    sceneBuilder
      ..pushTransform(Matrix4.identity().storage)
      ..addPicture(Offset.zero, picture)
      ..pop();
    
    final scene = sceneBuilder.build();
    scene.dispose();
    picture.dispose();
  }

  static Future<void> hardWarmUpScroll(BuildContext context) async {
    if (!context.mounted) return;

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -3000,
        top: -3000,
        child: Opacity(
          opacity: 0.0,
          child: SizedBox(
            width: 400,
            height: 600,
            child: ListView.builder(
              itemCount: 30,
              itemBuilder: (context, index) {
                return Container(
                  height: 60,
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: index.isEven 
                          ? [Colors.blue.shade100, Colors.blue.shade300]
                          : [Colors.orange.shade100, Colors.orange.shade300],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(
                        index.isEven ? Icons.wb_sunny : Icons.cloud,
                        color: index.isEven ? Colors.orange : Colors.blueGrey,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Day $index: ${20 + index}°C',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    
    // Даем время на рендер всех элементов списка
    await Future.delayed(const Duration(milliseconds: 300));
    overlayEntry.remove();
  }
}

class ShaderWarmUpWidget extends StatefulWidget {
  final Widget child;

  const ShaderWarmUpWidget({super.key, required this.child});

  @override
  State<ShaderWarmUpWidget> createState() => _ShaderWarmUpWidgetState();
}

class _ShaderWarmUpWidgetState extends State<ShaderWarmUpWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await ShaderWarmUp.warmUpEssentialShaders(context);
        // Опционально: жесткий прогрев скроллом
        // await ShaderWarmUp.hardWarmUpScroll(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}