// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:convert';
import 'dart:io';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:test/test.dart';

/// [MessageProcessor.forAgent], which an agent checks its own payloads with,
/// over the schema-only catalog it negotiated.
void main() {
  final document = jsonDecode(
    File(
      '../../conformance/test_data/catalogs/simplified_catalog_v1_0.json',
    ).readAsStringSync(),
  ) as Map<String, Object?>;
  final CatalogApi catalog = Catalog.fromJson(document);

  MessageProcessor<ComponentApi> forAgent({
    List<CatalogApi>? catalogs,
    ValidationConfig? validationConfig = ValidationConfig.strict,
  }) {
    final MessageProcessor<ComponentApi> processor = MessageProcessor.forAgent(
      catalogs: catalogs ?? [catalog],
      validationConfig: validationConfig,
    );
    addTearDown(processor.model.dispose);
    return processor;
  }

  Map<String, Object?> createSurface(List<Map<String, Object?>> components) => {
        'version': 'v1.0',
        'createSurface': {
          'surfaceId': 's',
          'catalogId': catalog.id,
          'components': components,
        },
      };

  Map<String, Object?> callRendererFunction(Map<String, Object?> call) => {
        'version': 'v1.0',
        'callRendererFunction': {
          'functionCallId': 'call_1',
          'callFunction': {'catalogId': catalog.id, ...call},
        },
      };

  test('holds every function of the catalog as its signature', () {
    final MessageProcessor<ComponentApi> processor = forAgent();
    final Catalog<ComponentApi, FunctionImplementation> held =
        processor.catalogs.single;
    expect(held.id, catalog.id);
    expect(held.functions.keys, catalog.functions.keys);
    expect(
      held.functions['openUrl']!.requiresUserActivation,
      catalog.functions['openUrl']!.requiresUserActivation,
    );
  });

  test('applies a payload the catalog accepts', () {
    final MessageProcessor<ComponentApi> processor = forAgent();
    processor.processMessages([
      createSurface([
        {'id': 'root', 'component': 'Text', 'text': 'Hello'},
      ]),
    ]);
    expect(
      processor.model.getSurface('s')!.componentsModel.all.single.type,
      'Text',
    );
  });

  test('rejects a component the catalog does not declare', () {
    expect(
      () => forAgent().processMessages([
        createSurface([
          {'id': 'root', 'component': 'Marquee', 'text': 'Hello'},
        ]),
      ]),
      throwsA(isA<A2uiValidationError>()),
    );
  });

  test('checks the graph strictly by default', () {
    expect(
      () => forAgent().processMessages([
        createSurface([
          {'id': 'title', 'component': 'Text', 'text': 'Hello'},
        ]),
      ]),
      throwsA(isA<A2uiError>()),
    );
  });

  test('ignores a response to a call the renderer made', () {
    forAgent().processMessages([
      {
        'version': 'v1.0',
        'agentFunctionResponse': {'functionCallId': 'call_1', 'value': 42},
      },
    ]);
  });

  group('callRendererFunction', () {
    /// The catalog with [function] given [definition] on top of its own.
    CatalogApi declaring(String function, Map<String, Object?> definition) {
      final functions = document['functions']! as Map<String, Object?>;
      return Catalog.fromJson({
        ...document,
        'functions': {
          ...functions,
          function: {
            ...functions[function]! as Map<String, Object?>,
            ...definition,
          },
        },
      });
    }

    // The fixture declares no allowedCallers, so only the renderer may call
    // its functions. This copy lets the agent call formatString.
    final CatalogApi callable = declaring('formatString', {
      'allowedCallers': 'rendererOrAgent',
    });

    final Map<String, Object?> formatHello = callRendererFunction({
      '@call': 'formatString',
      'args': {'value': 'Hello'},
    });

    test('accepts a call to a function the agent may call', () {
      forAgent(catalogs: [callable]).processMessages([formatHello]);
    });

    test('accepts a call to a function only the agent may call', () {
      forAgent(
        catalogs: [
          declaring('formatString', {'allowedCallers': 'agentOnly'}),
        ],
      ).processMessages([formatHello]);
    });

    test('accepts a call on a surface the processor holds', () {
      forAgent(catalogs: [callable]).processMessages([
        createSurface([
          {'id': 'root', 'component': 'Text', 'text': 'Hello'},
        ]),
        {
          'version': 'v1.0',
          'callRendererFunction': {
            'surfaceId': 's',
            'functionCallId': 'call_1',
            'callFunction': {
              'catalogId': catalog.id,
              '@call': 'formatString',
              'args': {
                'value': {'@path': '/name'},
              },
            },
          },
        },
      ]);
    });

    test('rejects a call to a function only the renderer may call', () {
      expect(
        () => forAgent().processMessages([formatHello]),
        throwsA(
          isA<A2uiValidationError>().having(
            (e) => e.message,
            'message',
            contains('rendererOnly'),
          ),
        ),
      );
    });

    test('rejects a call needing a user activation without one', () {
      final MessageProcessor<ComponentApi> processor = forAgent(
        catalogs: [
          declaring('openUrl', {'allowedCallers': 'rendererOrAgent'}),
        ],
      );
      final Map<String, Object?> openUrl = callRendererFunction({
        '@call': 'openUrl',
        'args': {'url': 'https://example.com'},
      });
      expect(
        () => processor.processMessages([openUrl]),
        throwsA(isA<A2uiValidationError>()),
      );
      processor.processMessages([openUrl], isUserActivated: true);
    });

    test('rejects a call to a function the catalog does not declare', () {
      expect(
        () => forAgent(catalogs: [callable]).processMessages([
          callRendererFunction({'@call': 'vibrate', 'args': {}}),
        ]),
        throwsA(isA<A2uiValidationError>()),
      );
    });

    test('rejects arguments that do not match the signature', () {
      expect(
        () => forAgent(catalogs: [callable]).processMessages([
          callRendererFunction({
            '@call': 'formatString',
            'args': {'text': 'Hello'},
          }),
        ]),
        throwsA(isA<A2uiValidationError>()),
      );
    });

    test('rejects a call naming a catalog it does not hold', () {
      expect(
        () => forAgent(catalogs: [callable]).processMessages([
          callRendererFunction({
            'catalogId': 'elsewhere',
            '@call': 'formatString',
            'args': {'value': 'Hello'},
          }),
        ]),
        throwsA(isA<A2uiCatalogError>()),
      );
    });

    test('rejects a call naming a catalog of another version', () {
      final CatalogApi v0_9 = Catalog.fromJson({
        'catalogId': 'example/v0_9',
        'components': <String, Object?>{},
        'functions': {
          'ping': {
            'type': 'object',
            'allowedCallers': 'rendererOrAgent',
            'properties': {
              'call': {'const': 'ping'},
              'args': {'type': 'object'},
            },
          },
        },
      });
      expect(
        () => forAgent(catalogs: [v0_9]).processMessages([
          callRendererFunction({'catalogId': v0_9.id, '@call': 'ping'}),
        ]),
        throwsA(isA<A2uiCatalogError>()),
      );
    });

    test('rejects a call naming a surface that does not exist', () {
      expect(
        () => forAgent(catalogs: [callable]).processMessages([
          {
            'version': 'v1.0',
            'callRendererFunction': {
              'surfaceId': 'missing',
              'functionCallId': 'call_1',
              'callFunction': {
                'catalogId': catalog.id,
                '@call': 'formatString',
                'args': {'value': 'Hello'},
              },
            },
          },
        ]),
        throwsA(isA<A2uiValidationError>()),
      );
    });
  });
}
