property that; options : Object
property file : 4D.File
property oid : Text
property onDownload; _onResponse : 4D.Function
property event : cs.event
Class constructor($that : Object; $file : 4D.File; $folder : 4D.Folder; $oid : Text; $URL : Text; $options : Object; $formula : 4D.Function; $event : cs.event; $onDownload : 4D.Function)
	This.that:=$that
	This.file:=$file
	This.oid:=$oid
	This.options:=$options
	This._onResponse:=$formula
	This.onDownload:=$onDownload
	This.event:=$event
Function head()
	This.that.testDownloads.push(This)
	Case of
		: (This.that.schedule="inline")
			This.complete()
		: (This.that.schedule="failure")
			This.fail()
	End case
Function complete()
	This.file.parent.create()
	This.file.setText("test")
	This.onDownload.call(This.that; This.oid)
Function fail()
	This._onResponse.call(This; {success: False}; This.options)
