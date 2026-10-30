import 'package:flutter/widgets.dart';

import '../models/family_member.dart';
import 'api_client.dart';
import 'api_models.dart';
import 'session_store.dart';

class AppSession extends ChangeNotifier {
  AppSession({ApiClient? api, SessionStore? store})
    : _api = api ?? ApiClient(),
      _store = store ?? SessionStore();

  final ApiClient _api;
  final SessionStore _store;
  ApiSession? _session;
  ApiMembership? _membership;
  ApiTree? _tree;
  ApiFamily? _family;
  bool _loading = false;
  bool _restoring = false;
  String? _error;

  ApiUser? get user => _session?.user;
  ApiFamily? get family => _family ?? _session?.family;
  bool get canWrite => _membership?.canReview ?? false;
  bool get isOwner => _membership?.role == 'owner';
  ApiMembership? get membership => _membership;
  ApiTree? get tree => _tree;
  bool get isAuthenticated => _session != null;
  bool get loading => _loading;
  bool get restoring => _restoring;
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
      _family = _session?.family;
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
      await _persistSession();
      return true;
    } on ApiException catch (error) {
      _session = null;
      _membership = null;
      _tree = null;
      _family = null;
      _error = error.message;
      return false;
    } catch (_) {
      _session = null;
      _membership = null;
      _tree = null;
      _family = null;
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

  Future<ApiEditRequest> createWriteRequest({
    required String requestType,
    required Map<String, dynamic> payload,
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.createWriteRequest(requestType: requestType, payload: payload);
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

  Future<String?> register({
    required String serverUrl,
    required String loginName,
    required String password,
    required String displayName,
    required String inviteCode,
    String phone = '',
  }) async {
    try {
      await _api.register(
        serverUrl: serverUrl,
        loginName: loginName,
        password: password,
        displayName: displayName,
        inviteCode: inviteCode,
        phone: phone,
      );
      final ok = await login(
        serverUrl: serverUrl,
        loginName: loginName,
        password: password,
      );
      return ok ? null : _error;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<void> sendLoginCode(String phone) {
    return _api.sendLoginCode(phone);
  }

  Future<bool> loginWithPhone({
    required String serverUrl,
    required String phone,
    required String code,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final session = await _api.loginWithPhone(
        serverUrl: serverUrl,
        phone: phone,
        code: code,
      );
      _session = session;
      _family = session.family;
      final me = await _api.me();
      _membership = me.membership;
      _family = me.family;
      await refreshTree();
      await _persistSession();
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (_restoring) return;
    _restoring = true;
    _loading = true;
    notifyListeners();
    try {
      final stored = await _store.read();
      if (stored == null) return;
      _api.configureSession(serverUrl: stored.serverUrl, token: stored.token);
      final me = await _api.me();
      _session = ApiSession(
        token: stored.token,
        expiresAt: stored.expiresAt,
        user: me.user,
        family: me.family,
      );
      _membership = me.membership;
      _family = me.family;
      try {
        _tree = await _api.tree();
      } on ApiException catch (error) {
        _error = '已恢复登录，但族谱加载失败：${error.message}';
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _store.clear();
      } else {
        _error = '自动登录失败：${error.message}';
      }
    } catch (_) {
      _error = '自动登录失败，请重新登录';
    } finally {
      _restoring = false;
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _persistSession() async {
    final session = _session;
    if (session == null) return;
    await _store.save(
      StoredSession(
        serverUrl: _api.baseUrl,
        token: session.token,
        expiresAt: session.expiresAt,
      ),
    );
  }

  Future<void> sendBindCode(String phone) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.sendBindCode(phone);
  }

  Future<void> bindPhone({required String phone, required String code}) async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    await _api.bindPhone(phone: phone, code: code);
    await refreshMe();
  }

  Future<void> refreshMe() async {
    if (!isAuthenticated) return;
    try {
      final me = await _api.me();
      _membership = me.membership;
      _family = me.family;
      notifyListeners();
    } on ApiException catch (error) {
      _error = error.message;
      notifyListeners();
    }
  }

  Future<List<ApiInvite>> invites() async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    final page = await _api.invites();
    return page.items;
  }

  Future<ApiInvite> createInvite({
    String role = 'member',
    String? branchId,
    int maxUses = 1,
    int expiresInDays = 7,
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.createInvite(
      role: role,
      branchId: branchId,
      maxUses: maxUses,
      expiresInDays: expiresInDays,
    );
  }

  Future<List<ApiFamilyAccount>> accounts() async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    final page = await _api.accounts();
    return page.items;
  }

  Future<List<ApiBranchAdminGrant>> branchAdmins() async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    final page = await _api.branchAdmins();
    return page.items;
  }

  Future<ApiBranchAdminGrant> grantBranchAdmin({
    required String userId,
    required String branchId,
    bool includeDescendants = true,
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.grantBranchAdmin(
      userId: userId,
      branchId: branchId,
      includeDescendants: includeDescendants,
    );
  }

  Future<void> revokeBranchAdmin(String grantId) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.revokeBranchAdmin(grantId);
  }

  Future<ApiBindingRequest> createBindingRequest(String personId) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.createBindingRequest(personId);
  }

  Future<ApiBindingRequestPage> bindingRequests({
    String? status,
    bool mine = false,
    int limit = 50,
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.bindingRequests(status: status, mine: mine, limit: limit);
  }

  Future<ApiBindingRequest> reviewBindingRequest(
    String requestId, {
    required bool approve,
    String note = '',
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.reviewBindingRequest(requestId, approve: approve, note: note);
  }

  Future<void> refreshTree() async {
    if (!isAuthenticated) return;
    try {
      _tree = await _api.tree();
      _family = await _api.family();
      _error = null;
    } on ApiException catch (error) {
      _error = error.message;
    }
    notifyListeners();
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
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    final person = await _api.createPerson(
      surname: surname,
      givenName: givenName,
      gender: gender,
      generationNo: generationNo,
      branchId: branchId,
      birthOrder: birthOrder,
      birthYear: birthYear,
      biography: biography,
    );
    await refreshTree();
    return person;
  }

  Future<void> addParentChild({
    required String parentId,
    required String childId,
    required String parentRole,
  }) async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    await _api.addParentChild(
      parentId: parentId,
      childId: childId,
      parentRole: parentRole,
    );
    await refreshTree();
  }

  Future<void> addSpouse({
    required String personAId,
    required String personBId,
  }) async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    await _api.addSpouse(personAId: personAId, personBId: personBId);
    await refreshTree();
  }

  Future<List<ApiBranch>> branches() async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    final page = await _api.branches();
    return page.items;
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } finally {
      await _store.clear();
      _session = null;
      _membership = null;
      _tree = null;
      _family = null;
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
