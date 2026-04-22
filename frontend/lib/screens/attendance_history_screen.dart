import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final int userId;
  const AttendanceHistoryScreen({super.key, required this.userId});
  @override
  State<AttendanceHistoryScreen> createState() =>
    _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends State<AttendanceHistoryScreen> {
  Map  _data    = {};
  List _records = [];
  bool _loading = true;
  DateTime _focused = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getStudentHistory(widget.userId);
      setState(() {
        _data    = res;
        _records = res['records'] ?? [];
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Color _dotColor(String? status) {
    switch (status) {
      case 'present': return AppColors.green;
      case 'absent':  return AppColors.red;
      case 'late':    return Colors.orange;
      default:        return Colors.transparent;
    }
  }

  Map<DateTime, String> get _calendarMap {
    final map = <DateTime, String>{};
    for (final r in _records) {
      if (r['session_date'] != null) {
        try {
          final d   = DateTime.parse(r['session_date']);
          final key = DateTime(d.year, d.month, d.day);
          map[key]  = r['status'] ?? '';
        } catch (_) {}
      }
    }
    return map;
  }

  void _requestCorrection(Map record) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        title: const Text('Request Correction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Class: ${record['class_name'] ?? ''}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textGray)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines:   3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText:  'I was present but face scan failed...',
                border: OutlineInputBorder())),
          ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8)),
            onPressed: () async {
              if (ctrl.text.isEmpty) return;
              Navigator.pop(context);
              try {
                final res = await ApiService
                  .requestAttendanceCorrection(
                    record['id'], ctrl.text.trim());
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      res['message'] ?? 'Request sent!'),
                    backgroundColor: AppColors.green));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to send'),
                    backgroundColor: AppColors.red));
              }
            },
            child: const Text('Send',
              style: TextStyle(color: Colors.white))),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final pct = _data['attendancePct'] ?? 0;
    final cal = _calendarMap;

    return _loading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(children: [
            // Summary
            Container(
              color: AppColors.navy,
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: _statBox(
                  '${_data['totalClasses'] ?? 0}',
                  'Total', AppColors.tealLight)),
                const SizedBox(width: 8),
                Expanded(child: _statBox(
                  '${_data['present'] ?? 0}',
                  'Present', Colors.greenAccent)),
                const SizedBox(width: 8),
                Expanded(child: _statBox(
                  '${_data['absent'] ?? 0}',
                  'Absent', Colors.redAccent)),
                const SizedBox(width: 8),
                Expanded(child: _statBox(
                  '$pct%', 'Rate',
                  pct >= 75
                    ? Colors.greenAccent
                    : Colors.orangeAccent)),
              ])),

            // Calendar
            Container(
              color: Colors.white,
              child: TableCalendar(
                key:        ValueKey(
                  'cal_${widget.userId}'),
                firstDay:   DateTime(2024),
                lastDay:    DateTime(2028),
                focusedDay: _focused,
                onPageChanged: (d) =>
                  setState(() => _focused = d),
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppColors.teal,
                    shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(
                    color: AppColors.navy,
                    shape: BoxShape.circle)),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (_, day, __) {
                    final key = DateTime(
                      day.year, day.month, day.day);
                    final status = cal[key];
                    if (status == null) return null;
                    return Positioned(
                      bottom: 4,
                      child: Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          color: _dotColor(status),
                          shape: BoxShape.circle)));
                  }),
              )),

            // Legend
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(
                16, 0, 16, 12),
              child: Row(
                mainAxisAlignment:
                  MainAxisAlignment.center,
                children: [
                  _legendDot(AppColors.green, 'Present'),
                  const SizedBox(width: 16),
                  _legendDot(AppColors.red, 'Absent'),
                  const SizedBox(width: 16),
                  _legendDot(Colors.orange, 'Late'),
                ])),

            // Records
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment:
                  CrossAxisAlignment.start,
                children: [
                const SectionHeader(
                  title: 'Attendance Records'),
                const SizedBox(height: 10),
                if (_records.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No records yet.',
                        style: TextStyle(
                          color: AppColors.textGray))))
                else
                  ..._records.map((r) {
                    final date = r['session_date'] != null
                      ? DateFormat('MMM d, yyyy').format(
                          DateTime.parse(
                            r['session_date']))
                      : '';
                    final isAbsent =
                      r['status'] == 'absent';
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(
                        bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                          BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                          color:
                            Colors.black.withAlpha(8),
                          blurRadius: 4)]),
                      child: Column(
                        crossAxisAlignment:
                          CrossAxisAlignment.start,
                        children: [
                        Row(children: [
                          Container(
                            width: 8, height: 40,
                            decoration: BoxDecoration(
                              color: _dotColor(
                                r['status']),
                              borderRadius:
                                BorderRadius.circular(
                                  4))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment:
                              CrossAxisAlignment.start,
                            children: [
                            Text(
                              r['class_name'] ?? '',
                              style: const TextStyle(
                                fontWeight:
                                  FontWeight.w600,
                                fontSize: 14)),
                            Text(r['subject'] ?? '',
                              style: const TextStyle(
                                fontSize: 11,
                                color:
                                  AppColors.textGray)),
                            Text(date,
                              style: const TextStyle(
                                fontSize: 11,
                                color:
                                  AppColors.textGray)),
                          ])),
                          StatusBadge(
                            status: r['status'] ??
                              'unknown'),
                        ]),
                        if (isAbsent) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                _requestCorrection(r),
                              style:
                                OutlinedButton.styleFrom(
                                  foregroundColor:
                                    AppColors.amber,
                                  side: const BorderSide(
                                    color:
                                      AppColors.amber),
                                  padding:
                                    const EdgeInsets
                                      .symmetric(
                                        vertical: 6)),
                              icon: const Icon(
                                Icons.edit_note,
                                size: 16),
                              label: const Text(
                                'Request Correction',
                                style: TextStyle(
                                  fontSize: 12)))),
                        ],
                      ]));
                  }),
              ])),
          ])));
  }

  Widget _statBox(String val, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(val, style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold,
          color: color)),
        Text(label, style: TextStyle(
          fontSize: 10, color: color)),
      ]));
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(
        fontSize: 11, color: AppColors.textGray)),
    ]);
  }
}
