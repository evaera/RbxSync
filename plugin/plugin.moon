-- BEGIN AUTO CONFIG --
BUILD=2
PORT=21496
-- END AUTO CONFIG

local hookChanges, sendScript, doSelection, alertBox, alertActive, resetCache

uis 	= game\GetService "UserInputService"
http 	= game\GetService "HttpService"
cgui 	= game\GetService "CoreGui"

scriptCache = {}
sourceCache = {}
gameGUID 	= http\GenerateGUID!
polling		= false
failed		= 0

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

hookChanges = (obj) ->
	obj.Changed\connect (prop) ->
		if prop == "Source"
			if sourceCache[obj] == obj.Source
				sourceCache[obj] = nil
			else
				sendScript obj, false

sendScript = (obj, open=true) ->
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

	data = 
		:path
		name: obj.Name
		source: obj.Source
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

				if command.type == "update"
					if scriptCache[command.data.guid]
						sourceCache[scriptCache[command.data.guid]] = command.data.source
						scriptCache[command.data.guid].Source = command.data.source

			failed += 1 unless success
			failed = 0 if success

			if failed > 3
				resetCache!
				alert "Lost connection to the helper client, stopping."
				break

init = ->
	success, err = pcall ->
		data = http\JSONDecode http\GetAsync("http://localhost:#{PORT}/", true)
		if data.status == "OK"
			if data.build == BUILD
				startPoll!
				doSelection!
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

doSelection = ->
	return init! unless polling

	selection = game.Selection\Get!

	if #selection == 0
		return alert "Select one or more scripts in the Explorer."

	for object in *selection
		if object\IsA "LuaSourceContainer"
			sendScript object

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
		doSelection!