import 'package:code_builder/code_builder.dart';

final _dartEmitter = DartEmitter();

@Deprecated('use literalList instead: https://github.com/dart-lang/code_builder/issues/225')
Code listReturned(List<Expression> values) {
  final stringedValues = values.map((c) => c.accept(_dartEmitter).toString());
  final innerString = stringedValues.join(', ');
  return Code('return [$innerString];');
}
