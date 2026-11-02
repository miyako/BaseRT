//%attributes = {"invisible":true,"preemptive":"capable"}
#DECLARE($options : Object; $formula : 4D:C1709.Function)

var $model : cs:C1710._Model
$model:=cs:C1710._Model.new($options.port; $options.huggingfaces; $options.options; $formula; $options.event)

If ($model.files.length#0) && (Not:C34($model.offline))
	$model.download()
Else
	If ($model.offline)\
 || ((Value type:C1509($model.options.model)=Is object:K8:27)\
 && (OB Instance of:C1731($model.options.model; 4D:C1709.File))\
 && ($model.options.model.exists))\
 || ((Value type:C1509($model.options.model)=Is collection:K8:32)\
 && ($model.options.model.length#0))\
 || ((Value type:C1509($model.options.models_preset)=Is object:K8:27)\
 && (OB Instance of:C1731($model.options.models_preset; 4D:C1709.File))\
 && ($model.options.models_preset.exists))\
 || ((Value type:C1509($model.options.models_dir)=Is object:K8:27)\
 && (OB Instance of:C1731($model.options.models_dir; 4D:C1709.Folder))\
 && ($model.options.models_dir.exists))
		$model.start()
	Else
		var $error : cs:C1710.event.error
		$error:=cs:C1710.event.error.new(2; "No local model or downloadable model was found.")
		If ($options.event#Null:C1517) && (OB Instance of:C1731($options.event; cs:C1710.event.event))
			$options.event.onError.call($model; $options; $error)
		Else
			LOG EVENT:C667(Into 4D debug message:K38:5; $error.message)
		End if
	End if
End if 