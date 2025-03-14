import 'package:aryabhata/aryabhata.dart';
import 'package:aryabhata/variables.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import '../../testing.dart';

class _TestCase {
  final Eq eq;
  final Eq res;

  _TestCase(this.eq, this.res);

  static final cases = <_TestCase>[
    _TestCase(x * x, x.pow(Eq.c(2))),
    _TestCase(x * x * x, x.pow(Eq.c(3))),
    _TestCase(x * (Eq.c(2) * x) * x, Eq.c(2) * x.pow(Eq.c(3))),
    _TestCase(x.pow(Eq.c(2)) * x.pow(Eq.c(3)), x.pow(Eq.c(5))),

    _TestCase(-x * x, -x.pow(Eq.c(2))),

    _TestCase(x.pow(y) * x.pow(y), x.pow(Eq.c(2) * y)),
  ];

  static final extras = <_TestCase>[
    _TestCase(Times([x]), x),
    ];
}

void main() {
  group('Times.combineMultiplications', () {
    test('test', () {
      for (final tc in _TestCase.cases) {
        final res = tc.eq.combineMultiplications();
        expect(res, EqEqualityMatcher(tc.res));
      }
    });
    test('extras', () {
      for (final tc in _TestCase.extras) {
        final res = tc.eq.combineMultiplications();
        expect(res, EqEqualityMatcher(tc.res));
      }
    });
  });
}
