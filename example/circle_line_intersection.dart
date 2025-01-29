import 'package:equation/equation.dart';

void main() {
  Eq line = a * x + b * y + c;
  line = (line as Plus).equationOf(y);
  print(line);

  Eq circle =
      (x - h).pow(Constant(2)) - (y - k).pow(Constant(2)) - r.pow(Constant(2));
  print(circle);

  circle = circle.simplify();
  print(circle);

  print('substituting y');
  circle = circle.substitute({'y': line});
  print(circle);

  circle = circle.simplify(dropMinus: true);
  print(circle);

  final quad = circle.asQuadratic(x);
  print(quad);
}
