# _CLI_Controller

Internal process controller for [`_CLI`](_CLI.md).

> _CLI_Controller.new(CLI : cs.BaseRT._CLI)

`execute(command; message; context)` queues a command or collection of commands,
messages and callback contexts. It returns the controller for chaining.
The controller creates `4D.SystemWorker` instances and advances the queue on
response. Messages may be text, blobs, JSON-compatible objects/collections, or
scalar values; posting a message closes the worker's input.

Properties include `worker`, `commands`, `complete`, `instance`,
`currentDirectory`, `variables`, `timeout`, `encoding`, `dataType`, and
`hideWindow`. Default event callbacks are no-ops; specializations can supply
`onData`, `onDataError`, `onError`, `onResponse`, and `onTerminate`.

`terminate()` aborts the queue, terminates the current worker, and restores
the original callbacks. [`_BaseRT_Controller`](_BaseRT_Controller.md) adds
BaseRT termination forwarding.
