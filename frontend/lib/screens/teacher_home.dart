import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';
import 'session_detail_screen.dart';
import 'schedule_session_screen.dart';
import 'attendance_management_screen.dart';
import 'class_detail_screen.dart';

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

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});
  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
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
    final titles = ['Dashboard', 'Sessions', 'Messages', 'Profile'];
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          if (_tab == 1)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ScheduleSessionScreen(),
                ),
              ),
            ),
          if (_tab == 3)
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _TeacherDashboard(name: auth.name, email: auth.email),
          const _SessionsTab(),
          const MessagesScreen(),
          const ProfileScreen(),
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

class _TeacherDashboard extends StatefulWidget {
  final String name, email;
  const _TeacherDashboard({required this.name, required this.email});
  @override
  State<_TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<_TeacherDashboard> {
  List _sessions = [];
  List _classes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await ApiService.getSessions();
      final c = await ApiService.getClasses();
      setState(() {
        _sessions = (s['sessions'] ?? [])
            .where((s) => s['status'] != 'completed')
            .toList();
        _classes = c['classes'] ?? [];
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final active = _sessions.where((s) => s['status'] == 'active').toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile card
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
                        const SizedBox(height: 4),
                        Text(
                          widget.email,
                          style: const TextStyle(
                            color: AppColors.tealLight,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const StatusBadge(status: 'teacher'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats
            Row(
              children: [
                StatCard(
                  label: 'My Classes',
                  value: '${_classes.length}',
                  icon: Icons.class_,
                  color: AppColors.teal,
                ),
                const SizedBox(width: 10),
                StatCard(
                  label: 'Active Now',
                  value: '${active.length}',
                  icon: Icons.radio_button_checked,
                  color: AppColors.green,
                ),
                const SizedBox(width: 10),
                StatCard(
                  label: 'Scheduled',
                  value:
                      '${_sessions.where((s) => s['status'] == 'scheduled').length}',
                  icon: Icons.schedule,
                  color: AppColors.navy,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Manage Attendance button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AttendanceManagementScreen(),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  side: const BorderSide(color: AppColors.navy),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.how_to_reg, size: 18),
                label: const Text('Manage Attendance'),
              ),
            ),
            const SizedBox(height: 16),

            // Live sessions
            if (active.isNotEmpty) ...[
              const SectionHeader(title: 'Live Sessions'),
              const SizedBox(height: 10),
              ...active.map(
                (s) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.green.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.green, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.radio_button_checked,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['title'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              s['class_name'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const StatusBadge(status: 'active'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Classes
            SectionHeader(title: 'My Classes (${_classes.length})'),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              ..._classes.map(
                (c) => GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassDetailScreen(classData: c),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 6,
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
                                c['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${c['subject'] ?? ''}'
                                ' · ${c['student_count'] ?? 0} students',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textGray,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _SessionsTab extends StatefulWidget {
  const _SessionsTab();
  @override
  State<_SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<_SessionsTab> {
  List _sessions = [];
  List _filtered = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getSessions();
      _sessions = res['sessions'] ?? [];
      _applyFilter();
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _applyFilter() {
    setState(() {
      _filtered = _filter == 'all'
          ? List.from(_sessions)
          : _sessions.where((s) => s['status'] == _filter).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in ['all', 'scheduled', 'active', 'completed'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f == 'all' ? 'All' : f),
                      selected: _filter == f,
                      onSelected: (_) {
                        setState(() => _filter = f);
                        _applyFilter();
                      },
                      selectedColor: AppColors.teal.withAlpha(40),
                      checkmarkColor: AppColors.teal,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
              ? const Center(
                  child: Text(
                    'No sessions.',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final s = _filtered[i];
                    return _TeacherSessionCard(session: s, onRefresh: _load);
                  },
                ),
        ),
      ],
    );
  }
}

class _TeacherSessionCard extends StatelessWidget {
  final Map session;
  final VoidCallback onRefresh;
  const _TeacherSessionCard({required this.session, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final status = session['status'] ?? 'scheduled';
    final title = session['title'] ?? 'Untitled';
    final cls = session['class_name'] ?? '';
    final link = session['meeting_link'] ?? '';

    Color sc;
    switch (status) {
      case 'active':
        sc = AppColors.green;
        break;
      case 'completed':
        sc = AppColors.textGray;
        break;
      default:
        sc = AppColors.teal;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: status == 'active'
            ? Border.all(color: AppColors.green, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: sc.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                status == 'active'
                    ? Icons.radio_button_checked
                    : status == 'completed'
                    ? Icons.check_circle_outline
                    : Icons.schedule,
                color: sc,
                size: 22,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              cls,
              style: const TextStyle(fontSize: 12, color: AppColors.textGray),
            ),
            trailing: StatusBadge(status: status),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SessionDetailScreen(sessionId: session['id']),
              ),
            ),
          ),
          if (link.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.videocam_outlined,
                    size: 13,
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      link,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.teal,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (status != 'completed')
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  if (status == 'scheduled')
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          await ApiService.activateSession(session['id']);
                          onRefresh();
                        },
                        icon: const Icon(
                          Icons.play_arrow,
                          color: AppColors.green,
                          size: 18,
                        ),
                        label: const Text(
                          'Start',
                          style: TextStyle(color: AppColors.green),
                        ),
                      ),
                    ),
                  if (status == 'active')
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          await ApiService.closeSession(session['id']);
                          onRefresh();
                        },
                        icon: const Icon(
                          Icons.stop_circle_outlined,
                          color: AppColors.amber,
                          size: 18,
                        ),
                        label: const Text(
                          'Close',
                          style: TextStyle(color: AppColors.amber),
                        ),
                      ),
                    ),
                  Container(width: 1, height: 32, color: AppColors.divider),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        await ApiService.deleteSession(session['id']);
                        onRefresh();
                      },
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.red,
                        size: 18,
                      ),
                      label: const Text(
                        'Delete',
                        style: TextStyle(color: AppColors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
