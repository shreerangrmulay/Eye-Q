import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'exam_screen.dart';

class StudentPanel extends StatefulWidget {
  const StudentPanel({super.key});

  @override
  State<StudentPanel> createState() => _StudentPanelState();
}

class _StudentPanelState extends State<StudentPanel> {
  final _sideCameraController = TextEditingController();
  bool _prefilledSideCamera = false;
  bool _loadingExams = true;
  List<Map<String, dynamic>> _exams = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefilledSideCamera) {
      _sideCameraController.text = context.read<AppState>().sideCameraUrl;
      _prefilledSideCamera = true;
      _loadExams();
    }
  }

  Future<void> _loadExams() async {
    final app = context.read<AppState>();
    if (!app.isProfileComplete) {
      setState(() => _loadingExams = false);
      return;
    }
    setState(() => _loadingExams = true);
    try {
      final rows = await app.api.getAvailableExams();
      if (!mounted) return;
      setState(() {
        _exams = rows.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exam list unavailable: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingExams = false);
    }
  }

  @override
  void dispose() {
    _sideCameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Candidate Console'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                app.displayName,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AppState>().logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _StatusPanel(name: app.displayName),
          if (!app.isProfileComplete) ...[
            const SizedBox(height: 12),
            _ProfileRequiredPanel(
              onComplete: () => Navigator.pushReplacementNamed(context, '/profile'),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'Available Exams',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (_loadingExams)
            const Center(child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ))
          else if (_exams.isEmpty)
            const _EmptyExamState()
          else
            ..._exams.map(
              (exam) => _ExamCard(
                exam: exam,
                sideCameraController: _sideCameraController,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileRequiredPanel extends StatelessWidget {
  const _ProfileRequiredPanel({required this.onComplete});

  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.badge, color: Colors.orangeAccent),
          const SizedBox(width: 12),
          const Expanded(child: Text('Complete your PRN, branch, division, semester, and year before joining exams.')),
          FilledButton.icon(onPressed: onComplete, icon: const Icon(Icons.edit), label: const Text('Complete')),
        ],
      ),
    );
  }
}

class _EmptyExamState extends StatelessWidget {
  const _EmptyExamState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(38),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: const Center(
        child: Text('No published exams are available for your profile yet.', style: TextStyle(color: Colors.white60)),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Color(0xFF00E5FF), size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $name',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Identity verified. AI monitoring starts automatically when an exam begins.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _SideCameraStartAction { retry, edit, cancel }

class _ExamCard extends StatefulWidget {
  const _ExamCard({required this.exam, required this.sideCameraController});

  final Map<String, dynamic> exam;
  final TextEditingController sideCameraController;

  @override
  State<_ExamCard> createState() => _ExamCardState();
}

class _ExamCardState extends State<_ExamCard> {
  bool _validating = false;
  String _sideCameraState = 'CONNECTING';

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.16),
              child: Text(
                (widget.exam['subject'] ?? '-').toString(),
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.exam['title'].toString(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.exam['duration_minutes']} min - ${widget.exam['question_count']} question images',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  if (_validating) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Connecting to side camera...',
                      style: TextStyle(color: Colors.orangeAccent),
                    ),
                  ],
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _validating ? null : () => _startExam(context, app),
              icon: _validating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_validating ? 'Checking' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startExam(BuildContext context, AppState app) async {
    String? sideIp = await _showSideCameraInput(context);
    while (mounted && sideIp != null && sideIp.trim().isNotEmpty) {
      final validatedUrl = await _validateSideCamera(app, sideIp.trim());
      if (validatedUrl != null) {
        await app.rememberSideCameraUrl(validatedUrl);
        if (!mounted) return;
        Navigator.push(
          this.context,
          MaterialPageRoute(
            builder: (_) => ExamScreen(
              examTitle: widget.exam['title'].toString(),
              examId: (widget.exam['id'] as num?)?.toInt(),
              subject: widget.exam['subject'].toString(),
              durationMinutes:
                  (widget.exam['duration_minutes'] as num?)?.toInt() ?? 60,
              sideCameraUrl: validatedUrl,
              studentId: app.username,
              studentName: app.displayName,
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      final action = await _showSideCameraFailureDialog(this.context);
      if (action == _SideCameraStartAction.retry) {
        continue;
      }
      if (action == _SideCameraStartAction.edit) {
        if (!mounted) return;
        sideIp = await _showSideCameraInput(this.context);
        continue;
      }
      return;
    }
  }

  Future<String?> _showSideCameraInput(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start ${widget.exam['title']}'),
        content: TextField(
          controller: widget.sideCameraController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Camera URL or IP',
            hintText: '192.168.0.5 or rtsp://admin:pass@192.168.0.5:8554',
            helperText:
                'Examples: 192.168.0.5, http://192.168.0.5:8080/video, rtsp://admin:pass@192.168.0.5:8554',
            prefixIcon: Icon(Icons.settings_input_antenna),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(context, widget.sideCameraController.text.trim()),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Future<String?> _validateSideCamera(AppState app, String sideIp) async {
    setState(() {
      _validating = true;
      _sideCameraState = 'CONNECTING';
    });
    try {
      final result = await app.api.validateSideCamera(sideIp);
      final success = result['success'] == true;
      final resolvedUrl = result['resolved_url']?.toString() ?? '';
      final normalizedUrl = resolvedUrl.isNotEmpty
          ? resolvedUrl
          : result['side_camera_url']?.toString() ?? sideIp;
      setState(() {
        _sideCameraState =
            (result['state'] ?? (success ? 'ONLINE' : 'STREAM_FAILED'))
                .toString();
      });
      if (success) return normalizedUrl;
      return null;
    } catch (error) {
      if (mounted) setState(() => _sideCameraState = 'CAMERA_OFFLINE');
      return null;
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<_SideCameraStartAction?> _showSideCameraFailureDialog(
    BuildContext context,
  ) {
    return showDialog<_SideCameraStartAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Unable to connect to side camera'),
        content: Text(_sideCameraFailureText(_sideCameraState)),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _SideCameraStartAction.cancel),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pop(context, _SideCameraStartAction.edit),
            icon: const Icon(Icons.edit),
            label: const Text('Re-enter IP'),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(context, _SideCameraStartAction.retry),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _sideCameraFailureText(String state) {
    return switch (state) {
      'INVALID_IP' =>
        'Enter a camera URL or IP, for example 192.168.0.5, http://192.168.0.5:8080/video, or rtsp://admin:pass@192.168.0.5:8554.',
      'CAMERA_OFFLINE' =>
        'The camera is offline or did not return a valid frame.',
      _ =>
        'Unable to connect. I tried the entered URL and common HTTP/RTSP formats when possible. Check that the stream is open and reachable.',
    };
  }
}
