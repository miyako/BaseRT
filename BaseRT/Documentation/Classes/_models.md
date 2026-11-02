# _models

Shared Hugging Face resolver used by [`_Model`](_Model.md).

The constructor stores the port/options/events, queries the Hugging Face tree
API for each requested repository, and records matching files with their
paths, object IDs and sizes. Short `owner/repo` references use branch `main`.
An absent HTTP response marks the resolver offline and selects the local file.

`download()` reuses an existing file when its size matches the API metadata;
otherwise it delegates transfer to `cs.event.download`. The implementation
does not verify a cryptographic model checksum.

`download()` registers the complete pending set before dispatch. Each destination
has a separate completion identity, even when two records share a provider
object ID. Cached completion may run synchronously. Deferred callbacks carry
both their destination and attempt generation; repeated calls to `download()`
do not dispatch the same attempt again.

`onDownload(oid; identity; generation)` validates and completes one pending
record. The original one-argument form still accepts an unambiguous pending
object ID; unknown, duplicate or ambiguous completions are diagnosed and ignored.
`start()` runs only after every required destination validates. `models()` and
`start()` are virtual methods implemented by `_Model`.

The private `_startup` registry tracks shared attempt tokens across preflight
and model-worker processes. A replacement attempt at the same port invalidates
its predecessor. Failure and public termination invalidate pending attempts
before forwarding failure/cleanup; late callbacks cannot re-open them or
complete a newer generation. The original download status receiver and arguments
are preserved. This does not cancel external HTTP requests/file writes, whose
handles the download component does not expose.

Use the `event` and `workers` components declared in
`Project/Sources/dependencies.json`; see [`BaseRT`](BaseRT.md) for public usage.
