import 'package:lunar/lunar.dart';

import '../../services/api_models.dart';

class LunarDateInfo {
  const LunarDateInfo({
    required this.lunarYear,
    required this.lunarMonth,
    required this.lunarDay,
    required this.isLeapMonth,
    required this.solar,
    required this.lunarText,
    required this.solarText,
    required this.zodiac,
  });

  final int lunarYear;
  final int lunarMonth;
  final int lunarDay;
  final bool isLeapMonth;
  final DateTime solar;
  final String lunarText;
  final String solarText;
  final String zodiac;
}

class LunarDateUtils {
  static LunarDateInfo? fromSolar(DateTime date) {
    try {
      final lunar = Lunar.fromDate(date);
      return LunarDateInfo(
        lunarYear: lunar.getYear(),
        lunarMonth: lunar.getMonth().abs(),
        lunarDay: lunar.getDay(),
        isLeapMonth: lunar.getMonth() < 0,
        solar: DateUtils.dateOnly(date),
        lunarText: lunarTextOf(lunar),
        solarText: solarTextOf(date),
        zodiac: lunar.getYearShengXiao(),
      );
    } catch (_) {
      return null;
    }
  }

  static LunarDateInfo? fromLunar({
    required int year,
    required int month,
    required int day,
    required bool isLeapMonth,
  }) {
    try {
      final signedMonth = isLeapMonth ? -month : month;
      final lunar = Lunar.fromYmd(year, signedMonth, day);
      final solar = lunar.getSolar();
      final solarDate = DateTime(
        solar.getYear(),
        solar.getMonth(),
        solar.getDay(),
      );
      return LunarDateInfo(
        lunarYear: year,
        lunarMonth: month,
        lunarDay: day,
        isLeapMonth: isLeapMonth,
        solar: solarDate,
        lunarText: lunarTextOf(lunar),
        solarText: solarTextOf(solarDate),
        zodiac: lunar.getYearShengXiao(),
      );
    } catch (_) {
      return null;
    }
  }

  static String lunarTextOf(Lunar lunar) =>
      '${lunar.getYearInGanZhi()}年${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';

  /// 生肖按农历年计算。公历生日先转换为农历年，农历生日直接取所在农历年。
  static String zodiacOf(ApiPartialDate? date) {
    if (date == null || date.year == null) return '';
    final year = date.year!;
    if (date.calendar == 'lunar') {
      if (date.month != null && date.day != null) {
        return fromLunar(
              year: year,
              month: date.month!,
              day: date.day!,
              isLeapMonth: date.isLeapMonth,
            )?.zodiac ??
            _zodiacForLunarYear(year);
      }
      return _zodiacForLunarYear(year);
    }
    if (date.month != null && date.day != null) {
      return fromSolar(DateTime(year, date.month!, date.day!))?.zodiac ??
          _zodiacForLunarYear(year);
    }
    // 只有年份时无法判断是否在春节前，按该公历年的农历年后半段估算。
    return _zodiacForLunarYear(year);
  }

  static String _zodiacForLunarYear(int year) {
    try {
      return Lunar.fromYmd(year, 6, 1).getYearShengXiao();
    } catch (_) {
      return '';
    }
  }

  static String zodiacLabel(ApiPartialDate? date) {
    final zodiac = zodiacOf(date);
    return zodiac.isEmpty ? '' : '属$zodiac';
  }

  static String solarTextOf(DateTime date) =>
      '${date.year}年${date.month}月${date.day}日';

  static String describe(ApiPartialDate? date) {
    if (date == null || date.year == null) return '未记录';
    if (date.calendar == 'lunar') {
      final info = date.month == null || date.day == null
          ? null
          : fromLunar(
              year: date.year!,
              month: date.month!,
              day: date.day!,
              isLeapMonth: date.isLeapMonth,
            );
      if (info != null) {
        return '农历 ${info.lunarText} · 属${info.zodiac}\n公历 ${info.solarText}';
      }
      return '农历 ${date.year}年${date.month ?? ''}${date.day == null ? '' : '${date.day}日'}';
    }
    if (date.month == null || date.day == null) {
      return '${date.year}年（月日未记录）';
    }
    final solar = DateTime(date.year!, date.month!, date.day!);
    final lunar = fromSolar(solar);
    if (lunar != null) {
      return '公历 ${solarTextOf(solar)}\n农历 ${lunar.lunarText} · 属${lunar.zodiac}';
    }
    return '公历 ${solarTextOf(solar)}';
  }

  static String short(ApiPartialDate? date) {
    if (date == null || date.year == null) return '未记录';
    if (date.calendar == 'lunar') {
      final month = date.month == null
          ? ''
          : '${date.isLeapMonth ? '闰' : ''}${date.month}月';
      final day = date.day == null ? '' : '${date.day}日';
      return '农历 ${date.year}年$month$day';
    }
    final month = date.month == null ? '' : '${date.month}月';
    final day = date.day == null ? '' : '${date.day}日';
    return '公历 ${date.year}年$month$day';
  }
}

class DateUtils {
  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
