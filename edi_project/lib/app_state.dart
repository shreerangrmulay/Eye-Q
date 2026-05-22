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
  bool get isProctor => _user?['role'] == 'proctor' || _user?['role'] == 'admin';
  bool get isTeacher => _user?['role'] == 'teacher';
  bool get isStudent =>
      _user?['role'] == 'student' || _user?['role'] == 'candidate';
  bool get isProfileComplete =>
      _user != null &&
      _user!['prn'] != null &&
      _user!['full_name'] != null &&
      _user!['branch'] != null &&
      _user!['division'] != null &&
      _user!['semester'] != null &&
      _user!['year'] != null &&
      _user!['prn'].toString().isNotEmpty &&
      _user!['branch'].toString().isNotEmpty &&
      _user!['division'].toString().isNotEmpty &&
      _user!['semester'].toString().isNotEmpty &&
      _user!['year'].toString().isNotEmpty;

  String get sideCameraUrl => _sideCameraUrl;
  String get displayName => (_user?['full_name'] ?? 'Candidate').toString();
  String get username => (_user?['username'] ?? 'candidate').toString();
  ApiService get api => ApiService(token: _token);

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _sideCameraUrl = prefs.getString('side_camera_url') ?? '';
    final keys = [
      'id',
      'username',
      'email',
      'full_name',
      'role',
      'prn',
      'branch',
      'division',
      'semester',
      'year',
    ];
    if (_token != null && prefs.containsKey('username')) {
      _user = {for (final key in keys) key: prefs.get(key)};
    }
    if (_token != null && isStudent) {
      await refreshStudentProfile();
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
    if (isStudent) {
      await refreshStudentProfile();
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

  /// Update user profile fields and persist them
  Future<void> updateProfile({
    required String prn,
    required String fullName,
    required String branch,
    required String division,
    required String semester,
    required String year,
  }) async {
    final profile = await api.updateStudentProfile(
      fullName: fullName,
      prn: prn,
      branch: branch,
      division: division,
      semester: semester,
      year: year,
    );
    await _applyStudentProfile(profile);
  }

  Future<void> refreshStudentProfile() async {
    if (!isStudent || _token == null) return;
    try {
      final profile = await api.getStudentProfile();
      await _applyStudentProfile(profile, notify: false);
    } catch (_) {
      // Keep locally persisted profile data if the backend is temporarily unreachable.
    }
  }

  Future<void> _applyStudentProfile(
    Map<String, dynamic> profile, {
    bool notify = true,
  }) async {
    _user = {
      ...?_user,
      'prn': profile['prn']?.toString() ?? '',
      'full_name': profile['full_name']?.toString() ?? displayName,
      'branch': profile['branch']?.toString() ?? '',
      'division': profile['division']?.toString() ?? '',
      'semester': profile['semester']?.toString() ?? '',
      'year': profile['year']?.toString() ?? '',
    };
    final prefs = await SharedPreferences.getInstance();
    if (_user != null) {
      for (final entry in _user!.entries) {
        if (entry.value != null) {
          await prefs.setString(entry.key, entry.value.toString());
        }
      }
    }
    if (notify) notifyListeners();
  }

  Future<void> rememberSideCameraUrl(String value) async {
    _sideCameraUrl = value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('side_camera_url', _sideCameraUrl);
    notifyListeners();
  }
}
