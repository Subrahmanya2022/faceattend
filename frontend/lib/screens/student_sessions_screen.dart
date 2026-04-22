import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// ignore: unused_import
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/utils/app_theme.dart';

// import '../../services/api_service.dart';
// import '../../utils/app_theme.dart';
import 'face_scan_screen.dart' hide AppColors;

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

class StudentSessionsScreen extends StatefulWidget {
  final int userId;
  const StudentSessionsScreen({super.key, required this.userId});
  @override
  State<StudentSessionsScreen> createState() => _StudentSessionsScreenState();
}

class _StudentSessionsScreenState extends State<StudentSessionsScreen> {
  List _sessions = [];
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
      setState(() => _sessions = res['sessions'] ?? []);
    } catch (_) {}
    setState(() => _loading = false);
  }

  List get _filtered {
    switch (_filter) {
      case 'active':
        return _sessions.where((s) => s['status'] == 'active').toList();
      case 'scheduled':
        return _sessions.where((s) => s['status'] == 'scheduled').toList();
      case 'completed':
        return _sessions.where((s) => s['status'] == 'completed').toList();
      default:
        return _sessions;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in ['all', 'active', 'scheduled', 'completed'])
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f == 'all' ? 'All' : f),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: AppColors.teal.withAlpha(40),
                      checkmarkColor: AppColors.teal,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 56,
                          color: AppColors.textGray,
                        ),
                        SizedBox(height: 12),
                        Text(
                          _filter == 'active'
                              ? 'No active sessions right now.'
                              : 'No sessions found.',
                          style: TextStyle(color: AppColors.textGray),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final s = _filtered[i];
                      return _StudentSessionCard(
                        session: s,
                        userId: widget.userId,
                        onDone: _load,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _StudentSessionCard extends StatelessWidget {
  final Map session;
  final int userId;
  final VoidCallback onDone;
  const _StudentSessionCard({
    required this.session,
    required this.userId,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final status = session['status'] ?? 'scheduled';
    final title = session['title'] ?? '';
    final cls = session['class_name'] ?? '';
    final subject = session['subject'] ?? '';
    final myStatus = session['my_status'];
    final link = session['meeting_link'] ?? '';
    final schedAt = session['scheduled_at'];
    final fmt = schedAt != null
        ? DateFormat(
            'MMM d, yyyy · h:mm a',
          ).format(DateTime.parse(schedAt).toLocal())
        : '';

    final isActive = status == 'active';
    final isScheduled = status == 'scheduled';
    final isCompleted = status == 'completed';
    final alreadyMarked = myStatus != null;

    Color borderColor;
    if (isActive) {
      borderColor = AppColors.green;
    } else if (isScheduled) {
      borderColor = AppColors.teal;
    } else {
      borderColor = AppColors.divider;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isActive ? 1.5 : 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color:
                        (isActive
                                ? AppColors.green
                                : isCompleted
                                ? AppColors.textGray
                                : AppColors.teal)
                            .withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isActive
                        ? Icons.radio_button_checked
                        : isCompleted
                        ? Icons.check_circle_outline
                        : Icons.schedule,
                    color: isActive
                        ? AppColors.green
                        : isCompleted
                        ? AppColors.textGray
                        : AppColors.teal,
                    size: 22,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '$cls · $subject',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),

            if (fmt.isNotEmpty) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 13, color: AppColors.textGray),
                  SizedBox(width: 4),
                  Text(
                    fmt,
                    style: TextStyle(fontSize: 11, color: AppColors.textGray),
                  ),
                ],
              ),
            ],

            if (link.isNotEmpty) ...[
              SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.videocam_outlined,
                    size: 13,
                    color: AppColors.teal,
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      link,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.teal,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Action area
            if (isActive) ...[
              SizedBox(height: 10),
              if (alreadyMarked)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.green.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppColors.green,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Attendance marked: ${myStatus.toString().toUpperCase()}',
                        style: TextStyle(
                          color: AppColors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
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
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: Icon(Icons.face, size: 18),
                    label: Text('Mark Attendance'),
                  ),
                ),
            ],

            if (isScheduled)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Session not started yet — available when teacher activates',
                    style: TextStyle(fontSize: 11, color: AppColors.teal),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            if (isCompleted && alreadyMarked)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 13, color: AppColors.textGray),
                    SizedBox(width: 4),
                    Text(
                      'Your result: ${myStatus.toString().toUpperCase()}',
                      style: TextStyle(fontSize: 11, color: AppColors.textGray),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
