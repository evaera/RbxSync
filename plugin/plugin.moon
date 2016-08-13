-- BEGIN AUTO CONFIG --
BUILD=3
PORT=21496
-- END AUTO CONFIG

local hookChanges, sendScript, doSelection, alertBox, alertActive, resetCache, checkMoonHelper, parseMixinsOut, parseMixinsIn, deleteScript

uis 	= game\GetService "UserInputService"
http 	= game\GetService "HttpService"
cgui 	= game\GetService "CoreGui"

scriptCache = {}
sourceCache = {}
gameGUID 	= http\GenerateGUID!
temp 		= true
polling		= false
failed		= 0

mixinRequire = "local __RSMIXINS=require(game.ServerScriptService.Mixins);__RSMIXIN=function(a,b,c)if type(__RSMIXINS[a])=='function'then return __RSMIXINS[a](a,b,c)else return __RSMIXINS[a]end end\n"
mixinString = "__RSMIXIN('%1', script, getfenv())"
mixinStringPattern = "__RSMIXIN%('(%w+)', script, getfenv%(%)%)"

debug = (...) ->
	print "[RSync build #{BUILD}] ", ...

alert = (...) ->
	debug ...

	alertActive = tick!

	text = ""
	for segment in *{...}
		text ..= segment .. " "
	text = text\sub 1, #text-1

	alertBox.Text = text
	alertBox.Visible = true

	snapshot = alertActive

	Spawn ->
		wait 5
		if snapshot == alertActive
			alertBox.Visible = false

