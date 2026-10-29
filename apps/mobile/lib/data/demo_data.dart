import '../models/family_activity.dart';
import '../models/family_member.dart';
import '../models/family_profile.dart';

/// Static demo data for the first Flutter milestone.
///
/// Nothing here is persisted and nothing is sent to a server yet. The IDs and
/// fields mirror the planned API entities so this file can later be replaced by
/// repository calls.
abstract final class DemoData {
  static const String familyId = 'family_zhang';

  /// Family branding is session data, not application identity.
  ///
  /// When authentication is connected, this object comes from the signed-in
  /// account's family. The product itself is deliberately multi-family.
  static const FamilyProfile family = FamilyProfile(
    id: familyId,
    name: '张氏家族',
    surname: '张',
    motto: '寻根溯源 · 传承家风',
    region: '江南 · 青溪',
    subtitle: '江南 · 青溪张氏',
    memberCount: 128,
    branchCount: 5,
  );

  static const FamilyMember currentUser = FamilyMember(
    id: 'person_zhang_san',
    familyId: familyId,
    branchId: 'branch_zhang',
    name: '张三',
    gender: Gender.male,
    generation: 8,
    birthYear: 1998,
    birthPlace: '江南 · 青溪村',
    residence: '杭州',
    occupation: '产品设计师',
    biography: '性格沉稳，热心族中事务。',
    tags: ['普通成员'],
    isCurrentUser: true,
  );

  static const FamilyMember zhangTianming = FamilyMember(
    id: 'person_zhang_tianming',
    familyId: familyId,
    branchId: 'branch_zhang',
    name: '张天明',
    gender: Gender.male,
    generation: 6,
    birthYear: 1680,
    deathYear: 1750,
    birthPlace: '江南府 · 青溪村',
    occupation: '乡贤',
    biography: '始修家谱，置义田，训诫后人以耕读传家。',
    tags: ['六世祖'],
  );

  static const FamilyMember linShi = FamilyMember(
    id: 'person_lin_shi',
    familyId: familyId,
    branchId: 'branch_zhang',
    name: '林氏',
    gender: Gender.female,
    generation: 6,
    birthYear: 1685,
    deathYear: 1752,
    birthPlace: '江南府 · 林溪',
    biography: '温良持家，善纺织，好施与。',
    relation: '配偶',
  );

  static const FamilyMember zhangHongyuan = FamilyMember(
    id: 'person_zhang_hongyuan',
    familyId: familyId,
    branchId: 'branch_zhang',
    name: '张宏远',
    gender: Gender.male,
    generation: 7,
    birthYear: 1710,
    deathYear: 1780,
    birthPlace: '江南府 · 青溪村',
    occupation: '贡生',
    biography: '续修族谱，设义塾，教诲族中子弟。',
    relation: '子',
  );

  static const FamilyMember suShi = FamilyMember(
    id: 'person_su_shi',
    familyId: familyId,
    branchId: 'branch_zhang',
    name: '苏氏',
    gender: Gender.female,
    generation: 7,
    birthYear: 1715,
    deathYear: 1785,
    birthPlace: '江南府 · 苏桥',
    biography: '知书达理，工于书画。',
    relation: '配偶',
  );

  static const FamilyMember zhangYi = FamilyMember(
    id: 'person_zhang_yi',
    familyId: familyId,
    branchId: 'branch_zhang',
    name: '张一',
    gender: Gender.male,
    generation: 8,
    birthYear: 1998,
    birthPlace: '江南 · 青溪村',
    residence: '杭州',
    occupation: '建筑师',
    biography: '性格沉稳，天资聪颖，自幼随祖父修习家学，热心族中公益。',
  );

  static const FamilyMember yuMeng = FamilyMember(
    id: 'person_yu_meng',
    familyId: familyId,
    branchId: 'branch_yu',
    name: '余梦',
    gender: Gender.female,
    generation: 8,
    birthYear: 2000,
    birthPlace: '江南 · 烟溪',
    occupation: '教师',
    biography: '温婉耐心，喜好书法与旅行。',
    relation: '配偶',
  );

  static const FamilyMember zhangXu = FamilyMember(
    id: 'person_zhang_xu',
    familyId: familyId,
    branchId: 'branch_zhang',
    name: '张旭',
    gender: Gender.male,
    generation: 9,
    birthYear: 2019,
    birthPlace: '杭州',
    biography: '活泼好动，喜欢画画。',
    relation: '长子',
  );

  static const FamilyMember zhangYao = FamilyMember(
    id: 'person_zhang_yao',
    familyId: familyId,
    branchId: 'branch_zhang',
    name: '张瑶',
    gender: Gender.female,
    generation: 9,
    birthYear: 2020,
    birthPlace: '杭州',
    biography: '爱笑，喜欢听太爷爷讲古。',
    relation: '长女',
  );

