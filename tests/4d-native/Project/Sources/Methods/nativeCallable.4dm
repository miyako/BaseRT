#DECLARE($value : Variant) : Boolean
If (Value type($value)=Is object)
	return OB Instance of($value; 4D.Function)
End if
return False
