import 'package:sp_mcp_server/src/tools/fetch_feed_tool.dart';
import 'package:test/test.dart';

import '../../helpers/fake_http_client.dart';

void main() {
  group('fetchFeedTool definition', () {
    test('has correct name', () {
      expect(fetchFeedTool.name, 'fetch_feed');
    });

    test('url is required', () {
      final required = fetchFeedTool.inputSchema['required'] as List<dynamic>?;
      expect(required, contains('url'));
    });
  });

  group('executeFetchFeed', () {
    late FakeHttpClient client;

    setUp(() {
      client = FakeHttpClient();
    });

    test('throws ArgumentError when url is missing', () async {
      expect(() => executeFetchFeed(client, {}), throwsA(isA<ArgumentError>()));
    });

    test('throws ArgumentError when url is empty', () async {
      expect(
        () => executeFetchFeed(client, {'url': ''}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('calls GET /api/feeds with url query parameter', () async {
      client.getResponse = {'episodes': []};

      await executeFetchFeed(client, {'url': 'https://example.com/feed.xml'});

      expect(client.lastGetPath, '/api/feeds');
      expect(client.lastGetQueryParams, {
        'url': 'https://example.com/feed.xml',
      });
    });
  });
}
