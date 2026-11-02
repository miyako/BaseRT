ON ERR CALL("catchError")
var $errors : Collection
$errors:=[]
var $root : 4D.Folder
$root:=Folder(Temporary folder; fk platform path).folder(Generate UUID)
$root.create()
var $model; $second : 4D.File
$model:=$root.file("model with spaces.base")
$second:=$root.file("second.base")
$model.setText("test")
$second.setText("test")
var $server : cs._server
$server:=cs._server.new()
var $options : Object
$options:={model: $model; port: 8080; max_tokens: 128}
$server.start($options)
var $command : Text
$command:=$server.controller.lastCommand
If (Position("basert-serve "+$server.escape($model.path); $command)=0)
	$errors.push("Missing executable/model argument separator")
End if
If (Position("--port 8080"; $command)=0) || (Position("--max-tokens 128"; $command)=0)
	$errors.push("Numeric flags missing")
End if
Folder($server.controller.variables.HF_HUB_CACHE).delete()

$options.model:=[$model; $second]
$options.source_runtime:=$root.folder("runtime with spaces")
$options.engine_dir:=$root.folder("engine with spaces")
$options.source_runtime.create()
$options.engine_dir.create()
$server.start($options)
$command:=$server.controller.lastCommand
If (Position($server.escape($options.source_runtime.file("basert-serve").path)+" "; $command)#1)
	$errors.push("Wrong source runtime executable")
End if
If (Position(" --model "+$server.escape($second.path); $command)=0)
	$errors.push("Additional model flag missing")
End if
If (Position("--source-runtime"; $command)#0) || (Position("--engine-dir"; $command)#0)
	$errors.push("Adapter-only options leaked to CLI")
End if
If ($server.controller.variables.BASERT_LIB#$options.engine_dir.path)
	$errors.push("Wrong BASERT_LIB")
End if
If ($server.controller.variables.BASERT_SUPERFLUID_AUTO_INSTALL#"0")
	$errors.push("Auto-install was not disabled")
End if
Folder($server.controller.variables.HF_HUB_CACHE).delete()
var $event : cs.event.event
$event:=cs.event.event.new()
$event.onError:=Formula(recordError($1; $2))
var $worker : cs.workers.worker
$worker:=cs.workers.worker.new()
start({port: 8080; huggingfaces: cs.event.huggingfaces.new([]); options: {model: $model}; event: $event}; Formula(Null))
If ($worker.calls#1)
	$errors.push("Local model without downloads was not started exactly once")
End if
start({port: 8080; huggingfaces: cs.event.huggingfaces.new([]); options: {model: $model; source_runtime: "invalid"}; event: $event}; Formula(Null))
If ($worker.calls#1) || (Storage.errorState.code#3)
	$errors.push("Invalid source_runtime did not fail before worker launch")
End if
start({port: 8080; huggingfaces: cs.event.huggingfaces.new([]); options: $options; event: $event}; Formula(Null))
If ($worker.calls#1) || (Storage.errorState.code#3)
	$errors.push("Incomplete source runtime did not fail before worker launch")
End if
var $name : Text
var $runtimeFiles : Collection
$runtimeFiles:=["basert"; "basert-serve"; "superfluid/bin/superfluid"; "superfluid/bin/superfluid-workerd"; "superfluid/bin/superfluid-noded"; "superfluid/libexec/superfluid/superfluid-worker-basert"]
For each ($name; $runtimeFiles)
	$options.source_runtime.file($name).parent.create()
	$options.source_runtime.file($name).setText("test")
End for each
$options.engine_dir.file("libbaseRT.dylib").setText("test")
start({port: 8080; huggingfaces: cs.event.huggingfaces.new([]); options: $options; event: $event}; Formula(Null))
If ($worker.calls#2)
	$errors.push("Complete source runtime was not selected")
End if
start({port: 8080; huggingfaces: cs.event.huggingfaces.new([]); options: {}; event: $event}; Formula(Null))
If ($worker.calls#2) || (Storage.errorState.code#2)
	$errors.push("Missing model did not report an error")
End if
start({port: 8080; huggingfaces: cs.event.huggingfaces.new([]); options: {model: $model}}; Formula(Null))
If ($worker.calls#3)
	$errors.push("Null event object prevented local model start")
End if
var $resultPath : Text
var $parameter : Integer
$parameter:=Get database parameter(User param value; $resultPath)
File($resultPath).setText(JSON Stringify({errors: $errors; command: $command}))
$model.delete()
$second.delete()
For each ($name; $runtimeFiles)
	$options.source_runtime.file($name).delete()
End for each
$options.source_runtime.folder("superfluid/libexec/superfluid").delete()
$options.source_runtime.folder("superfluid/libexec").delete()
$options.source_runtime.folder("superfluid/bin").delete()
$options.source_runtime.folder("superfluid").delete()
$options.engine_dir.file("libbaseRT.dylib").delete()
$options.source_runtime.delete()
$options.engine_dir.delete()
$root.delete()
QUIT 4D
