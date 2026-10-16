/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import {BasicCatalog, provideA2Ui, provideMarkdownRenderer} from '@a2ui/angular/v0_9';
import {renderMarkdown} from '@a2ui/markdown-it';
import {A2uiClientAction} from '@a2ui/web_core/v0_9';
import {
  ApplicationConfig,
  inject,
  Injector,
  provideBrowserGlobalErrorListeners,
  provideZonelessChangeDetection,
} from '@angular/core';
import {provideClientHydration, withEventReplay} from '@angular/platform-browser';

import {Client} from './client';
import {DASHBOARD_CATALOG} from './dashboard-catalog/catalog';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideZonelessChangeDetection(),
    provideClientHydration(withEventReplay()),
    // The renderer holds both catalogs. Each surface names the one it uses in
    // its `createSurface` message.
    provideA2Ui(() => {
      const injector = inject(Injector);
      return {
        catalogs: [inject(BasicCatalog), DASHBOARD_CATALOG],
        actionHandler: (action: A2uiClientAction) => injector.get(Client).handleAction(action),
      };
    }),
    // The basic catalog's Text renders Markdown.
    provideMarkdownRenderer(renderMarkdown),
  ],
};
