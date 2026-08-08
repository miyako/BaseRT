# BaseRT

Local inference engine

[BaseRT](https://github.com/basecompute/baseRT) is a high-performance, native C++ inference runtime built directly on Apple's Metal GPU API to run large language models locally on Apple Silicon. 

The component manages the whole lifecycle: resolving and downloading models from Hugging Face, building the `basert-serve` command line, launching it as a background process, and shutting it down cleanly when the app quits.

## Requirements

- macOS on Apple Silicon (the BaseRT engine is Metal-based; ARM is expected/checked internally)
- 4D v20 R-series or later (uses 4D classes, `4D.SystemWorker`, `4D.HTTPRequest`, formulas, etc.)
- The `basert-serve` executable, placed at:

  ```
  /RESOURCES/bin/macOS/basert-serve
  ```

  If the binary isn't found there, the component falls back to calling `basert-serve` from `$PATH`. The component `chmod +x`'s the binary on first use.

> Windows is not currently supported — the underlying CLI wrapper returns immediately on Windows.

## What's included

| File | Role |
|---|---|
| `BaseRT.4dm` | Public entry point. Checks the requested port isn't already in use, fills in sensible defaults, and starts the server via a 4D worker. |
| `_interface.4dm` | Shared constructor/`terminate()` contract, plus the TCP pre-flight check (`_onTCP`) that reports a port conflict through the `event.onError` callback. |
| `_CLI.4dm` | Generic wrapper around a native command-line executable: locates the binary, escapes arguments for bash/zsh or cmd.exe, and resolves the current directory. |
| `_CLI_Controller.4dm` | Generic controller that drives a `4D.SystemWorker`: queues commands, wires up `onData` / `onDataError` / `onResponse` / `onError` / `onTerminate`, and manages worker lifecycle. |
| `_BaseRT.4dm` / `_BaseRT_Controller.4dm` | BaseRT-specific specializations of `_CLI` / `_CLI_Controller` (executable name `basert-serve`, `port` property, termination pass-through). |
| `_server.4dm` | Builds the actual `basert-serve` command line from an options object (model path(s), flags, key/value arguments) and starts it as a system worker. |
| `_models.4dm` / `_Model.4dm` | Resolves model references — either local files, single/multiple Hugging Face repos, or "router mode" (a models directory / preset file) — downloads any missing weights, and calls `start()` once everything is on disk. |
| `onStartup.4dm` | Example database method: builds a Qwen chat + embedding model configuration and starts BaseRT when the 4D app launches. |
| `onExit.4dm` | Terminates the running BaseRT worker when the 4D app quits. |

## Installation

1. Add this project as a 4D component (or copy it into `Components/` of your host database).
2. Download or build `basert-serve` from [miyako/BaseRT](https://github.com/miyako/BaseRT) and place it at `RESOURCES/bin/macOS/basert-serve` in your project.
3. Call `cs.BaseRT.new(...)` from `onStartup` (see below), and `cs.BaseRT.new().terminate()` from `onExit`.

## Basic usage

```4d
var $BaseRT : cs.BaseRT
var $homeFolder : 4D.Folder
$homeFolder:=Folder(fk home folder).folder(".BaseRT")

var $event : cs.event.event
$event:=cs.event.event.new()
$event.onError:=Formula(ALERT($2.message))

var $chat : cs.event.huggingface
$chat:=cs.event.huggingface.new($homeFolder.folder("Qwen"); "keisuke-miyako/Qwen3.5-2B-basert"; "Qwen3.5-2B-Q8.base")

var $huggingfaces : cs.event.huggingfaces
$huggingfaces:=cs.event.huggingfaces.new([$chat])

var $options : Object
$options:={max_tokens: 4096; max_context: 8192}

$BaseRT:=cs.BaseRT.new(8080; $huggingfaces; $homeFolder; $options; $event)
```

On termination (e.g. in `onExit`):

```4d
var $BaseRT : cs.BaseRT
$BaseRT:=cs.BaseRT.new()
$BaseRT.terminate()
```

### How it starts up

1. `BaseRT.new(...)` checks whether the given port is already bound; if so, `event.onError` fires and nothing else happens.
2. If the port is free, it resolves the model(s) referenced by `huggingfaces` (or a local `model` file/folder passed in `options`), downloading anything missing from Hugging Face and reporting progress through `event.onData` / `event.onResponse`.
3. Once all files are on disk, `_server.start()` translates the `options` object into `basert-serve` command-line flags (any `snake_case` key becomes a `--kebab-case` flag; `File`/`Folder` values, booleans, numbers, and collections are all handled) and launches it as a `4D.SystemWorker`.
4. `event.onSuccess` fires with the resolved model list once the server is up.

### Options object

Any key in the `options` object passed to `BaseRT.new()` is turned into a `basert-serve` command-line argument, for example:

```4d
$options:={\
  model: [$folder.file("chat.gguf"); $folder.file("embeddings.gguf")]; \
  log_file: $logFile; \
  max_tokens: 4096; \
  max_context: 8192}
```

becomes:

```
basert-serve <chat.gguf> --model <embeddings.gguf> --log-file <path> --max-tokens 4096 --max-context 8192
```

`model`, `help`, and `version` are handled specially and never emitted as generic flags. Reserved keys `models_dir` / `models_preset` put the server into "router mode," serving whatever models are found in a folder or listed in a preset file rather than a single fixed model.

### Events

`cs.event.event` accepts formulas/functions for:

- `onError($params; $error)` — port conflict or other startup failure
- `onSuccess($params; $models)` — server is up and serving these models
- `onData($request; $event)` — Hugging Face download progress
- `onResponse($request; $event)` — a download finished
- `onTerminate($worker; $params)` — the `basert-serve` process exited

## Credits

- Native runtime: [miyako/BaseRT](https://github.com/miyako/BaseRT) — a Metal-based local inference engine for Apple Silicon.
- This repository provides the 4D-side glue (process management, model resolution/downloading, event wiring) to run BaseRT as an embedded local LLM server inside a 4D application.
