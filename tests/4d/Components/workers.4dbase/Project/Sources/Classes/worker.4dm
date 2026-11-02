Class constructor($class : 4D.Class)
	If (Storage.workerState=Null)
		Use (Storage)
			Storage.workerState:=New shared object("calls"; 0)
		End use
	End if
Function start($port : Integer; $options : Object)
	Use (Storage.workerState)
		Storage.workerState.calls+=1
	End use
Function get calls() : Integer
	return Storage.workerState.calls
