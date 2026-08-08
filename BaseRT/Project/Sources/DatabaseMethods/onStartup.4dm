var $BaseRT : cs:C1710.BaseRT

var $homeFolder : 4D:C1709.Folder
$homeFolder:=Folder:C1567(fk home folder:K87:24).folder(".BaseRT")

var $file : 4D:C1709.File
var $URL : Text
var $port : Integer
var $huggingface : cs:C1710.event.huggingface

var $event : cs:C1710.event.event
$event:=cs:C1710.event.event.new()
/*
        Function onError($params : Object; $error : cs.event.error)
        Function onSuccess($params : Object; $models : cs.event.models)
        Function onData($request : 4D.HTTPRequest; $event : Object)
        Function onResponse($request : 4D.HTTPRequest; $event : Object)
        Function onTerminate($worker : 4D.SystemWorker; $params : Object)
 */

$event.onError:=Formula:C1597(ALERT:C41($2.message))
$event.onSuccess:=Formula:C1597(ALERT:C41($2.models.extract("name").join(",")+" loaded!"))
$event.onData:=Formula:C1597(LOG EVENT:C667(Into 4D debug message:K38:5; This:C1470.file.fullName+":"+String:C10((This:C1470.range.end/This:C1470.range.length)*100; "###.00%")))
$event.onData:=Formula:C1597(MESSAGE:C88(This:C1470.file.fullName+":"+String:C10((This:C1470.range.end/This:C1470.range.length)*100; "###.00%")))
$event.onResponse:=Formula:C1597(LOG EVENT:C667(Into 4D debug message:K38:5; This:C1470.file.fullName+":download complete"))
$event.onResponse:=Formula:C1597(MESSAGE:C88(This:C1470.file.fullName+":download complete"))
$event.onTerminate:=Formula:C1597(LOG EVENT:C667(Into 4D debug message:K38:5; (["process"; $1.pid; "terminated!"].join(" "))))

$port:=8080

$folder:=$homeFolder.folder("Qwen")

//$path_chat:="Qwen3.5-0.8B-Q8.base"
//$URL_chat:="keisuke-miyako/Qwen3.5-0.8B-basert"

$path_chat:="Qwen3.5-2B-Q8.base"
$URL_chat:="keisuke-miyako/Qwen3.5-2B-basert"

$path_embeddings:="Qwen3-Embedding-0.6B-Q8.base"
$URL_embeddings:="keisuke-miyako/Qwen3-Embedding-0.6B-basert"

$max_tokens:=4096
$max_context:=8192

var $logFile : 4D:C1709.File
$logFile:=$folder.file("BaseRT.log")
$folder.create()
If (Not:C34($logFile.exists))
	$logFile.setContent(4D:C1709.Blob.new())
End if 

var $options : Object

$options:={\
model: [$folder.file($path_chat); $folder.file($path_embeddings)]; \
log_file: $logFile; \
max_tokens: $max_tokens; \
max_context: $max_context}

var $huggingfaces : cs:C1710.event.huggingfaces

$chat:=cs:C1710.event.huggingface.new($folder; $URL_chat; $path_chat)
$embeddings:=cs:C1710.event.huggingface.new($folder; $URL_embeddings; $path_embeddings)
$huggingfaces:=cs:C1710.event.huggingfaces.new([$chat; $embeddings])

$BaseRT:=cs:C1710.BaseRT.new($port; $huggingfaces; $homeFolder; $options; $event)
