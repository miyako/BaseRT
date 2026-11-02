Class constructor($class : 4D.Class)
	If (Storage.workerState=Null)
		Use (Storage)
			Storage.workerState:=New shared object("calls"; 0; "terminations"; 0)
		End use
	End if
Function start($port : Integer; $options : Object)
	Use (Storage.workerState)
		Storage.workerState.calls+=1
	End use
	If (OB Instance of($options.testOnStart; 4D.Function))
		$options.testOnStart.call(Null)
	End if
Function get calls() : Integer
	return Storage.workerState.calls
Function get terminations() : Integer
	return Storage.workerState.terminations
Function terminate()
	Use (Storage.workerState)
		Storage.workerState.terminations+=1
	End use
Function isRunning($port : Integer) : Boolean
	return False
