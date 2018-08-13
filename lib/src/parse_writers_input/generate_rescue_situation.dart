import 'package:code_builder/code_builder.dart';
import 'package:egamebook_builder/src/parse_writers_input/list.dart';

import '../recase/recase.dart';
import 'generate_simple_action.dart';
import 'method_builders.dart';
import 'parameters.dart';
import 'types.dart';

/// Generates the Situation class for a particular Action.
///
/// Each Situation needs to be implemented as its own class. Can't use deeper
/// inheritance here because then built_value wouldn't work. And we need
/// built_value to support saving, immutability, value type and all the other
/// nice things it gives to all situations.
///
/// We can't have a generic `ActionRescueSituation` with some data attached
/// because we need the situation to filter actions (rescue action and
/// continuation of failure action).
Spec generateRescueSituation(
    String className,
    String writersName,
    String rescueCommand,
    String rescueDescription,
    String rescuePrerequisites,
    String rescueEffect,
    String rescueHint,
    String continuationCommand,
    String continuationDescription,
    String continuationEffect,
    String continuationHint,
    String successEffect) {
  final situationClassType = TypeReference((b) => b..symbol = className);
  final situationBuilderClassName = '${className}Builder';
  final situationBuilderClass =
      TypeReference((b) => b..symbol = situationBuilderClassName);

  // Generate:
  //   abstract class AbcRescueSituation extends Situation implements
  //       Built<AbcRescueSituation, AbcRescueSituationBuilder> {}
  final situationClass = ClassBuilder()
    ..name = className
    ..abstract = true
    ..extend = TypeReference((b) => b..symbol = 'Object')
    ..mixins.add(situationBaseBehaviorType)
    ..implements.add(TypeReference((b) => b
      ..symbol = 'Built'
      ..types.addAll([
        situationClassType,
        situationBuilderClass,
      ])));

  final generatedSituationClassType =
      TypeReference((b) => b..symbol = "_\$$className");

  final camelCaseSituation = ReCase(className).camelCase;
  final generatedSerializerName = refer("_\$${camelCaseSituation}Serializer");

  // static Serializer<AbcRescueSituation> get serializer =>
  //     _$abcRescueSituationSerializer;
  final serializerGetter = Method((b) => b
    ..name = 'serializer'
    ..type = MethodType.getter
    ..static = true
    ..returns = TypeReference((b) => b
      ..symbol = 'Serializer'
      ..types.add(situationClassType))
    ..body = generatedSerializerName.code);

  situationClass.methods.add(serializerGetter);

  //  factory AbcRescueSituation([updates(AbcRescueSituationBuilder b)]) =
  //      _$AbcRescueSituation;
  final updatesParameter = Parameter((b) => b
    ..name = 'updates'
    ..type = FunctionType((t) => t
      ..returnType = TypeReference((r) => r..symbol = 'void')
      ..requiredParameters.add(situationBuilderClass)));
  final defaultConst = Constructor((b) => b
    ..factory = true
    ..optionalParameters.add(updatesParameter)
    ..redirect = generatedSituationClassType);
  situationClass.constructors.add(defaultConst);

  //    factory TakeOutGateGuardsRescueSituation.initialized(int id) =>
  //    new TakeOutGateGuardsRescueSituation((b) {
  //      b.id = id;
  //      b.time = 0;
  //    });
  final initializedConstructor = Constructor((b) => b
    ..name = 'initialized'
    ..factory = true
    ..requiredParameters.add(Parameter((p) => p
      ..name = 'id'
      ..type = intType))
    ..body = refer(situationClass.name)
        .newInstance([
          Method((m) => m
            ..requiredParameters.add(Parameter((p) => p..name = 'b'))
            ..body = Block((c) => c
              ..addExpression(refer('id').assign(refer('b').property('id')))
              ..addExpression(
                  refer('b').property('time').assign(literal(0))))).closure
        ])
        .returned
        .statement);
  situationClass.constructors.add(initializedConstructor);

  //    TakeOutGateGuardsRescueSituation._();
  var privateConst = new Constructor((b) => b..name = '_');
  situationClass.constructors.add(privateConst);

  //      actions can be just instances of a generic SimpleAction and ContinuationOfFailureAction
  //      but Situation needs to be each implemented, otherwise it can't be a built value
  //    @override
  //    List<Action> get actions => [new SimpleAction('Blah', (a, w, s) {
  //      s.add("Blah!");
  //  w.popSituation();
  //      return "blah done";
  //    }, null)];
  var effect = "${rescueEffect ?? ''}\n"
      "${successEffect ?? ''}";
  final actionsGetter = createGetter('actions', listOfActionType);
  actionsGetter.block.statements.add(listReturned([
    generateSimpleAction("${writersName}_rescue", rescueCommand,
        rescueDescription, rescuePrerequisites, effect, rescueHint, className),
    generateSimpleAction(
        "${writersName}_continuation_of_failure",
        continuationCommand,
        continuationDescription,
        null,
        continuationEffect,
        continuationHint,
        className)
  ]));
  situationClass.methods.add(actionsGetter.bake());

  //    @override
  //    int get id;
  final idGetter = createGetter('id', intType);
  situationClass.methods.add(idGetter.bake());

  //    @override
  //    int get time;
  final timeGetter = createGetter('time', intType);
  situationClass.methods.add(timeGetter.bake());

  //    @override
  //    String get name => "RoomRoamingSituation";
  final nameGetter = createGetter('name', stringType);
  nameGetter.block.addExpression(literal(writersName).returned);
  situationClass.methods.add(nameGetter.bake());

  //    @override
  //    Situation elapseTime() => rebuild((b) => b..time += 1);
  final elapseTime = Method((b) => b
    ..name = 'elapseTime'
    ..returns = situationType
    ..annotations.add(overrideAnnotation)
    ..body = refer('rebuild').call([
      Method((c) => c
        ..requiredParameters.add(Parameter((p) => p..name = 'b'))
        // TODO: rewrite below
        ..body = Code('return b..time += 1;')).closure
    ]).code);
  situationClass.methods.add(elapseTime);

  //    @override
  //    Actor getActorAtTime(int time, WorldState world) {
  //    return world.actors.singleWhere((a) => a.isPlayer);
  //    }
  final getActorAtTimeMethod = MethodBuilder();
  getActorAtTimeMethod
    ..name = 'getActorAtTime'
    ..returns = actorType
    ..annotations.add(overrideAnnotation)
    ..requiredParameters.addAll([
      Parameter((p) => p
        ..name = 'time'
        ..type = intType),
      simulationParameter,
      worldParameter,
    ])
    ..body = Block.of([
      // TODO: build this instead when
      //       https://github.com/dart-lang/code_builder/issues/223
      //       is resolved
      Code('if (time != 0) return null;'),
      refer(worldParameter.name)
          .property('actors')
          .property('singleWhere')
          .call([
        Method((b) => b
          ..requiredParameters.add(Parameter((p) => p..name = 'a'))
          ..body = refer('a').property('isPlayer').code).closure
      ]).returned.statement
    ]);
  situationClass.methods.add(getActorAtTimeMethod.build());

  //    @override
  //    Iterable<Actor> getActors(Iterable<Actor> actors, WorldState world) {
  //    return [world.actors.singleWhere((a) => a.isPlayer)];
  //    }
  final actorIterablesType = new TypeReference((b) => b
    ..symbol = 'Iterable'
    ..types.add(actorType));
  final getActorsMethod = MethodBuilder();
  getActorsMethod
    ..name = 'getActors'
    ..returns = actorIterablesType
    ..annotations.add(overrideAnnotation)
    ..requiredParameters.addAll([
      Parameter((b) => b
        ..name = 'actors'
        ..type = actorIterablesType),
      simulationParameter,
      worldParameter,
    ])
  ..body = listReturned([refer('actors').property('singleWhere').call([
    Method((b) => b..requiredParameters.add(actorParameter)..body = refer(actorParameter.name)
    .property('isPlayer').returned.statement).closure
  ])]);
  situationClass.methods.add(getActorsMethod.build());

  return situationClass.build();
}
