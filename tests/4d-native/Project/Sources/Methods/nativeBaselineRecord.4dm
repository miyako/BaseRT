#DECLARE($state : Object; $worker : 4D.SystemWorker; $event : Object; $kind : Text)
Case of
	: ($kind="stdout")
		$state.stdout+=nativeText($event.data)
	: ($kind="stderr")
		$state.stderr+=nativeText($event.data)
		$state.stderrType:=Value type($event.data)
	: ($kind="error")
		$state.nativeErrors+=1
	: ($kind="termination")
		$state.terminations+=1
End case
