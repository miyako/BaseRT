# BaseRT

Public entry point for the `basert-serve` process.

> BaseRT.new(port : Integer; huggingfaces : cs.event.huggingfaces; HOME : 4D.Folder; options : Object; event : cs.event.event)

| Parameter | Meaning |
| --- | --- |
| `port` | TCP port; defaults to 8080 for values outside 1...65535 |
| `huggingfaces` | Download references; invalid/missing values become an empty collection |
| `HOME` | Existing home folder; the legacy fallback is `.GGUF` in the user's home |
| `options` | BaseRT CLI arguments, not llama.cpp flags |
| `event` | `cs.event.event` callbacks |

Use Apple Silicon macOS and the `tcp`, `workers`, and `event` components in
`Project/Sources/dependencies.json`. Windows and Intel macOS are unsupported.

```4d
var $home : 4D.Folder
$home:=Folder(fk home folder).folder(".BaseRT")
$home.create()
var $event : cs.event.event
$event:=cs.event.event.new()
$event.onError:=Formula(ALERT($2.message))
var $chat : cs.event.huggingface
$chat:=cs.event.huggingface.new($home; "keisuke-miyako/Qwen3.5-2B-basert"; "Qwen3.5-2B-Q8.base")
var $models : cs.event.huggingfaces
$models:=cs.event.huggingfaces.new([$chat])
var $options : Object
$options:={max_tokens: 4096; max_context: 8192}
var $BaseRT : cs.BaseRT.BaseRT
$BaseRT:=cs.BaseRT.BaseRT.new(8080; $models; $home; $options; $event)
```

The constructor avoids starting a second registered worker on the same port,
then asks the TCP component to check the port. A conflict calls `onError`.
Model downloads precede process launch. See [`_server`](_server.md) for
argument construction and `basert-serve --help` for the pinned server's flags.
Pass compatible `.base` models; do not use GGUF files, llama.cpp router INI
files, or flags such as `n_gpu_layers`/`ctx_size`.

`event.onSuccess` currently means the worker launch was requested, not that
the server has loaded its model or passed an HTTP health check.
`event.onTerminate` reports process exit; monitor server output for failures.
`onData`/`onResponse` are model-download events.

To terminate from the host application's `onExit`:

```4d
var $BaseRT : cs.BaseRT.BaseRT
$BaseRT:=cs.BaseRT.BaseRT.new()
$BaseRT.terminate()
```

See the [repository README](https://github.com/miyako/BaseRT#readme) for
installation, source builds, licensing, and the custom documentation site.
