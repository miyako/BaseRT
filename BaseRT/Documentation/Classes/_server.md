# _server

Extends [`_BaseRT`](_BaseRT.md) to assemble and launch `basert-serve`.
Application code uses [`BaseRT`](BaseRT.md), not this internal class.

## start(option : Object) -> 4D.SystemWorker

An existing `4D.File` in `option.model` becomes the first positional model.
A collection emits the first existing file positionally and subsequent files
as repeated `--model` arguments. Model paths are escaped and separated from
the executable name.

Other option names replace underscores with hyphens. Numeric and text values
produce `--key value`; numbers are formatted with `_argNumber`, which always
uses `.` as the decimal separator regardless of system locale (`0.3`, `1E-05`); true booleans produce `--key`; existing files/folders
produce escaped paths. Collections repeat the flag. False values are omitted.
`model`, `help`, `version`, `onTerminate`, `onStdErr`, `onStdOut`,
the internal `_onWorkerError` bridge, `executable`, `source_runtime`, and `engine_dir` are not
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

Choose `executable : 4D.File` for an independently installed, compatible,
separately licensed `basert-serve`, or `source_runtime : 4D.Folder` for the
source-built compatibility entry point. No inference runtime is bundled.
The external executable uses its parent as working directory; the adapter
never changes its permissions or searches component resources or `PATH`.
Without a selector this internal method logs a diagnostic and returns Null.
Public startup additionally validates selectors/files and reports error code 3.

The source-runtime selection uses that
folder as the working directory, sets `BASERT_LIB` from the separately licensed
`engine_dir : 4D.Folder`, and disables automatic Superfluid installation.
The entry point fixes `BASERT_SUPERFLUID_DIR` to the staged server.
