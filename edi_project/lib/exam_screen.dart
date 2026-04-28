import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

class ExamScreen extends StatefulWidget {
  final String examTitle;
  const ExamScreen({super.key, required this.examTitle});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  CameraController? _controller;
  Timer? _captureTimer;
  final ApiService _apiService = ApiService();

  bool _isCameraReady = false;
  String? _selectedOption;

  bool _isCheatingDetected = false;
  String _aiMessage = "";

  bool _isUploading = false;

  // 🔥 SESSION ID (later make dynamic)
  final String sessionId = "999";

  @override
  void initState() {
    super.initState();
    _startSession();   // ✅ Start backend session
    _initializeCamera();
  }

  // ─────────────────────────────────────────────
  // 🚀 START SESSION (NEW)
  // ─────────────────────────────────────────────
  Future<void> _startSession() async {
    try {
      await http.post(
        Uri.parse("${ApiService.baseUrl}/session/start"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "session_id": sessionId,
          "student_id": "student_1"
        }),
      );
    } catch (e) {
      debugPrint("Session start error: $e");
    }
  }

  // ─────────────────────────────────────────────
  // CAMERA INIT
  // ─────────────────────────────────────────────
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (!mounted) return;

      setState(() => _isCameraReady = true);
      _startProctoring();
    } catch (e) {
      debugPrint("Camera Init Error: $e");
    }
  }

  // ─────────────────────────────────────────────
  // AI PROCTORING LOOP
  // ─────────────────────────────────────────────
  void _startProctoring() {
    _captureTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_isUploading) return;

      final ctrl = _controller;
      if (ctrl == null ||
          !ctrl.value.isInitialized ||
          ctrl.value.isTakingPicture) {
        return;
      }

      _isUploading = true;

      try {
        final XFile image = await ctrl.takePicture();

        // 🔥 Send with session ID
        final result = await _apiService.uploadFrame(
          File(image.path),
          sessionId,
        );

        try {
          await File(image.path).delete();
        } catch (_) {}

        if (mounted) {
          setState(() {
            _isCheatingDetected = result['cheating'] ?? false;
            _aiMessage = result['message'] ?? "";
          });
        }
      } catch (e) {
        debugPrint("Proctoring error: $e");
        if (mounted) {
          setState(() {
            _isCheatingDetected = false;
            _aiMessage = "Connection lost";
          });
        }
      } finally {
        _isUploading = false;
      }
    });
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.examTitle),
        automaticallyImplyLeading: false,
        actions: [_buildTimerBadge()],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildQuestionUI(),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _buildCameraContainer(),
          ),
          if (_isCheatingDetected)
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: _buildWarningBanner(),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // WARNING BANNER
  // ─────────────────────────────────────────────
  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4)
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "WARNING: $_aiMessage",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CAMERA VIEW
  // ─────────────────────────────────────────────
  Widget _buildCameraContainer() {
    return Container(
      width: 110,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isCheatingDetected ? Colors.red : Colors.blue,
          width: 3,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _isCameraReady
            ? CameraPreview(_controller!)
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildTimerBadge() {
    return Container(
      margin: const EdgeInsets.only(right: 130),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        "59:52",
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // QUESTION UI
  // ─────────────────────────────────────────────
  Widget _buildQuestionUI() {
    final options = [
      "K-Means",
      "Linear Regression",
      "PCA",
      "Association"
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Question 1 of 20",
            style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 10),
        const Text(
          "Which of the following is Supervised Learning?",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        Expanded(
          child: RadioGroup<String>(
            groupValue: _selectedOption,
            onChanged: (v) => setState(() => _selectedOption = v),
            child: ListView(
              children: options.map((opt) {
                return RadioListTile<String>(
                  title: Text(opt),
                  value: opt,
                );
              }).toList(),
            ),
          ),
        ),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("SUBMIT EXAM"),
          ),
        ),
      ],
    );
  }
}