Class extends _BaseRT

Class constructor($controller : 4D:C1709.Class)
	
	Super:C1705($controller)
	
Function start($option : Object) : 4D:C1709.SystemWorker
	
	This:C1470.bind({onTerminate: Null:C1517}; ["onTerminate"])
	This:C1470.options:=$option
	This:C1470.onData:=Null:C1517
	This:C1470.onDataError:=Null:C1517
	This:C1470.onWorkerError:=Null:C1517
	var $callback : Text
	For each ($callback; ["onStdOut"; "onStdErr"; "_onWorkerError"; "onTerminate"])
		If (Value type:C1509($option[$callback])=Is object:K8:27)\
			 && (OB Instance of:C1731($option[$callback]; 4D:C1709.Function))
			Case of
				: ($callback="onStdOut")
					This:C1470.onData:=$option[$callback]
				: ($callback="onStdErr")
					This:C1470.onDataError:=$option[$callback]
				: ($callback="_onWorkerError")
					This:C1470.onWorkerError:=$option[$callback]
				: ($callback="onTerminate")
					This:C1470.bind($option; ["onTerminate"])
			End case
		Else
			If ($option[$callback]#Null:C1517)
				LOG EVENT:C667(Into 4D debug message:K38:5; "BaseRT "+$callback+" must be a Function.")
			End if
		End if
	End for each
	
	var $command : Text
	If (OB Instance of:C1731($option.source_runtime; 4D:C1709.Folder))
		$command:=This:C1470.escape(This:C1470.expand($option.source_runtime.file("basert-serve")).path)
	Else
		$command:=This:C1470.escape(This:C1470.executablePath)
	End if
	
	Case of 
		: (Value type:C1509($option.model)=Is object:K8:27)\
			 && (OB Instance of:C1731($option.model; 4D:C1709.File))\
			 && ($option.model.exists)
			$command+=" "+This:C1470.escape(This:C1470.expand($option.model).path)
			$command+=" "
		: (Value type:C1509($option.model)=Is collection:K8:32)
			var $model : Variant
			var $count : Integer
			For each ($model; $option.model)
				If (OB Instance of:C1731($model; 4D:C1709.File))\
					 && ($model.exists)
					$count+=1
					If ($count=1)
						$command+=" "
					Else 
						$command+=" --model "
					End if 
					$command+=This:C1470.escape(This:C1470.expand($model).path)
					$command+=" "
				End if 
			End for each 
	End case 
	
	var $arg : Object
	var $valueType : Integer
	var $key : Text
	
	For each ($arg; OB Entries:C1720($option))
		Case of 
			: (["model"; "help"; "version"; "onTerminate"; "onStdErr"; "onStdOut"; "_onWorkerError"; "source_runtime"; "engine_dir"].includes($arg.key))
				continue
		End case 
		$valueType:=Value type:C1509($arg.value)
		$key:=Replace string:C233($arg.key; "_"; "-"; *)
		Case of 
			: ($valueType=Is real:K8:4) || ($valueType=Is integer:K8:5)
				$command+=(" --"+$key+" "+String:C10($arg.value)+" ")
			: ($valueType=Is text:K8:3)
				$command+=(" --"+$key+" "+This:C1470.escape($arg.value)+" ")
			: ($valueType=Is boolean:K8:9) && ($arg.value)
				$command+=(" --"+$key+" ")
			: ($valueType=Is object:K8:27) && (OB Instance of:C1731($arg.value; 4D:C1709.File)) && ($arg.value.exists)
				$command+=(" --"+$key+" "+This:C1470.escape(This:C1470.expand($arg.value).path))+" "
			: ($valueType=Is object:K8:27) && (OB Instance of:C1731($arg.value; 4D:C1709.Folder)) && ($arg.value.exists)
				$command+=(" --"+$key+" "+This:C1470.escape(This:C1470.expand($arg.value).path))+" "
			: ($valueType=Is collection:K8:32)
				var $value : Variant
				var $valueTypeValue : Integer
				For each ($value; $arg.value)
					$valueTypeValue:=Value type:C1509($value)
					Case of 
						: ($valueTypeValue=Is real:K8:4) || ($valueTypeValue=Is integer:K8:5)
							$command+=(" --"+$key+" "+String:C10($value)+" ")
						: ($valueTypeValue=Is text:K8:3)
							$command+=(" --"+$key+" "+This:C1470.escape($value)+" ")
						: ($valueTypeValue=Is boolean:K8:9) && ($value)
							$command+=(" --"+$key+" ")
						: ($valueTypeValue=Is object:K8:27) && (OB Instance of:C1731($value; 4D:C1709.File)) && ($value.exists)
							$command+=(" --"+$key+" "+This:C1470.escape(This:C1470.expand($value).path))+" "
					End case 
				End for each 
			Else 
				//
		End case 
	End for each 
	
	var $HF_HUB_CACHE : 4D:C1709.Folder
	$HF_HUB_CACHE:=Folder:C1567(Temporary folder:C486; fk platform path:K87:2).folder(Generate UUID:C1066)
	$HF_HUB_CACHE.create()
	
	This:C1470.controller.variables:={\
		HF_HUB_CACHE: $HF_HUB_CACHE.path}
	
	If (OB Instance of:C1731($option.source_runtime; 4D:C1709.Folder))
		This:C1470.controller.currentDirectory:=This:C1470.expand($option.source_runtime)
		This:C1470.controller.variables.BASERT_LIB:=This:C1470.expand($option.engine_dir).path
		This:C1470.controller.variables.BASERT_SUPERFLUID_AUTO_INSTALL:="0"
	End if

	return This:C1470.controller.execute($command).worker