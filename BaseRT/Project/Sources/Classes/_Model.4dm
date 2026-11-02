property model : 4D:C1709.Folder

Class extends _models

Class constructor($port : Integer; $huggingfaces : cs:C1710.event.huggingfaces; $options : Object; $formula : 4D:C1709.Function; $event : cs:C1710.event.event; $attempt : Object)
	
	Super:C1705($port; $huggingfaces; $options; $formula; $event; $attempt)
	
Function _isRouterMode() : Boolean
	
	return ((Value type:C1509(This:C1470.options.models_preset)=Is object:K8:27)\
		 && (OB Instance of:C1731(This:C1470.options.models_preset; 4D:C1709.File))\
		 && (This:C1470.options.models_preset.exists))\
		 || ((Value type:C1509(This:C1470.options.models_dir)=Is object:K8:27)\
		 && (OB Instance of:C1731(This:C1470.options.models_dir; 4D:C1709.Folder))\
		 && (This:C1470.options.models_dir.exists))
	
Function models() : cs:C1710.event.models
	
	If (This:C1470._isRouterMode())
		return cs:C1710.event.models.new([cs:C1710.event.model.new()])
	End if 
	
	var $model : cs:C1710.event.model
	
	Case of
		: (Value type:C1509(This:C1470.options.model)=Is object:K8:27)\
			 && (OB Instance of:C1731(This:C1470.options.model; 4D:C1709.File))
			$model:=cs:C1710.event.model.new(This:C1470.options.model.name; Not:C34(This:C1470.options.model.exists))
			return cs:C1710.event.models.new([$model])
			
		: (Value type:C1509(This:C1470.options.model)=Is collection:K8:32)
			var $models : Collection
			$models:=[]
			For each ($_model; This:C1470.options.model)
				If (Value type:C1509($_model)=Is object:K8:27)\
					 && (OB Instance of:C1731($_model; 4D:C1709.File))
					$model:=cs:C1710.event.model.new($_model.name; Not:C34($_model.exists))
				Else
					$model:=cs:C1710.event.model.new(""; True:C214)
				End if
				$models.push($model)
			End for each 
			return cs:C1710.event.models.new($models)
			
	End case
	return cs:C1710.event.models.new([])
	
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
	If (This:C1470.options.model=Null:C1517)
		var $downloaded : Object
		$downloaded:=$record.file
		If ($downloaded#Null:C1517)
			var $model : Object
			$model:=OB Instance of:C1731($downloaded.folder; 4D:C1709.Folder)\
				 ? $downloaded.folder.file($downloaded.path) : $downloaded.folder
			
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
				If ($model.path=("@"+$value.fullName))
					$match:=True:C214
					break
				End if 
			End for each 
			
			If (Not:C34($match))
				This:C1470.options.model:=$model
			End if 
		End if 
	End if 
	
	Super:C1706.onDownload($oid; $record.id; This:C1470.attempt.id)
	
Function start()
	
	If (Not:C34(This:C1470._startup.active(This:C1470.attempt)))
		return
	End if
	If (This:C1470._pending.query("done == :1"; False:C215).length#0)
		return
	End if
	var $required : Collection
	If (Value type:C1509(This:C1470.options.model)=Is collection:K8:32)
		$required:=This:C1470.options.model
	Else
		$required:=[This:C1470.options.model]
	End if
	If (Not:C34(This:C1470._isRouterMode()))
		If ($required.length=0)
			This:C1470.fail("At least one local model file is required.")
			return
		End if
		var $file : Variant
		For each ($file; $required)
			If (Value type:C1509($file)#Is object:K8:27)\
				 || (Not:C34(OB Instance of:C1731($file; 4D:C1709.File))) || (Not:C34($file.exists))
				This:C1470.fail("A required local model file is missing or invalid.")
				return
			End if
		End for each
	End if
	var $record : Object
	For each ($record; This:C1470._pending)
		If (Not:C34(This:C1470._validFile($record.file)))
			This:C1470.fail("A completed model file is missing or has an unexpected size.")
			return
		End if
	End for each
	var $message : Text
	If (This:C1470.options.source_runtime#Null:C1517)
		Case of
			: (This:C1470.options.executable#Null:C1517)
				$message:="Select source_runtime or executable, not both."
			: (Value type:C1509(This:C1470.options.source_runtime)#Is object:K8:27)\
				 || (Not:C34(OB Instance of:C1731(This:C1470.options.source_runtime; 4D:C1709.Folder)))
				$message:="source_runtime must be a Folder containing the source-built runtime."
			: (Not:C34(This:C1470.options.source_runtime.file("basert-serve").exists))\
				 || (Not:C34(This:C1470.options.source_runtime.file("basert").exists))\
				 || (Not:C34(This:C1470.options.source_runtime.file("superfluid/bin/superfluid").exists))\
				 || (Not:C34(This:C1470.options.source_runtime.file("superfluid/bin/superfluid-workerd").exists))\
				 || (Not:C34(This:C1470.options.source_runtime.file("superfluid/bin/superfluid-noded").exists))\
				 || (Not:C34(This:C1470.options.source_runtime.file("superfluid/libexec/superfluid/superfluid-worker-basert").exists))
				$message:="source_runtime is incomplete. Run scripts/build-native.py first."
			: (Value type:C1509(This:C1470.options.engine_dir)#Is object:K8:27)\
				 || (Not:C34(OB Instance of:C1731(This:C1470.options.engine_dir; 4D:C1709.Folder)))
				$message:="engine_dir must be a separately licensed BaseRT engine Folder."
			: (Not:C34(This:C1470.options.engine_dir.file("libbaseRT.dylib").exists))
				$message:="engine_dir does not contain libbaseRT.dylib. The public source build does not include the engine."
		End case
	Else
		Case of
			: (Value type:C1509(This:C1470.options.executable)#Is object:K8:27)\
				 || (Not:C34(OB Instance of:C1731(This:C1470.options.executable; 4D:C1709.File)))
				$message:="BaseRT runtime is not installed. Set executable to a separately licensed basert-serve File, or select source_runtime and engine_dir. No runtime is bundled or downloaded."
			: (Not:C34(This:C1470.options.executable.exists))
				$message:="The selected BaseRT executable is missing. Install a separately licensed basert-serve outside the component and set executable to its File."
		End case
	End if
	If ($message#"")
		If (Not:C34(This:C1470._startup.finish(This:C1470.attempt; "failed")))
			return
		End if
		var $error : cs:C1710.event.error
		$error:=cs:C1710.event.error.new(3; $message)
		If (OB Instance of:C1731(This:C1470.event; cs:C1710.event.event))\
			 && (OB Instance of:C1731(This:C1470.event.onError; 4D:C1709.Function))\
			 && ((OB Keys(This:C1470.event).includes("onError")) || (OB Class:C1730(This:C1470.event)#cs:C1710.event.event))
			This:C1470.event.onError.call(This:C1470; This:C1470.options; $error)
		Else
			LOG EVENT:C667(Into 4D debug message:K38:5; $message)
		End if
		return
	End if

	If (Not:C34(This:C1470._startup.claim(This:C1470.attempt)))
		return
	End if
	var $BaseRT : cs:C1710.workers.worker
	$BaseRT:=cs:C1710.workers.worker.new(cs:C1710._server)
	$BaseRT.start(This:C1470.options.port; This:C1470.options)
	If (Not:C34(This:C1470._startup.finish(This:C1470.attempt; "launched")))
		return
	End if
	
	If (OB Instance of:C1731(This:C1470.event; cs:C1710.event.event))\
		 && (OB Instance of:C1731(This:C1470.event.onSuccess; 4D:C1709.Function))
		This:C1470.event.onSuccess.call(This:C1470; This:C1470.options; This:C1470.models())
	End if 