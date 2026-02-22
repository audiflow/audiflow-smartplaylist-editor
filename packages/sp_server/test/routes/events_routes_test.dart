import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_server/src/routes/events_routes.dart';
import 'package:sp_server/src/services/file_watcher_service.dart';

void main() {
  group('eventsHandler', () {
    late StreamController<FileChangeEvent> controller;
    late Handler handler;

    setUp(() {
      controller = StreamController<FileChangeEvent>.broadcast();
      handler = eventsHandler(controller.stream);
    });

    tearDown(() async {
      await controller.close();
    });

    test('returns 200 status', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/events'),
      );

      final response = await handler(request);

      expect(response.statusCode, equals(200));
    });

    test('returns SSE content type headers', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/events'),
      );

      final response = await handler(request);

      expect(
        response.headers['content-type'],
        equals('text/event-stream'),
      );
      expect(
        response.headers['cache-control'],
        equals('no-cache'),
      );
      expect(
        response.headers['connection'],
        equals('keep-alive'),
      );
    });

    test('streams events in SSE format', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/events'),
      );

      final response = await handler(request);

      // Collect emitted chunks in the background
      final chunks = <String>[];
      final subscription = response
          .read()
          .transform(utf8.decoder)
          .listen(chunks.add);

      // Emit a file change event
      controller.add(const FileChangeEvent(
        type: FileChangeType.modified,
        path: 'patterns/pod-a/playlists/main.json',
      ));

      // Give the stream time to propagate
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await subscription.cancel();

      expect(chunks, hasLength(1));
      expect(
        chunks.first,
        equals(
          'data: {"type":"modified","path":"patterns/pod-a/playlists/main.json"}\n\n',
        ),
      );
    });

    test('streams multiple events sequentially', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/events'),
      );

      final response = await handler(request);

      final chunks = <String>[];
      final subscription = response
          .read()
          .transform(utf8.decoder)
          .listen(chunks.add);

      controller.add(const FileChangeEvent(
        type: FileChangeType.created,
        path: 'patterns/new/meta.json',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      controller.add(const FileChangeEvent(
        type: FileChangeType.deleted,
        path: 'patterns/old/playlists/extra.json',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await subscription.cancel();

      expect(chunks, hasLength(2));
      expect(
        chunks[0],
        equals(
          'data: {"type":"created","path":"patterns/new/meta.json"}\n\n',
        ),
      );
      expect(
        chunks[1],
        equals(
          'data: {"type":"deleted","path":"patterns/old/playlists/extra.json"}\n\n',
        ),
      );
    });
  });
}
