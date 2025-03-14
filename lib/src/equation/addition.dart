import 'dart:math';

import 'package:collection/collection.dart';
import 'package:aryabhata/aryabhata.dart';
import 'package:number_factorization/number_factorization.dart';

class Plus extends Eq {
  final UnmodifiableListView<Eq> expressions;

  Plus._(Iterable<Eq> expressions)
    : assert(expressions.isNotEmpty),
      expressions = UnmodifiableListView<Eq>(expressions.toList());

  factory Plus(Iterable expressions) {
    expressions = expressions.map((e) => Eq.from(e)).toList();
    final ret = <Eq>[];
    for (final e in expressions) {
      if (e is Plus) {
        ret.addAll(e.expressions);
      } else if (e is Times && e.expressions.length == 1) {
        ret.add(e.expressions.first);
      } else if (e is Constant && e.value.isEqual(0)) {
        continue;
      } else if (e is Minus &&
          e.expression is Constant &&
          (e.expression as Constant).value.isEqual(0)) {
        continue;
      } else {
        ret.add(e);
      }
    }
    return Plus._(ret);
  }

  factory Plus.fromJson(Map map) {
    assert(map['type'] == EqJsonType.plus.name);
    final List expressions = map['expressions'];
    return Plus(expressions.map((e) => Eq.from(e)).toList());
  }

  @override
  Eq substitute(Map<String, Eq> substitutions) =>
      Plus(expressions.map((e) => e.substitute(substitutions)));

  @override
  Eq dissolveConstants({int? depth}) {
    if (depth != null) {
      depth = depth - 1;
      if (depth < 0) return this;
    }
    final ret = <Eq>[];
    num constant = 0;
    for (int i = 0; i < expressions.length; i++) {
      Eq e = expressions[i];
      e = e.dissolveConstants(depth: depth);
      if (!e.isSimpleConstant()) {
        ret.add(e);
        continue;
      }
      constant += e.toConstant()!;
    }
    if (ret.isEmpty) {
      return Constant(constant);
    } else if (!constant.isEqual(0)) {
      ret.insert(0, Eq.c(constant).dissolveMinus());
    }
    return Plus(ret);
  }

  @override
  num? toConstant() {
    num constant = 0;
    for (var e in expressions) {
      final c = e.toConstant();
      if (c == null) {
        return null;
      }
      constant += c;
    }
    return constant;
  }

  @override
  Eq factorOutMinus({int? depth}) {
    if (depth != null) {
      depth = depth - 1;
      if (depth < 0) return this;
    }
    final list =
        expressions.map((e) => e.factorOutMinus(depth: depth)).toList();
    final count = list.fold(
      0,
      (int count, Eq v) => count + (v is Minus ? 1 : 0),
    );
    if (count > list.length / 2) {
      return Minus(
        Plus(
          list.map(
            (e) =>
                e is Minus
                    ? e.expression
                    : Minus(e).factorOutMinus(depth: depth),
          ),
        ),
      );
    }
    return Plus(list);
  }

  @override
  Eq dropMinus() => this;

  @override
  Eq dissolveMinus({int? depth}) {
    if (depth != null) {
      depth = depth - 1;
      if (depth < 0) return this;
    }
    final list = <Eq>[];
    for (final e in expressions) {
      list.add(e.dissolveMinus(depth: depth));
    }
    /*final count = list.fold(
      0,
      (int count, Eq v) => count + (v is Minus ? 1 : 0),
    );
    if (count > list.length / 2) {
      return Minus(Plus(list.map((e) => e is Minus ? e.expression : Minus(e))));
    }*/
    return Plus(list);
  }

  @override
  (num, num)? toComplexConstant() {
    num real = 0;
    num imaginary = 0;
    for (Eq e in expressions) {
      num minus = 1;
      if (e is Minus) {
        minus = -1;
        e = e.expression;
      }
      if (e.isSimpleConstant()) {
        real += -e.toConstant()!;
        continue;
      } else if (e is Imaginary) {
        imaginary += -1;
        continue;
      } else if (e is! Times) {
        return null;
      }
      if (e.expressions.length != 2) {
        return null;
      }
      final rem = e.expressions.where((e) => e != i).toList();
      if (rem.length != 1) {
        return null;
      } else if (!rem.first.isSimpleConstant()) {
        return null;
      }
      imaginary += minus * rem.first.toConstant()!;
    }
    return (real, imaginary);
  }

