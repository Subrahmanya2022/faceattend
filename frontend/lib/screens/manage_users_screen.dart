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

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});
  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List _users = [];
  List _filtered = [];
  bool _loading = true;
  String _roleFilter = 'all';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_apply);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getUsers();
      _users = res['users'] ?? [];
      _apply();
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _apply() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = _users.where((u) {
        final matchRole = _roleFilter == 'all' || u['role'] == _roleFilter;
        final matchQ =
            q.isEmpty ||
            (u['name'] ?? '').toLowerCase().contains(q) ||
            (u['email'] ?? '').toLowerCase().contains(q);
        return matchRole && matchQ;
      }).toList();
    });
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete User'),
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
    await ApiService.deleteUser(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgGray,
      appBar: AppBar(
        title: Text('Manage Users'),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'teacher', 'student', 'admin']
                        .map(
                          (r) => Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(r == 'all' ? 'All' : r),
                              selected: _roleFilter == r,
                              onSelected: (_) {
                                setState(() => _roleFilter = r);
                                _apply();
                              },
                              selectedColor: AppColors.teal.withAlpha(40),
                              checkmarkColor: AppColors.teal,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(color: AppColors.textGray),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final u = _filtered[i];
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
                          leading: AvatarCircle(
                            name: u['name'] ?? '',
                            size: 40,
                            color: u['role'] == 'teacher'
                                ? AppColors.teal
                                : AppColors.navy,
                          ),
                          title: Text(
                            u['name'] ?? '',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u['email'] ?? '',
                                style: TextStyle(fontSize: 12),
                              ),
                              SizedBox(height: 4),
                              StatusBadge(status: u['role'] ?? ''),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: AppColors.red,
                            ),
                            onPressed: () => _delete(u['id'], u['name']),
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
}
