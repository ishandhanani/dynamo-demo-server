# Three Dynamo Crates for Rust Inference Frontends

A working OpenAI/Anthropic-compatible server in ~600 lines of Rust, built on three crates from [NVIDIA Dynamo](https://github.com/ai-dynamo/dynamo). Each crate is independently usable; this server exists to show what they look like wired together end-to-end.

```
   tokenizer.json (HF Hub)
            │
            ▼
  ┌──────────────────┐
  │ dynamo-tokenizers│  encode / decode / detokenization tricks
  └──────────────────┘
            │
            ▼
  ┌──────────────────┐
  │ dynamo-protocols │  chat / completions / responses / anthropic types
  └──────────────────┘
            │
            ▼
  ┌──────────────────┐
  │ dynamo-parsers   │  18+ tool-call + reasoning parsers (incl. DSv4 day-0)
  └──────────────────┘
            │
            ▼
       OpenAI-shaped JSON / SSE response
```

## The crates

One of the hardest parts of serving LLMs is staying compliant with the various API specs (Anthropic, OpenAI chat, OpenAI responses) and keeping up with the nuances of every new reasoning/tool-call parser. We split this work into three independent crates:

- **`dynamo-protocols`** — a single crate exposing inference-engine extensions on top of `chat/completions`, `completions`, `responses`, and Anthropic `messages`.
- **`dynamo-parsers`** — a single crate for reasoning + tool-calling parsers (18+ models supported, with day-0 DeepSeek-V4 support).
- **`dynamo-tokenizers`** — a lightweight crate wrapping HuggingFace + tiktoken + FastTokenizers, with tricks to speed up incremental detokenization.

Each can be adopted on its own. This demo binary uses all three.

## Why we want this shared

Our goal is for the inference community to explore and adopt these crates so we have **one set of Rust implementations** for these pieces going forward. We currently test all three together against coding agents (Codex and Claude) in our CI to make sure they stay fully spec-compliant. The NVIDIA Dynamo team will be maintaining these for the long term and is committed to **day-0 support for all new models and techniques**.

We'll be moving these three crates into their own repo outside of Dynamo and giving the SGLang team and other members of the inference community ownership/maintainer privileges — so they aren't just owned by Dynamo. If you're building a Rust frontend for an inference engine, we'd love to talk about whether these could eliminate some of your maintenance burden and free your team up to focus on the things that actually matter: the frontend server, the scheduler, and the model forward pass.

## Run it

```bash
make server                                                  # clone dynamo + build
cargo run --release -- --model Qwen/Qwen2.5-0.5B-Instruct    # run
```

`make server` clones `ai-dynamo/dynamo` (main) into `./.dynamo` (gitignored) and builds the release binary. Then run it with any HuggingFace repo — the tokenizer is fetched from the Hub on first run and cached.

```
$ cargo run --release -- --help
  --model <MODEL>          HuggingFace repo id (fetches tokenizer.json)
  --tokenizer <PATH>       local tokenizer.json (alternative to --model)
  --host <HOST>            default 0.0.0.0
  --http-port <PORT>       default 3000
```

Use an existing dynamo checkout instead of cloning:

```bash
make server DYNAMO_SRC=/path/to/dynamo
```

## What each endpoint demonstrates

| Endpoint | API | Crate(s) exercised |
|---|---|---|
| `POST /v1/chat/completions` | OpenAI Chat (streaming + tool calls) | protocols, parsers, tokenizers |
| `POST /v1/completions` | OpenAI Completions | protocols, tokenizers |
| `POST /v1/responses` | OpenAI Responses | protocols, tokenizers |
| `POST /v1/messages` | Anthropic Messages (streaming) | protocols, tokenizers |
| `POST /v1/tokenize` | encode → token IDs | tokenizers |
| `POST /v1/detokenize` | token IDs → text | tokenizers |
| `POST /v1/tool-parse` | tool-call parser (15+ formats) | parsers |
| `POST /v1/reasoning-parse` | reasoning parser (deepseek_r1, qwen3, gpt_oss, kimi_k25, dsv4, …) | parsers |
| `GET /health` | — | — |

## Examples

```bash
# Real token counts in usage come from dynamo-tokenizers
curl -s localhost:3000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"echo","messages":[{"role":"user","content":"hello world"}]}'

# Tool-call parsing across 15+ model formats
curl -s localhost:3000/v1/tool-parse \
  -H 'Content-Type: application/json' \
  -d '{"text":"<tool_call>{\"name\":\"get_weather\",\"arguments\":{\"city\":\"SF\"}}</tool_call>","parser":"hermes"}'

# Reasoning parsers — try deepseek_r1, qwen3, gpt_oss, kimi_k25, deepseek_v4, mistral, granite, gemma4, ...
curl -s localhost:3000/v1/reasoning-parse \
  -H 'Content-Type: application/json' \
  -d '{"text":"<think>let me think</think>the answer is 42","parser":"deepseek_r1"}'

# Round-trip via the tokenizer
curl -s localhost:3000/v1/tokenize   -H 'Content-Type: application/json' -d '{"text":"hello"}'
curl -s localhost:3000/v1/detokenize -H 'Content-Type: application/json' -d '{"token_ids":[14990]}'
```

## Where to plug in your own inference

`src/echo.rs` extracts text from incoming requests; `src/engine.rs` owns the tokenizer. Replace those + the per-handler echo with a call to your scheduler/forward-pass and you have a real server.

## Layout

```
src/
  main.rs                 axum router + CLI + HF Hub tokenizer fetch
  engine.rs               AppState — holds the loaded Tokenizer
  echo.rs                 dummy backend (extracts text from request bodies)
  handlers/
    chat.rs               /v1/chat/completions  (streaming + tool parsing)
    completions.rs        /v1/completions
    responses.rs          /v1/responses
    anthropic.rs          /v1/messages          (Anthropic SSE format)
    tokenize.rs           /v1/tokenize, /v1/detokenize
    tool_parse.rs         /v1/tool-parse
    reasoning_parse.rs    /v1/reasoning-parse
```
