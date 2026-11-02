Class extends _BaseRT_Controller

property state : Object

Class constructor($CLI : cs._CLI)
	Super($CLI)
	var $resultPath : Text
	var $parameter : Integer
	$parameter:=Get database parameter(User param value; $resultPath)
	$CLI._executablePath:=File($resultPath).parent.file("native child.sh").path
	This.reset()

Function reset()
	This.state:={stdout: []; stderr: []; errors: []; terminations: []; responses: []; callbackStdout: ""; callbackStderr: ""; callbackStdoutCount: 0; callbackStderrCount: 0; callbackTerminations: 0; callbackErrors: 0; callbackIssues: []}

Function onData($worker : 4D.SystemWorker; $event : Object)
	This.state.stdout.push({worker: $worker; event: $event})
	This.state.currentWorker:=$worker
	This.state.currentEvent:=$event
	Super.onData($worker; $event)

Function onDataError($worker : 4D.SystemWorker; $event : Object)
	This.state.stderr.push({worker: $worker; event: $event})
	This.state.currentWorker:=$worker
	This.state.currentEvent:=$event
	Super.onDataError($worker; $event)

Function onError($worker : 4D.SystemWorker; $event : Object)
	This.state.errors.push({worker: $worker; event: $event})
	This.state.currentWorker:=$worker
	This.state.currentEvent:=$event
	Super.onError($worker; $event)

Function onResponse($worker : 4D.SystemWorker; $event : Object)
	This.state.responses.push({worker: $worker; event: $event})

Function onTerminate($worker : 4D.SystemWorker; $event : Object)
	This.state.terminations.push({worker: $worker; event: $event})
	This.state.currentWorker:=$worker
	This.state.currentEvent:=$event
	Super.onTerminate($worker; $event)
