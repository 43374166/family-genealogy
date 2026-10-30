import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_models.dart';

class ApiConfig {
  const ApiConfig._();

  /// Override at build time:
  /// flutter build ipa --dart-define=API_BASE_URL=http://192.168.1.201:8080
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.201:8080',
  );
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String _baseUrl = ApiConfig.defaultBaseUrl;
  String? _token;

  String get baseUrl => _baseUrl;
  String? get token => _token;

  Future<ApiSession> login({
    required String serverUrl,
    required String loginName,
    required String password,
  }) async {
    _baseUrl = normalizeBaseUrl(serverUrl);
    final body = await _request(
      'POST',
      '/api/v1/auth/login',
      body: {'loginName': loginName, 'password': password},
      authenticated: false,
    );
    final session = ApiSession.fromJson(body);
    if (session.token.isEmpty) {
      throw const ApiException('登录响应缺少会话令牌');
    }
    _token = session.token;
    return session;
  }

  Future<ApiTree> tree() async {
    final body = await _request('GET', '/api/v1/tree');
    return ApiTree.fromJson(body);
  }

  Future<ApiMe> me() async {
    final body = await _request('GET', '/api/v1/me');
    return ApiMe.fromJson(body);
  }

  Future<ApiFamily> family() async {
    final body = await _request('GET', '/api/v1/family');
    return ApiFamily.fromJson(body);
  }

  Future<void> logout() async {
    final token = _token;
    if (token == null) return;
    try {
      await _request('POST', '/api/v1/auth/logout');
    } finally {
      _token = null;
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (authenticated && _token != null) 'Authorization': 'Bearer $_token',
    };

    late http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 15)),
      ).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException('连接服务器超时，请确认地址和网络');
    } on http.ClientException {
      throw const ApiException('无法连接服务器，请确认 API 已启动');
    } on FormatException {
      throw const ApiException('服务器地址格式不正确');
    }

    if (response.statusCode == 204) {
      return const {};
    }

    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw ApiException('服务器返回了无法识别的数据', statusCode: response.statusCode);
    }
    final map = decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _errorMessage(map, response.statusCode),
        statusCode: response.statusCode,
        code: map['code'] as String?,
      );
    }
    return map;
  }

  String _errorMessage(Map<String, dynamic> body, int status) {
    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    final title = body['title'];
    if (title is String && title.isNotEmpty) return title;
    return '请求失败（$status）';
  }

  void close() => _client.close();

  static String normalizeBaseUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) {
      throw const ApiException('请填写服务器地址');
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const ApiException('服务器地址格式不正确');
    }
    return value;
  }
}
