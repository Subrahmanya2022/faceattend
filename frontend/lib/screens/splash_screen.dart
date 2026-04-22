import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/auth_provider.dart';
// ignore: unused_import
import 'package:frontend/services/api_service.dart';
// ignore: unused_import
import 'package:frontend/utils/app_theme.dart';

// import '../../providers/auth_provider.dart';
// import '../../utils/app_theme.dart';
import 'login_screen.dart';
import 'student_home.dart';
import 'teacher_home.dart';
import 'admin_home.dart';
import 'superadmin_home.dart';

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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Duration(seconds: 2));
    _progress = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    _ctrl.forward();
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(Duration(seconds: 2));
    if (!mounted) return;
    await context.read<AuthProvider>().loadFromStorage();
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    Widget next;
    if (!auth.isLoggedIn) {
      next = LoginScreen();
    } else {
      switch (auth.role) {
        case 'superadmin':
          next = SuperAdminHome();
          break;
        case 'admin':
          next = AdminHome();
          break;
        case 'teacher':
          next = TeacherHome();
          break;
        default:
          next = StudentHome();
      }
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(),
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.tealLight, width: 2),
              ),
              child: Icon(
                Icons.face_retouching_natural,
                color: AppColors.tealLight,
                size: 56,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'FaceAttend',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Smart Attendance. Powered by AI.',
              style: TextStyle(color: AppColors.tealLight, fontSize: 14),
            ),
            Spacer(),
            Padding(
              padding: EdgeInsets.fromLTRB(40, 0, 40, 48),
              child: AnimatedBuilder(
                animation: _progress,
                builder: (_, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _progress.value,
                    minHeight: 4,
                    // ignore: deprecated_member_use
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(AppColors.tealLight),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
