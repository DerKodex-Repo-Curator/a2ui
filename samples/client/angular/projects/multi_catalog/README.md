# Angular multi-catalog client

This client renders the
[multi-catalog sales dashboard agent](../../../../agent/adk/multi_catalog). The
renderer holds two catalogs:

- the basic catalog (`BasicCatalog` from `@a2ui/angular/v0_9`), and
- the dashboard catalog in
  [`src/app/dashboard-catalog`](src/app/dashboard-catalog), which renders the
  agent's `MetricGrid`, `StatCard` and `ProgressBar` components.

Each surface names its catalog in `createSurface`, so one response can show a
`metrics` surface on the dashboard catalog and a `notes` surface on the basic
catalog.

## How it works

1. [`app.config.ts`](src/app/app.config.ts) registers both catalogs with
   `provideA2Ui`.
2. [`server.ts`](src/server.ts) forwards each request to the agent over A2A. It
   sends the catalogs the renderer holds as `a2uiClientCapabilities`, keyed by
   protocol version, and `useStreaming` in the message metadata. The agent
   negotiates its catalogs from them.
3. With `ENABLE_STREAMING` unset or `true`, the server uses `message/stream`
   and passes each agent update on as a server-sent event, so the UI renders
   while the model writes it. With `ENABLE_STREAMING=false`, it uses
   `message/send` and returns the whole response at once.
4. [`client.ts`](src/app/client.ts) passes the A2UI messages to the renderer.
   The **Refresh** button sends its `refresh_dashboard` action back to the
   agent as a `{"version": "v0.9", "action": ...}` data part.

## Running the sample

1. Start the agent. See its [README](../../../../agent/adk/multi_catalog/README.md).
2. In `samples/client/angular`, build the renderers and start the client:

   ```bash
   yarn install
   yarn build:renderer
   yarn start multi_catalog
   ```

   Or start both the agent and the client:

   ```bash
   yarn demo:multi_catalog
   ```

3. Open http://localhost:4200 and ask for a region's dashboard, for example
   "Show me the sales dashboard for Europe".

To try the non-streaming path, build the client and run its server with
streaming off:

```bash
yarn ng build multi_catalog
ENABLE_STREAMING=false PORT=4000 yarn serve:ssr:multi_catalog
```

The agent's URL defaults to `http://localhost:10010`. Set `AGENT_URL` to use
another one.
