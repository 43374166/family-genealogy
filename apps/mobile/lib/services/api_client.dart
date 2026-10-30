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

  Future<void> sendLoginCode(String phone) async {
    await _request(
      'POST',
      '/api/v1/auth/sms/send',
      authenticated: false,
      body: {'phone': phone},
    );
  }

  Future<ApiSession> loginWithPhone({
    required String serverUrl,
    required String phone,
    required String code,
  }) async {
    _baseUrl = normalizeBaseUrl(serverUrl);
    final body = await _request(
      'POST',
      '/api/v1/auth/sms/login',
      authenticated: false,
      body: {'phone': phone, 'code': code},
    );
    return ApiSession.fromJson(body);
  }

  Future<void> sendBindCode(String phone) async {
    await _request('POST', '/api/v1/auth/phone/send', body: {'phone': phone});
  }

  Future<void> bindPhone({required String phone, required String code}) async {
    await _request(
      'POST',
      '/api/v1/auth/phone/bind',
      body: {'phone': phone, 'code': code},
    );
  }

  Future<ApiRegistration> register({
    required String serverUrl,
    required String loginName,
    required String password,
    required String displayName,
    required String inviteCode,
    String phone = '',
  }) async {
    _baseUrl = normalizeBaseUrl(serverUrl);
    final body = await _request(
      'POST',
      '/api/v1/auth/register',
      authenticated: false,
      body: {
        'loginName': loginName,
        'password': password,
        'displayName': displayName,
        'inviteCode': inviteCode,
        'phone': phone,
      },
    );
    return ApiRegistration.fromJson(body);
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

  Future<ApiInvitePage> invites() async {
    final body = await _request('GET', '/api/v1/invites');
    return ApiInvitePage.fromJson(body);
  }

  Future<ApiInvite> createInvite({
    String role = 'member',
    String? branchId,
    int maxUses = 1,
    int expiresInDays = 7,
  }) async {
    final body = await _request(
      'POST',
      '/api/v1/invites',
      body: {
        'role': role,
        if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
        'maxUses': maxUses,
        'expiresInDays': expiresInDays,
      },
    );
    return ApiInvite.fromJson(body);
  }

  Future<ApiFamilyAccountPage> accounts() async {
    final body = await _request('GET', '/api/v1/accounts');
    return ApiFamilyAccountPage.fromJson(body);
  }

  Future<ApiBranchAdminGrantPage> branchAdmins() async {
    final body = await _request('GET', '/api/v1/branch-admins');
    return ApiBranchAdminGrantPage.fromJson(body);
  }

  Future<ApiBranchAdminGrant> grantBranchAdmin({
    required String userId,
    required String branchId,
    bool includeDescendants = true,
  }) async {
    final body = await _request(
      'POST',
      '/api/v1/branch-admins',
      body: {
        'userId': userId,
        'branchId': branchId,
        'includeDescendants': includeDescendants,
      },
    );
    return ApiBranchAdminGrant.fromJson(body);
  }

  Future<void> revokeBranchAdmin(String grantId) async {
    await _request(
      'DELETE',
      '/api/v1/branch-admins/${Uri.encodeComponent(grantId)}',
    );
  }

  Future<ApiBindingRequest> createBindingRequest(String personId) async {
    final body = await _request(
      'POST',
      '/api/v1/bind-requests',
      body: {'personId': personId},
    );
    return ApiBindingRequest.fromJson(body);
  }

  Future<ApiBindingRequestPage> bindingRequests({
    String? status,
    bool mine = false,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      if (status != null && status.isNotEmpty) 'status': status,
      if (mine) 'mine': 'true',
    };
    final body = await _request(
      'GET',
      '/api/v1/bind-requests?${Uri(queryParameters: params).query}',
    );
    return ApiBindingRequestPage.fromJson(body);
  }

  Future<ApiBindingRequest> reviewBindingRequest(
    String requestId, {
    required bool approve,
    String note = '',
  }) async {
    final body = await _request(
      'POST',
      '/api/v1/bind-requests/${Uri.encodeComponent(requestId)}/'
          '${approve ? 'approve' : 'reject'}',
      body: {'note': note},
    );
    return ApiBindingRequest.fromJson(body);
  }

  Future<ApiBranchPage> branches() async {
    final body = await _request('GET', '/api/v1/branches');
    return ApiBranchPage.fromJson(body);
  }

  Future<ApiPerson> createPerson({
    required String surname,
    required String givenName,
    required String gender,
    required int generationNo,
    required String branchId,
    int? birthOrder,
    int? birthYear,
    String biography = '',
  }) async {
    final body = await _request(
      'POST',
      '/api/v1/persons',
      body: {
        'surname': surname,
        'givenName': givenName,
        'gender': gender,
        'generationNo': generationNo,
        'branchId': branchId,
        'birthOrder': birthOrder,
        'birthYear': birthYear,
        'biography': biography,
      },
    );
    return ApiPerson.fromJson(body);
  }

  Future<void> addParentChild({
    required String parentId,
    required String childId,
    required String parentRole,
  }) async {
    await _request(
      'POST',
      '/api/v1/relationships/parent-child',
      body: {
        'parentId': parentId,
        'childId': childId,
        'parentRole': parentRole,
      },
    );
  }

  Future<void> addSpouse({
    required String personAId,
    required String personBId,
  }) async {
    await _request(
      'POST',
      '/api/v1/relationships/spouse',
      body: {'personAId': personAId, 'personBId': personBId},
    );
  }

  Future<ApiPerson> person(String personId) async {
    final body = await _request(
      'GET',
      '/api/v1/persons/${Uri.encodeComponent(personId)}',
    );
    return ApiPerson.fromJson(body);
  }

  Future<ApiPersonPage> persons({
    String query = '',
    int? generation,
    int limit = 100,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (generation != null) 'generation': '$generation',
    };
    final body = await _request(
      'GET',
      '/api/v1/persons?${Uri(queryParameters: params).query}',
    );
    return ApiPersonPage.fromJson(body);
  }

  Future<ApiEditRequest> createEditRequest({
    required String targetPersonId,
    required int baseVersion,
    required ApiEditChanges changes,
  }) async {
    final body = await _request(
      'POST',
      '/api/v1/edit-requests',
      body: {
        'targetPersonId': targetPersonId,
        'baseVersion': baseVersion,
        'changes': changes.toJson(),
      },
    );
    return ApiEditRequest.fromJson(body);
  }

  Future<ApiEditRequest> createWriteRequest({
    required String requestType,
    required Map<String, dynamic> payload,
  }) async {
    final body = await _request(
      'POST',
      '/api/v1/edit-requests/write',
      body: {'requestType': requestType, 'payload': payload},
    );
    return ApiEditRequest.fromJson(body);
  }

  Future<ApiEditRequestPage> editRequests({
    String? status,
    bool mine = false,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      if (status != null && status.isNotEmpty) 'status': status,
      if (mine) 'mine': 'true',
    };
    final body = await _request(
      'GET',
      '/api/v1/edit-requests?${Uri(queryParameters: params).query}',
    );
    return ApiEditRequestPage.fromJson(body);
  }

  Future<ApiEditRequest> reviewEditRequest(
    String requestId, {
    required bool approve,
    String note = '',
  }) async {
    final body = await _request(
      'POST',
      '/api/v1/edit-requests/${Uri.encodeComponent(requestId)}/'
          '${approve ? 'approve' : 'reject'}',
      body: {'note': note},
    );
    return ApiEditRequest.fromJson(body);
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
