import 'dart:async';

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
  List<ApiFamilyMembership> _families = const [];
  bool _loading = false;
  bool _restoring = false;
  String? _error;
  int _unreadNotifications = 0;
  Timer? _notificationTimer;

  ApiUser? get user => _session?.user;
  ApiFamily? get family => _family ?? _session?.family;
  bool get canWrite => _membership?.canReview ?? false;
  bool get isOwner => _membership?.role == 'owner';
  ApiMembership? get membership => _membership;
  List<ApiFamilyMembership> get families => _families;
  ApiTree? get tree => _tree;
  bool get isAuthenticated => _session != null;
  bool get loading => _loading;
  bool get restoring => _restoring;
  String? get error => _error;
  bool get termsAccepted => user?.termsAccepted ?? false;
  int get unreadNotifications => _unreadNotifications;

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<Map<String, dynamic>> exportFamily() async {
    final familyId = family?.id;
    if (familyId == null) {
      throw const ApiException('当前没有可导出的家族');
    }
    return _api.exportFamily(familyId);
  }

  Future<void> archiveFamily({
    required String password,
    required String confirmName,
  }) async {
    final familyId = family?.id;
    if (familyId == null) {
      throw const ApiException('当前没有可注销的家族');
    }
    await _api.archiveFamily(
      familyId: familyId,
      password: password,
      confirmName: confirmName,
    );
    await _stopAccount();
  }

  Future<void> transferOwner(String userId) async {
    final familyId = family?.id;
    if (familyId == null) {
      throw const ApiException('当前没有可管理的家族');
    }
    await _api.transferOwner(familyId, userId);
    final me = await _api.me();
    _applyMe(me);
    await refreshTree();
    await reloadFamilies();
    notifyListeners();
  }

  Future<String> createRecoveryCode() async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.createRecoveryCode();
  }

  Future<String?> resetPassword({
    required String serverUrl,
    required String loginName,
    required String recoveryCode,
    required String newPassword,
  }) async {
    try {
      await _api.resetPassword(
        serverUrl: serverUrl,
        loginName: loginName,
        recoveryCode: recoveryCode,
        newPassword: newPassword,
      );
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<void> acceptTerms(String version) async {
    await _api.acceptTerms(version);
    final current = _session;
    if (current != null) {
      _session = ApiSession(
        token: current.token,
        expiresAt: current.expiresAt,
        user: ApiUser(
          id: current.user.id,
          displayName: current.user.displayName,
          loginName: current.user.loginName,
          status: current.user.status,
          phone: current.user.phone,
          termsAccepted: true,
        ),
        family: current.family,
      );
      notifyListeners();
    }
  }

  Future<void> deleteAccount(String password) async {
    await _api.deleteAccount(password);
    await _stopAccount();
  }

  Future<void> _stopAccount() async {
    _stopNotificationPolling();
    await _store.clear();
    _session = null;
    _membership = null;
    _tree = null;
    _family = null;
    notifyListeners();
  }

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
        _applyMe(me);
      } on ApiException {
        _membership = null;
      }
      try {
        _tree = await _api.tree();
      } on ApiException catch (error) {
        _error = '登录成功，但族谱加载失败：${error.message}';
      }
      await _persistSession();
      _startNotificationPolling();
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
    ApiPartialDate? birth,
    ApiPartialDate? death,
    required String lifeStatus,
    required String birthPlace,
    required String residence,
    required String occupation,
    required String education,
    required String biography,
    required int version,
  }) async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    final person = await _api.updatePerson(
      personId: personId,
      surname: surname,
      givenName: givenName,
      courtesyName: courtesyName,
      alias: alias,
      gender: gender,
      generationNo: generationNo,
      branchId: branchId,
      birthOrder: birthOrder,
      birth: birth,
      death: death,
      lifeStatus: lifeStatus,
      birthPlace: birthPlace,
      residence: residence,
      occupation: occupation,
      education: education,
      biography: biography,
      version: version,
    );
    await refreshTree();
    return person;
  }

  Future<void> deleteParentChild(String edgeId) async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    await _api.deleteParentChild(edgeId);
    await refreshTree();
  }

  Future<void> deleteSpouse(String edgeId) async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    await _api.deleteSpouse(edgeId);
    await refreshTree();
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
    ApiPartialDate? birth,
    ApiPartialDate? death,
    required String lifeStatus,
    required String birthPlace,
    required String residence,
    required String occupation,
    required String education,
    required String biography,
    required int version,
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.createProfileRequest(
      personId: personId,
      surname: surname,
      givenName: givenName,
      courtesyName: courtesyName,
      alias: alias,
      gender: gender,
      generationNo: generationNo,
      branchId: branchId,
      birthOrder: birthOrder,
      birth: birth,
      death: death,
      lifeStatus: lifeStatus,
      birthPlace: birthPlace,
      residence: residence,
      occupation: occupation,
      education: education,
      biography: biography,
      version: version,
    );
  }

  Future<ApiEditRequest> createRelationshipEndRequest({
    required String edgeType,
    required String edgeId,
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.createRelationshipEndRequest(
      edgeType: edgeType,
      edgeId: edgeId,
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
    String inviteCode = '',
    String phone = '',
    String familyName = '',
    String surname = '',
    bool acceptTerms = false,
  }) async {
    try {
      await _api.register(
        serverUrl: serverUrl,
        loginName: loginName,
        password: password,
        displayName: displayName,
        inviteCode: inviteCode,
        phone: phone,
        familyName: familyName,
        surname: surname,
        acceptTerms: acceptTerms,
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
      _applyMe(me);
      await refreshTree();
      await _persistSession();
      _startNotificationPolling();
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
      _applyMe(me);
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
      if (_session != null) {
        _startNotificationPolling();
      }
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
      _applyMe(me);
      notifyListeners();
    } on ApiException catch (error) {
      _error = error.message;
      notifyListeners();
    }
  }

  void _applyMe(ApiMe me) {
    _membership = me.membership;
    _family = me.family;
    _families = me.families;
    final current = _session;
    if (current != null) {
      _session = ApiSession(
        token: current.token,
        expiresAt: current.expiresAt,
        user: me.user,
        family: me.family,
      );
    }
  }

  Future<void> switchFamily(String familyId) async {
    final me = await _api.switchFamily(familyId);
    _applyMe(me);
    await refreshTree();
    await refreshUnreadNotifications();
    notifyListeners();
  }

  Future<void> uploadAvatar({
    required String personId,
    required List<int> bytes,
    required String filename,
  }) async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    await _api.uploadAvatar(
      personId: personId,
      bytes: bytes,
      filename: filename,
    );
    await refreshTree();
    notifyListeners();
  }

  Future<List<ApiAnniversary>> anniversaries({int days = 60}) async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.anniversaries(days: days);
  }

  Future<ApiNotificationPage> notifications() async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.notifications();
  }

  Future<void> refreshUnreadNotifications() async {
    if (!isAuthenticated) return;
    try {
      final count = await _api.unreadNotificationCount();
      if (_unreadNotifications == count) return;
      _unreadNotifications = count;
      notifyListeners();
    } catch (_) {
      // Notification polling is best-effort; pages still have manual refresh.
    }
  }

  void _startNotificationPolling() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => refreshUnreadNotifications(),
    );
    refreshUnreadNotifications();
  }

  void _stopNotificationPolling() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    _unreadNotifications = 0;
  }

  Future<void> markNotificationRead({int? id, bool all = false}) async {
    await _api.markNotificationRead(id: id, all: all);
    if (all) {
      _unreadNotifications = 0;
    } else if (_unreadNotifications > 0) {
      _unreadNotifications--;
    }
    notifyListeners();
  }

  Future<List<ApiStory>> stories() async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    final page = await _api.stories();
    return page.items;
  }

  Future<ApiStory> story(String storyId) => _api.story(storyId);

  Future<ApiStory> createStory({
    required String title,
    required String body,
    String personId = '',
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.createStory(title: title, body: body, personId: personId);
  }

  Future<ApiStory> updateStory({
    required String storyId,
    required String title,
    required String body,
    String personId = '',
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.updateStory(
      storyId: storyId,
      title: title,
      body: body,
      personId: personId,
    );
  }

  Future<void> deleteStory(String storyId) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.deleteStory(storyId);
  }

  Future<List<ApiActivity>> activity({int limit = 20}) async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    final page = await _api.activity(limit: limit);
    return page.items;
  }

  Future<List<ApiPhoto>> photos({String? personId}) async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    final page = await _api.photos(personId: personId);
    return page.items;
  }

  Future<ApiPhoto> uploadPhoto({
    required List<int> bytes,
    required String filename,
    String personId = '',
    String caption = '',
    DateTime? takenAt,
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.uploadPhoto(
      bytes: bytes,
      filename: filename,
      contentType: '',
      personId: personId,
      caption: caption,
      takenAt: takenAt,
    );
  }

  Future<ApiPhoto> updatePhoto({
    required String photoId,
    String personId = '',
    String caption = '',
    DateTime? takenAt,
  }) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.updatePhoto(
      photoId: photoId,
      personId: personId,
      caption: caption,
      takenAt: takenAt,
    );
  }

  Future<void> deletePhoto(String photoId) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.deletePhoto(photoId);
  }

  String photoUrl(String contentPath) => _api.photoUrl(contentPath);

  Map<String, String> get photoHeaders => _api.authHeaders;

  Future<ApiImportPackage> createImportPackage(String rootPersonId) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.createImportPackage(rootPersonId);
  }

  Future<ApiImportPreview> previewImportPackage(String code) {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    return _api.previewImportPackage(code);
  }

  Future<ApiImportResult> importPackage({
    required String code,
    required String branchId,
    required int rootGeneration,
    String parentId = '',
    String parentRole = '',
  }) async {
    if (!isAuthenticated) {
      throw const ApiException('登录状态已失效，请重新登录');
    }
    final result = await _api.importPackage(
      code: code,
      branchId: branchId,
      rootGeneration: rootGeneration,
      parentId: parentId,
      parentRole: parentRole,
    );
    await refreshTree();
    return result;
  }

  Future<ApiMe> joinFamily(String inviteCode) async {
    final me = await _api.joinFamily(inviteCode);
    _applyMe(me);
    await refreshTree();
    notifyListeners();
    return me;
  }

  Future<void> createFamily({
    required String name,
    required String surname,
  }) async {
    final me = await _api.createFamily(name: name, surname: surname);
    _applyMe(me);
    await refreshTree();
    notifyListeners();
  }

  Future<void> reloadFamilies() async {
    final items = await _api.families();
    _families = items;
    notifyListeners();
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
    ApiPartialDate? birth,
    ApiPartialDate? death,
    String lifeStatus = 'living',
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
      birth: birth,
      death: death,
      lifeStatus: lifeStatus,
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
    _stopNotificationPolling();
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
    _stopNotificationPolling();
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

  static AppSession? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SessionScope>()?.notifier;
  }
}
