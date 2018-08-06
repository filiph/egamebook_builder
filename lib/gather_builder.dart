import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'package:egamebook_builder/src/generators/instance_serializer_generator.dart';

/// Builder that wraps generators which take multiple files and
/// summarize their contents into a single one.
Builder gatherBuilder(BuilderOptions options) => PartBuilder(
      [const InstanceSerializerGenerator()],
      generatedExtension: '.gathered.g.dart',
    );
