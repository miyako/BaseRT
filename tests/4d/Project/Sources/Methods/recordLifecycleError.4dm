#DECLARE($trace : Object; $receiver : Object; $error : cs.event.error)
$trace.errors+=1
$trace.lastError:=$error
$trace.receiver:=$receiver
