import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
// ignore: unused_import
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

class ManageClassesScreen extends StatefulWidget {
  const ManageClassesScreen({super.key});
  @override
  State<ManageClassesScreen> createState() => _ManageClassesScreenState();
}

class _ManageClassesScreenState extends State<ManageClassesScreen> {
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
      final res = await ApiService.getClasses();
      setState(() => _classes = res['classes'] ?? []);
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _showCreateDialog() {
    final name = TextEditingController();
    final subject = TextEditingController();
    final meeting = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Create Class'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(labelText: 'Class Name'),
              ),
              SizedBox(height: 12),
              TextField(
                controller: subject,
                decoration: InputDecoration(labelText: 'Subject'),
              ),
              SizedBox(height: 12),
              TextField(
                controller: meeting,
                decoration: InputDecoration(
                  labelText: 'Meeting Link (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              minimumSize: Size.zero,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await ApiService.createClass({
                'name': name.text.trim(),
                'subject': subject.text.trim(),
                'meetingLink': meeting.text.trim(),
              });
              _load();
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Class'),
        content: Text('Delete "$name"?'),
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
    await ApiService.deleteClass(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      appBar: AppBar(
        title: Text('Manage Classes'),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.teal,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('New Class', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _classes.isEmpty
          ? Center(
              child: Text(
                'No classes yet.',
                style: TextStyle(color: AppColors.textGray),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: _classes.length,
              itemBuilder: (_, i) {
                final c = _classes[i];
                return Container(
                  margin: EdgeInsets.only(bottom: 8),
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
                  child: ListTile(
                    contentPadding: EdgeInsets.fromLTRB(14, 8, 8, 8),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.teal.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.class_, color: AppColors.teal),
                    ),
                    title: Text(
                      c['name'] ?? '',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['subject'] ?? ''),
                        Text(
                          '${c['student_count'] ?? 0} students'
                          ' · ${c['teacher_name'] ?? 'No teacher'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textGray,
                          ),
                        ),
                        if ((c['meeting_link'] ?? '').isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.videocam_outlined,
                                size: 12,
                                color: AppColors.teal,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  c['meeting_link'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.teal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: AppColors.red),
                      onPressed: () => _delete(c['id'], c['name']),
                    ),
                    isThreeLine: true,
                  ),
                );
              },
              //             itemBuilder: (_, i) {
              //               final c = _classes[i];
              //               return Container(
              //                 margin: const EdgeInsets.only(bottom: 8),
              //                 decoration: BoxDecoration(
              //                   color: Colors.white,
              //                   borderRadius: BorderRadius.circular(12),
              //                   boxShadow: [BoxShadow(
              //                     color: Colors.black.withAlpha(10),
              //                     blurRadius: 6)]),
              //                 child: ListTile(
              //                   leading: Container(
              //                     width: 44, height: 44,
              //                     decoration: BoxDecoration(
              //                       color: AppColors.teal.withAlpha(25),
              //                       borderRadius: BorderRadius.circular(12)),
              //                     child: const Icon(Icons.class_,
              //                       color: AppColors.teal)),
              //                   title: Text(c['name'] ?? '',
              //                     style: const TextStyle(
              //                       fontWeight: FontWeight.w600)),
              //                   subtitle: Column(
              // crossAxisAlignment: CrossAxisAlignment.start,
              // children: [
              //   Text(c['subject'] ?? ''),
              //   Text(
              //     '${c['student_count'] ?? 0} students'
              //     ' · ${c['teacher_name'] ?? 'No teacher'}',
              //     style: const TextStyle(
              //       fontSize: 11,
              //       color: AppColors.textGray)),
              //   if ((c['meeting_link'] ?? '').isNotEmpty)
              //     Row(children: [
              //       const Icon(Icons.videocam_outlined,
              //         size: 12, color: AppColors.teal),
              //       const SizedBox(width: 4),
              //       Expanded(child: Text(
              //         c['meeting_link'],
              //         style: const TextStyle(
              //           fontSize: 11, color: AppColors.teal),
              //         overflow: TextOverflow.ellipsis)),
              //     ]),
              // ]),
              //               );
            ),
    );
  }
}
