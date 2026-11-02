# _interface

Shared lifecycle base for [`BaseRT`](BaseRT.md).

`_onTCP(status; options)` starts the model worker when the port preflight
succeeds. On conflict it calls `event.onError` with error code 1 and the
conflicting port/process information.

`terminate()` first invalidates all pending adapter startup tokens, including
TCP preflight and downloads, then serializes native-worker cleanup on the
`BaseRT` startup worker. It retains the existing all-registered-workers scope.
Outside the startup/native-worker callback contexts it waits up to 10 seconds
for the cleanup request, logging if still pending; callback contexts avoid
waiting on their own worker. New attempts during cleanup are cancelled.
Late old callbacks cannot start a server or affect a later independent run.
External download HTTP/file operations are not aborted by this token cancellation.

```4d
var $BaseRT : cs.BaseRT.BaseRT
$BaseRT:=cs.BaseRT.BaseRT.new()
$BaseRT.terminate()
```

Calling the zero-argument constructor is the existing termination idiom; it
does not prove a model was loaded or an HTTP endpoint was ready.
