# _Model

Extends [`_models`](_models.md) for BaseRT model resolution.

The constructor resolves the files; the `start` project method dispatches
pending downloads or launches an existing local model. This avoids starting
twice when cached downloads finish synchronously. `onDownload(oid)` assigns a downloaded file to `options.model` when
no model was specified, then delegates completion tracking to `_models`.
Use upstream-compatible `.base` weights, not llama.cpp GGUF models.

`models()` returns model names and missing-file status for a file or collection
in `options.model`. The inherited legacy router branch returns an unnamed
entry for existing `models_preset`/`models_dir` paths; these keys are not a
promise of upstream CLI support and should not be used.

`start()` obtains the `_server` worker, starts it with `options.port`, then
immediately invokes `event.onSuccess`. This is a launch notification, **not**
a health/model-readiness check. Inspect stderr/termination and poll the server
before sending inference requests.

With `source_runtime` selected, `start()` first validates the runtime's launcher,
server and worker paths and the separately supplied `engine_dir`. Invalid
selections call `onError` (code 3), or log an error when no event object exists.
This path validation does not establish engine ABI compatibility.

See [`BaseRT`](BaseRT.md) and [`_server`](_server.md).
