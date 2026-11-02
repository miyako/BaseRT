# _Model

Extends [`_models`](_models.md) for BaseRT model resolution.

The constructor resolves the files; the `start` project method dispatches
pending downloads or launches an existing local model. This avoids starting
twice when cached downloads finish synchronously. `onDownload(oid; identity;
generation)` assigns the identified destination to `options.model` when no
model was specified, then delegates completion tracking to `_models`.
Use upstream-compatible `.base` weights, not llama.cpp GGUF models.

`models()` returns model names and missing-file status for a file or collection
in `options.model`. The inherited legacy router branch returns an unnamed
entry for existing `models_preset`/`models_dir` paths; these keys are not a
promise of upstream CLI support and should not be used.

`start()` obtains the `_server` worker, starts it with `options.port`, then
invokes `event.onSuccess` once for a still-active attempt. Pending downloads,
invalid required local files and failed/cancelled/stale attempts cannot reach
launch. This is a launch notification, **not** a health/model-readiness check.
Inspect native diagnostics and verify process/model identity through the
selected runtime's protocol. A model listing alone may describe unloaded models.

`start()` requires either an existing external `executable : 4D.File` or
`source_runtime : 4D.Folder` plus `engine_dir : 4D.Folder`, never both selectors.
No inference runtime is bundled and there is no resource or `PATH` fallback.
With `source_runtime` selected, it validates the runtime's launcher,
server and worker paths and the separately supplied `engine_dir`. Missing,
malformed or conflicting selections call `onError` (code 3) before launch,
or log an error when no event object exists.
This path validation does not establish engine ABI compatibility.

See [`BaseRT`](BaseRT.md) and [`_server`](_server.md).
