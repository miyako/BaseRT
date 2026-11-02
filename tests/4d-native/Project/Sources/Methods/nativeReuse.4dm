#DECLARE($model : 4D.File) : Object
var $server : cs._server
$server:=cs._server.new(cs.NativeProbe)
var $options : Object
$options:={model: $model; native_timeout: True}
$options.onStdOut:=Formula(nativeRecord(This; $1; $2; "stdout"))
$options.onStdErr:=Formula(nativeRecord(This; $1; $2; "stderr"))
$options.onTerminate:=Formula(nativeRecord(This; $1; $2; "termination"))
$options._onWorkerError:=Formula(nativeRecordError(This; $1; $2))
var $controller : cs.NativeProbe
$controller:=$server.controller
$controller.timeout:=1
var $first; $second : 4D.SystemWorker
$first:=$server.start($options)
$first.wait(3)
If (Not($first.terminated))
	$first.terminate()
	$first.wait(2)
End if
var $state; $result : Object
$state:=$controller.state
$result:={nativeErrors: $state.errors.length; responses: $state.responses.length; terminations: $state.terminations.length; complete: $controller.complete; workerRetained: ($controller.worker#Null)}
var $issue : Text
For each ($issue; $state.callbackIssues)
	nativeAssert(False; "Native execution-error/reuse: "+$issue)
End for each
$controller.reset()
$controller.timeout:=10
OB REMOVE($options; "native_timeout")
$second:=$server.start($options)
$result.sameWorker:=($first=$second)
$result.firstPid:=$first.pid
If ($second#Null)
	$result.secondPid:=$second.pid
	$second.wait(3)
End if
$result.reuseStarted:=($controller.state.terminations.length=1)
If ($state.errors.length>0)
	nativeAssert($state.errors.length=1; "Native execution error count")
	nativeAssert($state.callbackErrors=1; "Native execution error wrapper callback count")
	nativeAssert($state.terminations.length=1; "Native execution error termination count")
	nativeAssert($result.reuseStarted; "Native onError retained the completed worker and blocked the next start: "+JSON Stringify($result))
Else
	$result.limit:="The real timed-out worker produced no native onError on this engine; reuse is not evidence of the onError lifecycle."
End if
$server.terminate()
var $cache : 4D.Folder
$cache:=Folder($controller.variables.HF_HUB_CACHE)
If ($cache.exists)
	$cache.delete()
End if
return $result