  @override
  Eq distributeMinus() => Plus(expressions.map((e) => e.distributeMinus()));

  @override
  Eq dissolveImaginary() => Plus(expressions.map((e) => e.dissolveImaginary()));

  @override
  Eq shrink({int? depth}) {
    if (depth != null) {
      depth = depth - 1;
      if (depth < 0) return this;
    }
    final expressions = <Eq>[];
    for (Eq e in this.expressions) {
      e = e.shrink(depth: depth);
      if (e is Plus) {
        expressions.addAll(e.expressions);
        continue;
      }
      if (e is Minus && e.expression is Plus) {
        expressions.addAll(
          (e.expression as Plus).expressions.map((e) => Minus(e)),
        );
        continue;
      }
      expressions.add(e);
    }
    if (expressions.length == 1) {
      return expressions.first;
    }
    return Plus(expressions);
  }

  @override
  Eq combineAdditions({int? depth}) {
    if (depth != null) {
      depth = depth - 1;
      if (depth < 0) return this;
    }
    var ret = <Eq>[];
    for (var term in expressions) {
      ret.add(term.combineAdditions(depth: depth));
    }
    for (int i = 0; i < ret.length; i++) {
      for (int j = i + 1; j < ret.length; j++) {
        final a = ret[i];
        final b = ret[j];
        final s = tryAddTerms(a, b);
        if (s != null) {
          ret[i] = s;
          ret.removeAt(j);
          j--;
          continue;
        }
      }
    }
    return Plus(ret);
  }

  (List<Times>, List<Times>) separateIndividualDivision() {
    List<Times> parts =
        expressions.map((e) => e.multiplicativeTerms()).toList();
    List<Times> numerators = [];
    List<Times> denominators = [];
    for (final part in parts) {
      final (numerator, denominator) = part.separateDivision();
      if (numerator.isNotEmpty) {
        numerators.add(Times(numerator));
      } else {
        numerators.add(Times([one]));
      }
      if (denominator.isNotEmpty) {
        denominators.add(Times(denominator));
      } else {
        denominators.add(Times([one]));
      }
    }
    return (numerators, denominators);
  }

  @override
  (List<Eq> numerators, List<Eq> denominators) separateDivision() {
    final terms = multiplicativeTerms().expressions;
    final numerators = <Eq>[];
    final denominators = <Eq>[];
    for (final term in terms) {
      if (term is! Power) {
        numerators.add(term);
        continue;
      }
      final denom = term.toDenominator;
      if (denom == null) {
        numerators.add(term);
        continue;
      }
      denominators.add(denom);
    }
    return (numerators, denominators);
  }

  /*@override
  Times multiplicativeTerms() {
    final (numerators, denominators) = _separateDivision();
    final factors = <Eq>[];
    List<Eq> ret = [];
    for (int i = 0; i < numerators.length; i++) {
      final list = <Eq>[...numerators[i].expressions];
      list.addAll(denominators[i].expressions.map((e) => e.pow(-1)));
      ret.add(Times(list));
    }
    List<Eq> possibleFactors = numerators.fold(
      <Eq>[],
          (ret, eq) => ret..addAll(eq.expressions),
    );
    for (final factor in possibleFactors) {
      List<Eq>? object = tryFactorizeBy(factor, ret);
      if (object != null) {
        factors.add(factor);
        ret = object;
        continue;
      }
    }
    possibleFactors = denominators.fold(
      <Eq>[],
      (ret, eq) => ret..addAll(eq.expressions),
    );
    for (Eq factor in possibleFactors) {
      factor = factor.lpow(-1);
      List<Eq>? object = tryFactorizeBy(factor, ret);
      if (object != null) {
        factors.add(factor);
        ret = object;
        continue;
      }
    }
    // TODO
    if (factors.isEmpty) {
      return Times([this]);
    }
    return Times([...factors, Plus(ret)]);
  }*/

