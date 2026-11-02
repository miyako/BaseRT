#DECLARE($data : Variant) : Text
If (Value type($data)=Is text)
	return $data
End if
return Convert to text($data; "UTF-8")
