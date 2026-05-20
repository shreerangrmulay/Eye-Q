import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'exam_screen.dart';

class StudentPanel extends StatefulWidget {
  const StudentPanel({super.key});

  static const exams = [
    {
      'title': 'Computer Science 101',
      'duration': '60 min',
      'subject': 'CS',
      'questions': '20',
    },
    {
      'title': 'AI and Ethics',
      'duration': '45 min',
      'subject': 'AI',
      'questions': '15',
    },
    {
      'title': 'Digital Security',
      'duration': '30 min',
      'subject': 'SEC',
      'questions': '12',
    },
  ];

  @override
  State<StudentPanel> createState() => _StudentPanelState();
}

class _StudentPanelState extends State<StudentPanel> {
  final _sideCameraController = TextEditingController();
  bool _prefilledSideCamera = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefilledSideCamera) {
      _sideCameraController.text = context.read<AppState>().sideCameraUrl;
      _prefilledSideCamera = true;
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
          const SizedBox(height: 18),
          Text(
            'Available Exams',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...StudentPanel.exams.map(
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

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.sideCameraController});

  final Map<String, String> exam;
  final TextEditingController sideCameraController;

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
                exam['subject']!,
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
                    exam['title']!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${exam['duration']} - ${exam['questions']} questions',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                _startExam(context, app);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startExam(BuildContext context, AppState app) async {
    final sideIp = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start ${exam['title']}'),
        content: TextField(
          controller: sideCameraController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Side camera IP:PORT',
            hintText: '192.168.0.103:8080',
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
                Navigator.pop(context, sideCameraController.text.trim()),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
          ),
        ],
      ),
    );
    if (sideIp == null || sideIp.trim().isEmpty || !context.mounted) return;
    await app.rememberSideCameraUrl(sideIp.trim());
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamScreen(
          examTitle: exam['title']!,
          subject: exam['subject']!,
          sideCameraUrl: sideIp.trim(),
          studentId: app.username,
          studentName: app.displayName,
        ),
      ),
    );
  }
}