  @override
  Times multiplicativeTerms() {
    List<Times> parts = [];
    List<Eq> possibles;
    {
      Set<Eq> possiblesSet = {};
      for (final e in expressions) {
        final t = e.multiplicativeTerms();
        parts.add(t);
        possiblesSet.addAll(t.expressions);
      }
      possibles = possiblesSet.toList();
    }
    List<Eq> ret = parts.toList();
    final factors = <Eq>[];
    for (var possible in possibles) {
      List<Eq>? object = tryFactorizeBy(possible, ret);
      if (object != null) {
        factors.add(possible);
        ret = object;
        continue;
      }
    }
    final (numerator, denominators) = commonDenominators(ret);
    factors.addAll(denominators.map((e) => e.lpow(-1)));
    if (factors.isEmpty) {
      return Times([numerator]);
    }
    return Times([...factors, numerator]);
  }

  static (Eq numerator, List<Eq> denominators) commonDenominators(
    List<Eq> terms,
  ) {
    var (numerators, denominators) = terms[0].separateDivision();
    Eq numerator = Times(numerators);
    for (int i = 1; i < terms.length; i++) {
      final term2 = terms[i];
      (numerator, denominators) = commonDenominators2Terms(
        numerator,
        denominators,
        term2,
      );
    }
    return (numerator, denominators);
  }

  static (Eq numerator, List<Eq> denominators) commonDenominators2Terms(
    Eq numerator,
    List<Eq> term1Denominators,
    Eq term2,
  ) {
    final (term2Numerators, term2Denominators) = term2.separateDivision();
    final factors = <Eq>[];
    final List<Eq> possible = [...term1Denominators, ...term2Denominators];
    List<Eq> denominatorsTerms = <Eq>[
      Times(term1Denominators),
      Times(term2Denominators),
    ];
    for (final factor in possible) {
      final div = tryFactorizeBy(factor, denominatorsTerms);
      if (div == null) continue;
      factors.add(factor);
      denominatorsTerms = div;
    }
    numerator = Times([
      Plus([
        numerator * denominatorsTerms[1] +
            Times(term2Numerators) * denominatorsTerms[0],
      ]),
    ]);
    return (
      numerator,
      Times([
        ...factors,
        ...denominatorsTerms,
      ]).multiplicativeTerms().expressions.toList(),
    );
  }

  @override
  Eq factorOutAddition() {
    final factors = <Eq>[];
    var ret = expressions.toList();
    final terms = expressions.first.multiplicativeTerms().expressions;
    for (final t in terms) {
      if (t is Constant && t.value.isInt) {
        int c = t.value.round().abs();
        middle:
        while (true) {
          final facs = integerFactorization(c).where((e) => e != 1);
          for (final f in facs) {
            final tmp = tryFactorizeBy(Eq.c(f.toDouble()), ret);
            if (tmp == null) continue;
            factors.add(Eq.c(f.toDouble()));
            ret = tmp;
            c = (c / f).round();
            continue middle;
          }
          break;
        }
        continue;
      }
      final tmp = tryFactorizeBy(t, ret);
      if (tmp == null) continue;
      factors.add(t);
      ret = tmp;
    }
    if (factors.isEmpty) {
      return this;
    }
    return Times([...factors, Plus(ret)]);
  }

  Plus expandingMultiply(Eq s) {
    if (s is! Plus) {
      s = Plus([s]);
    }
    var ret = <Eq>[];
    for (var e1 in expressions) {
      for (var e2 in s.expressions) {
        ret.add(e1 * e2);
      }
    }
    return Plus(ret);
  }

