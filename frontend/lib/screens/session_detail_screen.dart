import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
// ignore: unused_import
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/utils/app_theme.dart';

// import '../../services/api_service.dart';
// import '../../utils/app_theme.dart';

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

class SessionDetailScreen extends StatefulWidget {
  final int sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});
  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  Map _session = {};
  List _attendance = [];
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
      final res = await ApiService.getSessionDetail(widget.sessionId);
      setState(() {
        _session = res['session'] ?? {};
        _attendance = res['attendance'] ?? [];
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  List get _filteredAttendance {
    if (_filter == 'all') return _attendance;
    if (_filter == 'not_marked') {
      return _attendance.where((a) => a['status'] == null).toList();
    }
    return _attendance.where((a) => a['status'] == _filter).toList();
  }

  int get _presentCount =>
      _attendance.where((a) => a['status'] == 'present').length;
  int get _absentCount =>
      _attendance.where((a) => a['status'] == 'absent').length;
  int get _notMarked => _attendance.where((a) => a['status'] == null).length;

  @override
  Widget build(BuildContext context) {
    final link = _session['meeting_link'] ?? '';
    final status = _session['status'] ?? '';
    final schedAt = _session['scheduled_at'];
    final schedFmt = schedAt != null
        ? DateFormat(
            'MMM d, yyyy · h:mm a',
          ).format(DateTime.parse(schedAt).toLocal())
        : '';

    return Scaffold(
      backgroundColor: AppColors.bgGray,
      appBar: AppBar(
        title: Text(_session['title'] ?? 'Session'),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Session info card
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_session['class_name'] ?? ''}'
                                  ' · ${_session['subject'] ?? ''}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textGray,
                                  ),
                                ),
                                if (schedFmt.isNotEmpty) ...[
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 13,
                                        color: AppColors.textGray,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        schedFmt,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          StatusBadge(status: status),
                        ],
                      ),
                      if (link.isNotEmpty) ...[
                        SizedBox(height: 10),
                        InkWell(
                          onTap: () => launchUrl(Uri.parse(link)),
                          child: Row(
                            children: [
                              Icon(
                                Icons.videocam,
                                color: AppColors.teal,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  link,
                                  style: TextStyle(
                                    color: AppColors.teal,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: 12),
                      Row(
                        children: [
                          _statPill(
                            '${_attendance.length}',
                            'Total',
                            AppColors.navy,
                          ),
                          SizedBox(width: 8),
                          _statPill(
                            '$_presentCount',
                            'Present',
                            AppColors.green,
                          ),
                          SizedBox(width: 8),
                          _statPill('$_absentCount', 'Absent', AppColors.red),
                          SizedBox(width: 8),
                          _statPill('$_notMarked', 'Unmarked', AppColors.amber),
                        ],
                      ),
                    ],
                  ),
                ),

                // Filter chips
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in [
                          'all',
                          'present',
                          'absent',
                          'not_marked',
                        ])
                          Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(f == 'not_marked' ? 'Unmarked' : f),
                              selected: _filter == f,
                              onSelected: (_) => setState(() => _filter = f),
                              selectedColor: AppColors.teal.withAlpha(40),
                              checkmarkColor: AppColors.teal,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // child: SingleChildScrollView(
                  //   scrollDirection: Axis.horizontal,
                  //   child: Row(children: [
                  //     ['all','present','absent','not_marked']
                  //     .map((f) => Padding(
                  //       padding: const EdgeInsets.only(right: 8),
                  //       child: FilterChip(
                  //         label: Text(f == 'not_marked'
                  //           ? 'Unmarked' : f),
                  //         selected: _filter == f,
                  //         onSelected: (_) =>
                  //           setState(() => _filter = f),
                  //         selectedColor:
                  //           AppColors.teal.withAlpha(40),
                  //         checkmarkColor: AppColors.teal),
                  //     )).toList()]),
                  // ),
                ),

                // Student list
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(12),
                    itemCount: _filteredAttendance.length,
                    itemBuilder: (_, i) {
                      final a = _filteredAttendance[i];
                      final st = a['status'];
                      return Container(
                        margin: EdgeInsets.only(bottom: 8),
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
                        child: ListTile(
                          leading: AvatarCircle(
                            name: a['name'] ?? '',
                            size: 40,
                            color: st == 'present'
                                ? AppColors.green
                                : st == 'absent'
                                ? AppColors.red
                                : AppColors.textGray,
                          ),
                          title: Text(
                            a['name'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            a['email'] ?? '',
                            style: TextStyle(fontSize: 11),
                          ),
                          trailing: st != null
                              ? StatusBadge(status: st)
                              : StatusBadge(status: 'pending'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statPill(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}