parseMixinsOut = (source) ->
	return source unless game.ServerScriptService\FindFirstChild("Mixins") and 
		game.ServerScriptService.Mixins\IsA("ModuleScript")

	if source\sub(1, #mixinRequire) == mixinRequire
		source = source\sub(#mixinRequire + 1)

	source = source\gsub mixinStringPattern, "@(%1)"

	return source

parseMixinsIn = (source) ->
	return source unless game.ServerScriptService\FindFirstChild("Mixins") and 
		game.ServerScriptService.Mixins\IsA("ModuleScript")

	if source\find "@%((%w+)%)"
		source = mixinRequire .. source

		source = source\gsub "@%((%w+)%)", mixinString

	return source

hookChanges = (obj) ->
	obj.Changed\connect (prop) ->
		switch prop
			when "Source"
				if sourceCache[obj] == obj.Source
					sourceCache[obj] = nil
				else
					sendScript obj, false
			when "Parent", "Name"
				deleteScript obj


deleteScript = (obj) ->
	return unless scriptCache[obj]

	data =
		guid: scriptCache[obj]

	scriptCache[scriptCache[obj]] = nil
	scriptCache[obj] = nil

	pcall ->
		http\PostAsync "http://localhost:#{PORT}/delete", http\JSONEncode(data), "ApplicationJson", false
		sendScript obj, false

sendScript = (obj, open=true) ->
	return unless obj.Parent
	
	stack = {}
	parent = obj.Parent
	while parent != game
		table.insert stack, 1, parent
		parent = parent.Parent

	path = ""
	for ancestor in *stack
		path ..= ancestor.Name .. "/"

	if not scriptCache[obj]
		scriptCache[obj] = http\GenerateGUID false
		scriptCache[scriptCache[obj]] = obj
		hookChanges obj

	local syntax, source
	if obj\FindFirstChild("MoonScript") and obj.MoonScript\IsA("StringValue")
		syntax = "moon"
		source = obj.MoonScript.Value
	else
		syntax = "lua"
		source = parseMixinsOut obj.Source

	data = 
		:path
		:syntax
		:source
		:temp
		name: obj.Name
		class: obj.ClassName
		place_name: gameGUID
		guid: scriptCache[obj]

	pcall ->
		http\PostAsync "http://localhost:#{PORT}/write/#{open and 'open' or 'update'}", http\JSONEncode(data), "ApplicationJson", false


resetCache = ->
	polling = false
	scriptCache = {}
	sourceCache = {}
	gameGUID 	= http\GenerateGUID!
	debug "Resetting, if you restart the client you will need to reopen your scripts again, the files on disk will no longer be sent to this game instance as a result of the connection loss."

startPoll = ->
	return if polling
	polling = true

	Spawn ->
		while true
			success = pcall ->
				body = http\GetAsync "http://localhost:#{PORT}/poll", true
				command = http\JSONDecode body

				switch command.type
					when "update"
						if scriptCache[command.data.guid]
							obj = scriptCache[command.data.guid]
							sourceCache[scriptCache[command.data.guid]] = parseMixinsIn command.data.source
							obj.Source = parseMixinsIn command.data.source

							if command.data.moon and obj\FindFirstChild("MoonScript") and obj.MoonScript\IsA("StringValue")
								obj.MoonScript.Value = command.data.moon
					when "output"
						return if #command.data.text == 0
						debug command.data.text

			failed += 1 unless success
			failed = 0 if success

			if failed > 3
				resetCache!
				alert "Lost connection to the helper client, stopping."
				break

init = (cb) ->
	success, err = pcall ->
		data = http\JSONDecode http\PostAsync("http://localhost:#{PORT}/new", http\JSONEncode(place_name: gameGUID), "ApplicationJson", false)
		if data.status == "OK"
			if data.build == BUILD
				startPoll!
				cb!
			else
				alert "Plugin version does not match helper version, restart studio."
		else
			alert "Unhandled error, please check output."
			debug data.error

	unless success
		if err\find "Http requests are not enabled"
			alert "Set HttpService.HttpEnabled to true to use this feature."
		elseif err\find "Couldn't connect to server"
			alert "Couldn't connect to helper client, did you start the executable?"
		else
			alert "Unhandled error, please check output."
			debug "An error occurred: #{err}"

scan = ->
	return init scan unless polling

	lookIn = (obj) ->
		for child in *obj\GetChildren!
			if child\IsA "LuaSourceContainer"
				sendScript child, false
			lookIn child

	lookIn game.Workspace
	lookIn game.Lighting
	lookIn game.ReplicatedFirst
	lookIn game.ReplicatedStorage
	lookIn game.ServerScriptService
	lookIn game.ServerStorage
	lookIn game.StarterGui
	lookIn game.StarterPack
	lookIn game.StarterPlayer

	game.DescendantAdded\connect (obj) ->
		if obj\IsA "LuaSourceContainer"
			sendScript obj, false

	alert "All game scripts updated on filesystem, path in output"
	debug "Documents\\ROBLOX\\RSync\\#{gameGUID}\\"

doSelection = ->
	return init doSelection unless polling

	selection = game.Selection\Get!

	if #selection == 0
		return alert "Select one or more scripts in the Explorer."

	for obj in *selection
		if obj\IsA "LuaSourceContainer"
			checkMoonHelper obj
			sendScript obj

checkMoonHelper = (obj, force) ->
	return unless obj\IsA "LuaSourceContainer"
	return if obj\FindFirstChild "MoonScript"
	return if #obj.Source > 100

	hasExt = obj.Name\sub(#obj.Name-4, #obj.Name) == ".moon"

	if force or hasExt or
		obj.Source\lower! == "m" or 
		obj.Source\lower! == "moon" or 
		obj.Source\lower! == "moonscript"
			with Instance.new "StringValue", obj
				.Name 	= "MoonScript"
				.Value 	= 'print "Hello", "from MoonScript", "Lua version: #{_VERSION}'
			obj.Name = obj.Name\sub 1, #obj.Name-5 if hasExt

with alertBox = Instance.new "TextLabel"
	.Parent 				= Instance.new "ScreenGui", cgui
	.Name 					= "RSync Alert"
	.BackgroundColor3 		= Color3.new 1, 1, 1
	.BackgroundTransparency	= 0.3
	.BorderColor3 			= Color3.new 1, 1, 1
	.BorderSizePixel 		= 30
	.Position 				= UDim2.new 0.5, -150, 0.5, -25
	.Size 					= UDim2.new 0, 300, 0, 50
	.ZIndex 				= 10
	.Font 					= "SourceSansLight"
	.FontSize				= "Size24"
	.Visible 				= false
	.TextWrapped			= true

toolbar = plugin\CreateToolbar "RSync"
button = toolbar\CreateButton "Open with Editor", "Open with system .lua editor (Ctrl+B)", "rbxassetid://478150446"

button.Click\connect doSelection

uis.InputBegan\connect (input, gpe) ->
	return if gpe

	if input.KeyCode == Enum.KeyCode.B and uis\IsKeyDown(Enum.KeyCode.LeftControl)
		if uis\IsKeyDown Enum.KeyCode.LeftAlt
			for obj in *game.Selection\Get!
				checkMoonHelper obj, true
		
		doSelection!

if http\FindFirstChild("PlaceName") and http.PlaceName\IsA("StringValue") and #http.PlaceName.Value > 0
	gameGUID = http.PlaceName.Value
	temp = false
	scan!