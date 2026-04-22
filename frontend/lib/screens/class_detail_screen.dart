import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// ignore: unused_import
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/utils/app_theme.dart';

// import '../../services/api_service.dart';
// import '../../utils/app_theme.dart';
import 'schedule_session_screen.dart' hide AppColors;
import 'session_detail_screen.dart' hide AppColors;

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

class ClassDetailScreen extends StatefulWidget {
  final Map classData;
  const ClassDetailScreen({super.key, required this.classData});
  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  List _sessions = [];
  List _students = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final classRes = await ApiService.getClassDetail(widget.classData['id']);
      final sessRes = await ApiService.getSessions();
      final allSess = sessRes['sessions'] ?? [];
      setState(() {
        _students = classRes['students'] ?? [];
        _sessions = allSess
            .where((s) => s['class_id'] == widget.classData['id'])
            .toList();
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cls = widget.classData;
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      appBar: AppBar(
        title: Text(cls['name'] ?? 'Class'),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ScheduleSessionScreen()),
          );
          _load();
        },
        backgroundColor: AppColors.teal,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('Add Session', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class info
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cls['name'] ?? '',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          cls['subject'] ?? '',
                          style: TextStyle(
                            color: AppColors.tealLight,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            StatCard(
                              label: 'Students',
                              value: '${_students.length}',
                              icon: Icons.people,
                              color: AppColors.teal,
                            ),
                            SizedBox(width: 10),
                            StatCard(
                              label: 'Sessions',
                              value: '${_sessions.length}',
                              icon: Icons.event,
                              color: AppColors.green,
                            ),
                            SizedBox(width: 10),
                            StatCard(
                              label: 'Active',
                              value:
                                  '${_sessions.where((s) => s['status'] == 'active').length}',
                              icon: Icons.radio_button_checked,
                              color: AppColors.amber,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Sessions
                  SectionHeader(title: 'Sessions (${_sessions.length})'),
                  SizedBox(height: 10),
                  if (_sessions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 40,
                            color: AppColors.textGray,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No sessions yet.',
                            style: TextStyle(color: AppColors.textGray),
                          ),
                          Text(
                            'Tap + to schedule one.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGray,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._sessions.map((s) {
                      final status = s['status'] ?? 'scheduled';
                      final schedAt = s['scheduled_at'];
                      final fmt = schedAt != null
                          ? DateFormat(
                              'MMM d · h:mm a',
                            ).format(DateTime.parse(schedAt).toLocal())
                          : '';

                      Color color;
                      switch (status) {
                        case 'active':
                          color = AppColors.green;
                          break;
                        case 'completed':
                          color = AppColors.textGray;
                          break;
                        default:
                          color = AppColors.teal;
                      }

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SessionDetailScreen(sessionId: s['id']),
                          ),
                        ),
                        child: Container(
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: status == 'active'
                                ? Border.all(color: AppColors.green, width: 1.5)
                                : null,
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
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withAlpha(25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  status == 'active'
                                      ? Icons.radio_button_checked
                                      : status == 'completed'
                                      ? Icons.check_circle_outline
                                      : Icons.schedule,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s['title'] ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (fmt.isNotEmpty)
                                      Text(
                                        fmt,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textGray,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              StatusBadge(status: status),
                              Icon(
                                Icons.chevron_right,
                                color: AppColors.textGray,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  SizedBox(height: 16),

                  // Students
                  SectionHeader(title: 'Students (${_students.length})'),
                  SizedBox(height: 10),
                  ..._students.map(
                    (s) => Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
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
                          AvatarCircle(
                            name: s['name'] ?? '',
                            size: 38,
                            color: AppColors.navy,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['name'] ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  s['email'] ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}
