property onResponse : 4D:C1709.Function

Class extends _CLI_Controller

Class constructor($CLI : cs:C1710._CLI)
	
	Super:C1705($CLI)
	
Function onData($worker : 4D:C1709.SystemWorker; $params : Object)
	
	If (Value type:C1509(This:C1470.instance.onData)=Is object:K8:27)\
		 && (OB Instance of:C1731(This:C1470.instance.onData; 4D:C1709.Function))
		This:C1470.instance.onData.call(This:C1470; $worker; $params)
	End if
	
Function onDataError($worker : 4D:C1709.SystemWorker; $params : Object)
	
	If (Value type:C1509(This:C1470.instance.onDataError)=Is object:K8:27)\
		 && (OB Instance of:C1731(This:C1470.instance.onDataError; 4D:C1709.Function))
		This:C1470.instance.onDataError.call(This:C1470; $worker; $params)
	End if

Function onError($worker : 4D:C1709.SystemWorker; $params : Object)

	//Execution errors can terminate without a response event.
	This:C1470._abort()
	This:C1470._messages.clear()
	This:C1470._contexts.clear()
	var $error : cs:C1710.event.error
	$error:=cs:C1710.event.error.new(4; "BaseRT process execution failed."; cs:C1710.event.models.new([]))
	$error.native:={pid: $worker.pid; errors: $worker.errors; event: $params}
	If (Value type:C1509(This:C1470.instance.onWorkerError)=Is object:K8:27)\
		 && (OB Instance of:C1731(This:C1470.instance.onWorkerError; 4D:C1709.Function))
		This:C1470.instance.onWorkerError.call(This:C1470; This:C1470.instance.options; $error)
	Else
		LOG EVENT:C667(Into 4D debug message:K38:5; $error.message+" "+JSON Stringify:C1217($error.native))
	End if
	
Function onTerminate($worker : 4D:C1709.SystemWorker; $params : Object)
	
	var $instance : cs:C1710._server
	$instance:=This:C1470.instance
	
	If (Value type:C1509($instance.onTerminate)=Is object:K8:27)\
		 && (OB Instance of:C1731($instance.onTerminate; 4D:C1709.Function))
		$instance.onTerminate.call(This:C1470; $worker; $params)
	End if 