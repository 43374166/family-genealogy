import 'package:family_tree/core/lunar/lunar_utils.dart';
import 'package:family_tree/services/api_client.dart';
import 'package:family_tree/services/api_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zodiac follows the lunar new year boundary', () {
    final beforeNewYear = LunarDateUtils.fromSolar(DateTime(2024, 2, 9));
    final newYear = LunarDateUtils.fromSolar(DateTime(2024, 2, 10));
    expect(beforeNewYear?.zodiac, '兔');
    expect(newYear?.zodiac, '龙');
  });

  test('zodiac works for lunar and gregorian partial dates', () {
    expect(
      LunarDateUtils.zodiacOf(
        const ApiPartialDate(year: 2024, month: 1, day: 1, calendar: 'lunar'),
      ),
      '龙',
    );
    expect(
      LunarDateUtils.zodiacOf(
        const ApiPartialDate(year: 2024, month: 2, day: 10),
      ),
      '龙',
    );
    expect(
      LunarDateUtils.zodiacLabel(
        const ApiPartialDate(year: 1990, month: 1, day: 1, calendar: 'lunar'),
      ),
      '属马',
    );
    expect(LunarDateUtils.zodiacOf(null), '');
  });

  test('default API server is the online family server', () {
    expect(ApiConfig.defaultBaseUrl, 'https://family.fishdream.xyz:10443');
    expect(
      ApiConfig.normalizeStoredBaseUrl('http://192.168.1.201:8080/'),
      'https://family.fishdream.xyz:10443',
    );
    expect(
      ApiConfig.normalizeStoredBaseUrl('https://example.com'),
      'https://example.com',
    );
  });
}
