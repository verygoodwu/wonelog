import 'dart:convert';
import 'dart:io';

import '../models/summaries.dart';

class WonelogApi {
  WonelogApi({this.baseUrl = 'http://127.0.0.1:5000'});

  final String baseUrl;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  Future<Map<String, dynamic>> health() => _getMap('/api/health');
  Future<Map<String, dynamic>> config() => _getMap('/api/config');
  Future<Map<String, dynamic>> saveConfig(Map<String, dynamic> config) =>
      _postMap('/api/config', config);
  Future<Map<String, dynamic>> aboutContent() => _getMap('/api/about-content');
  Future<Map<String, dynamic>> saveAboutContent(Map<String, dynamic> content) =>
      _postMap('/api/about-content', content);
  Future<Map<String, dynamic>> publishStatus() =>
      _getMap('/api/publish/status');

  Future<List<dynamic>> cities() => _getList('/api/cities');
  Future<Map<String, dynamic>> cityCoords() => _getMap('/api/city-coords');
  Future<Map<String, dynamic>> saveCities(List<Map<String, dynamic>> cities) =>
      _postRawMap('/api/cities', cities);
  Future<List<dynamic>> links() => _getList('/api/links');
  Future<List<dynamic>> projects() => _getList('/api/projects');
  Future<Map<String, dynamic>> saveProjects(
    List<Map<String, dynamic>> projects,
  ) =>
      _postRawMap('/api/projects', projects);

  Future<List<ArticleSummary>> articles() async {
    final items = await _getList('/api/articles');
    return items
        .whereType<Map>()
        .map((e) => ArticleSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<VersionSummary>> versions() async {
    final items = await _getList('/api/versions');
    return items
        .whereType<Map>()
        .map((e) => VersionSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> article(String filename) async {
    final body = await _request(
      'GET',
      '/api/articles/${Uri.encodeComponent(filename)}',
    );
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<Map<String, dynamic>> saveArticle(String filename, String content) {
    return _postMap(
      '/api/articles/${Uri.encodeComponent(filename)}',
      <String, dynamic>{'content': content},
    );
  }

  Future<Map<String, dynamic>> importArticle(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('Cannot open selected Markdown file: $filePath');
    }
    if (!file.path.toLowerCase().endsWith('.md')) {
      throw Exception('Please select a .md file');
    }
    final originalName = file.uri.pathSegments.isEmpty
        ? 'article.md'
        : file.uri.pathSegments.last;
    final safeName = _safeMarkdownFilename(originalName);
    final boundary = '----wonelog-${DateTime.now().microsecondsSinceEpoch}';
    final uri = Uri.parse('$baseUrl/api/articles/import');
    final request = await _client.postUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );
    request.write('--$boundary\r\n');
    request.write(
      'Content-Disposition: form-data; name="file"; filename="$safeName"\r\n',
    );
    request.write('Content-Type: text/markdown; charset=utf-8\r\n\r\n');
    request.add(await file.readAsBytes());
    request.write('\r\n--$boundary--\r\n');

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WonelogApiException(response.statusCode, body);
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<Map<String, dynamic>> uploadImage(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('Cannot open selected image: $filePath');
    }
    final lowerPath = file.path.toLowerCase();
    final extension = lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')
        ? '.jpg'
        : lowerPath.endsWith('.webp')
            ? '.webp'
            : lowerPath.endsWith('.gif')
                ? '.gif'
                : '.png';
    final filename =
        'wonelog-image-${DateTime.now().microsecondsSinceEpoch}$extension';
    final boundary = '----wonelog-${DateTime.now().microsecondsSinceEpoch}';
    final uri = Uri.parse('$baseUrl/api/upload-image');
    final request = await _client.postUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );
    request.write('--$boundary\r\n');
    request.write(
      'Content-Disposition: form-data; name="file"; filename="$filename"\r\n',
    );
    request.write('Content-Type: ${_contentType(filename)}\r\n\r\n');
    request.add(await file.readAsBytes());
    request.write('\r\n--$boundary--\r\n');

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WonelogApiException(response.statusCode, body);
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return Map<String, dynamic>.from(decoded as Map);
  }

  static String _contentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/png';
  }

  static String _safeMarkdownFilename(String filename) {
    final stem = filename.replaceFirst(
      RegExp(r'\.md$', caseSensitive: false),
      '',
    );
    var cleaned = stem
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
    if (cleaned.isEmpty) cleaned = 'article';
    if (cleaned.length > 48) cleaned = cleaned.substring(0, 48);
    return '$cleaned-${DateTime.now().microsecondsSinceEpoch}.md';
  }

  Future<Map<String, dynamic>> publish({String? version}) {
    final payload = <String, dynamic>{};
    if (version != null && version.isNotEmpty) payload['version'] = version;
    return _postMap('/api/publish', payload);
  }

  Future<Map<String, dynamic>> syncFromServer() =>
      _postMap('/api/sync', <String, dynamic>{});
  Future<Map<String, dynamic>> createVersion() =>
      _postMap('/api/versions', <String, dynamic>{});
  Future<Map<String, dynamic>> deleteVersion(String timestamp) =>
      _deleteMap('/api/versions/${Uri.encodeComponent(timestamp)}');
  Future<Map<String, dynamic>> shutdown() =>
      _postMap('/api/shutdown', <String, dynamic>{});

  Future<Map<String, dynamic>> _getMap(String path) async {
    final body = await _request('GET', path);
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<List<dynamic>> _getList(String path) async {
    final body = await _request('GET', path);
    final decoded = jsonDecode(body);
    return decoded is List<dynamic> ? decoded : <dynamic>[];
  }

  Future<Map<String, dynamic>> _postMap(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final body = await _request('POST', path, payload: payload);
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<Map<String, dynamic>> _deleteMap(String path) async {
    final body = await _request('DELETE', path);
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<Map<String, dynamic>> _postRawMap(String path, Object payload) async {
    final body = await _request('POST', path, payload: payload);
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<String> _request(String method, String path, {Object? payload}) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await _client.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (payload != null) {
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      request.write(jsonEncode(payload));
    }

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WonelogApiException(response.statusCode, body);
    }
    return body;
  }
}

class WonelogApiException implements Exception {
  WonelogApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'HTTP $statusCode: $body';
}
