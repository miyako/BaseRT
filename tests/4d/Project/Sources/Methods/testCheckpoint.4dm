#DECLARE($phase : Text)
var $path : Text
var $parameter : Integer
$parameter:=Get database parameter(User param value; $path)
File($path).setText(JSON Stringify({fatal: True; phase: $phase}))