  Eq equationOf(Variable v) {
    var leftExps = <Eq>[];
    var rightExps = <Eq>[];
    for (var e in expressions) {
      if (e.hasVariable(v)) {
        leftExps.add(e);
        continue;
      }
      rightExps.add(Minus(e));
    }
    if (leftExps.isEmpty) {
      return Constant(0);
    }
    Eq left;
    {
      List<Eq>? tmp = Plus.tryFactorizeBy(v, leftExps);
      if (tmp == null || tmp.any((e) => e.hasVariable(v))) {
        throw UnimplementedError('Only linear equations are supported');
      }
      if (tmp.isEmpty) {
        left = Constant(1);
      } else if (tmp.length == 1) {
        left = tmp[0];
      } else {
        left = Plus(tmp);
      }
    }
    Eq right;
    if (rightExps.isEmpty) {
      right = Constant(0);
    } else if (rightExps.length == 1) {
      right = rightExps[0];
    } else {
      right = Plus(rightExps);
    }
    return (right / left).simplify();
  }

  @override
  (num, Plus) separateConstant() {
    final separated = expressions.map((e) => e.separateConstant()).toList();
    final constants = separated.map((e) => e.$1).toList();
    num gcd = gcdAll(constants.map((e) => e.abs()));
    // Separate sign
    final numNeg = constants.fold(0, (int v, num c) => c.isNegative ? ++v : v);
    if (numNeg > constants.length / 2) {
      gcd = -gcd;
    }
    return (
      gcd,
      Plus(
        separated.map((e) {
          final c = e.$1 / gcd;
          if (c.isEqual(1)) return e.$2;
          return (Constant(c) * e.$2).dissolveMinus(depth: 1);
        }),
      ),
    );
  }

  @override
  Eq expandMultiplications({int? depth}) {
    if (depth != null) {
      depth = depth - 1;
      if (depth < 0) return this;
    }
    return Plus(expressions.map((e) => e.expandMultiplications(depth: depth)));
  }

  @override
  Eq expandPowers({int? depth}) {
    if (depth != null) {
      depth = depth - 1;
      if (depth < 0) return this;
    }
    final list = <Eq>[];
    for (final e in expressions) {
      list.add(e.expandPowers(depth: depth));
    }
    return Plus(list);
  }

  @override
  Eq distributeExponent({int? depth}) {
    if (depth != null) {
      depth = depth - 1;
      if (depth < 0) return this;
    }
    return Plus(expressions.map((e) => e.distributeExponent(depth: depth)));
  }

  @override
  Eq expandDivision({int? depth}) {
    if (depth != null) {
      depth = depth - 1;
      if (depth < 0) return this;
    }
    return Plus(expressions.map((e) => e.expandDivision(depth: depth)));
  }

  @override
  Eq combineMultiplications({int? depth}) {
    if (depth != null) {
      depth = depth - 1;
      if (depth < 0) return this;
    }
    final list = <Eq>[];
    for (final e in expressions) {
      list.add(e.combineMultiplications(depth: depth));
    }
    return Plus(list);
  }

  @override
  Eq combinePowers({int? depth}) {
    if (depth != null) {
      depth = depth - 1;
      if (depth < 0) return this;
    }
    final list = <Eq>[];
    for (final e in expressions) {
      list.add(e.combinePowers(depth: depth));
    }
    return Plus(list);
  }

  @override
  Eq dissolvePowerOfPower({int? depth}) {
    if (depth != null) {
      depth = depth - 1;
      if (depth < 0) return this;
    }
    final list = <Eq>[];
    for (final e in expressions) {
      list.add(e.dissolvePowerOfPower(depth: depth));
    }
    return Plus(list);
  }

  @override
  Eq dissolvePowerOfComplex({int? depth}) {
    if (depth != null) {
      depth = depth - 1;
      if (depth < 0) return this;
    }
    final list = <Eq>[];
    for (final e in expressions) {
      list.add(e.dissolvePowerOfComplex(depth: depth));
    }
    return Plus(list);
  }

  @override
  Eq rationalizeComplexDenominator() {
    final list = <Eq>[];
    for (final e in expressions) {
      list.add(e.rationalizeComplexDenominator());
    }
    return Plus(list);
  }

  @override
  Eq? tryCancelDivision(Eq other) {
    if (isSame(other)) return one;
    if (isSame(Minus(other))) return -one;
    final ret = tryFactorizeBy(other, expressions);
    if (ret == null) {
      return null;
    }
    return Plus(ret);
  }

