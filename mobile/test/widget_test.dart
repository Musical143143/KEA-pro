import 'package:flutter_test/flutter_test.dart';
import 'package:kea_pro/main.dart';

void main() {
  test('localization helper returns the selected language', () {
    expect(T.s(false, 'Home', 'ಮುಖಪುಟ'), 'Home');
    expect(T.s(true, 'Home', 'ಮುಖಪುಟ'), 'ಮುಖಪುಟ');
  });
}
