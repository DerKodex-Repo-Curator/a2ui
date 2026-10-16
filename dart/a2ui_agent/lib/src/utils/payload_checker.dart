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

import 'package:a2ui_core/a2ui_core.dart';

/// Checks what `MessageReader` cannot see in one message: the surfaces a
/// payload creates, applied in order as a renderer holding the catalogs
/// would apply them.
///
/// A message for a surface the payload creates is applied once the surface's
/// `createSurface` has been, so a self-reference, a cycle or an over-deep
/// chain is reported for the message that makes it. A surface the payload
/// does not create may hold components from earlier responses, so its
/// messages are left to `MessageReader`, as are function calls and
/// responses, which a renderer answers rather than applies.
///
/// [finish] then checks each created surface whole: it has a root, no
/// reference to a missing component, and nothing the root does not reach.
class PayloadChecker {
  /// A checker for messages of the protocol version [catalogs] target.
  ///
  /// When [created] holds the surfaces the whole payload creates, a message
  /// for one of them that comes before its `createSurface` throws. A checker
  /// of a payload still arriving is given none, and skips such a message,
  /// since a renderer would see it only once the payload is whole.
  PayloadChecker(
    List<CatalogApi> catalogs,
    A2uiProtocolVersion version, {
    this.created = const {},
  }) : _processor = MessageProcessor.forAgent(
         catalogs: catalogs,
         defaultVersion: version,
         // A surface may arrive across several messages, so the checks that
         // span them wait for finish.
         validationConfig: const ValidationConfig(
           allowOrphanComponents: true,
           allowDanglingReferences: true,
           allowMissingRoot: true,
         ),
       );

  /// The surfaces the whole payload creates, or none for a payload still
  /// arriving.
  final Set<String> created;

  final MessageProcessor<ComponentApi> _processor;

  /// The surfaces of [messages] that a `createSurface` among them creates.
  static Set<String> createdBy(Iterable<AgentToRendererMessage> messages) => {
    for (final CreateSurfaceMessage message
        in messages.whereType<CreateSurfaceMessage>())
      message.surfaceId,
  };

  /// Applies [message] if it is for a surface this payload has created.
  ///
  /// Throws [A2uiIntegrityError] for a message other than a `deleteSurface`
  /// for a surface in [created] that comes before its `createSurface`, and
  /// otherwise the [A2uiError] a
  /// renderer would report for the message.
  void add(AgentToRendererMessage message) {
    final String? surfaceId = switch (message) {
      CreateSurfaceMessage(:final String surfaceId) ||
      UpdateComponentsMessage(:final String surfaceId) ||
      UpdateDataModelMessage(:final String surfaceId) ||
      DeleteSurfaceMessage(:final String surfaceId) => surfaceId,
      _ => null,
    };
    if (surfaceId == null) return;
    if (message is! CreateSurfaceMessage &&
        _processor.model.getSurface(surfaceId) == null) {
      // Deleting a surface that does not exist does nothing, as a renderer
      // treats it.
      if (created.contains(surfaceId) && message is! DeleteSurfaceMessage) {
        throw A2uiIntegrityError(
          "A message for surface '$surfaceId' comes before the createSurface "
          'that creates it.',
        );
      }
      return;
    }
    _processor.processMessages([message]);
  }

  /// Checks that each surface in [created] is complete, and releases the
  /// surfaces.
  ///
  /// Throws [A2uiIntegrityError] for a surface with no root, a reference to
  /// a component it does not hold, or a component the root does not reach.
  void finish() {
    try {
      for (final String surfaceId in created) {
        _processor.model
            .getSurface(surfaceId)
            ?.componentsModel
            .validateTopology(ValidationConfig.strict);
      }
    } finally {
      dispose();
    }
  }

  /// Releases the surfaces, without the checks of [finish].
  void dispose() => _processor.model.dispose();
}
