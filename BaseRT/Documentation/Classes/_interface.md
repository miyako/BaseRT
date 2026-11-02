# _interface

Shared lifecycle base for [`BaseRT`](BaseRT.md).

`_onTCP(status; options)` starts the model worker when the port preflight
succeeds. On conflict it calls `event.onError` with error code 1 and the
conflicting port/process information.

`terminate()` obtains the registered `_server` worker through the `workers`
component and terminates it.

```4d
var $BaseRT : cs.BaseRT.BaseRT
$BaseRT:=cs.BaseRT.BaseRT.new()
$BaseRT.terminate()
```

Calling the zero-argument constructor is the existing termination idiom; it
does not prove a model was loaded or an HTTP endpoint was ready.
