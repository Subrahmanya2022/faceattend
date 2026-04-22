import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';
// ignore: unused_import
import 'profile_screen.dart';
import 'messages_screen.dart';
import 'notifications_screen.dart';
import 'student_sessions_screen.dart';
import 'attendance_history_screen.dart';
import 'face_scan_screen.dart';
import 'student_profile_screen.dart';

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

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});
  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int _tab = 0;

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
    final auth = context.watch<AuthProvider>();
    final titles = ['Dashboard', 'Sessions', 'History', 'Messages', 'Profile'];
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          if (_tab == 0)
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
          if (_tab == 4)
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _StudentDashboard(userId: auth.userId, name: auth.name),
          StudentSessionsScreen(userId: auth.userId),
          AttendanceHistoryScreen(userId: auth.userId),
          const MessagesScreen(),
          const StudentProfileScreen(key: ValueKey('student_profile')),
          // ProfileScreen(key: const ValueKey('student_profile')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.message_outlined),
            selectedIcon: Icon(Icons.message),
            label: 'Messages',
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

class _StudentDashboard extends StatefulWidget {
  final int userId;
  final String name;
  const _StudentDashboard({required this.userId, required this.name});
  @override
  State<_StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<_StudentDashboard> {
  Map _data = {};
  List _sessions = [];
  // ignore: unused_field
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await ApiService.getStudentDashboard(widget.userId);
      final s = await ApiService.getSessions();
      setState(() {
        _data = d;
        _sessions = (s['sessions'] ?? [])
            .where((s) => s['status'] == 'active')
            .toList();
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final pct = _data['attendancePct'] ?? 0;
    final warn = _data['warning'] ?? false;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  AvatarCircle(
                    name: widget.name,
                    size: 52,
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const StatusBadge(status: 'student'),
                      ],
                    ),
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(
                          value: pct / 100,
                          strokeWidth: 6,
                          backgroundColor: Colors.white.withAlpha(40),
                          valueColor: AlwaysStoppedAnimation(
                            pct >= 75 ? AppColors.tealLight : Colors.orange,
                          ),
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (warn)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withAlpha(100)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Attendance below 75% — you are at risk!',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                StatCard(
                  label: 'Total',
                  value: '${_data['totalClasses'] ?? 0}',
                  icon: Icons.class_,
                  color: AppColors.navy,
                ),
                const SizedBox(width: 10),
                StatCard(
                  label: 'Present',
                  value: '${_data['present'] ?? 0}',
                  icon: Icons.check_circle_outline,
                  color: AppColors.green,
                ),
                const SizedBox(width: 10),
                StatCard(
                  label: 'Absent',
                  value: '${_data['absent'] ?? 0}',
                  icon: Icons.cancel_outlined,
                  color: AppColors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_sessions.isNotEmpty) ...[
              const SectionHeader(title: 'Active Sessions — Mark Now'),
              const SizedBox(height: 10),
              ..._sessions.map(
                (s) => _ActiveSessionCard(
                  session: s,
                  userId: widget.userId,
                  onDone: _load,
                ),
              ),
              const SizedBox(height: 16),
            ],

            if ((_data['byClass'] as List? ?? []).isNotEmpty) ...[
              const SectionHeader(title: 'My Classes'),
              const SizedBox(height: 10),
              ...(_data['byClass'] as List).map(
                (c) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.teal.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.class_,
                          color: AppColors.teal,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c['class_name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              c['subject'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${c['attendance_pct'] ?? 0}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              (int.tryParse(
                                        c['attendance_pct']?.toString() ?? '0',
                                      ) ??
                                      0) >=
                                  75
                              ? AppColors.green
                              : AppColors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  final Map session;
  final int userId;
  final VoidCallback onDone;
  const _ActiveSessionCard({
    required this.session,
    required this.userId,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final alreadyMarked = session['my_status'] != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.green.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.radio_button_checked,
              color: AppColors.green,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session['title'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  session['class_name'] ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ),
          if (alreadyMarked)
            StatusBadge(status: session['my_status'])
          else
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FaceScanScreen(
                    sessionId: session['id'],
                    userId: userId,
                    onSuccess: () {
                      onDone();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              child: const Text('Scan Face', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