  @override
  Eq reduceDivisions({int? depth}) {
    if (depth != null) {
      depth = depth - 1;
      if (depth < 0) return this;
    }
    final list = <Eq>[];
    for (final e in expressions) {
      list.add(e.reduceDivisions(depth: depth));
    }
    return Plus(list);
  }

  @override
  bool get isSingle => false;

  @override
  bool needsParenthesis({bool noMinus = false}) {
    if (noMinus && expressions.first.isNegative) {
      return true;
    }
    if (expressions.length != 1) return true;
    return expressions[0].needsParenthesis(noMinus: noMinus);
  }

  @override
  bool get isNegative => false;

  @override
  bool isSimpleConstant() => expressions.every((e) => e.isSimpleConstant());

  @override
  Simplification? canSimplify() {
    for (final e in expressions) {
      final s = e.canSimplify();
      if (s != null) return s;
    }
    if (canShrink()) return Simplification.shrink;
    if (canDissolveConstants()) return Simplification.dissolveConstants;
    if (canCombineAdditions()) return Simplification.combineAdditions;
    return null;
  }

  @override
  bool hasVariable(Variable v) => expressions.any((e) => e.hasVariable(v));

  @override
  bool isSame(Eq otherSimplified, [double epsilon = 1e-6]) {
    final thisSimplified = simplify();
    otherSimplified = otherSimplified.simplify();
    if (thisSimplified is! Plus) {
      return thisSimplified.isSame(otherSimplified, epsilon);
    }
    if (otherSimplified is! Plus) {
      // TODO handle UnaryMinus
      return false;
    }
    if (thisSimplified.expressions.length !=
        otherSimplified.expressions.length) {
      return false;
    }
    final otherExps = otherSimplified.expressions.toList();
    for (final item in thisSimplified.expressions) {
      final match = otherExps.indexWhere(
        (otherItem) => otherItem.isSame(item, epsilon),
      );
      if (match == -1) {
        return false;
      }
      otherExps.removeAt(match);
    }
    return true;
  }

  @override
  bool canDissolveConstants() {
    int countConstants = 0;
    for (int i = 0; i < expressions.length; i++) {
      final e = expressions[i];
      if (e.canDissolveConstants()) return true;
      if (!e.isSimpleConstant()) continue;
      if (i > 0) return true;
      countConstants++;
    }
    return countConstants > 1;
  }

  @override
  bool canDissolveMinus() {
    /*int countMinus = 0;
    for (final e in expressions) {
      if (e.canDissolveMinus()) return true;
      if (e is Minus) countMinus++;
    }
    return countMinus > expressions.length / 2;*/
    return expressions.any((e) => e.canDissolveMinus());
  }

  @override
  bool canDissolveImaginary() =>
      expressions.any((e) => e.canDissolveImaginary());

  @override
  bool canShrink() {
    for (final e in expressions) {
      if (e.canShrink()) return true;
      if (e is Plus) return true;
      if (e is Minus && e.expression is Plus) return true;
    }
    return expressions.length == 1;
  }

  @override
  bool canFactorOutAddition() {
    throw UnimplementedError();
    // TODO
    return false;
  }

  @override
  bool canCombineAdditions() {
    for (final e in expressions) {
      if (e.canCombineAdditions()) return true;
    }
    for (int i = 0; i < expressions.length; i++) {
      for (int j = i + 1; j < expressions.length; j++) {
        Eq a = expressions[i];
        Eq b = expressions[j];
        if (canAddTerms(a, b)) return true;
      }
    }
    return false;
  }

  @override
  bool canCombineMultiplications({int? depth}) {
    if (depth != null) {
      depth = depth - 1;
      if (depth < 0) return false;
    }
    for (final e in expressions) {
      if (e.canCombineMultiplications(depth: depth)) {
        return true;
      }
    }
    return false;
  }

  @override
  bool canExpandMultiplications() =>
      expressions.any((e) => e.canExpandMultiplications());

  @override
  bool canReduceDivisions() => expressions.any((e) => e.canReduceDivisions());

  @override
  bool canCombinePowers() => expressions.any((e) => e.canCombinePowers());

  @override
  bool canExpandPowers() => expressions.any((e) => e.canExpandPowers());

