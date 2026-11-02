#DECLARE($receiver : Object; $options : Object; $error : Object)
var $state : Object
$state:=$receiver.state
$state.callbackErrors+=1
If ($receiver#$receiver.instance.controller)
	$state.callbackIssues.push("Wrong error callback receiver")
End if
If ($options#$receiver.instance.options)
	$state.callbackIssues.push("Original options identity changed")
End if
If (Not(OB Instance of($error; cs.event.error))) || ($error.code#4)
	$state.callbackIssues.push("Native error was not an event.error with code 4")
End if
If (Value type($error.models)#Is collection)
	$state.callbackIssues.push("Native error models is not a collection")
Else
	If ($error.models.length#0)
		$state.callbackIssues.push("Native error models is not empty")
	End if
End if
If (Value type($error.message)#Is text)
	$state.callbackIssues.push("Native error message is not text")
Else
	If (Length($error.message)=0)
		$state.callbackIssues.push("Native error message is empty")
	End if
End if
If ($error.native=Null)
	$state.callbackIssues.push("Missing native error metadata")
Else
	If ($error.native.pid#$state.currentWorker.pid)
		$state.callbackIssues.push("Native pid changed")
	End if
	If ($error.native.event#$state.currentEvent)
		$state.callbackIssues.push("Native event identity changed")
	End if
	If (Value type($error.native.errors)#Value type($state.currentWorker.errors))
		$state.callbackIssues.push("Native errors type changed")
	Else
		If (Value type($state.currentWorker.errors)=Is collection)
			If ($error.native.errors#$state.currentWorker.errors)
				$state.callbackIssues.push("Native errors identity changed")
			End if
		End if
	End if
End if
$state.wrapperError:=$error
