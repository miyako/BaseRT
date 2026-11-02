property registry : Object

Class constructor

	Use (Storage)
		If (Storage.miyako_BaseRT_startups=Null)
			Storage.miyako_BaseRT_startups:=New shared object("items"; New shared collection; "stopping"; 0)
		End if
	End use
	This.registry:=Storage.miyako_BaseRT_startups

Function create($port : Integer) : Object

	var $token : Object
	$token:=New shared object("id"; Generate UUID; "port"; $port; "state"; "active")
	Use (This.registry)
		var $index : Integer
		For ($index; This.registry.items.length-1; 0; -1)
			If (This.registry.items[$index].port=$port)
				This.registry.items[$index].state:="cancelled"
				This.registry.items.remove($index)
			End if
		End for
		If (This.registry.stopping=0)
			This.registry.items.push($token)
		Else
			Use ($token)
				$token.state:="cancelled"
			End use
		End if
	End use
	return $token

Function active($token : Object) : Boolean

	return ($token#Null) && ($token.state="active") && (This.registry.stopping=0)

Function claim($token : Object) : Boolean

	var $claimed : Boolean
	Use (This.registry)
		If (This.active($token))
			$token.state:="launching"
			$claimed:=True
		End if
	End use
	return $claimed

Function finish($token : Object; $state : Text) : Boolean

	var $finished : Boolean
	Use (This.registry)
		If ($token#Null) && (["active"; "launching"].includes($token.state))
			$token.state:=$state
			var $index : Integer
			$index:=This.registry.items.findIndex(Formula($1.value.id=$2); $token.id)
			If ($index#-1)
				This.registry.items.remove($index)
			End if
			$finished:=True
		End if
	End use
	return $finished

Function cancelAll()

	Use (This.registry)
		This.registry.stopping+=1
		var $token : Object
		For each ($token; This.registry.items)
			$token.state:="cancelled"
		End for each
		This.registry.items.clear()
	End use

Function endStop()

	Use (This.registry)
		If (This.registry.stopping>0)
			This.registry.stopping-=1
		End if
	End use
