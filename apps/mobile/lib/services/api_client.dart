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

  void configureSession({required String serverUrl, required String token}) {
    _baseUrl = normalizeBaseUrl(serverUrl);
    _token = token;
  }

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

  Future<ApiMe> switchFamily(String familyId) async {
    final body = await _request(
      'POST',
      '/api/v1/auth/switch-family',
      body: {'familyId': familyId},
    );
    return ApiMe.fromJson(body);
  }

  Future<ApiStoryPage> stories() async {
    final body = await _request('GET', '/api/v1/stories');
    return ApiStoryPage.fromJson(body);
  }

  Future<ApiStory> story(String storyId) async {
    final body = await _request(
      'GET',
      '/api/v1/stories/${Uri.encodeComponent(storyId)}',
    );
    return ApiStory.fromJson(body);
  }

  Future<ApiStory> createStory({
    required String title,
    required String body,
    String personId = '',
  }) async {
    final response = await _request(
      'POST',
      '/api/v1/stories',
      body: {'title': title, 'body': body, 'personId': personId},
    );
    return ApiStory.fromJson(response);
  }

  Future<ApiStory> updateStory({
    required String storyId,
    required String title,
    required String body,
    String personId = '',
  }) async {
    final response = await _request(
      'PATCH',
      '/api/v1/stories/${Uri.encodeComponent(storyId)}',
      body: {'title': title, 'body': body, 'personId': personId},
    );
    return ApiStory.fromJson(response);
  }

  Future<void> deleteStory(String storyId) async {
    await _request('DELETE', '/api/v1/stories/${Uri.encodeComponent(storyId)}');
  }

  Future<ApiActivityPage> activity({int limit = 20}) async {
    final body = await _request('GET', '/api/v1/activity?limit=$limit');
    return ApiActivityPage.fromJson(body);
  }

  Future<ApiPhotoPage> photos({String? personId}) async {
    final params = <String, String>{
      if (personId != null && personId.isNotEmpty) 'personId': personId,
    };
    final query = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final body = await _request('GET', '/api/v1/photos$query');
    return ApiPhotoPage.fromJson(body);
  }

  Future<ApiPhoto> uploadPhoto({
    required List<int> bytes,
    required String filename,
    required String contentType,
    String personId = '',
    String caption = '',
    DateTime? takenAt,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/photos');
    final request = http.MultipartRequest('POST', uri);
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    request.fields['personId'] = personId;
    request.fields['caption'] = caption;
    if (takenAt != null) {
      request.fields['takenAt'] = _dateOnly(takenAt);
    }
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 204) return ApiPhoto.fromJson(const {});
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
    return ApiPhoto.fromJson(map);
  }

  Future<ApiPhoto> updatePhoto({
    required String photoId,
    String personId = '',
    String caption = '',
    DateTime? takenAt,
  }) async {
    final body = await _request(
      'PATCH',
      '/api/v1/photos/${Uri.encodeComponent(photoId)}',
      body: {
        'personId': personId,
        'caption': caption,
        'takenAt': takenAt == null ? '' : _dateOnly(takenAt),
      },
    );
    return ApiPhoto.fromJson(body);
  }

  Future<void> deletePhoto(String photoId) async {
    await _request('DELETE', '/api/v1/photos/${Uri.encodeComponent(photoId)}');
  }

  String photoUrl(String contentPath) => '$_baseUrl$contentPath';

  Map<String, String> get authHeaders => {
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<ApiImportPackage> createImportPackage(String rootPersonId) async {
    final body = await _request(
      'POST',
      '/api/v1/import-packages',
      body: {'rootPersonId': rootPersonId},
    );
    return ApiImportPackage.fromJson(body);
  }

  Future<ApiImportPreview> previewImportPackage(String code) async {
    final body = await _request(
      'POST',
      '/api/v1/import-packages/preview',
      body: {'code': code},
    );
    return ApiImportPreview.fromJson(body);
  }

  Future<ApiImportResult> importPackage({
    required String code,
    required String branchId,
    required int rootGeneration,
    String parentId = '',
    String parentRole = '',
  }) async {
    final body = await _request(
      'POST',
      '/api/v1/import-packages/import',
      body: {
        'code': code,
        'branchId': branchId,
        'rootGeneration': rootGeneration,
        'parentId': parentId,
        'parentRole': parentRole,
      },
    );
    return ApiImportResult.fromJson(body);
  }

  Future<ApiMe> joinFamily(String inviteCode) async {
    final body = await _request(
      'POST',
      '/api/v1/families/join',
      body: {'inviteCode': inviteCode},
    );
    return ApiMe.fromJson(body);
  }

  Future<ApiMe> createFamily({
    required String name,
    required String surname,
    String motto = '',
    String region = '',
    String description = '',
  }) async {
    final body = await _request(
      'POST',
      '/api/v1/families',
      body: {
        'name': name,
        'surname': surname,
        'motto': motto,
        'region': region,
        'description': description,
      },
    );
    return ApiMe.fromJson(body);
  }

  Future<List<ApiFamilyMembership>> families() async {
    final body = await _request('GET', '/api/v1/families');
    final items = body['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ApiFamilyMembership.fromJson)
        .toList(growable: false);
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
    final session = ApiSession.fromJson(body);
    if (session.token.isEmpty) {
      throw const ApiException('登录响应缺少会话令牌');
    }
    _token = session.token;
    return session;
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
    String inviteCode = '',
    String phone = '',
    String familyName = '',
    String surname = '',
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
        'familyName': familyName,
        'surname': surname,
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

  Future<ApiPerson> updatePerson({
    required String personId,
    required String surname,
    required String givenName,
    required String courtesyName,
    required String alias,
    required String gender,
    required int generationNo,
    required String branchId,
    int? birthOrder,
    int? birthYear,
    int? deathYear,
    required String lifeStatus,
    required String birthPlace,
    required String residence,
    required String occupation,
    required String education,
    required String biography,
    required int version,
  }) async {
    final body = await _request(
      'PATCH',
      '/api/v1/persons/${Uri.encodeComponent(personId)}',
      body: {
        'surname': surname,
        'givenName': givenName,
        'courtesyName': courtesyName,
        'alias': alias,
        'gender': gender,
        'generationNo': generationNo,
        'branchId': branchId,
        'birthOrder': birthOrder,
        'birthYear': birthYear,
        'deathYear': deathYear,
        'lifeStatus': lifeStatus,
        'birthPlace': birthPlace,
        'residence': residence,
        'occupation': occupation,
        'education': education,
        'biography': biography,
        'version': version,
      },
    );
    return ApiPerson.fromJson(body);
  }

  Future<void> deleteParentChild(String edgeId) async {
    await _request(
      'DELETE',
      '/api/v1/relationships/parent-child/${Uri.encodeComponent(edgeId)}',
    );
  }

  Future<void> deleteSpouse(String edgeId) async {
    await _request(
      'DELETE',
      '/api/v1/relationships/spouse/${Uri.encodeComponent(edgeId)}',
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

  Future<ApiEditRequest> createProfileRequest({
    required String personId,
    required String surname,
    required String givenName,
    required String courtesyName,
    required String alias,
    required String gender,
    required int generationNo,
    required String branchId,
    int? birthOrder,
    int? birthYear,
    int? deathYear,
    required String lifeStatus,
    required String birthPlace,
    required String residence,
    required String occupation,
    required String education,
    required String biography,
    required int version,
  }) async {
    final body = await _request(
      'POST',
      '/api/v1/edit-requests/profile',
      body: {
        'personId': personId,
        'surname': surname,
        'givenName': givenName,
        'courtesyName': courtesyName,
        'alias': alias,
        'gender': gender,
        'generationNo': generationNo,
        'branchId': branchId,
        'birthOrder': birthOrder,
        'birthYear': birthYear,
        'deathYear': deathYear,
        'lifeStatus': lifeStatus,
        'birthPlace': birthPlace,
        'residence': residence,
        'occupation': occupation,
        'education': education,
        'biography': biography,
        'version': version,
      },
    );
    return ApiEditRequest.fromJson(body);
  }

  Future<ApiEditRequest> createRelationshipEndRequest({
    required String edgeType,
    required String edgeId,
  }) async {
    final body = await _request(
      'POST',
      '/api/v1/edit-requests/relationship-end',
      body: {'edgeType': edgeType, 'edgeId': edgeId},
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
