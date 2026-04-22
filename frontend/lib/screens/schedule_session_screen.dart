import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

class ScheduleSessionScreen extends StatefulWidget {
  const ScheduleSessionScreen({super.key});
  @override
  State<ScheduleSessionScreen> createState() => _ScheduleSessionScreenState();
}

class _ScheduleSessionScreenState extends State<ScheduleSessionScreen> {
  final _title = TextEditingController();
  final _link = TextEditingController();
  List _classes = [];
  int? _classId;
  DateTime? _date;
  TimeOfDay? _time;
  bool _notify = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final res = await ApiService.getClasses();
      setState(() => _classes = res['classes'] ?? []);
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (_title.text.isEmpty ||
        _classId == null ||
        _date == null ||
        _time == null) {
      setState(
        () => _error = 'Please fill all required fields and pick date + time',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dt = DateTime(
        _date!.year,
        _date!.month,
        _date!.day,
        _time!.hour,
        _time!.minute,
      );
      final res = await ApiService.createSession({
        'classId': _classId,
        'title': _title.text.trim(),
        'scheduledAt': dt.toIso8601String(),
        'meetingLink': _link.text.trim(),
        'notifyStudents': _notify,
      });
      if (!mounted) return;
      if (res['session'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session scheduled successfully!'),
            backgroundColor: AppColors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() => _error = res['error'] ?? 'Failed to create session');
      }
    } catch (e) {
      setState(() => _error = 'Connection error');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _date != null
        ? DateFormat('MMM d, yyyy').format(_date!)
        : 'Pick a date';
    final timeStr = _time != null ? _time!.format(context) : 'Pick a time';

    return Scaffold(
      backgroundColor: AppColors.bgGray,
      appBar: AppBar(title: Text('Schedule Session')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 16),

              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: 'Session Title *',
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              SizedBox(height: 12),

              DropdownButtonFormField<int>(
                initialValue: _classId,
                decoration: InputDecoration(
                  labelText: 'Select Class *',
                  prefixIcon: Icon(Icons.class_outlined),
                ),

                items: _classes
                    .map(
                      (c) => DropdownMenuItem(
                        value: c['id'] as int,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width - 200,
                          child: Text(
                            '${c['name']} · ${c['subject'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    )
                    .toList(),

                // items: _classes.map((c) => DropdownMenuItem(
                //   value: c['id'] as int,
                //   child: Text(
                //     '${c['name']} · ${c['subject'] ?? ''}',
                //     overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _classId = v),
              ),
              SizedBox(height: 12),

              // Date and time pickers
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: Container(
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: AppColors.teal,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dateStr,
                                style: TextStyle(
                                  color: _date != null
                                      ? AppColors.textDark
                                      : AppColors.textGray,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      child: Container(
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: AppColors.teal,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                timeStr,
                                style: TextStyle(
                                  color: _time != null
                                      ? AppColors.textDark
                                      : AppColors.textGray,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              TextField(
                controller: _link,
                decoration: InputDecoration(
                  labelText: 'Meeting Link (optional)',
                  prefixIcon: Icon(Icons.videocam_outlined),
                  hintText: 'https://meet.google.com/...',
                ),
              ),
              SizedBox(height: 12),

              // Notify toggle
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.teal.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_outlined, color: AppColors.teal),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notify enrolled students',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Send email + app notification',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _notify,
                      onChanged: (v) => setState(() => _notify = v),
                      activeThumbColor: AppColors.teal,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!, style: TextStyle(color: AppColors.red)),
                ),

              AppButton(
                label: 'Schedule Session',
                loading: _loading,
                onPressed: _submit,
                icon: Icons.schedule,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
