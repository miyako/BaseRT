#DECLARE($options : Object; $gate : 4D.Signal; $finished : 4D.Signal)
If ($gate.wait(5))
	start($options; Formula(Null))
Else
	LOG EVENT(Into 4D debug message; "Queued startup regression gate timed out.")
End if
$finished.trigger()
