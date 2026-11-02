#DECLARE($model : 4D.File) : Object
var $server : cs._server
$server:=cs._server.new(cs.NativeProbe)
var $options : Object
$options:={model: $model}
$options.onTerminate:=Formula(nativeRecord(This; $1; $2; "termination"))
$options._onWorkerError:=Formula(nativeRecordError(This; $1; $2))
var $controller : cs.NativeProbe
$controller:=$server.controller
$controller.timeout:=10
var $first; $second : 4D.SystemWorker
$first:=$server.start($options)
$first.wait(3)
nativeAssert($first.terminated; "Controlled error/reuse warm-up worker did not terminate")
var $firstCache : 4D.Folder
$firstCache:=Folder($controller.variables.HF_HUB_CACHE)

// Recreate the state immediately after execute(), but deliver onError followed
// by onTerminate without onResponse. The worker is real; these two events and
// the no-response lifecycle are controlled, not an observed native OS error.
$controller.reset()
$controller._worker:=$first
$controller._complete:=False
$controller.onResponse:=$controller._onExecute
$controller.onTerminate:=$controller._onComplete
$controller._commands.push("/usr/bin/false")
$controller._messages.push("aborted queued message")
$controller._contexts.push({aborted: True})
$controller.onError($first; {type: "error"})
nativeAssert(($controller._commands.length=0) && ($controller._messages.length=0) && ($controller._contexts.length=0); "Native execution error retained aborted queue entries")
$controller.onTerminate($first; {type: "termination"})
var $state; $result : Object
$state:=$controller.state
$result:={controlled: True; nativeErrors: $state.errors.length; callbackErrors: $state.callbackErrors; responses: $state.responses.length; terminations: $state.terminations.length; complete: $controller.complete; workerRetained: ($controller.worker#Null)}
nativeAssert($state.errors.length=1; "Controlled no-response error count")
nativeAssert($state.callbackErrors=1; "Controlled no-response wrapper callback count")
nativeAssert($state.terminations.length=1; "Controlled no-response termination count")
nativeAssert($controller.complete && ($controller.worker=Null); "Controlled no-response error failed to release the worker")
var $issue : Text
For each ($issue; $state.callbackIssues)
	nativeAssert(False; "Controlled no-response error/reuse: "+$issue)
End for each
$controller.reset()
$second:=$server.start($options)
$result.sameWorker:=($first=$second)
$result.firstPid:=$first.pid
If ($second#Null)
	$result.secondPid:=$second.pid
	$second.wait(3)
End if
$result.reuseStarted:=($controller.state.terminations.length=1)
nativeAssert($result.reuseStarted; "Controlled no-response onError retained the completed worker and blocked the next start: "+JSON Stringify($result))
nativeAssert(Not($result.sameWorker); "Controlled no-response error reused the old native worker")
$server.terminate()
If ($firstCache.exists)
	$firstCache.delete()
End if
var $cache : 4D.Folder
$cache:=Folder($controller.variables.HF_HUB_CACHE)
If ($cache.exists)
	$cache.delete()
End if
return $result
