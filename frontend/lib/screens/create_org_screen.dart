import 'package:flutter/material.dart';
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

class CreateOrgScreen extends StatefulWidget {
  const CreateOrgScreen({super.key});
  @override
  State<CreateOrgScreen> createState() => _CreateOrgScreenState();
}

class _CreateOrgScreenState extends State<CreateOrgScreen> {
  final _orgName = TextEditingController();
  final _orgAddress = TextEditingController();
  final _orgEmail = TextEditingController();
  final _orgPhone = TextEditingController();
  final _adminName = TextEditingController();
  final _adminEmail = TextEditingController();
  final _adminPass = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_orgName.text.isEmpty ||
        _orgEmail.text.isEmpty ||
        _adminName.text.isEmpty ||
        _adminEmail.text.isEmpty ||
        _adminPass.text.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.createOrganisation({
        'name': _orgName.text.trim(),
        'address': _orgAddress.text.trim(),
        'email': _orgEmail.text.trim(),
        'phone': _orgPhone.text.trim(),
        'adminName': _adminName.text.trim(),
        'adminEmail': _adminEmail.text.trim(),
        'adminPassword': _adminPass.text.trim(),
      });
      if (!mounted) return;
      if (res['organisation'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Organisation "${_orgName.text}" created!'),
            backgroundColor: AppColors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() => _error = res['error'] ?? 'Failed to create');
      }
    } catch (e) {
      setState(() => _error = 'Connection error');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      appBar: AppBar(title: Text('New Organisation')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _Section(
              title: 'Organisation Details',
              children: [
                _field(_orgName, 'Organisation Name', Icons.business),
                _field(_orgAddress, 'Address', Icons.location_on_outlined),
                _field(
                  _orgEmail,
                  'Official Email',
                  Icons.email_outlined,
                  type: TextInputType.emailAddress,
                ),
                _field(
                  _orgPhone,
                  'Phone Number',
                  Icons.phone_outlined,
                  type: TextInputType.phone,
                ),
              ],
            ),
            SizedBox(height: 16),
            _Section(
              title: 'Admin Account',
              children: [
                _field(_adminName, 'Admin Full Name', Icons.person_outline),
                _field(
                  _adminEmail,
                  'Admin Email',
                  Icons.email_outlined,
                  type: TextInputType.emailAddress,
                ),
                _field(
                  _adminPass,
                  'Temporary Password',
                  Icons.lock_outlined,
                  obscure: true,
                ),
              ],
            ),
            SizedBox(height: 8),
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
              label: 'Create Organisation',
              loading: _loading,
              onPressed: _submit,
              icon: Icons.add_business,
            ),
            SizedBox(height: 8),
            Text(
              'Admin will receive login credentials by email.',
              style: TextStyle(fontSize: 12, color: AppColors.textGray),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? type,
    bool obscure = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
