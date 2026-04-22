import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';
import 'messages_screen.dart';

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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _changingPass = false;
  final _newPass = TextEditingController();
  final _confPass = TextEditingController();
  bool _loadingPass = false;
  String? _passError;
  String? _passSuccess;

  void _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _openHelpSupport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewMessageSheet(
        onSent: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Help request sent!'),
              backgroundColor: AppColors.green,
            ),
          );
        },
      ),
    );
  }

  Future<void> _changePassword() async {
    if (_newPass.text != _confPass.text) {
      setState(() => _passError = 'Passwords do not match');
      return;
    }
    if (_newPass.text.length < 6) {
      setState(() => _passError = 'Minimum 6 characters required');
      return;
    }
    setState(() {
      _loadingPass = true;
      _passError = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final res = await ApiService.updatePassword(
        auth.userId,
        _newPass.text.trim(),
      );
      if (!mounted) return;
      if (res['user'] != null) {
        setState(() {
          _passSuccess = 'Password changed successfully!';
          _changingPass = false;
          _loadingPass = false;
        });
        _newPass.clear();
        _confPass.clear();
      } else {
        setState(() {
          _passError = res['error'] ?? 'Failed';
          _loadingPass = false;
        });
      }
    } catch (e) {
      setState(() {
        _passError = 'Connection error';
        _loadingPass = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                AvatarCircle(name: auth.name, size: 80, color: AppColors.teal),
                const SizedBox(height: 14),
                Text(
                  auth.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.email,
                  style: const TextStyle(
                    color: AppColors.tealLight,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                StatusBadge(status: auth.role),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Success message
          if (_passSuccess != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _passSuccess!,
                      style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Settings card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6),
              ],
            ),
            child: Column(
              children: [
                // Change password
                _item(
                  icon: Icons.lock_outline,
                  label: 'Change Password',
                  color: AppColors.navy,
                  onTap: () => setState(() {
                    _changingPass = !_changingPass;
                    _passError = null;
                    _passSuccess = null;
                  }),
                  trailing: Icon(
                    _changingPass ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textGray,
                  ),
                ),

                if (_changingPass)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _newPass,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: Icon(Icons.lock_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _confPass,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: Icon(Icons.lock_outlined),
                          ),
                        ),
                        if (_passError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _passError!,
                            style: const TextStyle(
                              color: AppColors.red,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _loadingPass ? null : _changePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _loadingPass
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Update Password',
                                    style: TextStyle(color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                _divider(),

                // Help and support
                _item(
                  icon: Icons.help_outline,
                  label: 'Help & Support',
                  color: AppColors.amber,
                  subtitle: 'Send a message to your admin',
                  onTap: _openHelpSupport,
                ),

                _divider(),

                // Logout
                _item(
                  icon: Icons.logout,
                  label: 'Logout',
                  color: AppColors.red,
                  onTap: _logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'FaceAttend v1.0.0',
            style: TextStyle(fontSize: 11, color: AppColors.textGray),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? subtitle,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color == AppColors.red ? AppColors.red : AppColors.textDark,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 11))
          : null,
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right,
            color: color == AppColors.red ? AppColors.red : AppColors.textGray,
          ),
      onTap: onTap,
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 64, color: AppColors.divider);
}
