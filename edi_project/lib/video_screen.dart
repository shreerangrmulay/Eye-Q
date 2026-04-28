import 'package:flutter/material.dart';
import 'api_service.dart';

class VideoScreen extends StatelessWidget {
  final String sessionId;

  const VideoScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();

    return Scaffold(
      appBar: AppBar(title: Text("Live Feed - $sessionId")),
      body: Center(
        child: Image.network(
          api.getStreamUrl(sessionId),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Text("Stream not available"),
        ),
      ),
    );
  }
}