import '../models/family_member.dart';

class ApiUser {
  const ApiUser({
    required this.id,
    required this.displayName,
    required this.loginName,
    required this.status,
  });

  final String id;
  final String displayName;
  final String loginName;
  final String status;

  factory ApiUser.fromJson(Map<String, dynamic> json) {
    return ApiUser(
      id: _string(json['id']),
      displayName: _string(json['displayName']),
      loginName: _string(json['loginName']),
      status: _string(json['status']),
    );
  }
}

class ApiMembership {
  const ApiMembership({
    required this.id,
    required this.role,
    required this.status,
    this.personId,
  });

  final String id;
  final String role;
  final String status;
  final String? personId;

  factory ApiMembership.fromJson(Map<String, dynamic> json) {
    return ApiMembership(
      id: _string(json['id']),
      role: _string(json['role']),
      status: _string(json['status']),
      personId: _nullableString(json['personId']),
    );
  }

  String get roleLabel => switch (role) {
    'owner' => '族长',
    'admin' => '管理员',
    _ => '普通成员',
  };

  bool get canReview => role == 'owner' || role == 'admin';
}

class ApiFamily {
  const ApiFamily({
    required this.id,
    required this.name,
    required this.surname,
    required this.motto,
    required this.region,
    required this.description,
    required this.status,
    required this.memberCount,
    required this.branchCount,
    required this.version,
  });

  final String id;
  final String name;
  final String surname;
  final String motto;
  final String region;
  final String description;
  final String status;
  final int memberCount;
  final int branchCount;
  final int version;

  factory ApiFamily.fromJson(Map<String, dynamic> json) {
    return ApiFamily(
      id: _string(json['id']),
      name: _string(json['name']),
      surname: _string(json['surname']),
      motto: _string(json['motto']),
      region: _string(json['region']),
      description: _string(json['description']),
      status: _string(json['status']),
      memberCount: _int(json['memberCount']),
      branchCount: _int(json['branchCount']),
      version: _int(json['version']),
    );
  }
}

class ApiPartialDate {
  const ApiPartialDate({
    this.year,
    this.month,
    this.day,
    this.calendar,
    this.isLeapMonth = false,
    this.text = '',
  });

  final int? year;
  final int? month;
  final int? day;
  final String? calendar;
  final bool isLeapMonth;
  final String text;

  factory ApiPartialDate.fromJson(Map<String, dynamic> json) {
    return ApiPartialDate(
      year: _nullableInt(json['year']),
      month: _nullableInt(json['month']),
      day: _nullableInt(json['day']),
      calendar: _nullableString(json['calendar']),
      isLeapMonth: json['isLeapMonth'] == true,
      text: _string(json['text']),
    );
  }
}

class ApiPerson {
  const ApiPerson({
    required this.id,
    required this.fullName,
    required this.surname,
    required this.givenName,
    required this.courtesyName,
    required this.alias,
    required this.gender,
    required this.generationNo,
    required this.generationLabel,
    this.birthOrder,
    this.branchId,
    this.birth,
    this.death,
    required this.lifeStatus,
    required this.status,
    required this.version,
    this.birthPlace = '',
    this.residence = '',
    this.occupation = '',
    this.education = '',
    this.biography = '',
    this.parents = const [],
    this.children = const [],
    this.spouses = const [],
  });

  final String id;
  final String fullName;
  final String surname;
  final String givenName;
  final String courtesyName;
  final String alias;
  final String gender;
  final int generationNo;
  final String generationLabel;
  final int? birthOrder;
  final String? branchId;
  final ApiPartialDate? birth;
  final ApiPartialDate? death;
  final String lifeStatus;
  final String status;
  final int version;
  final String birthPlace;
  final String residence;
  final String occupation;
  final String education;
  final String biography;
  final List<ApiRelative> parents;
  final List<ApiRelative> children;
  final List<ApiRelative> spouses;

  factory ApiPerson.fromJson(Map<String, dynamic> json) {
    final name = _string(json['fullName']);
    return ApiPerson(
      id: _string(json['id']),
      fullName: name.isEmpty
          ? '${_string(json['surname'])}${_string(json['givenName'])}'
          : name,
      surname: _string(json['surname']),
      givenName: _string(json['givenName']),
      courtesyName: _string(json['courtesyName']),
      alias: _string(json['alias']),
      gender: _string(json['gender'], fallback: 'unknown'),
      generationNo: _int(json['generationNo']),
      generationLabel: _string(json['generationLabel']),
      birthOrder: _nullableInt(json['birthOrder']),
      branchId: _nullableString(json['branchId']),
      birth: _date(json['birth']),
      death: _date(json['death']),
      lifeStatus: _string(json['lifeStatus'], fallback: 'unknown'),
      status: _string(json['status'], fallback: 'active'),
      version: _int(json['version'], fallback: 1),
      birthPlace: _string(json['birthPlace']),
      residence: _string(json['residence']),
      occupation: _string(json['occupation']),
      education: _string(json['education']),
      biography: _string(json['biography']),
      parents: _relatives(json['parents']),
      children: _relatives(json['children']),
      spouses: _relatives(json['spouses']),
    );
  }

