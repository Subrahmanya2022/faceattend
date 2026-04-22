import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class AttendanceManagementScreen extends StatefulWidget {
  const AttendanceManagementScreen({super.key});
  @override
  State<AttendanceManagementScreen> createState() =>
      _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState
    extends State<AttendanceManagementScreen> {
  List _classes = [];
  int? _classId;
  List _sessions = [];
  int? _sessionId;
  List _records = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final res = await ApiService.getClasses();
      final cls = res['classes'] ?? [];
      setState(() {
        _classes = cls;
        if (cls.isNotEmpty) _classId = cls[0]['id'];
      });
      if (_classId != null) await _loadSessions();
    } catch (_) {}
  }

  Future<void> _loadSessions() async {
    if (_classId == null) return;
    setState(() {
      _loading = true;
      _records = [];
      _sessionId = null;
    });
    try {
      final res = await ApiService.getSessions();
      final all = (res['sessions'] ?? []) as List;
      final filtered = all.where((s) => s['class_id'] == _classId).toList();
      setState(() {
        _sessions = filtered;
        _sessionId = filtered.isNotEmpty ? filtered[0]['id'] : null;
      });
      if (_sessionId != null) await _loadRecords();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _loadRecords() async {
    if (_sessionId == null) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService.getSessionDetail(_sessionId!);
      setState(() => _records = res['attendance'] ?? []);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _editStatus(Map record) async {
    // Check attendance record exists before showing dialog
    if (record['id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Student has not marked attendance yet. '
            'No record to edit.',
          ),
          backgroundColor: AppColors.amber,
        ),
      );
      return;
    }

    final current = record['status'] ?? 'absent';
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit: ${record['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['present', 'absent', 'late']
              .map(
                (s) => RadioListTile<String>(
                  value: s,
                  groupValue: current,
                  title: Text(
                    s.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: s == 'present'
                          ? AppColors.green
                          : s == 'absent'
                          ? AppColors.red
                          : AppColors.amber,
                    ),
                  ),
                  onChanged: (v) => Navigator.pop(context, v),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (selected == null || selected == current || !mounted) return;

    try {
      final res = await ApiService.updateAttendance(record['id'], selected);
      if (!mounted) return;
      if (res['updated'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${record['name']} marked as '
              '${selected.toUpperCase()}',
            ),
            backgroundColor: AppColors.green,
          ),
        );
        await _loadRecords();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Failed'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection error'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final present = _records.where((r) => r['status'] == 'present').length;
    final absent = _records.where((r) => r['status'] == 'absent').length;
    final unmarked = _records.where((r) => r['status'] == null).length;

    return Scaffold(
      backgroundColor: AppColors.bgGray,
      appBar: AppBar(
        title: const Text('Manage Attendance'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRecords),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: _classId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    prefixIcon: Icon(Icons.class_outlined),
                    isDense: true,
                  ),
                  items: _classes
                      .map(
                        (c) => DropdownMenuItem(
                          value: c['id'] as int,
                          child: Text(
                            c['name'] ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    setState(() => _classId = v);
                    await _loadSessions();
                  },
                ),
                const SizedBox(height: 10),
                if (_sessions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.bgGray,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'No sessions for this class',
                      style: TextStyle(color: AppColors.textGray, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    value: _sessionId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Session',
                      prefixIcon: Icon(Icons.event_outlined),
                      isDense: true,
                    ),
                    items: _sessions.map((s) {
                      final raw = s['scheduled_at'];
                      final date = raw != null
                          ? DateFormat(
                              'MMM d, h:mm a',
                            ).format(DateTime.parse(raw).toLocal())
                          : '';
                      return DropdownMenuItem(
                        value: s['id'] as int,
                        child: Text(
                          '${s['title'] ?? ''}'
                          '${date.isNotEmpty ? " — $date" : ""}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) async {
                      setState(() => _sessionId = v);
                      await _loadRecords();
                    },
                  ),
              ],
            ),
          ),

          // Stats
          if (_records.isNotEmpty)
            Container(
              color: AppColors.navy,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _statPill('${_records.length}', 'Total', Colors.white),
                  _statPill('$present', 'Present', Colors.greenAccent),
                  _statPill('$absent', 'Absent', Colors.redAccent),
                  _statPill('$unmarked', 'Unmarked', Colors.orangeAccent),
                ],
              ),
            ),

          // Records
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.how_to_reg,
                            size: 56,
                            color: AppColors.textGray,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No attendance records',
                            style: TextStyle(color: AppColors.textGray),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _records.length,
                    itemBuilder: (_, i) {
                      final r = _records[i];
                      final status = r['status'] ?? 'pending';
                      final color = status == 'present'
                          ? AppColors.green
                          : status == 'absent'
                          ? AppColors.red
                          : status == 'late'
                          ? AppColors.amber
                          : AppColors.textGray;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
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
                          contentPadding: const EdgeInsets.fromLTRB(
                            14,
                            8,
                            12,
                            8,
                          ),
                          leading: AvatarCircle(
                            name: r['name'] ?? '',
                            size: 42,
                            color: color,
                          ),
                          title: Text(
                            r['name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['email'] ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textGray,
                                ),
                              ),
                              if (r['check_in'] != null)
                                Text(
                                  'Checked in: ${DateFormat("h:mm a").format(DateTime.parse(r['check_in']).toLocal())}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textGray,
                                  ),
                                ),
                              if ((r['confidence'] ?? 0) > 0)
                                Text(
                                  'Confidence: ${((r['confidence'] as num) * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textGray,
                                  ),
                                ),
                            ],
                          ),
                          trailing: GestureDetector(
                            onTap: () => _editStatus(r),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: color.withAlpha(20),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: color.withAlpha(80)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.edit, size: 11, color: color),
                                ],
                              ),
                            ),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String val, String label, Color c) {
    return Expanded(
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: c,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 9, color: c.withAlpha(180))),
        ],
      ),
    );
  }
}