  @override
  bool canDissolvePowerOfPower() {
    for (final e in expressions) {
      if (e.canDissolvePowerOfPower()) return true;
    }
    return false;
  }

  @override
  bool canDissolvePowerOfComplex() {
    for (final e in expressions) {
      if (e.canDissolvePowerOfComplex()) return true;
    }
    return false;
  }

  @override
  bool canRationalizeComplexDenominator() {
    for (final e in expressions) {
      if (e.canRationalizeComplexDenominator()) return true;
    }
    return false;
  }

  @override
  bool canDistributeExponent() {
    for (final e in expressions) {
      if (e.canDistributeExponent()) return true;
    }
    return false;
  }

  @override
  String toString({EquationPrintSpec spec = const EquationPrintSpec()}) {
    final sb = StringBuffer();
    for (int i = 0; i < expressions.length; i++) {
      Eq expression = expressions[i];
      if (expression is Minus) {
        sb.write(spec.minus);
        expression = expression.expression;
      } else {
        if (i > 0) {
          sb.write(spec.plus);
        }
      }
      bool needsParen = expression.needsParenthesis(noMinus: true);
      if (needsParen) {
        sb.write(spec.lparen);
      }
      sb.write(expression.toString(spec: spec));
      if (needsParen) {
        sb.write(spec.rparen);
      }
    }
    return sb.toString();
  }

  /*
  @override
  String toString({EquationPrintSpec spec = const EquationPrintSpec()}) {
    final sb = StringBuffer();
    sb.write(expressions.first.toString(spec: spec));
    for (int i = 1; i < expressions.length; i++) {
      var (c, e) = expressions[i].separateConstant();
      if (c.isNegative) {
        sb.write(spec.minus);
      } else {
        sb.write(spec.plus);
      }
      c = c.abs();
      bool hasC = false;
      if ((c - 1).abs() > 1e-6) {
        sb.write(c.stringMaybeInt);
        hasC = true;
      }
      if (!(e.toConstant()?.isEqual(1) ?? false) || !hasC) {
        if (hasC) sb.write(spec.times);
        if (e.isLone || e is Times) {
          sb.write(e.toString(spec: spec));
        } else {
          sb.write(spec.lparen);
          sb.write(e.toString(spec: spec));
          sb.write(spec.rparen);
        }
      }
    }
    return sb.toString();
  }*/

  @override
  Map<String, dynamic> toJson() => {
    'type': EqJsonType.plus.name,
    'expressions': expressions.map((e) => e.toJson()).toList(),
  };

  @override
  int get hashCode => Object.hashAll(expressions);

  @override
  bool operator ==(Object other) =>
      other is Plus &&
      DeepCollectionEquality.unordered().equals(expressions, other.expressions);

  static List<Eq>? tryFactorizeBy(Eq factor, List<Eq> terms) {
    // assert(factor.isSingle);
    if (factor == one || factor == zero) return null;
    final ret = <Eq>[];
    for (int i = 0; i < terms.length; i++) {
      final term = terms[i];
      final d = term.tryCancelDivision(factor);
      if (d == null) return null;
      ret.add(d);
    }
    return ret;
  }

  static List<Eq>? combineFractions(List<Eq> terms, Eq factor) {
    if (factor is! Power) return null;
    final denom = (factor).toDenominator;
    if (denom == null) return null;
    return terms
        .map((e) => Times([denom, e]).combineMultiplications())
        .toList();
  }

  static bool canAddTerms(Eq a, Eq b) {
    var (aC, aSimplified) = a.separateConstant();
    var (bC, bSimplified) = b.separateConstant();
    return aSimplified.isSame(bSimplified);
  }

  static Eq? tryAddTerms(Eq a, Eq b) {
    var (aC, aSimplified) = a.separateConstant();
    var (bC, bSimplified) = b.separateConstant();
    if (!aSimplified.isSame(bSimplified)) return null;

    if (aSimplified is Constant) {
      return Constant((aC + bC) * aSimplified.value).dissolveMinus();
    }
    return aSimplified.withConstant(aC + bC);
  }
}
