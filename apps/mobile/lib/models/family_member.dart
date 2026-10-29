import 'package:flutter/foundation.dart';

enum Gender { male, female }

/// Core person record aligned with the fields proposed in the project plan.
///
/// The prototype stays local-only; the field names are intentionally close to
/// the future API contract so the data layer can be replaced without touching
/// the screens.
@immutable
class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.familyId,
    required this.branchId,
    required this.name,
    required this.gender,
    required this.generation,
    this.aliases = const [],
    this.birthYear,
    this.deathYear,
    this.birthPlace,
    this.residence,
    this.occupation,
    this.biography,
    this.relation,
    this.tags = const [],
    this.isCurrentUser = false,
  });

  final String id;
  final String familyId;
  final String branchId;
  final String name;
  final List<String> aliases;
  final Gender gender;
  final int generation;
  final int? birthYear;
  final int? deathYear;
  final String? birthPlace;
  final String? residence;
  final String? occupation;
  final String? biography;

  /// Describes how the person is attached to the focused branch in the demo,
  /// e.g. 配偶 / 长子 / 女儿. Empty for the branch owner.
  final String? relation;
  final List<String> tags;
  final bool isCurrentUser;

  bool get isFemale => gender == Gender.female;
  bool get isElder => age >= 60;
  bool get isChild => age <= 16;
  bool get isLiving => deathYear == null;

  int get age {
    final year = birthYear;
    if (year == null) return 0;
    return (deathYear ?? DateTime.now().year) - year;
  }

  String get generationLabel => generationLabelFor(generation);

  static String generationLabelFor(int generation) =>
      '第${_chineseNumber(generation)}世';

  String get lifespan {
    final birth = birthYear?.toString();
    if (birth == null) return '生卒不详';
    if (deathYear != null) return '$birth–$deathYear';
    return '$birth–';
  }

  String get ageLabel {
    if (birthYear == null) return '生辰不详';
    if (deathYear != null) return '享年 ${deathYear! - birthYear!} 岁';
    return '${DateTime.now().year - birthYear!} 岁';
  }

  static String _chineseNumber(int value) {
    const digits = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    if (value < 10) return digits[value];
    if (value < 20) return '十${value == 10 ? '' : digits[value % 10]}';
    if (value < 100) {
      return '${digits[value ~/ 10]}十${value % 10 == 0 ? '' : digits[value % 10]}';
    }
    return '$value';
  }
}
