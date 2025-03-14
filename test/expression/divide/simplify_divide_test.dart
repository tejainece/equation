import 'package:aryabhata/aryabhata.dart';
import 'package:aryabhata/variables.dart';
import 'package:test/test.dart';

import '../../testing.dart';

class _Test {
  final Eq eq;
  final Eq res;
  final String string;

  _Test(this.eq, this.res, this.string);

  static List<_Test> cases = [
    _Test(x / (y / z), (x * z) / y, 'x⋅z/y'),
    _Test(x / y / z, x / (y * z), 'x/(y⋅z)'),
  ];

  static List<_Test> nans = [
    // TODO _Test(x / Constant(0), Constant(double.infinity) * x, '∞⋅x'),
  ];
}

void main() {
  group('simplify.divide', () {
    test('test', () {
      for (final test in _Test.cases) {
        final res = test.eq.simplify();
        expect(res, EqEqualityMatcher(test.res));
        expect(res.toString(), test.string);
      }
    });
    test('nan', () {
      for (final test in _Test.nans) {
        final res = test.eq.simplify();
        expect(res, EqEqualityMatcher(test.res));
        expect(res.toString(), test.string);
      }
    });
  });
}
