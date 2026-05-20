import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiService {
  ApiService({this.token});

  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8000',
  );

  final String? token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: '${base.path}${path.startsWith('/') ? path : '/$path'}',
      queryParameters: query,
    );
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required String role,
    required bool rememberMe,
  }) async {
    final response = await http.post(
      _uri('/auth/login'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'password': password,
        'role': role,
        'remember_me': rememberMe,
      }),
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> health() async {
    final response = await http
        .get(_uri('/health'))
        .timeout(const Duration(seconds: 4));
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> startSession({
    required String sessionId,
    required String studentId,
    required String studentName,
    required String examTitle,
    required String subject,
    required String sideCameraUrl,
  }) async {
    final response = await http.post(
      _uri('/session/start'),
      headers: _headers,
      body: jsonEncode({
        'session_id': sessionId,
        'student_id': studentId,
        'student_name': studentName,
        'exam_title': examTitle,
        'subject': subject,
        'side_camera_url': sideCameraUrl,
      }),
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> uploadFrame(
    Uint8List imageBytes,
    String sessionId, {
    String filename = 'front-camera.jpg',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/proctor/upload-frame', {'session_id': sessionId}),
    );
    if (token != null && token!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      http.MultipartFile.fromBytes('file', imageBytes, filename: filename),
    );

    final streamed = await request.send().timeout(const Duration(seconds: 12));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    throw ApiException(_errorMessage(body), streamed.statusCode);
  }

  Future<Map<String, dynamic>> checkSideCamera(String sessionId) async {
    final response = await http.post(
      _uri('/proctor/side-camera/check/$sessionId'),
      headers: _headers,
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> logClientEvent({
    required String sessionId,
    required String eventType,
    required String message,
    String severity = 'INFO',
    double scoreDelta = 0,
    Map<String, dynamic> metadata = const {},
  }) async {
    final response = await http.post(
      _uri('/session/$sessionId/event'),
      headers: _headers,
      body: jsonEncode({
        'event_type': eventType,
        'message': message,
        'severity': severity,
        'score_delta': scoreDelta,
        'metadata': metadata,
      }),
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> submitExam({
    required String sessionId,
    required Map<String, String> answers,
    String reason = 'submitted_by_candidate',
  }) async {
    final response = await http.post(
      _uri('/session/$sessionId/submit'),
      headers: _headers,
      body: jsonEncode({'answers': answers, 'reason': reason}),
    );
    return _decodeMap(response);
  }

  Future<List<dynamic>> getSessions({String? subject}) async {
    final response = await http.get(
      _uri('/admin/sessions', {
        if (subject != null && subject != 'ALL') 'subject': subject,
      }),
      headers: _headers,
    );
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> getSessionDetail(String sessionId) async {
    final response = await http.get(
      _uri('/admin/sessions/$sessionId'),
      headers: _headers,
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await http.get(_uri('/admin/stats'), headers: _headers);
    return _decodeMap(response);
  }

  Future<List<dynamic>> getEvents() async {
    final response = await http.get(_uri('/admin/events'), headers: _headers);
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> terminateSession(String sessionId) async {
    final response = await http.post(
      _uri('/admin/session/$sessionId/terminate'),
      headers: _headers,
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> flagSession(String sessionId) async {
    final response = await http.post(
      _uri('/admin/session/$sessionId/flag'),
      headers: _headers,
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> approveRejoin(String sessionId) async {
    final response = await http.post(
      _uri('/admin/session/$sessionId/approve-rejoin'),
      headers: _headers,
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> denyRejoin(String sessionId) async {
    final response = await http.post(
      _uri('/admin/session/$sessionId/deny-rejoin'),
      headers: _headers,
    );
    return _decodeMap(response);
  }

  String getStreamUrl(String sessionId) => '$baseUrl/admin/stream/$sessionId';

  String getSideStreamUrl(String sessionId) =>
      '$baseUrl/admin/stream/$sessionId/side';

  String getSnapshotUrl(String sessionId, int cacheKey) =>
      '$baseUrl/admin/snapshot/$sessionId?t=$cacheKey';

  String getSideSnapshotUrl(String sessionId, int cacheKey) =>
      '$baseUrl/admin/snapshot/$sessionId/side?t=$cacheKey';

  String adminWebSocketUrl() => _ws('/ws/admin');

  String sessionWebSocketUrl(String sessionId) => _ws('/ws/session/$sessionId');

  String _ws(String path) {
    final base = Uri.parse(baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final uri = base.replace(
      scheme: scheme,
      path: path,
      queryParameters: {
        if (token != null && token!.isNotEmpty) 'token': token!,
      },
    );
    return uri.toString();
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(_errorMessage(response.body), response.statusCode);
  }

  List<dynamic> _decodeList(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw ApiException(_errorMessage(response.body), response.statusCode);
  }

  String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      return detail?.toString() ?? 'Request failed';
    } catch (_) {
      return body.isEmpty ? 'Request failed' : body;
    }
  }
}