  static const FamilyMember zhangLang = FamilyMember(
    id: 'person_zhang_lang',
    familyId: familyId,
    branchId: 'branch_zhang',
    name: '张浪',
    gender: Gender.male,
    generation: 9,
    birthYear: 2018,
    birthPlace: '杭州',
    biography: '精力充沛，热爱自然。',
    relation: '次子',
  );

  static const FamilyMember zhangXue = FamilyMember(
    id: 'person_zhang_xue',
    familyId: familyId,
    branchId: 'branch_zhang',
    name: '张雪',
    gender: Gender.female,
    generation: 9,
    birthYear: 2017,
    birthPlace: '杭州',
    biography: '安静细心，喜欢读书。',
    relation: '次女',
  );

  static const FamilyMember zhangXuan = FamilyMember(
    id: 'person_zhang_xuan',
    familyId: familyId,
    branchId: 'branch_zhang',
    name: '张轩',
    gender: Gender.male,
    generation: 9,
    birthYear: 2021,
    birthPlace: '杭州',
    biography: '家中幼子，聪明伶俐。',
    relation: '三子',
  );

  static const FamilyMember zhangXiaohu = FamilyMember(
    id: 'person_zhang_xiaohu',
    familyId: familyId,
    branchId: 'branch_zhang',
    name: '张小虎',
    gender: Gender.male,
    generation: 10,
    birthYear: 2023,
    birthPlace: '杭州',
    biography: '虎头虎脑，是家中开心果。',
    relation: '长孙',
  );

  static const FamilyMember zhangXiaoyu = FamilyMember(
    id: 'person_zhang_xiaoyu',
    familyId: familyId,
    branchId: 'branch_zhang',
    name: '张小雨',
    gender: Gender.female,
    generation: 10,
    birthYear: 2024,
    birthPlace: '杭州',
    biography: '爱笑的小女孩。',
    relation: '长孙女',
  );

  static const FamilyMember zhangXiaoyue = FamilyMember(
    id: 'person_zhang_xiaoyue',
    familyId: familyId,
    branchId: 'branch_zhang',
    name: '张小月',
    gender: Gender.female,
    generation: 10,
    birthYear: 2025,
    birthPlace: '杭州',
    biography: '家中最小的妹妹。',
    relation: '次孙女',
  );

  static const FamilyMember zhangXiaoyuJunior = FamilyMember(
    id: 'person_zhang_xiaoyu_junior',
    familyId: familyId,
    branchId: 'branch_zhang',
    name: '张小宇',
    gender: Gender.male,
    generation: 10,
    birthYear: 2026,
    birthPlace: '杭州',
    biography: '族中新添的小成员。',
    relation: '次孙',
  );

  static const List<FamilyMember> treeMembers = [
    zhangTianming,
    linShi,
    zhangHongyuan,
    suShi,
    zhangYi,
    yuMeng,
    zhangXu,
    zhangYao,
    zhangLang,
    zhangXue,
    zhangXuan,
    zhangXiaohu,
    zhangXiaoyu,
    zhangXiaoyue,
    zhangXiaoyuJunior,
  ];

  static const List<FamilyMember> directory = [
    zhangTianming,
    linShi,
    zhangHongyuan,
    suShi,
    zhangYi,
    yuMeng,
    zhangXu,
    zhangYao,
    zhangLang,
    zhangXue,
    zhangXuan,
    zhangXiaohu,
    zhangXiaoyu,
    zhangXiaoyue,
    zhangXiaoyuJunior,
    currentUser,
  ];

  static FamilyMember? memberById(String id) {
    for (final member in directory) {
      if (member.id == id) return member;
    }
    return null;
  }

  static FamilyMember? spouseOf(String personId) =>
      memberById(_spouseIds[personId] ?? '');

  static FamilyMember? fatherOf(String personId) =>
      memberById(_fatherIds[personId] ?? '');

  static FamilyMember? motherOf(String personId) =>
      memberById(_motherIds[personId] ?? '');

  static List<FamilyMember> childrenOf(String personId) {
    final ids = _childIds[personId] ?? const <String>[];
    return ids
        .map(memberById)
        .whereType<FamilyMember>()
        .toList(growable: false);
  }

  // Relationships are explicit in the demo, mirroring the future Relationship
  // records rather than inferring family links from names.
  static const Map<String, String> _spouseIds = {
    'person_zhang_tianming': 'person_lin_shi',
    'person_lin_shi': 'person_zhang_tianming',
    'person_zhang_hongyuan': 'person_su_shi',
    'person_su_shi': 'person_zhang_hongyuan',
    'person_zhang_yi': 'person_yu_meng',
    'person_yu_meng': 'person_zhang_yi',
  };

  static const Map<String, String> _fatherIds = {
    'person_zhang_hongyuan': 'person_zhang_tianming',
    'person_zhang_yi': 'person_zhang_hongyuan',
    'person_zhang_xu': 'person_zhang_yi',
    'person_zhang_yao': 'person_zhang_yi',
    'person_zhang_lang': 'person_zhang_yi',
    'person_zhang_xue': 'person_zhang_yi',
    'person_zhang_xuan': 'person_zhang_yi',
    'person_zhang_xiaoyue': 'person_zhang_xuan',
    'person_zhang_xiaoyu_junior': 'person_zhang_xuan',
  };

