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

import {AngularCatalog, createComponentImplementation} from '@a2ui/angular/v0_9';

import {MetricGridApi, ProgressBarApi, StatCardApi} from './apis';
import {MetricGrid} from './metric-grid';
import {ProgressBar} from './progress-bar';
import {StatCard} from './stat-card';

/**
 * The id of the dashboard catalog. The agent defines the catalog in
 * samples/agent/adk/multi_catalog/catalogs/0.9/dashboard_catalog.json.
 */
export const DASHBOARD_CATALOG_ID =
  'https://a2ui.org/samples/agent/adk/multi_catalog/catalogs/0.9/dashboard_catalog.json';

/** Renders the components of the dashboard catalog. */
export const DASHBOARD_CATALOG = new AngularCatalog(DASHBOARD_CATALOG_ID, '0.9', [
  createComponentImplementation(MetricGridApi, MetricGrid),
  createComponentImplementation(StatCardApi, StatCard),
  createComponentImplementation(ProgressBarApi, ProgressBar),
]);
