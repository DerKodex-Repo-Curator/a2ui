# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Stateless validation of the payloads that an agent sends."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any

from a2ui.core import A2uiValidationError, CatalogApi
from a2ui.core.schema import AgentToRendererMessagePayload

from .renderer_state import RendererState


class _PayloadState(RendererState):
    """The state of a renderer that `validate_payload` knows nothing about.

    A surface the payload updates without creating is assumed to exist,
    holding components the check never saw. The state creates an empty
    placeholder for it, on the first catalog that defines the update's
    components and accepts it. Each component is still checked against that
    catalog, but the surface's tree is not: references to components outside
    the payload, a missing root and unreachable components are accepted there.
    A surface whose catalog the caller knows is created on that catalog only.
    """

    _assumes_unknown_surfaces = True

    def __init__(
        self,
        catalogs: Sequence[CatalogApi],
        surface_catalog_ids: Mapping[str, str] | None = None,
    ) -> None:
        super().__init__(catalogs)
        self._surface_catalog_ids = dict(surface_catalog_ids or {})

    def _placeholder_catalogs(
        self, surface_id: str, payload: list[dict[str, Any]]
    ) -> list[CatalogApi]:
        catalog_id = self._surface_catalog_ids.get(surface_id)
        if catalog_id is None:
            return super()._placeholder_catalogs(surface_id, payload)
        candidates = [c for c in self.catalogs if c.catalog_id == catalog_id]
        if not candidates:
            raise A2uiValidationError(
                f"Surface '{surface_id}' uses catalog '{catalog_id}', which"
                " isn't one of the active catalogs."
            )
        return candidates


def validate_payload(
    catalogs: Sequence[CatalogApi],
    payload: AgentToRendererMessagePayload,
    *,
    surface_catalog_ids: Mapping[str, str] | None = None,
) -> None:
    """Checks a payload the way a renderer holding the catalogs would.

    The check is stateless: it sees one payload, with no record of what earlier
    payloads sent. A surface that the payload creates, with
    `createSurface` or the v0.8 `beginRendering`, is checked in full, so its
    components must be valid and reachable from the root, and their references
    must resolve once every message in the payload is applied: a component may
    name a child that a later message adds. A surface that the payload only
    updates may already hold components, so references to components outside
    the payload and a missing root are accepted there. Each of its components
    is still checked against a catalog that defines all of them, and the
    surface passes if one such catalog accepts it. A caller that knows the
    catalog an earlier payload created the surface with passes it in
    `surface_catalog_ids`, and the surface is then checked against that
    catalog only.

    To check a payload against what earlier payloads sent, keep a
    `RendererState` and call its `apply` and `check_topology` instead.

    Each message must state a `version` that the catalogs' protocol version
    accepts, spelled as the specification spells it: none for v0.8, `v0.9` or
    `v0.9.1` for v0.9 and v0.9.1, and `v1.0` for v1.0.

    Args:
      catalogs: The active catalogs, which must target compatible protocol
        versions. Each surface is checked against the catalog its `catalogId`
        names. A v0.8 surface that names none uses the first catalog.
      payload: One message or a sequence of messages, as parsed JSON mappings
        or typed schema models.
      surface_catalog_ids: The catalog ids that earlier payloads created
        surfaces with, keyed by surface id. A surface that the payload creates
        uses the catalog that the payload names instead.

    Raises:
      A2uiValidationError: If a renderer holding the catalogs would reject the
        payload. The error, or a subclass such as `A2uiIntegrityError`,
        describes the first problem found.
      A2uiCatalogError: If no catalogs are given, or if their messages state
        different versions, for example v0.9 and v1.0 catalogs.
    """
    state = _PayloadState(catalogs, surface_catalog_ids)
    state.check_topology(state.apply(payload))
