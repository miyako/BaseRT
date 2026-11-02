property options : Object
property onData; onDataError; onTerminate; onWorkerError : 4D.Function

Class extends _CLI

Class constructor
	Super("basert-serve"; cs.SmokeController)

Function bind($options : Object; $properties : Collection) : cs._CLI
	return This
