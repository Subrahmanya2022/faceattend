import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';
import 'notifications_screen.dart';
import 'manage_users_screen.dart';
import 'manage_classes_screen.dart';
import 'invite_user_screen.dart';
import 'attendance_management_screen.dart';

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

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;
  Map _dashboard = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getAdminDashboard();
      setState(() => _dashboard = res);
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Admin Panel', 'Messages', 'Notifications', 'Profile'];
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          if (_tab == 0)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          if (_tab == 3)
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _AdminDashboardTab(
            dashboard: _dashboard,
            loading: _loading,
            onRefresh: _load,
          ),
          const MessagesScreen(),
          const NotificationsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.message_outlined),
            selectedIcon: Icon(Icons.message),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _AdminDashboardTab extends StatelessWidget {
  final Map dashboard;
  final bool loading;
  final Future<void> Function() onRefresh;
  const _AdminDashboardTab({
    required this.dashboard,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!loading)
              Row(
                children: [
                  StatCard(
                    label: 'Users',
                    value: '${dashboard['totalUsers'] ?? 0}',
                    icon: Icons.people,
                    color: AppColors.navy,
                  ),
                  const SizedBox(width: 10),
                  StatCard(
                    label: 'Students',
                    value: '${dashboard['totalStudents'] ?? 0}',
                    icon: Icons.school,
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 10),
                  StatCard(
                    label: 'Attendance',
                    value: '${dashboard['attendancePct'] ?? 0}%',
                    icon: Icons.check_circle_outline,
                    color: AppColors.green,
                  ),
                ],
              ),
            const SizedBox(height: 16),

            const SectionHeader(title: 'Quick Actions'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: [
                _tile(
                  context,
                  Icons.person_add_outlined,
                  'Invite Teacher',
                  AppColors.teal,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InviteUserScreen(role: 'teacher'),
                    ),
                  ),
                ),
                _tile(
                  context,
                  Icons.school_outlined,
                  'Invite Student',
                  AppColors.navy,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InviteUserScreen(role: 'student'),
                    ),
                  ),
                ),
                _tile(
                  context,
                  Icons.people_outline,
                  'Manage Users',
                  AppColors.amber,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManageUsersScreen(),
                    ),
                  ),
                ),
                _tile(
                  context,
                  Icons.class_outlined,
                  'Manage Classes',
                  AppColors.green,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManageClassesScreen(),
                    ),
                  ),
                ),
                _tile(
                  context,
                  Icons.how_to_reg,
                  'Attendance',
                  AppColors.red,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AttendanceManagementScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if ((dashboard['topAbsent'] as List? ?? []).isNotEmpty) ...[
              const SectionHeader(title: 'Top Absent Students'),
              const SizedBox(height: 10),
              ...((dashboard['topAbsent'] as List).map(
                (s) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      AvatarCircle(
                        name: s['name'] ?? '',
                        size: 38,
                        color: AppColors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              s['email'] ?? '',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.red.withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${s['absences']} absent',
                          style: const TextStyle(
                            color: AppColors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
