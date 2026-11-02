//%attributes = {}
#DECLARE($status : Object; $options : Object)

If ($status.success)
	
Else 
	
	var $error : cs:C1710.event.error
	$error:=cs:C1710.event.error.new(2; "failed to load model!"; This:C1470.that.models())
	
	If (OB Instance of:C1731(This:C1470.event; cs:C1710.event.event))\
		 && (OB Instance of:C1731(This:C1470.event.onError; 4D:C1709.Function))
		This:C1470.event.onError.call(This:C1470.that; $options; $error)
	Else
		LOG EVENT:C667(Into 4D debug message:K38:5; $error.message)
	End if 
	
	var $workers : cs:C1710.workers.workers
	$workers:=cs:C1710.workers.workers.new()
	$workers.remove($options.port)
	
End if 