# _server

Extends [`_BaseRT`](_BaseRT.md) to assemble and launch `basert-serve`.
Application code uses [`BaseRT`](BaseRT.md), not this internal class.

## start(option : Object) -> 4D.SystemWorker

An existing `4D.File` in `option.model` becomes the first positional model.
A collection emits the first existing file positionally and subsequent files
as repeated `--model` arguments. Model paths are escaped and separated from
the executable name.

Other option names replace underscores with hyphens. Numeric and text values
produce `--key value`; true booleans produce `--key`; existing files/folders
produce escaped paths. Collections repeat the flag. False values are omitted.
`model`, `help`, `version`, `onTerminate`, `onStdErr`, `onStdOut`,
the internal `_onWorkerError` bridge, `source_runtime`, and `engine_dir` are not
emitted as generic CLI arguments. Only pass flags accepted by the pinned
upstream server; the wrapper is not a CLI option validator.

`start` maps callable `onStdOut`/`onStdErr` options to native
`onData`/`onDataError`, binds termination and the internal execution-error
bridge, creates a temporary `HF_HUB_CACHE`
directory, and delegates to [`_CLI_Controller`](_CLI_Controller.md).
Missing stream/error aliases are reset on each start so reuse cannot retain a
previous subscriber; malformed non-null aliases are diagnosed. The lower-level
`_BaseRT` native properties remain available for direct controller execution.
The returned worker indicates process creation, not HTTP/model readiness.

The optional `source_runtime : 4D.Folder` selects the source-built compatibility
entry point without replacing the bundled legacy executable. It uses that
folder as the working directory, sets `BASERT_LIB` from the separately licensed
`engine_dir : 4D.Folder`, and disables automatic Superfluid installation.
The entry point fixes `BASERT_SUPERFLUID_DIR` to the staged server.
