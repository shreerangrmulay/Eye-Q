import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'video_screen.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  late WebSocketChannel channel;

  // Stores sessions dynamically
  Map<String, dynamic> sessions = {};

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    // ✅ IMPORTANT:
    // Android Emulator → ws://10.0.2.2:8000/ws/admin
    // Real Device → ws://YOUR_LOCAL_IP:8000/ws/admin
    // Windows Web → ws://localhost:8000/ws/admin

    channel = WebSocketChannel.connect(
      Uri.parse("ws://10.0.2.2:8000/ws/admin"),
    );

    channel.stream.listen(
      (data) {
        final decoded = jsonDecode(data);

        setState(() {
          sessions[decoded["session_id"]] = {
            "cheating": decoded["cheating"],
            "message": decoded["message"]
          };
        });
      },
      onError: (error) {
        debugPrint("WebSocket Error: $error");
      },
      onDone: () {
        debugPrint("WebSocket closed. Reconnecting...");
        Future.delayed(const Duration(seconds: 2), _connectWebSocket);
      },
    );
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionEntries = sessions.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Proctor Dashboard"),
        backgroundColor: Colors.indigo,
      ),
      body: sessionEntries.isEmpty
          ? const Center(
              child: Text(
                "Waiting for sessions...",
                style: TextStyle(fontSize: 18),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sessionEntries.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) {
                final sessionId = sessionEntries[index].key;
                final session = sessionEntries[index].value;

                final isCheating = session["cheating"] ?? false;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            VideoScreen(sessionId: sessionId),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isCheating ? Colors.red : Colors.green,
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 4,
                          color: Colors.black12,
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            color: Colors.black12,
                            child: Center(
                              child: Icon(
                                isCheating
                                    ? Icons.warning
                                    : Icons.verified,
                                color: isCheating
                                    ? Colors.red
                                    : Colors.green,
                                size: 60,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isCheating
                                ? Colors.red
                                : Colors.green,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(10),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Session: $sessionId",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                session["message"] ?? "",
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}