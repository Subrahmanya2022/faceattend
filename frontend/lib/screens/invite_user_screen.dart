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

class InviteUserScreen extends StatefulWidget {
  final String role;
  const InviteUserScreen({super.key, required this.role});
  @override
  State<InviteUserScreen> createState() => _InviteUserScreenState();
}

class _InviteUserScreenState extends State<InviteUserScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  List _classes = [];
  int? _classId;
  bool _loading = false;
  String? _error;
  bool _sent = false;
  String _tempPass = '';

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

  Future<void> _submit() async {
    if (_name.text.isEmpty || _email.text.isEmpty) {
      setState(() => _error = 'Name and email are required');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.sendInvitation({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'role': widget.role,
        if (_classId != null) 'classId': _classId,
      });
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _sent = true;
          _tempPass = res['tempPass'] ?? '';
        });
      } else {
        setState(() => _error = res['error'] ?? 'Failed');
      }
    } catch (e) {
      setState(() => _error = 'Connection error');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = widget.role == 'teacher';
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      appBar: AppBar(
        title: Text('Invite ${isTeacher ? "Teacher" : "Student"}'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: _sent ? _buildSuccess(context) : _buildForm(isTeacher),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, color: AppColors.green, size: 64),
          SizedBox(height: 16),
          Text(
            'Invitation Sent!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.green,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${_name.text} has been invited as a ${widget.role}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGray),
          ),
          SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Login Credentials:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text('Email: ${_email.text}'),
                Text(
                  'Password: $_tempPass',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Done',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(bool isTeacher) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite a ${isTeacher ? "Teacher" : "Student"}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'They will receive login credentials by email.',
                style: TextStyle(fontSize: 12, color: AppColors.textGray),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              if (_classes.isNotEmpty) ...[
                SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _classId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: isTeacher
                        ? 'Assign Class (optional)'
                        : 'Enrol in Class (optional)',
                    prefixIcon: Icon(Icons.class_outlined),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text('No class')),
                    ..._classes.map(
                      (c) => DropdownMenuItem(
                        value: c['id'] as int,
                        child: Text(
                          '${c['name']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _classId = v),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 12),
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
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.send, color: Colors.white),
            label: Text(
              _loading ? 'Sending...' : 'Send Invitation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
