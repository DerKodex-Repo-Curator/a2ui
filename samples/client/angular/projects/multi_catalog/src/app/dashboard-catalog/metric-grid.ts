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

import {CatalogComponent, Child, ComponentHostComponent} from '@a2ui/angular/v0_9';
import {ChangeDetectionStrategy, Component, computed} from '@angular/core';

import {MetricGridApi} from './apis';

/** Lays out its children, the metric components, in a responsive grid. */
@Component({
  selector: 'app-metric-grid',
  imports: [ComponentHostComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: `
    :host {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 16px;
      width: 100%;
    }
  `,
  template: `
    @for (child of children(); track child.basePath + '/' + child.id) {
      <a2ui-v09-component-host [componentKey]="child" [surfaceId]="surfaceId()" />
    }
  `,
})
export class MetricGrid extends CatalogComponent<typeof MetricGridApi> {
  protected readonly children = computed<Child[]>(() => this.props()['children']?.value() ?? []);
}
