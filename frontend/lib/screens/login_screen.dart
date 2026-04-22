// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/auth_provider.dart';
// ignore: unused_import
import 'package:frontend/services/api_service.dart';
import 'package:frontend/utils/app_theme.dart';
// import '../../providers/auth_provider.dart';
// import '../../utils/app_theme.dart';
// ignore: unused_import
import 'student_home.dart';
// ignore: unused_import
import 'teacher_home.dart';
import 'admin_home.dart';
import 'superadmin_home.dart';
import 'face_enrollment_screen.dart';
import 'forgot_password_screen.dart';

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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  Future<void> _login() async {
    final ok = await context.read<AuthProvider>().login(
      _emailCtrl.text.trim(),
      _passCtrl.text.trim(),
    );
    if (!ok || !mounted) return;
    final auth = context.read<AuthProvider>();
    final role = auth.role;

    // Superadmin and admin go directly to dashboard
    if (role == 'superadmin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SuperAdminHome()),
      );
      return;
    }
    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminHome()),
      );
      return;
    }

    // Teacher goes directly to dashboard — no face enrollment needed
    if (role == 'teacher') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TeacherHome()),
      );
      return;
    }

    // Student — check if face is already enrolled
    if (role == 'student') {
      try {
        final status = await ApiService.getFaceStatus();
        if (!mounted) return;
        if (status['enrolled'] == true) {
          // Already enrolled — go to dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StudentHome()),
          );
        } else {
          // First time — show face enrollment
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()),
          );
        }
      } catch (e) {
        // On error go to dashboard anyway
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StudentHome()),
        );
      }
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const StudentHome()),
    );
  }

  // Future<void> _login() async {
  //   final ok = await context.read<AuthProvider>().login(
  //     _emailCtrl.text.trim(),
  //     _passCtrl.text.trim(),
  //   );
  //   if (!ok || !mounted) return;
  //   final auth = context.read<AuthProvider>();
  //   final role = auth.role;

  //   // Superadmin and admin go directly to dashboard
  //   if (role == 'superadmin' || role == 'admin') {
  //     Widget next = role == 'superadmin' ? SuperAdminHome() : AdminHome();
  //     Navigator.pushReplacement(
  //       context,
  //       MaterialPageRoute(builder: (_) => next),
  //     );
  //     return;
  //   }

  //   // Teacher and student go to face enrollment first
  //   Navigator.pushReplacement(
  //     context,
  //     MaterialPageRoute(builder: (_) => FaceEnrollmentScreen()),
  //   );
  // }

  // Future<void> _login() async {
  //   final ok = await context.read<AuthProvider>().login(
  //     _emailCtrl.text.trim(),
  //     _passCtrl.text.trim(),
  //   );
  //   if (!ok || !mounted) return;
  //   final role = context.read<AuthProvider>().role;
  //   Widget next;
  //   switch (role) {
  //     case 'superadmin': next = const SuperAdminHome(); break;
  //     case 'admin':      next = const AdminHome();      break;
  //     case 'teacher':    next = const TeacherHome();    break;
  //     default:           next = const StudentHome();
  //   }
  //   Navigator.pushReplacement(context,
  //     MaterialPageRoute(builder: (_) => next));
  // }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 48),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.tealLight,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.face_retouching_natural,
                        color: AppColors.tealLight,
                        size: 42,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'FaceAttend',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Smart Attendance. Powered by AI.',
                      style: TextStyle(
                        color: AppColors.tealLight,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    SizedBox(height: 8),
                    if (auth.error != null)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppColors.red,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                auth.error!,
                                style: TextStyle(
                                  color: AppColors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(color: AppColors.textGray),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    AppButton(
                      label: 'Login',
                      loading: auth.loading,
                      onPressed: _login,
                      icon: Icons.login,
                    ),
                    SizedBox(height: 24),

                    Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.teal.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.teal,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Contact your admin to create an account. '
                              'You will receive an email with login credentials.',
                              style: TextStyle(
                                color: AppColors.teal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.teal.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.teal,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Want to Register as New Admin of an Organisation?'
                              'Contact shegde28@gmail.com',
                              style: TextStyle(
                                color: AppColors.teal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