  static const Map<String, String> _motherIds = {
    'person_zhang_hongyuan': 'person_lin_shi',
    'person_zhang_yi': 'person_su_shi',
    'person_zhang_xu': 'person_yu_meng',
    'person_zhang_yao': 'person_yu_meng',
    'person_zhang_lang': 'person_yu_meng',
    'person_zhang_xue': 'person_yu_meng',
    'person_zhang_xuan': 'person_yu_meng',
    'person_zhang_xiaohu': 'person_zhang_yao',
    'person_zhang_xiaoyu': 'person_zhang_yao',
  };

  static const Map<String, List<String>> _childIds = {
    'person_zhang_tianming': ['person_zhang_hongyuan'],
    'person_lin_shi': ['person_zhang_hongyuan'],
    'person_zhang_hongyuan': ['person_zhang_yi'],
    'person_su_shi': ['person_zhang_yi'],
    'person_zhang_yi': [
      'person_zhang_xu',
      'person_zhang_yao',
      'person_zhang_lang',
      'person_zhang_xue',
      'person_zhang_xuan',
    ],
    'person_yu_meng': [
      'person_zhang_xu',
      'person_zhang_yao',
      'person_zhang_lang',
      'person_zhang_xue',
      'person_zhang_xuan',
    ],
    'person_zhang_yao': ['person_zhang_xiaohu', 'person_zhang_xiaoyu'],
    'person_zhang_xuan': ['person_zhang_xiaoyue', 'person_zhang_xiaoyu_junior'],
  };

  static const List<FamilyActivity> activities = [
    FamilyActivity(
      id: 'activity_1',
      actor: '张远',
      action: '提交了资料修改申请',
      detail: '申请修改：个人基本信息',
      time: '2025-04-28 16:32',
      kind: ActivityKind.request,
      needsReview: true,
    ),
    FamilyActivity(
      id: 'activity_2',
      actor: '王五',
      action: '加入了家族',
      detail: '加入家支：长房',
      time: '2025-04-28 14:20',
      kind: ActivityKind.joined,
    ),
    FamilyActivity(
      id: 'activity_3',
      actor: '系统',
      action: '备份了家族数据',
      detail: '数据已自动备份',
      time: '2025-04-28 10:15',
      kind: ActivityKind.backup,
    ),
    FamilyActivity(
      id: 'activity_4',
      actor: '张一',
      action: '完善了人物档案',
      detail: '补充籍贯与生平',
      time: '2025-04-27 20:08',
      kind: ActivityKind.approved,
    ),
  ];

  static const List<EditRequest> requests = [
    EditRequest(
      id: 'request_1',
      title: '个人基本信息修改',
      targetName: '张三',
      changedFields: ['居住地', '职业'],
      submittedAt: '2025-04-28 16:32',
      status: RequestStatus.pending,
    ),
    EditRequest(
      id: 'request_2',
      title: '头像资料更新',
      targetName: '张一',
      changedFields: ['头像'],
      submittedAt: '2025-04-18 09:20',
      status: RequestStatus.approved,
      reviewNote: '照片清晰，已同步至正式档案。',
      reviewedAt: '2025-04-19 11:02',
    ),
    EditRequest(
      id: 'request_3',
      title: '补充人物生平',
      targetName: '张宏远',
      changedFields: ['生平简介'],
      submittedAt: '2025-03-30 18:40',
      status: RequestStatus.rejected,
      reviewNote: '资料来源不明确，请补充出处后重新提交。',
      reviewedAt: '2025-03-31 10:15',
    ),
  ];

  static const List<FamilyMessage> messages = [
    FamilyMessage(
      id: 'message_1',
      title: '资料修改申请待审核',
      body: '你提交的「个人基本信息修改」已进入审核队列，族长审核后将通知你。',
      time: '今天 16:32',
      kind: MessageKind.review,
      unread: true,
    ),
    FamilyMessage(
      id: 'message_2',
      title: '家族春季祭祖活动',
      body: '长房将于清明前组织祭祖，请有意参加的族人于本周日前报名。',
      time: '昨天 09:10',
      kind: MessageKind.family,
      unread: true,
    ),
    FamilyMessage(
      id: 'message_3',
      title: '头像资料审核通过',
      body: '张一的头像更新申请已通过，正式档案已同步。',
      time: '04-19 11:02',
      kind: MessageKind.review,
    ),
    FamilyMessage(
      id: 'message_4',
      title: '数据备份完成',
      body: '系统已完成 4 月 28 日的家族数据自动备份。',
      time: '04-28 10:15',
      kind: MessageKind.system,
    ),
  ];

  static const List<({String name, int count})> branches = [
    (name: '长房', count: 46),
    (name: '二房', count: 32),
    (name: '三房', count: 28),
    (name: '迁杭支', count: 15),
    (name: '外迁支', count: 7),
  ];
}
