import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/services/api_service.dart';
// import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  String? _token;
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? get user => _user;
  String? get token => _token;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _token != null && _user != null;
  String get role => _user?['role'] ?? '';
  int get userId => _user?['id'] ?? 0;
  int? get orgId => _user?['org_id'];
  String get name => _user?['name'] ?? '';
  String get email => _user?['email'] ?? '';

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('fa_token');
    final userStr = prefs.getString('fa_user');
    if (_token != null && userStr != null) {
      _user = jsonDecode(userStr);
      ApiService.setToken(_token!);
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.login(email, password);
      if (res['token'] != null) {
        _token = res['token'];
        _user = res['user'];
        ApiService.setToken(_token!);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fa_token', _token!);
        await prefs.setString('fa_user', jsonEncode(_user));
        _loading = false;
        notifyListeners();
        return true;
      } else {
        _error = res['error'] ?? 'Login failed';
        _loading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Connection error. Check if server is running.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _error = null;
    ApiService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fa_token');
    await prefs.remove('fa_user');
    notifyListeners();
  }

  void updateUser(Map<String, dynamic> updatedUser) async {
    _user = updatedUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fa_user', jsonEncode(_user));
    notifyListeners();
  }
}
