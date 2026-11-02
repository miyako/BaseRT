#DECLARE() : Collection
var $errors : Collection
$errors:=[]
var $root : 4D.Folder
$root:=Folder("/RESOURCES/lifecycle")
$root.create()
var $a; $b : 4D.File
$a:=$root.file("a.base")
$b:=$root.file("b.base")
var $event : cs.event.event
$event:=cs.event.event.new()
var $trace : Object
$trace:={successes: 0; errors: 0}
$event.onSuccess:=Formula($trace.successes+=1)
$event.onError:=Formula($trace.errors+=1)
var $worker : cs.workers.worker
$worker:=cs.workers.worker.new()
var $before : Integer
$before:=$worker.calls
var $model : cs.LifecycleModels
var $defaultEvent : cs.event.event
$defaultEvent:=cs.event.event.new()
$model:=cs.LifecycleModels.new(18015; {model: $a}; $defaultEvent)
If ($model.options._onWorkerError#Null)
	$errors.push("Empty default event.onError suppressed native diagnostic logging")
End if
cs._startup.new().finish($model.attempt; "cancelled")
var $customEvent : cs.event.customEvent
$customEvent:=cs.event.customEvent.new()
$model:=cs.LifecycleModels.new(18016; {model: $a}; $customEvent)
If (Not(OB Instance of($model.options._onWorkerError; 4D.Function)))
	$errors.push("Subclass onError override was not retained: "+JSON Stringify({name: OB Class($model.event).name; expected: cs.event.event.name; keys: OB Keys($model.event); isBase: OB Instance of($model.event; cs.event.event); sameClass: OB Class($model.event)=cs.event.event; callbackType: Value type($model.options._onWorkerError)}))
End if
cs._startup.new().finish($model.attempt; "cancelled")
$model:=cs.LifecycleModels.new(18001; {model: [$a; $b]}; $event)
$model.files:=[{oid: "same"; folder: $a; size: 4}; {oid: "same"; folder: $b; size: 4}]
$model.download()
$model.start()
testCheckpoint("deferred equal-oid gating")
If ($model.testDownloads.length#2) || ($worker.calls#$before)
	$errors.push("Uncached records were not all registered before dispatch")
End if
$model.onDownload("same")
If ($model.files.length#2)
	$errors.push("Ambiguous legacy oid completion removed multiple destinations")
End if
$model.testDownloads[0].complete()
If ($worker.calls#$before) || ($model.files.length#1)
	$errors.push("Equal-oid first destination started before second completed")
End if
$model.testDownloads[0].complete()
$model.onDownload("unknown")
If ($worker.calls#$before) || ($model.files.length#1)
	$errors.push("Duplicate/unknown completion mutated pending destinations")
End if
$model.testDownloads[1].complete()
testCheckpoint("exactly-once final completion")
$model.testDownloads[1].complete()
$model.start()
$model.download()
If ($worker.calls#($before+1)) || ($trace.successes#1)
	$errors.push("Uncached completion/start was not exactly once")
End if

$before:=$worker.calls
$model:=cs.LifecycleModels.new(18002; {model: [$a; $b]}; $event)
$model.files:=[{oid: "same"; folder: $root; path: "a.base"; size: 4}; {oid: "same"; folder: $root; path: "b.base"; size: 4}]
$model.download()
If ($worker.calls#($before+1)) || ($model.testDownloads.length#0)
	$errors.push("All-cached synchronous completions skipped or double-started")
End if
$before:=$worker.calls
$model:=cs.LifecycleModels.new(18017; {}; $event)
$model.files:=[{oid: "a"; folder: $root; path: "a.base"; size: 4}; {oid: "b"; folder: $root; path: "b.base"; size: 4}]
$model.download()
If ($worker.calls#($before+1)) || ($model.options.model.path#$a.path) || ($model.files.length#0)
	$errors.push("Default model selection lost the completed destination or all-file gate")
End if

$b.delete()
testCheckpoint("mixed inline completion")
$before:=$worker.calls
$model:=cs.LifecycleModels.new(18003; {model: [$a; $b]}; $event)
$model.files:=[{oid: "a"; folder: $a; size: 4}; {oid: "b"; folder: $b; size: 4}]
$model.schedule:="inline"
$model.download()
If ($worker.calls#($before+1)) || ($model.testDownloads.length#1)
	$errors.push("Mixed cached/inline transfer did not gate every destination")
End if

$a.delete()
$b.delete()
testCheckpoint("failure and late completion")
$before:=$worker.calls
$model:=cs.LifecycleModels.new(18004; {model: [$a; $b]}; $event)
$model.files:=[{oid: "a"; folder: $a; size: 4}; {oid: "b"; folder: $b; size: 4}]
$model.download()
$model.testDownloads[1].complete()
If ($worker.calls#$before)
	$errors.push("Out-of-order completion started with a pending destination")
End if
$model.testDownloads[0].fail()
$model.testDownloads[0].fail()
$model.testDownloads[0].complete()
$model.start()
If ($worker.calls#$before) || ($model.failures#1) || ($model.attempt.state#"failed")
	$errors.push("Failure/late completion reopened or repeated a failed attempt")
End if

$a.delete()
$b.delete()
$model:=cs.LifecycleModels.new(18005; {model: [$a; $b]}; $event)
$model.files:=[{oid: "a"; folder: $a; size: 4}; {oid: "b"; folder: $b; size: 4}]
$model.schedule:="failure"
$model.download()
If ($model.testDownloads.length#1) || ($model.failures#1)
	$errors.push("Inline failure did not prevent remaining dispatch")
End if

var $old : cs.LifecycleModels
testCheckpoint("replacement generation")
$old:=cs.LifecycleModels.new(18006; {model: $a}; $event)
$old.files:=[{oid: "a"; folder: $a; size: 4}]
$old.download()
$model:=cs.LifecycleModels.new(18006; {model: $a}; $event)
$model.files:=[{oid: "a"; folder: $a; size: 4}]
$model.download()
$old.testDownloads[0].fail()
$old.testDownloads[0].complete()
$old.start()
If ($worker.calls#$before) || ($old.failures#0) || ($old.attempt.state#"cancelled")
	$errors.push("Stale generation callback affected a replacement attempt")
End if
$model.testDownloads[0].complete()
If ($worker.calls#($before+1))
	$errors.push("Replacement generation failed to complete independently")
End if

$a.delete()
$before:=$worker.calls
testCheckpoint("public termination")
$model:=cs.LifecycleModels.new(18007; {model: $a}; $event)
$model.files:=[{oid: "a"; folder: $a; size: 4}]
$model.download()
var $pending : Object
$pending:=cs._startup.new().create(18008)
var $interface : cs._interface
$interface:=cs._interface.new()
$interface.terminate()
$model.testDownloads[0].complete()
$model.testDownloads[0].fail()
$model.start()
$interface._onTCP({success: False}; {attempt: $pending; event: $event})
start({attempt: $pending; port: 18008; huggingfaces: cs.event.huggingfaces.new([]); options: {model: $a}; event: $event}; Formula(Null))
If ($worker.calls#$before) || ($model.failures#0) || ($model.attempt.state#"cancelled") || ($pending.state#"cancelled")
	$errors.push("Terminate allowed a late download/TCP/start to launch")
End if
$model:=cs.LifecycleModels.new(18007; {model: $a}; $event)
$model.start()
If ($worker.calls#($before+1))
	$errors.push("Completed cancellation blocked a later independent run")
End if
If ($trace.errors#0)
	$errors.push("Cancellation/stale completions emitted an unexpected user error")
End if
$a.delete()
$before:=$worker.calls
testCheckpoint("wrong-size completion")
$model:=cs.LifecycleModels.new(18009; {model: $a}; $event)
$model.files:=[{oid: "a"; folder: $a; size: 5}]
$model.download()
$model.testDownloads[0].complete()
$model.testDownloads[0].complete()
If ($worker.calls#$before) || ($trace.errors#1) || ($model.attempt.state#"failed")
	$errors.push("Wrong-size completion was accepted or error was repeated")
End if
$model:=cs.LifecycleModels.new(18010; {model: [$a; $root.file("missing.base")]}; $event)
testCheckpoint("invalid local collection")
$model.start()
If ($worker.calls#$before) || ($trace.errors#2)
	$errors.push("Invalid required local model collection reached launch")
End if
$model:=cs.LifecycleModels.new(18014; {model: [$a; "not a File"]}; $event)
$model.start()
If ($worker.calls#$before) || ($trace.errors#3)
	$errors.push("Malformed model collection did not report a safe selection error")
End if

testCheckpoint("real model failure adapter signature")
$a.delete()
$trace.lastError:=Null
$trace.receiver:=Null
$event.onError:=Formula(recordLifecycleError($trace; This; $2))
$model:=cs.LifecycleModels.new(18011; {model: $a}; $event)
$model._onResponse:=Formula(onModel)
$model.files:=[{oid: "a"; folder: $a; size: 4}]
$model.download()
$model.testDownloads[0].fail()
$model.testDownloads[0].fail()
$model.testDownloads[0].complete()
If ($trace.errors#4) || ($trace.lastError.code#2) || ($trace.receiver#$model) || ($worker.calls#$before)
	$errors.push("Download failure adapter changed callback shape/receiver or repeated terminal result")
End if

testCheckpoint("cancellation during claimed launch")
var $successes; $terminations : Integer
$successes:=$trace.successes
$terminations:=$worker.terminations
$model:=cs.LifecycleModels.new(18012; {model: $a; testOnStart: Formula($interface.terminate())}; $event)
$model.start()
If ($worker.calls#($before+1)) || ($trace.successes#$successes) || ($model.attempt.state#"cancelled") || ($worker.terminations#($terminations+1))
	$errors.push("Claimed-launch cancellation: "+JSON Stringify({calls: $worker.calls; before: $before; successes: $trace.successes; expectedSuccesses: $successes; state: $model.attempt.state; terminations: $worker.terminations; expectedTerminations: $terminations+1}))
End if
$model:=cs.LifecycleModels.new(18012; {model: $a}; $event)
$model.start()
If ($worker.calls#($before+2)) || ($trace.successes#($successes+1))
	$errors.push("Old claimed-launch cancellation affected a newer completed run")
End if

testCheckpoint("cross-worker cancelled token")
$before:=$worker.calls
$pending:=cs._startup.new().create(18013)
var $gate; $finished : 4D.Signal
$gate:=New signal
$finished:=New signal
CALL WORKER("BaseRT"; Formula(testQueuedStart); {attempt: $pending; port: 18013; huggingfaces: cs.event.huggingfaces.new([]); options: {model: $a}; event: $event}; $gate; $finished)
cs._startup.new().finish($pending; "cancelled")
$gate.trigger()
If (Not($finished.wait(5))) || ($worker.calls#$before)
	$errors.push("Cross-worker startup did not share cancelled attempt identity")
End if
If (cs._startup.new().registry.items.length#0) || (cs._startup.new().registry.stopping#0)
	$errors.push("Terminal attempts or cleanup state leaked in shared registry")
End if

return $errors
