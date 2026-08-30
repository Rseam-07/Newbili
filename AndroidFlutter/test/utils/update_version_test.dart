import 'package:PiliPlus/utils/update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only newer semantic releases trigger an update', () {
    expect(isNewerReleaseVersion('v1.1.1', '1.1.0'), isTrue);
    expect(isNewerReleaseVersion('v1.2.0', '1.1.9'), isTrue);
    expect(isNewerReleaseVersion('v2.0.0', '1.9.9'), isTrue);
    expect(isNewerReleaseVersion('v1.1.0', '1.1.0'), isFalse);
    expect(isNewerReleaseVersion('v1.0.9', '1.1.0'), isFalse);
    expect(isNewerReleaseVersion('latest', '1.1.0'), isFalse);
  });
}
