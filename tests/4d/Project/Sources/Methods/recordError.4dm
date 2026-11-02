#DECLARE($params : Object; $error : cs.event.error)
If (Storage.errorState=Null)
	Use (Storage)
		Storage.errorState:=New shared object("code"; 0)
	End use
End if
Use (Storage.errorState)
	Storage.errorState.code:=$error.code
End use
