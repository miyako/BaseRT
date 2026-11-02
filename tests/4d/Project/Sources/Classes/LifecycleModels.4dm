property testDownloads : Collection
property schedule : Text
property failures : Integer

Class extends _Model

Class constructor($port : Integer; $options : Object; $event : cs.event.event)
	Super($port; cs.event.huggingfaces.new([]); $options; Formula(This.that.recordFailure($1; $2)); $event)
	This.testDownloads:=[]
	This.schedule:="deferred"
	This.failures:=0

Function recordFailure($status : Object; $options : Object)
	This.failures+=1
