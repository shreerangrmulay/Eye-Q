import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class AppState extends ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  String _sideCameraUrl = '';
  bool _bootstrapped = false;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isReady => _bootstrapped;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isAdmin => _user?['role'] == 'admin';
  String get sideCameraUrl => _sideCameraUrl;
  String get displayName => (_user?['full_name'] ?? 'Candidate').toString();
  String get username => (_user?['username'] ?? 'candidate').toString();
  ApiService get api => ApiService(token: _token);

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _sideCameraUrl = prefs.getString('side_camera_url') ?? '';
    final keys = ['id', 'username', 'email', 'full_name', 'role'];
    if (_token != null && prefs.containsKey('username')) {
      _user = {for (final key in keys) key: prefs.get(key)};
    }
    _bootstrapped = true;
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
    required String role,
    required bool rememberMe,
    String sideCameraUrl = '',
  }) async {
    final data = await ApiService().login(
      username: username,
      password: password,
      role: role,
      rememberMe: rememberMe,
    );
    _token = data['access_token'] as String;
    _user = Map<String, dynamic>.from(data['user'] as Map);
    _sideCameraUrl = sideCameraUrl.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _token!);
    await prefs.setString('side_camera_url', _sideCameraUrl);
    for (final entry in _user!.entries) {
      if (entry.value != null) {
        await prefs.setString(entry.key, entry.value.toString());
      }
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final sideCameraUrl = _sideCameraUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _sideCameraUrl = sideCameraUrl;
    if (_sideCameraUrl.isNotEmpty) {
      await prefs.setString('side_camera_url', _sideCameraUrl);
    }
    notifyListeners();
  }

  Future<void> rememberSideCameraUrl(String value) async {
    _sideCameraUrl = value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('side_camera_url', _sideCameraUrl);
    notifyListeners();
  }
}
