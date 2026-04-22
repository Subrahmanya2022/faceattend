import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});
  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
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

  Future<void> _activate(int id) async {
    await ApiService.activateSession(id);
    _load();
  }

  Future<void> _close(int id) async {
    await ApiService.closeSession(id);
    _load();
  }

  Future<void> _delete(int id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Session'),
        content: Text('Delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              minimumSize: Size.zero,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.deleteSession(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      appBar: AppBar(
        title: Text('Sessions'),
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
        label: Text('Schedule', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'scheduled', 'active', 'completed']
                    .map(
                      (f) => Padding(
                        padding: EdgeInsets.only(right: 8),
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
                    )
                    .toList(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No sessions found.',
                      style: TextStyle(color: AppColors.textGray),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final s = _filtered[i];
                      return _SessionCard(
                        session: s,
                        onActivate: () => _activate(s['id']),
                        onClose: () => _close(s['id']),
                        onDelete: () => _delete(s['id'], s['title'] ?? ''),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SessionDetailScreen(sessionId: s['id']),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map session;
  final VoidCallback onActivate;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _SessionCard({
    required this.session,
    required this.onActivate,
    required this.onClose,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = session['status'] ?? 'scheduled';
    final title = session['title'] ?? 'Untitled';
    final cls = session['class_name'] ?? '';
    final subject = session['subject'] ?? '';
    final link = session['meeting_link'] ?? '';
    final sched = session['scheduled_at'];
    final schedFmt = sched != null
        ? DateFormat(
            'MMM d, yyyy · h:mm a',
          ).format(DateTime.parse(sched).toLocal())
        : '';

    Color statusColor;
    switch (status) {
      case 'active':
        statusColor = AppColors.green;
        break;
      case 'completed':
        statusColor = AppColors.textGray;
        break;
      default:
        statusColor = AppColors.teal;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
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
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      status == 'active'
                          ? Icons.radio_button_checked
                          : status == 'completed'
                          ? Icons.check_circle_outline
                          : Icons.schedule,
                      color: statusColor,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            StatusBadge(status: status),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$cls · $subject',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textGray,
                          ),
                        ),
                        if (schedFmt.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: AppColors.textGray,
                              ),
                              SizedBox(width: 4),
                              Text(
                                schedFmt,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Meeting link row
            if (link.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: InkWell(
                  onTap: () => launchUrl(Uri.parse(link)),
                  child: Row(
                    children: [
                      Icon(
                        Icons.videocam_outlined,
                        size: 14,
                        color: AppColors.teal,
                      ),
                      SizedBox(width: 6),
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
                ),
              ),

            // Action buttons
            if (status != 'completed')
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    if (status == 'scheduled')
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onActivate,
                          icon: Icon(
                            Icons.play_arrow,
                            color: AppColors.green,
                            size: 18,
                          ),
                          label: Text(
                            'Start',
                            style: TextStyle(color: AppColors.green),
                          ),
                        ),
                      ),
                    if (status == 'active')
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onClose,
                          icon: Icon(
                            Icons.stop_circle_outlined,
                            color: AppColors.amber,
                            size: 18,
                          ),
                          label: Text(
                            'Close',
                            style: TextStyle(color: AppColors.amber),
                          ),
                        ),
                      ),
                    Container(width: 1, height: 32, color: AppColors.divider),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.delete_outline,
                          color: AppColors.red,
                          size: 18,
                        ),
                        label: Text(
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
      ),
    );
  }
}
