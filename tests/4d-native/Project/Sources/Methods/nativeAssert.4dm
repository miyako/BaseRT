#DECLARE($condition : Boolean; $message : Text)
If (Not($condition))
	nativeFailures.push($message)
End if
