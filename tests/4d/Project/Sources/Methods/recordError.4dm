#DECLARE($params : Object; $error : cs.event.error)
If (Storage.errorState=Null)
	Use (Storage)
		Storage.errorState:=New shared object("code"; 0; "message"; "")
	End use
End if
Use (Storage.errorState)
	Storage.errorState.code:=$error.code
	Storage.errorState.message:=$error.message
End use
