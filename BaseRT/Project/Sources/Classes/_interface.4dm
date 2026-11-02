Class constructor
	
Function _onTCP($status : Object; $options : Object)
	
	var $startup : cs:C1710._startup
	$startup:=cs:C1710._startup.new()
	If ($options.attempt#Null:C1517) && (Not:C34($startup.active($options.attempt)))
		return
	End if

	If ($status.success)
		
		$name:=$options.name
		OB REMOVE:C1226($options; "name")
		
		CALL WORKER:C1389($name; Formula:C1597(start); $options; Formula:C1597(onModel))
		
	Else 
		
		var $statuses : Text
		$statuses:="TCP port "+String:C10($status.port)+" is aready used by process "+$status.PID.join(",")
		var $error : cs:C1710.event.error
		$error:=cs:C1710.event.error.new(1; $statuses)
		If ($options.attempt#Null:C1517)
			$startup.finish($options.attempt; "failed")
		End if
		
		If (OB Instance of:C1731($options.event; cs:C1710.event.event))\
			 && (OB Instance of:C1731($options.event.onError; 4D:C1709.Function))
			$options.event.onError.call(This:C1470; $options; $error)
		Else
			LOG EVENT:C667(Into 4D debug message:K38:5; $error.message)
		End if 
		
	End if 
	
Function terminate()
	
	cs:C1710._startup.new().cancelAll()
	var $signal : 4D:C1709.Signal
	$signal:=New signal:C1641
	var $process : Object
	$process:=Process info(Current process)
	//Serialize cleanup behind startup without blocking its native callback worker.
	If ($process.name="BaseRT")
		terminatePending($signal)
	Else
		CALL WORKER:C1389("BaseRT"; Formula:C1597(terminatePending); $signal)
		If ($process.name#".workers") && (Not:C34($signal.wait(10)))
			LOG EVENT:C667(Into 4D debug message:K38:5; "BaseRT termination is still pending after 10 seconds; startup remains cancelled.")
		End if
	End if