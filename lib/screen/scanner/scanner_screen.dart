import 'dart:math' as math;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../data/model/barcode_data.dart';
import '../../providers/scanner_provider.dart';
import '../../service/shared_preferences_service.dart';
import '../../theme/app_colors.dart';
import '../barcode/barcode_detail_screen.dart';
import '../barcode/barcode_ui.dart';
import '../barcode/widgets/barcode_form.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController cameraController = MobileScannerController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _checkPermission();
  }

  Future<void> _checkPermission() async {
    var status = await Permission.camera.status;

    if (status.isGranted) {
      if (!mounted) return;
      context.read<ScannerProvider>().setPermission(true);
      FirebaseAnalytics.instance.logEvent(name: "camera_permission_granted");
    } else {
      var result = await Permission.camera.request();
      if (result.isGranted) {
        if (!mounted) return;
        context.read<ScannerProvider>().setPermission(true);
        FirebaseAnalytics.instance.logEvent(name: "camera_permission_granted");
      } else if (result.isPermanentlyDenied) {
        if (mounted) {
          BarcodeUi.showCameraPermissionDialog(context);
        }
      }
    }
  }

  Future<void> _handleScanResult(String code) async {
    final list = await SharedPreferencesService().getBarcodes();

    if (!mounted) return;

    BarcodeData? found;

    FirebaseAnalytics.instance.logEvent(name: "barcode_scanned");

    for (final b in list) {
      if (b.code == code) {
        found = b;
        break;
      }
    }

    if (!mounted) return;

    FirebaseAnalytics.instance.logEvent(
      name: "barcode_scan_result",
      parameters: {"found": found != null},
    );
    if (found != null) {
      final result = await Navigator.push<bool?>(
        context,
        MaterialPageRoute(builder: (_) => BarcodeDetailScreen(barcode: found!)),
      );
      await _afterSubRoutePop(result, popScannerIf: (r) => r == true);
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BarcodeForm(type: 'code128', initialCode: code),
        ),
      );
      await _afterSubRoutePop(result, popScannerIf: (r) => r != null);
    }
  }

  Future<void> _afterSubRoutePop(
    Object? result, {
    required bool Function(Object? result) popScannerIf,
  }) async {
    if (!mounted) return;
    if (popScannerIf(result)) {
      Navigator.pop(context, true);
    } else {
      await _resumeScannerAfterSubScreen();
    }
  }

  Future<void> _resumeScannerAfterSubScreen() async {
    if (!mounted) return;
    context.read<ScannerProvider>().resetScan();
    try {
      await cameraController.start();
    } catch (_) {}
  }

  @override
  void dispose() {
    _animationController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scannerProvider = context.watch<ScannerProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: !scannerProvider.hasPermission
          ? const SafeArea(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) async {
                    final List<Barcode> barcodes = capture.barcodes;

                    if (barcodes.isEmpty) return;

                    final scanner = context.read<ScannerProvider>();
                    if (scanner.isScanned) return;

                    final String code = barcodes.first.rawValue ?? "";
                    if (code.isEmpty) return;

                    scanner.markScanned();

                    try {
                      await cameraController.stop();
                    } catch (_) {}

                    if (!context.mounted) return;

                    await _handleScanResult(code);
                  },
                ),

                _buildScannerOverlay(context),

                Positioned(
                  top: MediaQuery.of(context).padding.top + 15,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      LEDCornerWrapper(
                        animation: _animationController,
                        isCircle: true,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      LEDCornerWrapper(
                        animation: _animationController,
                        isCircle: false,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: const Text(
                            "Scan Barcode",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: cameraController,
                        builder: (context, state, child) {
                          final isOn = state.torchState == TorchState.on;
                          return LEDCornerWrapper(
                            animation: _animationController,
                            isCircle: true,
                            child: IconButton(
                              icon: Icon(
                                isOn ? Icons.flash_on : Icons.flash_off,
                                color: isOn ? Colors.yellow : Colors.white,
                              ),
                              onPressed: () => cameraController.toggleTorch(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.7;
    return Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(size, size),
                painter: ScannerLEDCornerPainter(
                  animationValue: _animationController.value,
                  baseColor: AppColors.primary,
                  ledColor: Colors.white,
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          minimum: EdgeInsets.zero,
          child: Align(
            alignment: const Alignment(0, 0.4),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.45),
                ),
              ),
              child: const Text(
                'Posisikan barcode di dalam kotak',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LEDCornerWrapper extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final bool isCircle;

  const LEDCornerWrapper({
    super.key,
    required this.child,
    required this.animation,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          painter: LEDBorderPainter(
            animationValue: animation.value,
            isCircle: isCircle,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircle ? null : BorderRadius.circular(20),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class LEDBorderPainter extends CustomPainter {
  final double animationValue;
  final bool isCircle;

  LEDBorderPainter({required this.animationValue, required this.isCircle});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [AppColors.primary, Colors.white, AppColors.primary],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(animationValue * 2 * math.pi),
      ).createShader(rect);

    if (isCircle) {
      canvas.drawCircle(size.center(Offset.zero), size.width / 2, paint);
    } else {
      final RRect rrect = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(20),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LEDBorderPainter oldDelegate) => true;
}

class ScannerLEDCornerPainter extends CustomPainter {
  final double animationValue;
  final Color baseColor;
  final Color ledColor;

  ScannerLEDCornerPainter({
    required this.animationValue,
    required this.baseColor,
    required this.ledColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double radius = 24.0;
    const double cornerLength = 60.0;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [baseColor, ledColor, baseColor],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(animationValue * 2 * math.pi),
      ).createShader(rect);

    final path = Path();

    path.moveTo(0, cornerLength);
    path.lineTo(0, radius);
    path.arcToPoint(
      const Offset(radius, 0),
      radius: const Radius.circular(radius),
    );
    path.lineTo(cornerLength, 0);

    path.moveTo(size.width - cornerLength, 0);
    path.lineTo(size.width - radius, 0);
    path.arcToPoint(
      Offset(size.width, radius),
      radius: const Radius.circular(radius),
    );
    path.lineTo(size.width, cornerLength);

    path.moveTo(size.width, size.height - cornerLength);
    path.lineTo(size.width, size.height - radius);
    path.arcToPoint(
      Offset(size.width - radius, size.height),
      radius: const Radius.circular(radius),
    );
    path.lineTo(size.width - cornerLength, size.height);

    path.moveTo(cornerLength, size.height);
    path.lineTo(radius, size.height);
    path.arcToPoint(
      Offset(0, size.height - radius),
      radius: const Radius.circular(radius),
    );
    path.lineTo(0, size.height - cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
