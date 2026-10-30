import 'package:flutter/widgets.dart';

import '../models/family_member.dart';
import 'api_client.dart';
import 'api_models.dart';

class AppSession extends ChangeNotifier {
  AppSession({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  ApiSession? _session;
  ApiMembership? _membership;
  ApiTree? _tree;
  bool _loading = false;
  String? _error;

  ApiUser? get user => _session?.user;
  ApiFamily? get family => _session?.family;
  ApiMembership? get membership => _membership;
  ApiTree? get tree => _tree;
  bool get isAuthenticated => _session != null;
  bool get loading => _loading;
  String? get error => _error;
  String get serverUrl => _api.baseUrl;

  String? get roleLabel =>
      _session == null ? null : (_membership?.roleLabel ?? '家族成员');

  Future<bool> login({
    required String serverUrl,
    required String loginName,
    required String password,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _session = await _api.login(
        serverUrl: serverUrl,
        loginName: loginName,
        password: password,
      );
      try {
        final me = await _api.me();
        _membership = me.membership;
      } on ApiException {
        _membership = null;
      }
      try {
        _tree = await _api.tree();
      } on ApiException catch (error) {
        _error = '登录成功，但族谱加载失败：${error.message}';
      }
      return true;
    } on ApiException catch (error) {
      _session = null;
      _membership = null;
      _tree = null;
      _error = error.message;
      return false;
    } catch (_) {
      _session = null;
      _membership = null;
      _tree = null;
      _error = '登录失败，请稍后重试';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<ApiPerson> fetchPerson(String personId) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.person(personId);
  }

  Future<ApiPersonPage> searchPersons({
    String query = '',
    int? generation,
    int limit = 100,
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.persons(query: query, generation: generation, limit: limit);
  }

  Future<ApiEditRequest> createEditRequest({
    required String targetPersonId,
    required int baseVersion,
    required ApiEditChanges changes,
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.createEditRequest(
      targetPersonId: targetPersonId,
      baseVersion: baseVersion,
      changes: changes,
    );
  }

  Future<ApiEditRequestPage> editRequests({
    String? status,
    bool mine = false,
    int limit = 50,
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.editRequests(status: status, mine: mine, limit: limit);
  }

  Future<ApiEditRequest> reviewEditRequest(
    String requestId, {
    required bool approve,
    String note = '',
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.reviewEditRequest(requestId, approve: approve, note: note);
  }

  Future<void> refreshTree() async {
    if (!isAuthenticated) return;
    try {
      _tree = await _api.tree();
      _error = null;
    } on ApiException catch (error) {
      _error = error.message;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } finally {
      _session = null;
      _membership = null;
      _tree = null;
      _error = null;
      notifyListeners();
    }
  }

  List<FamilyMember> get treeMembers {
    final currentTree = _tree;
    if (currentTree == null) return const [];
    return currentTree.persons
        .map((person) => person.toFamilyMember(currentTree.familyId))
        .toList(growable: false);
  }

  FamilyMember? memberByName(String name) {
    for (final person in treeMembers) {
      if (person.name == name) return person;
    }
    return null;
  }

  FamilyMember? memberById(String? personId) {
    if (personId == null) return null;
    for (final person in treeMembers) {
      if (person.id == personId) return person;
    }
    return null;
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }
}

class SessionScope extends InheritedNotifier<AppSession> {
  const SessionScope({
    super.key,
    required AppSession session,
    required super.child,
  }) : super(notifier: session);

  static AppSession of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope is missing above this context');
    return scope!.notifier!;
  }
}
