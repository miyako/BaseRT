#DECLARE($receiver : Object; $worker : 4D.SystemWorker; $event : Object; $kind : Text)
var $state : Object
$state:=$receiver.state
If ($receiver#$receiver.instance.controller)
	$state.callbackIssues.push("Wrong callback receiver")
End if
If ($worker#$state.currentWorker) || ($event#$state.currentEvent)
	$state.callbackIssues.push("Worker or event identity changed")
End if
Case of
	: ($kind="stdout")
		$state.callbackStdout+=nativeText($event.data)
		$state.callbackStdoutCount+=1
	: ($kind="stderr")
		$state.callbackStderr+=nativeText($event.data)
		$state.callbackStderrCount+=1
	: ($kind="termination")
		$state.callbackTerminations+=1
End case
