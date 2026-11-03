import 'package:family_tree/features/family/web_login_qr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the familytree web-login payload', () {
    final parsed = parseWebLoginPayload(
      'familytree://web-login?v=1&id=12345678-abcd&secret=abcdefghijklmnopqrstuvwxyz0123456789',
    );
    expect(parsed, isNotNull);
    expect(parsed!.id, '12345678-abcd');
    expect(parsed.secret, 'abcdefghijklmnopqrstuvwxyz0123456789');
  });

  test('rejects unrelated or malformed QR codes', () {
    expect(
      parseWebLoginPayload(
        'https://example.com/web-login?id=12345678&secret=abcdefghijklmnopqrstuvwxyz',
      ),
      isNull,
    );
    expect(
      parseWebLoginPayload('familytree://join-family?code=ABCDEF'),
      isNull,
    );
    expect(
      parseWebLoginPayload(
        'familytree://web-login?id=short&secret=abcdefghijklmnopqrstuvwxyz',
      ),
      isNull,
    );
    expect(
      parseWebLoginPayload('familytree://web-login?id=12345678&secret=short'),
      isNull,
    );
    expect(parseWebLoginPayload(''), isNull);
  });
}
