property huggingfaces : cs:C1710.event.huggingfaces
property files : Collection
property _models : Collection
property options : Object
property event : cs:C1710.event.event
property _onResponse : 4D:C1709.Function
property offline : Boolean
property attempt : Object
property _startup : cs:C1710._startup
property _pending : Collection
property _dispatched : Boolean

Class constructor($port : Integer; $huggingfaces : cs:C1710.event.huggingfaces; $options : Object; $formula : 4D:C1709.Function; $event : cs:C1710.event.event; $attempt : Object)
	
	This:C1470._startup:=cs:C1710._startup.new()
	This:C1470.attempt:=$attempt#Null:C1517 ? $attempt : This:C1470._startup.create($port)
	This:C1470._pending:=[]
	This:C1470._dispatched:=False:C215
	This:C1470.huggingfaces:=$huggingfaces
	This:C1470.event:=$event
	This:C1470._onResponse:=$formula
	This:C1470.options:=$options#Null:C1517 ? $options : {}
	This:C1470.options._onWorkerError:=Null:C1517
	If (This:C1470.event#Null:C1517) && (OB Instance of:C1731(This:C1470.event; cs:C1710.event.event))
		This:C1470.options.onTerminate:=This:C1470.event.onTerminate
		This:C1470.options.onStdErr:=This:C1470.event.onStdErr
		This:C1470.options.onStdOut:=This:C1470.event.onStdOut
		//The pinned event class has an empty default onError method.
		If (OB Keys(This:C1470.event).includes("onError")) || (OB Class:C1730(This:C1470.event)#cs:C1710.event.event)
			This:C1470.options._onWorkerError:=This:C1470.event.onError
		End if
	End if
	This:C1470.options.port:=$port
	This:C1470.offline:=False:C215
	
	This:C1470.files:=[]
	This:C1470._models:=[]
	
	ARRAY LONGINT:C221($pos; 0)
	ARRAY LONGINT:C221($len; 0)
	
	var $URL : Text
	var $huggingface : cs:C1710.event.huggingface
	$BRANCH:="main"
	var $components : Collection
	
	While (This:C1470.huggingfaces.huggingfaces.length#0)
		If (Not:C34(This:C1470._startup.active(This:C1470.attempt)))
			return
		End if
		$huggingface:=This:C1470.huggingfaces.huggingfaces.shift()
		Case of 
			: (Match regex:C1019("https:\\/\\/huggingface\\.co\\/(.+)"; $huggingface.URL; 1; $pos; $len))
				$URL:=Substring:C12($huggingface.URL; $pos{1}; $len{1})
				$components:=Split string:C1554($URL; "/")
				$USER:=$components.shift()
				$REPO:=$components.shift()
				$API:=["https://huggingface.co/api/models"; $URL; "?recursive=true"].join("/")
			: (Match regex:C1019("(^|\\/[^/]+){2,}"; $huggingface.URL; 1; $pos; $len))
				$URL:=$huggingface.URL
				$components:=Split string:C1554($URL; "/")
				$USER:=$components.shift()
				$REPO:=$components.shift()
				$API:=["https://huggingface.co/api/models"; $USER; $REPO; "tree"; $BRANCH; "?recursive=true"].join("/")
			Else 
				continue
		End case 
		var $request : 4D:C1709.HTTPRequest
		$request:=4D:C1709.HTTPRequest.new($API).wait()
		If (Not:C34(This:C1470._startup.active(This:C1470.attempt)))
			return
		End if
		If ($request.response.status=Null:C1517)
			This:C1470._models.push([$USER; $REPO].join("/"))
			This:C1470.options.model:=$huggingface.folder.file($huggingface.path)  //assuming the 1st path is model
			This:C1470.offline:=True:C214
			continue
		End if 
		If ($request.response.status=200)
			If (Value type:C1509($request.response)=Is object:K8:27)
				var $file : 4D:C1709.File
				Case of 
					: (OB Instance of:C1731($huggingface.folder; 4D:C1709.Folder))
						$resources:=$request.response.body.map(Formula:C1597($1.result:={\
							USER: $2; \
							REPO: $3; \
							BRANCH: $4; \
							type: $1.value.type; \
							domain: $6; \
							name: $7; \
							size: $1.value.size; \
							path: $1.value.path; \
							oid: $1.value.oid; \
							folder: $5}); $USER; $REPO; $BRANCH; $huggingface.folder; $huggingface.domain; $huggingface.name)
						
						For each ($file; $resources.query("type == :1 and path in :2"; "file"; $huggingface.paths))
							//any file not in option is assumed to be the main model
							var $option : Text
							var $match : Boolean
							$match:=False:C215
							For each ($option; This:C1470.options)
								var $value : Variant
								$value:=This:C1470.options[$option]
								var $vt : Integer
								$vt:=Value type:C1509($value)
								If ($vt#Is object:K8:27)
									continue
								End if 
								If (Not:C34(OB Instance of:C1731($value; 4D:C1709.File)))
									continue
								End if 
								If ($file.path=("@"+$value.fullName))
									$match:=True:C214
									break
								End if 
							End for each 
							If ($match)
								This:C1470.files.push($file)  //model: append
							Else 
								This:C1470.files.unshift($file)  //default: prepend
							End if 
						End for each 
						This:C1470._models.push([$USER; $REPO].join("/"))
					: (OB Instance of:C1731($huggingface.folder; 4D:C1709.File))
						$file:=$request.response.body.query("path == :1"; $huggingface.name).first()
						If ($file=Null:C1517)
							continue
						End if 
						$file.domain:=$huggingface.domain
						$file.name:=$huggingface.name
						$file.folder:=$huggingface.folder
						$file.USER:=$USER
						$file.REPO:=$REPO
						$file.BRANCH:=$BRANCH
						This:C1470.files.push($file)
						This:C1470._models.push([$USER; $REPO].join("/"))
				End case 
			End if 
		End if 
	End while 
	
Function download()
	
	If (This:C1470._dispatched) || (Not:C34(This:C1470._startup.active(This:C1470.attempt)))
		return
	End if
	This:C1470._dispatched:=True:C214
	//A cache hit can reenter completion before dispatch returns.
	For each ($file; This:C1470.files)
		This:C1470._pending.push({id: Generate UUID:C1066; file: $file; done: False:C215})
	End for each
	var $record : Object
	var $owner : cs:C1710._models
	$owner:=This:C1470
	var $generation : Text
	$generation:=This:C1470.attempt.id
	For each ($record; This:C1470._pending)
		If (Not:C34(This:C1470._startup.active(This:C1470.attempt)))
			break
		End if
		var $file : Object
		$file:=$record.file
		var $identity; $oid : Text
		$identity:=$record.id
		$oid:=$file.oid
		If (This:C1470._validFile($file))
			This:C1470.onDownload($oid; $identity; $generation)
			continue
		End if 
		cs:C1710.event.download.new(\
			This:C1470; \
			OB Instance of:C1731($file.folder; 4D:C1709.Folder) ? $file.folder.file($file.path) : $file.folder; \
			$file.folder; \
			$file.oid; \
			["https://huggingface.co"; $file.USER; $file.REPO; "resolve"; $file.BRANCH; $file.path].join("/"); \
			This:C1470.options; \
			Formula:C1597($owner._downloadStatus(This:C1470; $1; $2; $generation)); \
			This:C1470.event; Formula:C1597(This:C1470.onDownload($oid; $identity; $generation))).head()
	End for each 
	
Function _validFile($file : Object) : Boolean

	var $target : 4D:C1709.File
	Case of
		: (OB Instance of:C1731($file.folder; 4D:C1709.Folder))
			$target:=$file.folder.file($file.path)
		: (OB Instance of:C1731($file.folder; 4D:C1709.File))
			$target:=$file.folder
		Else
			return False:C215
	End case
	return ($target.exists) && ($target.size=$file.size)

Function pending($oid : Text; $identity : Text; $generation : Text) : Object

	If (Not:C34(This:C1470._startup.active(This:C1470.attempt)))
		return Null:C1517
	End if
	If ($generation#"") && ($generation#This:C1470.attempt.id)
		return Null:C1517
	End if
	var $matches : Collection
	If ($identity#"")
		$matches:=This:C1470._pending.query("id == :1 and done == :2"; $identity; False:C215)
	Else
		$matches:=This:C1470._pending.query("file.oid == :1 and done == :2"; $oid; False:C215)
	End if
	If ($matches.length=1)
		return $matches.first()
	End if
	LOG EVENT:C667(Into 4D debug message:K38:5; "BaseRT ignored an unknown, duplicate or ambiguous download completion.")
	return Null:C1517
	
Function onDownload($oid : Text; $identity : Text; $generation : Text)
	
	var $record : Object
	$record:=This:C1470.pending($oid; $identity; $generation)
	If ($record=Null:C1517)
		return
	End if
	If (Not:C34(This:C1470._validFile($record.file)))
		This:C1470.fail("Downloaded model is missing or has an unexpected size.")
		return
	End if
	$record.done:=True:C214
	This:C1470.files:=This:C1470._pending.query("done == :1"; False:C215).extract("file")
	If (This:C1470.files.length=0)
		This:C1470.start()
	End if

Function _downloadStatus($download : Object; $status : Object; $options : Object; $generation : Text)

	If ($generation#This:C1470.attempt.id) || (Not:C34(This:C1470._startup.active(This:C1470.attempt)))
		return
	End if
	If (Not:C34($status.success))
		If (Not:C34(This:C1470._startup.finish(This:C1470.attempt; "failed")))
			return
		End if
	End if
	If (OB Instance of:C1731(This:C1470._onResponse; 4D:C1709.Function))
		This:C1470._onResponse.call($download; $status; $options)
	Else
		LOG EVENT:C667(Into 4D debug message:K38:5; "BaseRT download status has no callable handler: "+JSON Stringify:C1217($status))
	End if

Function fail($message : Text)

	If (Not:C34(This:C1470._startup.finish(This:C1470.attempt; "failed")))
		return
	End if
	var $error : cs:C1710.event.error
	$error:=cs:C1710.event.error.new(2; $message; This:C1470.models())
	If (OB Instance of:C1731(This:C1470.event; cs:C1710.event.event))\
		 && (OB Instance of:C1731(This:C1470.event.onError; 4D:C1709.Function))
		This:C1470.event.onError.call(This:C1470; This:C1470.options; $error)
	Else
		LOG EVENT:C667(Into 4D debug message:K38:5; $message)
	End if
	
Function models() : cs:C1710.event.models
	//virtual
	return cs:C1710.event.models.new()
	
Function start()
	//virtual