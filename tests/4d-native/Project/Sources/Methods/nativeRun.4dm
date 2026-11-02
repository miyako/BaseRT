#DECLARE($server : cs._server; $options : Object; $dataType : Text; $label : Text) : Object
var $controller : cs.NativeProbe
$controller:=$server.controller
$controller.reset()
$controller.dataType:=$dataType
$controller.timeout:=10
var $state : Object
$state:=$controller.state
var $worker : 4D.SystemWorker
$worker:=$server.start($options)
nativeAssert($server.options=$options; $label+": original options identity")
var $alias : Object
var $expected : Variant
For each ($alias; [{input: "onStdOut"; output: "onData"}; {input: "onStdErr"; output: "onDataError"}; {input: "onTerminate"; output: "onTerminate"}; {input: "_onWorkerError"; output: "onWorkerError"}])
	$expected:=$options[$alias.input]
	If ($alias.input="onTerminate") && ($expected#Null) && (Not(nativeCallable($expected)))
		nativeAssert(Not(nativeCallable($server[$alias.output])); $label+": malformed termination callback retained a callable alias")
	Else
		If (Not(nativeCallable($expected)))
			$expected:=Null
		End if
		nativeAssert($server[$alias.output]=$expected; $label+": alias "+$alias.output+" was not bound/reset")
	End if
End for each
If ($worker=Null)
	nativeAssert(False; $label+": no worker")
	return {label: $label}
End if
$worker.wait(15)
nativeAssert($worker.terminated; $label+": worker did not terminate")
If (Not($worker.terminated))
	$worker.terminate()
	$worker.wait(2)
End if
nativeAssert($worker.exitCode=7; $label+": exit 7 lost")
nativeAssert($state.errors.length=0; $label+": nonzero exit incorrectly became a native execution error")
nativeAssert($state.callbackErrors=0; $label+": nonzero exit incorrectly invoked onWorkerError")
nativeAssert($state.terminations.length=1; $label+": native termination count")
nativeAssert($state.responses.length=1; $label+": native response count")
nativeAssert($state.stdout.length>0; $label+": no native stdout")
nativeAssert($state.stderr.length>0; $label+": no native stderr")
var $callbacks : Boolean
$callbacks:=nativeCallable($options.onStdOut)
If ($callbacks)
	nativeAssert($state.callbackStdoutCount=$state.stdout.length; $label+": stdout callback count")
	nativeAssert($state.callbackStderrCount=$state.stderr.length; $label+": stderr callback count")
	nativeAssert($state.callbackTerminations=1; $label+": callback termination count")
Else
	nativeAssert($state.callbackStdoutCount=0; $label+": absent/malformed stdout callback invoked")
	nativeAssert($state.callbackStderrCount=0; $label+": absent/malformed stderr callback invoked")
	nativeAssert($state.callbackTerminations=0; $label+": absent/malformed termination callback invoked")
End if
var $entries : Collection
var $entry : Object
var $stream : Text
var $stdout; $stderr : Text
For each ($stream; ["stdout"; "stderr"])
	$entries:=$state[$stream]
	For each ($entry; $entries)
		nativeAssert($entry.worker=$worker; $label+": native worker identity")
		If ($dataType="text") || ($stream="stderr")
			nativeAssert(Value type($entry.event.data)=Is text; $label+": native text type")
		Else
			If (Value type($entry.event.data)=Is object)
				nativeAssert(OB Instance of($entry.event.data; 4D.Blob); $label+": native Blob object type")
			Else
				nativeAssert(Value type($entry.event.data)=Is BLOB; $label+": native Blob type was "+String(Value type($entry.event.data))+"; worker dataType="+$worker.dataType)
			End if
		End if
		If ($stream="stdout")
			nativeAssert($entry.event.type="data"; $label+": stdout event type")
			$stdout+=nativeText($entry.event.data)
		Else
			nativeAssert($entry.event.type="error"; $label+": stderr event type")
			$stderr+=nativeText($entry.event.data)
		End if
	End for each
End for each
For each ($entry; $state.terminations)
	nativeAssert($entry.worker=$worker; $label+": termination worker identity")
	nativeAssert($entry.event.type="termination"; $label+": termination event type")
End for each
For each ($stream; $state.callbackIssues)
	nativeAssert(False; $label+": "+$stream)
End for each
var $cache : 4D.Folder
$cache:=Folder($controller.variables.HF_HUB_CACHE)
If ($cache.exists)
	$cache.delete()
End if
return {label: $label; callbacks: $callbacks; stdout: $stdout; stderr: $stderr; callbackStdout: $state.callbackStdout; callbackStderr: $state.callbackStderr; responseError: $worker.responseError; exitCode: $worker.exitCode; nativeErrors: $state.errors.length; terminations: $state.terminations.length}
