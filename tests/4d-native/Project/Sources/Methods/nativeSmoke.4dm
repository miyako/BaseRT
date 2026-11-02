ON ERR CALL("catchError")
var nativeFailures : Collection
nativeFailures:=[]
var nativeLaunchState : Object
nativeLaunchState:={engineErrors: []}
var nativeCaughtErrors : Collection
nativeCaughtErrors:=[]
var $resultPath : Text
var $parameter : Integer
$parameter:=Get database parameter(User param value; $resultPath)
var $model : 4D.File
$model:=File($resultPath).parent.file("model with spaces.base")
var $server : cs._server
$server:=cs._server.new(cs.NativeProbe)
nativeAssert(OB Instance of($server.controller; cs.NativeProbe); "Custom controller inheritance was ignored")
var $baseline : Object
$baseline:=nativeBaseline($server; $model)
var $options : Object
$options:={model: $model; port: 8123}
$options.onStdOut:=Formula(nativeRecord(This; $1; $2; "stdout"))
$options.onStdErr:=Formula(nativeRecord(This; $1; $2; "stderr"))
$options.onTerminate:=Formula(nativeRecord(This; $1; $2; "termination"))
$options._onWorkerError:=Formula(nativeRecordError(This; $1; $2))
var $cases : Collection
$cases:=[]
$cases.push(nativeRun($server; $options; "text"; "text"))
$cases.push(nativeRun($server; $options; "blob"; "blob"))
$cases.push(nativeRun($server; {model: $model; port: 8123}; "text"; "absent-reset"))
ON ERR CALL("nativeCatchError")
$cases.push(nativeRun($server; {model: $model; port: 8123; onStdOut: "not callable"; onStdErr: {}; onTerminate: 42; _onWorkerError: True}; "text"; "malformed"))
ON ERR CALL("catchError")
nativeAssert(nativeCaughtErrors.length=0; "Malformed callbacks raised engine errors: "+JSON Stringify(nativeCaughtErrors))
$cases.push(nativeRun($server; $options; "text"; "callable-again"))

// Controlled routing uses a real completed worker, not a fabricated worker or OS failure.
var $controller : cs.NativeProbe
$controller:=$server.controller
$controller.reset()
var $worker : 4D.SystemWorker
$worker:=4D.SystemWorker.new("/usr/bin/true")
$worker.wait(10)
nativeAssert($worker.terminated; "Controlled routing worker did not finish")
var $event : Object
$event:={type: "error"; message: "controlled native-shaped execution error"; errors: [{errorCode: 12345; message: "controlled"; componentSignature: "test"}]}
$controller.onError($worker; $event)
nativeAssert($controller.state.callbackErrors=1; "Controlled onError did not invoke wrapper callback once")
var $issue : Text
For each ($issue; $controller.state.callbackIssues)
	nativeAssert(False; "Controlled onError: "+$issue)
End for each
nativeAssert($controller.state.terminations.length=0; "Controlled onError synthesized a termination")

// Some engines send empty text stderr events in blob mode. Test Blob forwarding
// independently rather than substituting responseError for a native stream event.
var $blob : 4D.Blob
CONVERT FROM TEXT("controlled Blob stderr\n"; "UTF-8"; $blob)
$controller.onDataError($worker; {type: "error"; data: $blob})
nativeAssert($controller.state.callbackStderr="controlled Blob stderr\n"; "Controlled Blob stderr payload changed")
nativeAssert($controller.state.currentEvent.data=$blob; "Controlled Blob stderr identity changed")
For each ($issue; $controller.state.callbackIssues)
	nativeAssert(False; "Controlled Blob stderr: "+$issue)
End for each

// Missing/malformed error callbacks must be safe and must not reuse a previous alias.
var $fallback : Variant
nativeCaughtErrors:=[]
ON ERR CALL("nativeCatchError")
For each ($fallback; [Null; "not callable"; {}; 7; True])
	$server.onWorkerError:=$fallback
	$controller.onError($worker; $event)
End for each
ON ERR CALL("catchError")
nativeAssert(nativeCaughtErrors.length=0; "Absent/malformed onError fallback raised engine errors: "+JSON Stringify(nativeCaughtErrors))
nativeAssert($controller.state.callbackErrors=1; "Fallback onError invoked a stale callback")

// Actual nonexistent executable: capture engine throws instead of pretending they are callbacks.
var $missing : cs._server
$missing:=cs._server.new(cs.NativeProbe)
$missing._executablePath:=File($resultPath).parent.file("does-not-exist").path
$missing.controller.timeout:=10
ON ERR CALL("nativeCatchLaunchError")
$worker:=$missing.start($options)
If ($worker#Null)
	$worker.wait(15)
	If (Not($worker.terminated))
		$worker.terminate()
		$worker.wait(2)
	End if
End if
ON ERR CALL("catchError")
var $state : Object
$state:=$missing.controller.state
nativeLaunchState.nativeErrors:=$state.errors.length
nativeLaunchState.callbackErrors:=$state.callbackErrors
nativeLaunchState.terminations:=$state.terminations.length
nativeLaunchState.callbackTerminations:=$state.callbackTerminations
nativeLaunchState.workerReturned:=($worker#Null)
For each ($issue; $state.callbackIssues)
	nativeAssert(False; "Actual launch error: "+$issue)
End for each
If (nativeLaunchState.engineErrors.length=0)
	nativeAssert($state.errors.length=1; "Actual launch error missing native onError")
	nativeAssert($state.callbackErrors=1; "Actual launch error missing wrapper callback")
	nativeAssert($state.terminations.length=1; "Actual launch error native termination count")
	nativeAssert($state.callbackTerminations=1; "Actual launch error callback termination count")
Else
	var $call; $engineError : Object
	var $missingExecutable : Boolean
	For each ($call; nativeLaunchState.engineErrors)
		For each ($engineError; $call.errors)
			If ($engineError.errCode=2) && ($engineError.componentSignature="POSX")
				$missingExecutable:=True
			End if
		End for each
	End for each
	nativeAssert($missingExecutable; "Actual launch error threw without the expected POSX ENOENT")
End if
var $cache : 4D.Folder
$cache:=Folder($missing.controller.variables.HF_HUB_CACHE)
If ($cache.exists)
	$cache.delete()
End if
var $reuse : Object
$reuse:=nativeReuse($model)
var $controlledReuse : Object
$controlledReuse:=nativeErrorReuse($model)
var $logProbe : Object
$logProbe:=nativeLogProbe($model; File($resultPath).parent.name)
File($resultPath).setText(JSON Stringify({errors: nativeFailures; cases: $cases; blobBaseline: $baseline; launchError: nativeLaunchState; reuse: $reuse; controlledReuse: $controlledReuse; logProbe: $logProbe}))
QUIT 4D