  FamilyMember toFamilyMember(String familyId) {
    final aliases = <String>[
      if (courtesyName.isNotEmpty) courtesyName,
      if (alias.isNotEmpty) alias,
    ];
    return FamilyMember(
      id: id,
      familyId: familyId,
      branchId: branchId ?? '',
      name: fullName,
      gender: gender == 'female' ? Gender.female : Gender.male,
      generation: generationNo,
      aliases: aliases,
      birthYear: birth?.year,
      deathYear: death?.year,
      birthPlace: birthPlace.isEmpty ? null : birthPlace,
      residence: residence.isEmpty ? null : residence,
      occupation: occupation.isEmpty ? null : occupation,
      biography: biography.isEmpty ? null : biography,
    );
  }
}

class ApiRelative {
  const ApiRelative({
    required this.personId,
    required this.fullName,
    required this.relation,
  });

  final String personId;
  final String fullName;
  final String relation;

  factory ApiRelative.fromJson(Map<String, dynamic> json) {
    return ApiRelative(
      personId: _string(json['personId']),
      fullName: _string(json['fullName']),
      relation: _string(json['relation']),
    );
  }
}

class ApiParentChildEdge {
  const ApiParentChildEdge({
    required this.id,
    required this.parentId,
    required this.childId,
    required this.parentRole,
    required this.status,
  });

  final String id;
  final String parentId;
  final String childId;
  final String parentRole;
  final String status;

  factory ApiParentChildEdge.fromJson(Map<String, dynamic> json) {
    return ApiParentChildEdge(
      id: _string(json['id']),
      parentId: _string(json['parentId']),
      childId: _string(json['childId']),
      parentRole: _string(json['parentRole']),
      status: _string(json['status']),
    );
  }
}

class ApiSpouseEdge {
  const ApiSpouseEdge({
    required this.id,
    required this.personAId,
    required this.personBId,
    required this.status,
  });

  final String id;
  final String personAId;
  final String personBId;
  final String status;

  factory ApiSpouseEdge.fromJson(Map<String, dynamic> json) {
    return ApiSpouseEdge(
      id: _string(json['id']),
      personAId: _string(json['personAId']),
      personBId: _string(json['personBId']),
      status: _string(json['status']),
    );
  }
}

class ApiMe {
  const ApiMe({
    required this.user,
    required this.membership,
    required this.family,
  });

  final ApiUser user;
  final ApiMembership membership;
  final ApiFamily family;

  factory ApiMe.fromJson(Map<String, dynamic> json) {
    return ApiMe(
      user: ApiUser.fromJson(_map(json['user'])),
      membership: ApiMembership.fromJson(_map(json['membership'])),
      family: ApiFamily.fromJson(_map(json['family'])),
    );
  }
}

class ApiTree {
  const ApiTree({
    required this.familyId,
    required this.version,
    required this.persons,
    required this.parentChild,
    required this.spouses,
  });

  final String familyId;
  final int version;
  final List<ApiPerson> persons;
  final List<ApiParentChildEdge> parentChild;
  final List<ApiSpouseEdge> spouses;

  factory ApiTree.fromJson(Map<String, dynamic> json) {
    return ApiTree(
      familyId: _string(json['familyId']),
      version: _int(json['version'], fallback: 1),
      persons: _list(json['persons'], ApiPerson.fromJson),
      parentChild: _list(json['parentChild'], ApiParentChildEdge.fromJson),
      spouses: _list(json['spouses'], ApiSpouseEdge.fromJson),
    );
  }
}

class ApiEditChanges {
  const ApiEditChanges({
    this.birthPlace,
    this.residence,
    this.occupation,
    this.education,
    this.biography,
  });

  final String? birthPlace;
  final String? residence;
  final String? occupation;
  final String? education;
  final String? biography;

  bool get isEmpty =>
      birthPlace == null &&
      residence == null &&
      occupation == null &&
      education == null &&
      biography == null;

  List<String> get fieldKeys => [
    if (birthPlace != null) 'birthPlace',
    if (residence != null) 'residence',
    if (occupation != null) 'occupation',
    if (education != null) 'education',
    if (biography != null) 'biography',
  ];

