import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // ─────────────────────────────────────────────
  // BASE URL CONFIGURATION
  // ─────────────────────────────────────────────
  // Android Emulator  → http://10.0.2.2:8000
  // Real Device       → http://<YOUR_LOCAL_IP>:8000
  // iOS Simulator     → http://127.0.0.1:8000
  static const String baseUrl = "http://localhost:8000";

  // ─────────────────────────────────────────────
  // START SESSION
  // ─────────────────────────────────────────────
  Future<void> startSession(String sessionId, String studentId) async {
    try {
      final uri = Uri.parse("$baseUrl/session/start");

      await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "session_id": sessionId,
          "student_id": studentId,
        }),
      );
    } catch (e) {
      print("Start session error: $e");
    }
  }

  // ─────────────────────────────────────────────
  // REGISTER SIDE CAMERA (optional for later)
  // ─────────────────────────────────────────────
  Future<void> registerSideCam(String sessionId, String url) async {
    try {
      final uri = Uri.parse("$baseUrl/session/sidecam");

      await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "session_id": sessionId,
          "url": url,
        }),
      );
    } catch (e) {
      print("Side cam error: $e");
    }
  }

  // ─────────────────────────────────────────────
  // UPLOAD FRAME  →  POST /proctor/upload-frame
  // ─────────────────────────────────────────────
  /// Sends a camera frame to the backend
  /// Returns: { "cheating": bool, "message": String }
  Future<Map<String, dynamic>> uploadFrame(
      File imageFile, String sessionId) async {
    try {
      final uri = Uri.parse(
          "$baseUrl/proctor/upload-frame?session_id=$sessionId");

      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 10),
      );

      final responseBody =
          await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final decoded =
            jsonDecode(responseBody) as Map<String, dynamic>;

        return {
          "cheating": decoded["cheating"] ?? false,
          "message": decoded["message"] ?? "Clear",
        };
      } else {
        return {
          "cheating": false,
          "message":
              "Server error (${streamedResponse.statusCode})",
        };
      }
    } on SocketException {
      return {
        "cheating": false,
        "message": "No connection to server"
      };
    } on http.ClientException {
      return {
        "cheating": false,
        "message": "Network error"
      };
    } on FormatException {
      return {
        "cheating": false,
        "message": "Invalid response"
      };
    } catch (e) {
      return {
        "cheating": false,
        "message": "Unexpected error: $e"
      };
    }
  }

  // ─────────────────────────────────────────────
  // GET ALL SESSIONS (FOR ADMIN PANEL)
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getSessions() async {
    try {
      final uri = Uri.parse("$baseUrl/admin/sessions");

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {};
      }
    } catch (e) {
      print("Fetch sessions error: $e");
      return {};
    }
  }

  // ─────────────────────────────────────────────
  // VIDEO STREAM URL (FOR ADMIN UI)
  // ─────────────────────────────────────────────
  String getStreamUrl(String sessionId) {
    return "$baseUrl/admin/stream/$sessionId";
  }

  // ─────────────────────────────────────────────
  // STUBS (extend later)
  // ─────────────────────────────────────────────
  Future<void> login(String email, String password) async {}
  Future<void> submitExam() async {}
}