# _models

Shared Hugging Face resolver used by [`_Model`](_Model.md).

The constructor stores the port/options/events, queries the Hugging Face tree
API for each requested repository, and records matching files with their
paths, object IDs and sizes. Short `owner/repo` references use branch `main`.
An absent HTTP response marks the resolver offline and selects the local file.

`download()` reuses an existing file when its size matches the API metadata;
otherwise it delegates transfer to `cs.event.download`. The implementation
does not verify a cryptographic model checksum.

`onDownload(oid)` removes that entry from the pending collection and calls
`start()` once all entries have completed. `models()` and `start()` are virtual
methods implemented by `_Model`.

Use the `event` and `workers` components declared in
`Project/Sources/dependencies.json`; see [`BaseRT`](BaseRT.md) for public usage.
