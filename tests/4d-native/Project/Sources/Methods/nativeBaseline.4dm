#DECLARE($server : cs._server; $model : 4D.File) : Object
var $state : Object
$state:={stdout: ""; stderr: ""; nativeErrors: 0; terminations: 0}
var $options : Object
$options:={dataType: "blob"; timeout: 10}
$options.onData:=Formula(nativeBaselineRecord($state; $1; $2; "stdout"))
$options.onDataError:=Formula(nativeBaselineRecord($state; $1; $2; "stderr"))
$options.onError:=Formula(nativeBaselineRecord($state; $1; $2; "error"))
$options.onTerminate:=Formula(nativeBaselineRecord($state; $1; $2; "termination"))
var $worker : 4D.SystemWorker
$worker:=4D.SystemWorker.new($server.escape($server.executablePath)+" "+$server.escape($model.path)+" --port 8123"; $options)
$worker.wait(15)
nativeAssert($worker.terminated; "Raw blob baseline did not terminate")
If (Not($worker.terminated))
	$worker.terminate()
	$worker.wait(2)
End if
nativeAssert($worker.exitCode=7; "Raw blob baseline lost exit 7")
nativeAssert($state.nativeErrors=0; "Raw blob baseline execution error")
nativeAssert($state.terminations=1; "Raw blob baseline termination count")
$state.responseError:=$worker.responseError
return $state