  Map<String, dynamic> toJson() => {
    if (birthPlace != null) 'birthPlace': birthPlace,
    if (residence != null) 'residence': residence,
    if (occupation != null) 'occupation': occupation,
    if (education != null) 'education': education,
    if (biography != null) 'biography': biography,
  };

  factory ApiEditChanges.fromJson(Map<String, dynamic> json) {
    String? field(String key) {
      final value = json[key];
      if (value is! String) return null;
      // Empty strings are meaningful here: they clear an existing field.
      return value;
    }

    return ApiEditChanges(
      birthPlace: field('birthPlace'),
      residence: field('residence'),
      occupation: field('occupation'),
      education: field('education'),
      biography: field('biography'),
    );
  }

  static String labelFor(String key) => switch (key) {
    'birthPlace' => '籍贯',
    'residence' => '现居地',
    'occupation' => '职业',
    'education' => '教育',
    'biography' => '生平简介',
    _ => key,
  };
}

class ApiEditRequest {
  const ApiEditRequest({
    required this.id,
    required this.requesterName,
    required this.targetPersonId,
    required this.targetName,
    required this.baseVersion,
    required this.changes,
    required this.changedFields,
    required this.status,
    required this.reviewNote,
    required this.submittedAt,
    this.reviewedAt,
  });

  final String id;
  final String requesterName;
  final String? targetPersonId;
  final String targetName;
  final int? baseVersion;
  final ApiEditChanges changes;
  final List<String> changedFields;
  final String status;
  final String reviewNote;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  String get statusLabel => switch (status) {
    'pending' => '待审核',
    'approved' => '已通过',
    'rejected' => '已拒绝',
    'cancelled' => '已取消',
    _ => status,
  };

  factory ApiEditRequest.fromJson(Map<String, dynamic> json) {
    return ApiEditRequest(
      id: _string(json['id']),
      requesterName: _string(json['requesterName']),
      targetPersonId: _nullableString(json['targetPersonId']),
      targetName: _string(json['targetName']),
      baseVersion: _nullableInt(json['baseVersion']),
      changes: ApiEditChanges.fromJson(_map(json['changes'])),
      changedFields: _stringList(json['changedFields']),
      status: _string(json['status'], fallback: 'pending'),
      reviewNote: _string(json['reviewNote']),
      submittedAt: DateTime.tryParse(_string(json['submittedAt'])),
      reviewedAt: DateTime.tryParse(_string(json['reviewedAt'])),
    );
  }
}

class ApiEditRequestPage {
  const ApiEditRequestPage({required this.items});

  final List<ApiEditRequest> items;

  factory ApiEditRequestPage.fromJson(Map<String, dynamic> json) {
    return ApiEditRequestPage(
      items: _list(json['items'], ApiEditRequest.fromJson),
    );
  }
}

class ApiPersonPage {
  const ApiPersonPage({required this.items, this.nextCursor});

  final List<ApiPerson> items;
  final String? nextCursor;

  factory ApiPersonPage.fromJson(Map<String, dynamic> json) {
    return ApiPersonPage(
      items: _list(json['items'], ApiPerson.fromJson),
      nextCursor: _nullableString(json['nextCursor']),
    );
  }
}

class ApiSession {
  const ApiSession({
    required this.token,
    required this.expiresAt,
    required this.user,
    required this.family,
  });

  final String token;
  final DateTime? expiresAt;
  final ApiUser user;
  final ApiFamily family;

  factory ApiSession.fromJson(Map<String, dynamic> json) {
    return ApiSession(
      token: _string(json['token']),
      expiresAt: DateTime.tryParse(_string(json['expiresAt'])),
      user: ApiUser.fromJson(_map(json['user'])),
      family: ApiFamily.fromJson(_map(json['family'])),
    );
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : const {};

String _string(dynamic value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(dynamic value) =>
    value is String && value.isNotEmpty ? value : null;

int _int(dynamic value, {int fallback = 0}) =>
    value is num ? value.toInt() : fallback;

int? _nullableInt(dynamic value) => value is num ? value.toInt() : null;

ApiPartialDate? _date(dynamic value) {
  if (value is! Map<String, dynamic>) return null;
  final date = ApiPartialDate.fromJson(value);
  if (date.year == null && date.text.isEmpty) return null;
  return date;
}

List<ApiRelative> _relatives(dynamic value) =>
    _list(value, ApiRelative.fromJson);

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}

List<T> _list<T>(dynamic value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(parse)
      .toList(growable: false);
}
