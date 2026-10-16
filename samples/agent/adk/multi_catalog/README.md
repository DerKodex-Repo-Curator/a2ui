# Multi-catalog sales dashboard agent

This sample uses the Agent Development Kit (ADK) and the A2A protocol to host an
agent that answers with UI from two catalogs at once:

- The sample's dashboard catalog,
  [`catalogs/0.9/dashboard_catalog.json`](catalogs/0.9/dashboard_catalog.json),
  defines `MetricGrid`, `StatCard` and `ProgressBar`. The agent shows the numbers
  on a `metrics` surface that uses this catalog.
- The basic catalog shows the summary and a **Refresh** button on a `notes`
  surface.

The agent is built with the Python agent SDK (`a2ui-agent-sdk` and `a2ui-a2a`).
The matching client is the Angular
[`multi_catalog`](../../../client/angular/projects/multi_catalog) sample.

## Prerequisites

- Python: see `requires-python` in `pyproject.toml`
- [UV](https://docs.astral.sh/uv/)
- A Gemini API key

## Running the sample

1. Go to the sample's directory:

   ```bash
   cd samples/agent/adk/multi_catalog
   ```

2. Create an environment file with your API key:

   ```bash
   cp .env.example .env
   # Edit .env with your API key (do not commit .env)
   ```

3. Run the agent server. It listens on port 10010.

   ```bash
   uv run .
   ```

4. Run the Angular client. See its
   [README](../../../client/angular/projects/multi_catalog/README.md).

To check the agent without a browser, run the A2A check script while the server
is running. It sends one request in each mode, streaming and non-streaming, and
checks that the response has valid UI on both catalogs:

```bash
uv run check_e2e.py
```

To print the system prompt that the agent builds for a client that renders both
catalogs:

```bash
uv run prompt_builder.py
```

## How it works

1. The agent holds one `A2uiGenerator` with two `CatalogConfig`s: the basic
   catalog, and the dashboard catalog loaded with `CatalogConfig.from_path`. The
   generator also holds the example responses in `examples/0.9/`. The agent card
   lists both catalog ids.
2. Each request gets its own `A2uiRequestProcessor` from
   `generator.create_processor(capabilities)`. The capabilities are the
   `a2uiClientCapabilities` in the message metadata, keyed by protocol version:

   ```json
   {"v0.9": {"supportedCatalogIds": ["<basic catalog id>", "<dashboard catalog id>"]}}
   ```

   Creating the processor checks the examples against the negotiated catalogs.
   The examples use both catalogs, so a client must support both. Otherwise the
   agent answers with a text message.
3. The system prompt is built from `processor.prompt_snippet`, which describes
   both catalogs and lists the examples.
4. The client says whether it reads the response as a stream with `useStreaming`
   in the message metadata.
   - When streaming, `stream_response_to_parts(processor.open_stream(), ...)`
     validates each A2UI message against its surface's catalog and sends it as
     soon as the model has written it.
   - Otherwise `processor.parse_response(text)` validates the whole response, and
     `to_a2a_parts` sends it in the final message.

   On a validation error the agent asks the model to try again, unless it has
   already sent part of the response.
5. The **Refresh** button sends the `refresh_dashboard` action with the region in
   its context. The agent asks the model to show the region's dashboard again.

## Disclaimer

Important: The sample code provided is for demonstration purposes and
illustrates the mechanics of A2UI and the Agent-to-Agent (A2A) protocol. When
building production applications, it is critical to treat any agent operating
outside of your direct control as a potentially untrusted entity.

All operational data received from an external agent, including its AgentCard,
messages, artifacts, and task statuses, should be handled as untrusted input.
For example, a malicious agent could provide crafted data in its fields (e.g.,
name, skills.description) that, if used without sanitization to construct
prompts for a Large Language Model (LLM), could expose your application to
prompt injection attacks.

Developers are responsible for implementing appropriate security measures, such
as input validation and secure handling of credentials, to protect their
systems and users.
