import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/utils/app_theme.dart';

// import '../../providers/auth_provider.dart';
// import '../../services/api_service.dart';
// import '../../utils/app_theme.dart';
import 'student_home.dart';
import 'teacher_home.dart';

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

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});
  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  int _step = 0;
  // ignore: unused_field
  bool _loading = false;
  String _status = '';
  bool _success = false;
  File? _image;

  Future<void> _captureAndEnroll() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.front,
    );
    if (img == null) return;
    setState(() {
      _image = File(img.path);
      _loading = true;
      _status = 'Processing your face...';
      _step = 2;
    });
    try {
      // ignore: use_build_context_synchronously
      context.read<AuthProvider>();
      final res = await ApiService.enrollFace(_image!);
      if (!mounted) return;
      if (res['success'] == true || res['dims'] != null) {
        setState(() {
          _success = true;
          _status =
              'Face enrolled successfully!\n'
              'You can now mark attendance.';
          _loading = false;
          _step = 3;
        });
      } else {
        setState(() {
          _status =
              res['error'] ??
              'No face detected. Please try again in good lighting.';
          _loading = false;
          _step = 1;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Connection error. Make sure the server is running.';
        _loading = false;
        _step = 1;
      });
    }
  }

  void _proceed() {
    final auth = context.read<AuthProvider>();
    final role = auth.role;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            role == 'teacher' ? const TeacherHome() : const StudentHome(),
      ),
      (_) => false,
    );
  }

  void _skipForNow() {
    _proceed();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              SizedBox(height: 20),

              // Progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => Container(
                    width: i == (_step < 3 ? _step : 2) ? 24 : 8,
                    height: 8,
                    margin: EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: i <= (_step < 3 ? _step : 2)
                          ? AppColors.teal
                          : AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32),

              // Step content
              Expanded(child: _buildStep(auth)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(AuthProvider auth) {
    if (_step == 0) {
      return _StepWelcome(
        name: auth.name,
        role: auth.role,
        onNext: () => setState(() => _step = 1),
        onSkip: _skipForNow,
      );
    }

    if (_step == 1) {
      return _StepCapture(
        error: _status,
        onCapture: _captureAndEnroll,
        onSkip: _skipForNow,
      );
    }

    if (_step == 2) return _StepProcessing(image: _image);

    return _StepResult(
      success: _success,
      message: _status,
      image: _image,
      onDone: _proceed,
      onRetry: () => setState(() {
        _step = 1;
        _status = '';
        _success = false;
      }),
    );
  }
}

class _StepWelcome extends StatelessWidget {
  final String name, role;
  final VoidCallback onNext, onSkip;
  const _StepWelcome({
    required this.name,
    required this.role,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.navy.withAlpha(15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.teal, width: 2),
          ),
          child: Icon(
            Icons.face_retouching_natural,
            color: AppColors.navy,
            size: 60,
          ),
        ),
        SizedBox(height: 24),
        Text(
          'Welcome, $name!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.navy,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 12),
        Text(
          'Before you start, please enrol your face.\n'
          'This allows FaceAttend to verify your '
          'identity when marking attendance.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textGray,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 32),

        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.teal.withAlpha(15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              _tip(Icons.light_mode_outlined, 'Find a well-lit area'),
              _tip(Icons.face_outlined, 'Look directly at the camera'),
              _tip(Icons.no_photography_outlined, 'Remove sunglasses or hat'),
            ],
          ),
        ),
        SizedBox(height: 32),

        AppButton(
          label: 'Enrol My Face Now',
          onPressed: onNext,
          icon: Icons.camera_alt_outlined,
          color: AppColors.navy,
        ),
        SizedBox(height: 12),
        TextButton(
          onPressed: onSkip,
          child: Text(
            'Skip for now',
            style: TextStyle(color: AppColors.textGray),
          ),
        ),
      ],
    );
  }

  Widget _tip(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.teal, size: 20),
          SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 13, color: AppColors.textDark)),
        ],
      ),
    );
  }
}

class _StepCapture extends StatelessWidget {
  final String error;
  final VoidCallback onCapture, onSkip;
  const _StepCapture({
    required this.error,
    required this.onCapture,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: AppColors.bgGray,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.teal, width: 3),
          ),
          child: Icon(
            Icons.camera_alt_outlined,
            color: AppColors.teal,
            size: 70,
          ),
        ),
        SizedBox(height: 24),
        Text(
          'Take a clear selfie',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.navy,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Position your face in the centre\n'
          'and ensure good lighting.',
          style: TextStyle(fontSize: 14, color: AppColors.textGray),
          textAlign: TextAlign.center,
        ),
        if (error.isNotEmpty) ...[
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.red.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              error,
              style: TextStyle(color: AppColors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        SizedBox(height: 32),
        AppButton(
          label: 'Open Camera',
          onPressed: onCapture,
          icon: Icons.camera_front,
          color: AppColors.teal,
        ),
        SizedBox(height: 12),
        TextButton(
          onPressed: onSkip,
          child: Text(
            'Skip for now',
            style: TextStyle(color: AppColors.textGray),
          ),
        ),
      ],
    );
  }
}

class _StepProcessing extends StatelessWidget {
  final File? image;
  const _StepProcessing({this.image});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (image != null)
          ClipOval(
            child: Image.file(
              image!,
              width: 160,
              height: 160,
              fit: BoxFit.cover,
            ),
          ),
        SizedBox(height: 32),
        CircularProgressIndicator(color: AppColors.teal, strokeWidth: 3),
        SizedBox(height: 24),
        Text(
          'Enrolling your face...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'This may take a few seconds.',
          style: TextStyle(color: AppColors.textGray),
        ),
      ],
    );
  }
}

class _StepResult extends StatelessWidget {
  final bool success;
  final String message;
  final File? image;
  final VoidCallback onDone, onRetry;
  const _StepResult({
    required this.success,
    required this.message,
    this.image,
    required this.onDone,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            if (image != null)
              ClipOval(
                child: Image.file(
                  image!,
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: success
                      ? AppColors.green.withAlpha(20)
                      : AppColors.red.withAlpha(20),
                  shape: BoxShape.circle,
                ),
              ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: success ? AppColors.green : AppColors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                success ? Icons.check : Icons.close,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
        Text(
          success ? 'Enrolled!' : 'Try Again',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: success ? AppColors.green : AppColors.red,
          ),
        ),
        SizedBox(height: 12),
        Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textGray,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 32),
        if (success)
          AppButton(
            label: 'Go to Dashboard',
            onPressed: onDone,
            icon: Icons.arrow_forward,
            color: AppColors.green,
          )
        else ...[
          AppButton(
            label: 'Try Again',
            onPressed: onRetry,
            icon: Icons.refresh,
            color: AppColors.teal,
          ),
          SizedBox(height: 12),
          TextButton(
            onPressed: onDone,
            child: Text(
              'Skip for now',
              style: TextStyle(color: AppColors.textGray),
            ),
          ),
        ],
      ],
    );
  }
}
