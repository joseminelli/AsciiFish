import 'package:flutter_test/flutter_test.dart';

import 'package:ascii_fish_pet/platform/update_service.dart';

void main() {
  test('compara versões', () {
    expect(UpdateService.isNewer('1.0.1', '1.0.0'), isTrue);
    expect(UpdateService.isNewer('1.10.0', '1.9.9'), isTrue);
    expect(UpdateService.isNewer('2.0', '1.9.9'), isTrue);
    expect(UpdateService.isNewer('1.0.0', '1.0.0'), isFalse);
    expect(UpdateService.isNewer('1.0.0', '1.0.0+5'), isFalse);
    expect(UpdateService.isNewer('0.9.9', '1.0.0'), isFalse);
  });
}
