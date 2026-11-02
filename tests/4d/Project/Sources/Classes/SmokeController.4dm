property lastCommand : Text

Class extends _CLI_Controller

Class constructor($CLI : cs._CLI)
	Super($CLI)

Function execute($command : Variant; $message : Variant; $context : Variant) : cs._CLI_Controller
	This.lastCommand:=$command
	return This
