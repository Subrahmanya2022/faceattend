import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// ignore: unused_import
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/utils/app_theme.dart';
import 'package:permission_handler/permission_handler.dart';
// import '../../services/api_service.dart';
// import '../../utils/app_theme.dart';

class AppColors {
  static const navy = Color(0xFF1A237E);
  static const teal = Color(0xFF00897B);
  static const tealLight = Color(0xFF80CBC4);
  static const amber = Color(0xFFF57C00);
  static const red = Color(0xFFD32F2F);
  static const green = Color(0xFF2E7D32);
  static const bgGray = Color(0xFFF5F5F5);
  static const white = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF212121);
  static const textGray = Color(0xFF757575);
  static const cardBg = Color(0xFFFFFFFF);
  static const divider = Color(0xFFE0E0E0);
}

class FaceScanScreen extends StatefulWidget {
  final int sessionId;
  final int userId;
  final VoidCallback onSuccess;
  const FaceScanScreen({
    super.key,
    required this.sessionId,
    required this.userId,
    required this.onSuccess,
  });
  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  String _status = 'scanning';
  String _message = 'Position your face in the circle';
  // ignore: unused_field
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: Duration(seconds: 2))
      ..repeat();
    _startScan();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<void> _startScan() async {
    await Future.delayed(Duration(seconds: 1));
    setState(() {
      _status = 'detected';
      _message = 'Face detected — verifying...';
    });
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (img == null) {
      setState(() {
        _status = 'failed';
        _message = 'No image captured. Try again.';
      });
      return;
    }
    try {
      final res = await ApiService.markAttendance(
        File(img.path),
        widget.userId,
        widget.sessionId,
      );
      if (!mounted) return;
      if (res['marked'] == true) {
        _animCtrl.stop();
        setState(() {
          _status = 'success';
          _message = res['status'] == 'present'
              ? 'Verified! Attendance marked as Present.'
              : 'Face not matched. Marked as Absent.';
          _done = true;
        });
        await Future.delayed(Duration(seconds: 2));
        if (mounted) widget.onSuccess();
      } else {
        setState(() {
          _status = 'failed';
          _message = res['error'] ?? 'Verification failed';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'failed';
        _message = 'Connection error. Try again.';
      });
    }
  }

  Color get _statusColor {
    switch (_status) {
      case 'success':
        return AppColors.green;
      case 'failed':
        return AppColors.red;
      case 'detected':
        return Colors.orange;
      default:
        return AppColors.textGray;
    }
  }

  IconData get _statusIcon {
    switch (_status) {
      case 'success':
        return Icons.check_circle;
      case 'failed':
        return Icons.cancel;
      default:
        return Icons.face;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('Face Scan'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Spacer(),

          // Animated circle
          AnimatedBuilder(
            animation: _animCtrl,
            builder: (_, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _statusColor.withAlpha(
                          _status == 'scanning'
                              ? (50 + (_animCtrl.value * 100).toInt())
                              : 200,
                        ),
                        width: 3,
                      ),
                    ),
                  ),
                  // Corner brackets
                  if (_status == 'scanning') ..._brackets(),
                  // Center icon
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(15),
                      border: Border.all(color: _statusColor, width: 2),
                    ),
                    child: Icon(_statusIcon, color: _statusColor, size: 80),
                  ),
                ],
              );
            },
          ),

          SizedBox(height: 32),

          // Status text
          Text(
            _message,
            style: TextStyle(
              color: _statusColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 12),

          // Sub status
          Text(
            _status == 'scanning'
                ? 'Scanning...'
                : _status == 'detected'
                ? 'Processing...'
                : _status == 'success'
                ? 'Complete!'
                : _status == 'failed'
                ? 'Failed'
                : '',
            style: TextStyle(color: _statusColor.withAlpha(180), fontSize: 13),
          ),

          Spacer(),

          if (_status == 'failed')
            Padding(
              padding: EdgeInsets.all(24),
              child: AppButton(
                label: 'Try Again',
                onPressed: () {
                  setState(() {
                    _status = 'scanning';
                    _message = 'Position your face in the circle';
                  });
                  _animCtrl.repeat();
                  _startScan();
                },
                color: AppColors.teal,
              ),
            ),

          SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _brackets() {
    return [
      Positioned(top: 40, left: 40, child: _bracket(true, true)),
      Positioned(top: 40, right: 40, child: _bracket(true, false)),
      Positioned(bottom: 40, left: 40, child: _bracket(false, true)),
      Positioned(bottom: 40, right: 40, child: _bracket(false, false)),
    ];
  }

  Widget _bracket(bool top, bool left) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(
        painter: _BracketPainter(top: top, left: left, color: AppColors.teal),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final bool top, left;
  final Color color;
  const _BracketPainter({
    required this.top,
    required this.left,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    if (top && left) {
      path.moveTo(0, 20);
      path.lineTo(0, 0);
      path.lineTo(20, 0);
    } else if (top && !left) {
      path.moveTo(size.width - 20, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, 20);
    } else if (!top && left) {
      path.moveTo(0, size.height - 20);
      path.lineTo(0, size.height);
      path.lineTo(20, size.height);
    } else {
      path.moveTo(size.width - 20, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, size.height - 20);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
