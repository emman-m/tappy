import 'package:flutter_test/flutter_test.dart';
import 'package:tappy/services/server_service.dart';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:path/path.dart' as p;

class MockServiceInstance {
  List<Map<String, dynamic>> invoked = [];
  void invoke(String method, Map<String, dynamic> args) {
    invoked.add({'method': method, 'args': args});
  }
}

void main() {
  test('setSharableFiles updates file list and logs', () {
    final mockService = MockServiceInstance();
    final server = LocalServer(service: null); // No real service for this test
    server.setSharableFiles(['test1.txt', 'test2.txt']);
    // We can't check logs directly, but we can check internal state
    expect(server.sharableFilePaths, ['test1.txt', 'test2.txt']);
    server.clearSharedFiles();
    expect(server.sharableFilePaths, isEmpty);
  });

  test('download handler returns not found for unshared file', () async {
    final server = LocalServer(service: null);
    final handler = server.downloadHandler;
    final request = Request(
      'GET',
      Uri.parse('http://localhost/download?file=not_shared.txt'),
    );
    final response = await handler(request);
    expect(response.statusCode, equals(404));
  });

  test('download handler returns bad request if file param missing', () async {
    final server = LocalServer(service: null);
    final handler = server.downloadHandler;
    final request = Request('GET', Uri.parse('http://localhost/download'));
    final response = await handler(request);
    expect(response.statusCode, equals(400));
  });
}
