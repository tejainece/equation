import 'package:equation/equation.dart';

void main() {
  Eq eq = (t - 1) * (t - 2) * (t - 3) * (t - 4);
  eq = eq.simplify();
  print(eq);

  final quartic = eq.asQuartic(t);
  print(quartic);

  print(quartic.solve());
}