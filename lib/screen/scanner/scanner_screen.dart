import 'dart:math' as math;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/model/barcode_data.dart';
import '../../service/shared_preferences_service.dart';
import '../barcode/barcode_detail_screen.dart';
import '../barcode/widgets/barcode_form.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController cameraController = MobileScannerController();
  bool isScanned = false;
  bool hasPermission = false;
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
      setState(() => hasPermission = true);
    } else {
      var result = await Permission.camera.request();
      if (result.isGranted) {
        setState(() => hasPermission = true);
      } else if (result.isPermanentlyDenied) {
        if (mounted) {
          _showPermissionDialog();
        }
      }
    }

    FirebaseAnalytics.instance.logEvent(name: "camera_permission_granted");
  }

  Future<void> _handleScanResult(String code) async {
    final list = await SharedPreferencesService().getBarcodes();

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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BarcodeDetailScreen(barcode: found!)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BarcodeForm(type: 'code128', initialCode: code),
        ),
      );
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Izin Kamera Diperlukan"),
        content: const Text(
          "Aplikasi membutuhkan akses kamera untuk melakukan scan. Silakan aktifkan di pengaturan.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text("Buka Pengaturan"),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    isScanned = false;
  }

  @override
  void dispose() {
    _animationController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: !hasPermission
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF009688)),
            )
          : Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) async {
                    final List<Barcode> barcodes = capture.barcodes;

                    if (barcodes.isNotEmpty && !isScanned) {
                      isScanned = true;

                      final String code = barcodes.first.rawValue ?? "";

                      await _handleScanResult(code);
                    }
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
                  baseColor: const Color(0xFF009688),
                  ledColor: Colors.white,
                ),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(size, size),
                painter: ScannerLEDCornerPainter(
                  animationValue: _animationController.value,
                  baseColor: const Color(0xFF009688),
                  ledColor: Colors.white,
                ),
              );
            },
          ),
        ),
        const Align(
          alignment: Alignment(0, 0.4),
          child: Text(
            "Posisikan barcode di dalam kotak",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
        colors: [
          const Color(0xFF009688),
          Colors.white,
          const Color(0xFF009688),
        ],
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
