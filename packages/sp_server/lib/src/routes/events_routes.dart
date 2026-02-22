import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../services/file_watcher_service.dart';

/// Creates a shelf [Handler] that streams [FileChangeEvent]s as
/// Server-Sent Events (SSE).
///
/// Each event is formatted as `data: <json>\n\n` per the SSE spec.
/// The handler subscribes to [events] when a client connects and
/// cancels the subscription when the client disconnects.
Handler eventsHandler(Stream<FileChangeEvent> events) {
  return (Request request) {
    final outputController = StreamController<List<int>>();

    final subscription = events.listen((event) {
      final json = jsonEncode(event.toJson());
      final sseMessage = 'data: $json\n\n';
      outputController.add(utf8.encode(sseMessage));
    });

    // Clean up when the client disconnects
    outputController.onCancel = () async {
      await subscription.cancel();
    };

    return Response.ok(
      outputController.stream,
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    );
  };
}
