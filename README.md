# Dynamo Demo Server

Minimal API server showcasing [`dynamo-protocols`](https://github.com/ai-dynamo/dynamo/tree/main/lib/protocols) and [`dynamo-parsers`](https://github.com/ai-dynamo/dynamo/tree/main/lib/parsers) crates from [NVIDIA Dynamo](https://github.com/ai-dynamo/dynamo).

Demonstrates that you can build your own OpenAI/Anthropic-compatible inference server using Dynamo's protocol types and tool-call parsers, plugging in your own tokenization and inference backend.

## Endpoints

| Endpoint | API | Streaming |
|---|---|---|
| `POST /v1/chat/completions` | OpenAI Chat Completions | Yes |
| `POST /v1/completions` | OpenAI Completions | Yes |
| `POST /v1/responses` | OpenAI Responses | No |
| `POST /v1/messages` | Anthropic Messages | Yes |
| `POST /v1/tool-parse` | Tool-call parser demo | No |
| `GET /health` | Health check | No |

## Build & Run

```bash
cargo run
# Server starts on http://localhost:3000
```

## Example Requests

### Chat Completions

```bash
# Non-streaming
curl -s http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"echo","messages":[{"role":"user","content":"hello world"}]}'

# Streaming
curl -sN http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"echo","messages":[{"role":"user","content":"hello world"}],"stream":true}'

# With tool calls (demonstrates dynamo-parsers inline)
curl -s http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model":"echo",
    "messages":[{"role":"user","content":"whats the weather?"}],
    "tools":[{"type":"function","function":{"name":"get_weather","parameters":{"type":"object","properties":{"city":{"type":"string"}}}}}]
  }'
```

### Completions

```bash
curl -s http://localhost:3000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"echo","prompt":"hello world"}'
```

### Anthropic Messages

```bash
# Non-streaming
curl -s http://localhost:3000/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"model":"echo","messages":[{"role":"user","content":"hello world"}],"max_tokens":100}'

# Streaming
curl -sN http://localhost:3000/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"model":"echo","messages":[{"role":"user","content":"hello world"}],"max_tokens":100,"stream":true}'
```

### Responses API

```bash
curl -s http://localhost:3000/v1/responses \
  -H "Content-Type: application/json" \
  -d '{"model":"echo","input":"hello world"}'
```

### Tool Parse (dynamo-parsers demo)

```bash
curl -s http://localhost:3000/v1/tool-parse \
  -H "Content-Type: application/json" \
  -d '{
    "text": "<tool_call>{\"name\": \"get_weather\", \"arguments\": {\"city\": \"SF\"}}</tool_call>",
    "parser": "hermes",
    "tools": [{"name": "get_weather", "parameters": {"type": "object", "properties": {"city": {"type": "string"}}}}]
  }'
```

Available parsers: `hermes`, `llama3_json`, `mistral`, `phi4`, `pythonic`, `harmony`, `deepseek_v3`, `deepseek_v3_1`, `deepseek_v3_2`, `qwen3_coder`, `jamba`, `minimax_m2`, `glm47`, `kimi_k2`, `default`, and more.

## Architecture

```
src/
  main.rs              -- axum router setup
  echo.rs              -- dummy echo backend (replace with your inference engine)
  handlers/
    chat.rs            -- /v1/chat/completions (streaming + tool parsing)
    completions.rs     -- /v1/completions
    responses.rs       -- /v1/responses
    anthropic.rs       -- /v1/messages (Anthropic SSE format)
    tool_parse.rs      -- /v1/tool-parse (standalone parser demo)
```

### Where to plug in your own inference

The `echo.rs` module is the integration point. Replace `extract_chat_text` / `extract_completion_text` / `extract_anthropic_text` with calls to your tokenizer, and modify the handlers to call your inference engine instead of echoing input.

### Dependencies

Only two Dynamo crates are needed:

- **`dynamo-protocols`** -- Protocol types for all four APIs (re-exports from `async-openai` + Anthropic + inference extensions)
- **`dynamo-parsers`** -- Tool-call parsing for 15+ model formats (Hermes, Llama, Mistral, DeepSeek, Kimi K2, etc.)

No dependency on `dynamo-runtime` or `dynamo-llm`.

## Using as a standalone project

To use this outside the Dynamo repo, change the path dependencies in `Cargo.toml` to git dependencies:

```toml
dynamo-protocols = { git = "https://github.com/ai-dynamo/dynamo", branch = "main" }
dynamo-parsers = { git = "https://github.com/ai-dynamo/dynamo", branch = "main" }
```
