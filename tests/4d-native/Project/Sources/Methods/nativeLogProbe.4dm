#DECLARE($model : 4D.File; $token : Text) : Object
var $server : cs._server
$server:=cs._server.new(cs.NativeProbe)
var $options : Object
$options:={model: $model}
$options._onWorkerError:=Formula(nativeRecordError(This; $1; $2))
var $worker : 4D.SystemWorker
$worker:=$server.start($options)
$worker.wait(3)
nativeAssert($worker.terminated; "Log probe worker did not terminate")
var $controller : cs.NativeProbe
$controller:=$server.controller
$controller.reset()
$controller.onError($worker; {type: "error"; nativeLogProbe: $token+"-subscribed"})
nativeAssert($controller.state.callbackErrors=1; "Subscribed log probe callback count")
$server.onWorkerError:=Null
$controller.onError($worker; {type: "error"; nativeLogProbe: $token+"-fallback"})
nativeAssert($controller.state.callbackErrors=1; "Fallback log probe invoked a subscribed callback")
var $issue : Text
For each ($issue; $controller.state.callbackIssues)
	nativeAssert(False; "Log probe callback identity: "+$issue)
End for each
var $cache : 4D.Folder
$cache:=Folder($controller.variables.HF_HUB_CACHE)
If ($cache.exists)
	$cache.delete()
End if
return {token: $token; callbackErrors: $controller.state.callbackErrors; routedErrors: $controller.state.errors.length}
