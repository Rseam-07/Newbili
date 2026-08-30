import 'package:PiliPlus/utils/android/legacy_account_migration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLegacyCookieHeader', () {
    test(
      'parses the required account cookies without truncating equals signs',
      () {
        final cookies = parseLegacyCookieHeader(
          'SESSDATA=a=b; bili_jct=csrf; DedeUserID=42; buvid3=device',
        );

        expect(cookies, isNotNull);
        expect(cookies!['SESSDATA'], 'a=b');
        expect(cookies['DedeUserID'], '42');
      },
    );

    test('rejects incomplete or malformed sessions', () {
      expect(
        parseLegacyCookieHeader('SESSDATA=value; DedeUserID=42'),
        isNull,
      );
      expect(
        parseLegacyCookieHeader(
          'SESSDATA=value; bili_jct=csrf; DedeUserID=not-a-number',
        ),
        isNull,
      );
    });

    test('removes line breaks from cookie values', () {
      final cookies = parseLegacyCookieHeader(
        'SESSDATA=value\ncontinued; bili_jct=csrf; DedeUserID=7',
      );

      expect(cookies?['SESSDATA'], 'valuecontinued');
    });
  });
}
