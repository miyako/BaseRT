# _BaseRT_Controller
### Extends `_CLI_Controller` with BaseRT-specific process callbacks.

> _BaseRT_Controller.new (CLI : cs.BaseRT._CLI)

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| CLI | cs.BaseRT._CLI | -> | The owning `_CLI` (typically a `_server` instance) |

## Description

`_BaseRT_Controller` is the default controller used by all `_BaseRT` subclasses.
It inherits queueing from [`_CLI_Controller`](_CLI_Controller.md) and forwards
stdout, stderr and termination to callable instance callbacks. Their unchanged
arguments are `(worker, event)` and their receiver is the controller.

### Overridden event callbacks

Subclasses may override these native callbacks:

| Property | Description |
| --- | --- |
| onData | Forwards stdout to instance.onData |
| onDataError | Forwards stderr to instance.onDataError; not automatically fatal |
| onResponse | Inherited response / command-complete queue handling, not the HTTP download event |
| onError | Translates native execution errors into event.error code 4 |

Native `onError(worker, event)` has a different signature from public
`event.onError(options, error)`. The internal `onWorkerError` bridge receives
the original options and a constructed `cs.event.error` with code 4, a message,
and `native` details (`pid`, original `errors`, original `event`). Its receiver
is the controller. Without a callable bridge the diagnostic is logged.
The resolver does not install a bridge for the pinned event class's empty
default handler; explicit Formula overrides and component-local subclasses
are retained.
Ordinary stderr/nonzero exits are not relabeled as native execution errors.
A later native failure does not redefine the earlier launch-requested success.
Execution errors discard the aborted command/message/context queue so that
termination releases the worker even without a response event. A subsequent
start after termination can then launch a new worker.

#### onTerminate ($worker : 4D.SystemWorker; $params : Object)

Called when the managed `SystemWorker` terminates. Looks up `onTerminate` on the owning `_server` instance and calls it if present.

| Parameter | Type | | Description |
| --- | --- | --- | --- |
| $worker | 4D.SystemWorker | -> | The worker that terminated |
| $params | Object | -> | Termination parameters from the system worker |

## Examples

### Custom controller subclass

To handle stdout while the server is running, create a subclass of `_BaseRT_Controller` and override `onData`:

```4d
// Inside the BaseRT component project:
Class extends _BaseRT_Controller

Function onData($worker : 4D.SystemWorker; $params : Object)
    LOG EVENT(Into 4D debug message; $params.data)
```

Internal subclasses can pass that class to `_server.new(MyController)`.
4D does not support extending a user class from another project/component;
a host application should use event callbacks rather than copying this
inheritance declaration into its own project.
The public `BaseRT.new(...)` constructor does not accept a controller class.
For public termination notifications use the event object:

```4d
$event.onTerminate:=Formula(LOG EVENT(Into 4D debug message; "BaseRT exited"))
$BaseRT:=cs.BaseRT.BaseRT.new($port; $huggingfaces; $homeFolder; $options; $event)
```

## See also

- [`_CLI_Controller`](_CLI_Controller.md) — parent class
- [`_BaseRT`](_BaseRT.md) — attaches this controller by default
- [`_server`](_server.md) — the `_BaseRT` subclass whose `onTerminate` is forwarded here
