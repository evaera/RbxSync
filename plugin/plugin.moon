-- BEGIN AUTO CONFIG --
BUILD = [[ config:BUILD ]]
PORT = [[ config:PORT ]]
mixinRequire = [[ strings:mixinRequire ]]
mixinRequireOld = [[ strings:mixinRequireOld ]]
moonBoilerplate = [[ file:boilerplate.lua ]]
-- END AUTO CONFIG --

-- Variable declarations --
CoreGui             = game\GetService "CoreGui"
HttpService         = game\GetService "HttpService"
ServerScriptService = game\GetService "ServerScriptService"
ReplicatedStorage   = game\GetService "ReplicatedStorage"
Selection           = game\GetService "Selection"
UserInputService    = game\GetService "UserInputService"

local hookChanges, sendScript, doSelection, alertBox, alertActive, resetCache, checkLanguageHelper
local justAdded, parseMixinsOut, parseMixinsIn, deleteScript, checkForPlaceName, placeNameAdded
local createOriginalSourceValue, isHoldingCtrl, isHoldingCtrlAndAlt, languageSupportsRobloxObject
local splitString, importLanguageLuaIncludes, getDestinationFolder, getOrCreateFolder

pmPath            = "Documents\\ROBLOX\\RSync"
illegalCharacters = '[<>:"\\|?*]'
scriptCache       = {}
sourceCache       = {}
languages         = {}
gameGUID          = HttpService\GenerateGUID!
temp              = true
polling           = false
failed            = 0

mixinString = "__RSMIXIN('%1', script, getfenv())"
mixinStringPattern = "__RSMIXIN%('([%w_]+)', script, getfenv%(%)%)"

-- A wrapper for `print` that prefixes plugin version information.--
debug = (...) ->
	print "[RbxSync build #{BUILD}] ", ...

-- Creates a GUI alert to tell the user something,
-- also calls `debug` on the arguments. --
alert = (...) ->
	debug ...

	-- Use tick to save the time of the most recent alert. --
	alertActive = tick!

	text = ""
	for segment in *{...}
		text ..= segment .. " "
	text = text\sub 1, #text-1

	alertBox.Text = text
	alertBox.Visible = true

	-- Store the current alert's time. --
	snapshot = alertActive

	Spawn ->
		wait 5
		-- If the alert is still the most recent, hide it.
		-- Otherwise, keep it open since another alert has been issued. --
		if snapshot == alertActive
			alertBox.Visible = false

-- Takes the injected mixin code and reverts it back to special RbxSync syntax. --
parseMixinsOut = (source) ->
	return source unless ReplicatedStorage\FindFirstChild("Mixins") and
		ReplicatedStorage.Mixins\IsA("ModuleScript")

	if source\sub(1, #mixinRequire) == mixinRequire
		source = source\sub(#mixinRequire + 1)
	elseif source\sub(1, #mixinRequireOld) == mixinReqireOld
		source = source\sub(#mixinRequireOld + 1)

	source = source\gsub mixinStringPattern, "@(%1)"

	return source

-- Parses the special Mixin syntax and replaces it with the injected code. --
parseMixinsIn = (source) ->
	return source unless ReplicatedStorage\FindFirstChild("Mixins") and
		ReplicatedStorage.Mixins\IsA("ModuleScript")

	if source\find "@%(([%w_]+)%)"
		source = mixinRequire .. source

		source = source\gsub "@%(([%w_]+)%)", mixinString

	return source

-- Called with a LuaSourceContainer object to begin tracking script changes. --
hookChanges = (obj) ->
	obj.Changed\connect (prop) ->

		-- Ignore the change if the script was just added, since the Change event gets called immediately. --
		if obj == justAdded
			justAdded = nil
			return

		switch prop
			when "Source"
				-- Ignore custom language mode scripts --
				-- if obj\FindFirstChild "MoonScript"
				-- 	return
				return for language in *languages when obj\FindFirstChild language.originalSourceValueName
				-- Ignore the change if we are the ones who changed the script. --
				if sourceCache[obj] == obj.Source
					sourceCache[obj] = nil
				else
					sendScript obj, false
			when "Parent", "Name"
				-- If the Parent or Name properties change, delete the script.
				-- deleteScript will handle sending the script again after the request completes if Parent is not nil. --
				deleteScript obj

-- Deletes a script from the user's filesystem.
-- Called when a script's `Name` or `Parent` properties are changed. --
deleteScript = (obj) ->
	return unless scriptCache[obj]

	data =
		guid: scriptCache[obj]

	scriptCache[scriptCache[obj]] = nil
	scriptCache[obj] = nil

	pcall ->
		HttpService\PostAsync "http://localhost:#{PORT}/delete", HttpService\JSONEncode(data), "ApplicationJson", false
		-- Immediately send the script again. If the parent is still nil in the game, it will be ignored.
		-- In cases of name change, this is done so we can wait for the delete request to finish before sending the newly-named script. --
		sendScript obj, false

originalSourceValueExists = (obj, originalSourceValueName) ->
	obj\FindFirstChild(originalSourceValueName) and obj[originalSourceValueName]\IsA("StringValue")

languageSupportsRobloxObject = (obj, unallowedRobloxClasses) ->
	return false for unallowedRobloxClass in *unallowedRobloxClasses when obj\IsA unallowedRobloxClass
	return true

importLanguageLuaIncludes = (luaIncludes) ->
	for include in *luaIncludes
		destinationSegments = splitString include.destination
		destination = getDestinationFolder destinationSegments
		destination = getOrCreateFolder destination, "v#{include.version}" if include.version

		unless destination\FindFirstChild include.name
			with Instance.new "ModuleScript"
				.Name = include.name
				.Source = include.source
				.Parent = destination

splitString = (str, sep = "%.") ->
	results = {}
	string.gsub str, "([^#{sep}]+)", (match) ->
		table.insert results, match
	return results

getDestinationFolder = (destinationSegments) ->
	destination = game
	for segment in *destinationSegments
			destination = getOrCreateFolder destination, segment
	return destination

getOrCreateFolder = (parent, folderName) ->
	folder = parent\FindFirstChild folderName
	unless folder
		folder = with Instance.new "Folder", parent
			.Name = folderName
	return folder

-- Sends a script to the filesystem.
-- Optional second parameter, which will open the file automatically in a code editor if true. --
sendScript = (obj, open=true) ->
	-- If the script doesn't have a Parent, ignore it. --
	return unless obj.Parent

	-- Generate the script ancestry path to map to the filesystem. --
	stack = {}
	parent = obj.Parent
	while parent != game
		table.insert stack, 1, parent
		parent = parent.Parent

	path = ""
	for ancestor in *stack
		path ..= ancestor.Name\gsub(illegalCharacters, '') .. "/"

	-- Check if this is the first time we've seen this script. --
	if not scriptCache[obj]
		-- Assign the script a GUID, which is used for internally tracking the script changes. --
		scriptCache[obj] = HttpService\GenerateGUID false
		-- Also map the GUID to the object for easy referencing. --
		scriptCache[scriptCache[obj]] = obj
		-- Hook up the Change event on the script. --
		hookChanges obj

	-- Determine what syntax the script is using. --
	local syntax, source
	for language in *languages
		if originalSourceValueExists(obj, language.originalSourceValueName) and languageSupportsRobloxObject(obj, language.unallowedRobloxClasses)
			syntax = language.syntax
			source = obj[language.originalSourceValueName].Value
			importLanguageLuaIncludes language.luaIncludes
			break

	unless syntax
		syntax = "lua"
		source = parseMixinsOut obj.Source

	-- Send the data to the endpoint. --
	data =
		:path
		:syntax
		:source
		:temp
		name: obj.Name\gsub(illegalCharacters, '')
		class: obj.ClassName
		place_name: gameGUID
		guid: scriptCache[obj]

	pcall ->
		HttpService\PostAsync "http://localhost:#{PORT}/write/#{open and 'open' or 'update'}", HttpService\JSONEncode(data), "ApplicationJson", false

-- Resets the session, so it can be reinitialized.
-- Also called when there is a conneciton loss. --
resetCache = ->
	polling = false
	scriptCache = {}
	sourceCache = {}
	gameGUID 	= HttpService\GenerateGUID! if temp
	debug "Resetting, if you restart the client you will need to reopen your scripts again, the files on disk will no longer be sent to this game instance as a result of the connection loss."

-- Begins the long-polling to the local server. --
startPoll = ->
	return if polling
	polling = true

	Spawn ->
		-- Waiting here prevents most connection loses
		-- If polling returns immediatly, it would do 400 requests per minute
		while wait 0.14
			success = pcall ->
				body = HttpService\GetAsync "http://localhost:#{PORT}/poll", true
				command = HttpService\JSONDecode body

				-- Determine what kind of command the server has sent us. --
				switch command.type
					when "update"
						-- If we don't know about the script, then ignore it. --
						if scriptCache[command.data.guid]
							obj = scriptCache[command.data.guid]

							-- Only parse mixins if Lua. --
							local source
							if command.data.originalSource
								source = moonBoilerplate .. command.data.source
							else
								source = parseMixinsIn command.data.source

							-- Save the script source in sourceCache so we can ignore this change when the script changes from us setting the Source. --
							sourceCache[scriptCache[command.data.guid]] = source

							-- Update the script. --
							obj.Source = source

							for language in *languages
								if originalSourceValueExists(obj, language.originalSourceValueName) and languageSupportsRobloxObject(obj, language.unallowedRobloxClasses)
									obj[language.originalSourceValueName].Value = command.data.originalSource
									break
					when "output"
						-- An output command from the server, useful for showing information such as Moonscript compile errors. --
						return if #command.data.text == 0
						debug command.data.text
					when "reloadLanguages"
						languages = command.data.languages

			-- Increment the failed counter if the request failed, or reset it upon success. --
			failed += 1 unless success
			failed = 0 if success

			-- If the previous three requests have failed, determine there is a connection issue and stop long-polling. --
			if failed > 3
				resetCache!
				alert "Lost connection to the helper client, stopping."
				break

-- Performs the initial handshake and version check with the server. --
init = (cb) ->
	success, err = pcall ->
		data = HttpService\JSONDecode HttpService\PostAsync("http://localhost:#{PORT}/new", HttpService\JSONEncode(place_name: gameGUID), "ApplicationJson", false)
		if data.status == "OK"
			-- Check that the version of the plugin matches the version of the helper client. --
			if data.build == BUILD
				pmPath = data.pm
				languages = data.languages
				startPoll!
				cb!
			else
				alert "Plugin version does not match helper version, restart studio."
		else
			-- An unknown error has occurred. --
			alert "Unhandled error, please check output."
			debug data.error

	-- Show special alerts for certain common errors. --
	unless success
		if err\find "Http requests are not enabled"
			alert "Set HttpService.HttpEnabled to true to use this feature."
		elseif err\find "Couldn't connect to server"
			alert "Couldn't connect to helper client, did you start the executable?"
		else
			alert "Unhandled error, please check output."
			debug "An error occurred: #{err}"

-- Scans the game for scripts, used with persistent mode. --
scan = ->
	-- If the initial handshake hasn't been performed, do it first. --
	return init scan unless polling

	-- A recursive function used to check the game for scripts. --
	lookIn = (obj) ->
		for child in *obj\GetChildren!
			if child\IsA "LuaSourceContainer"
				sendScript child, false
			lookIn child

	lookIn game\GetService "Chat"
	lookIn game\GetService "Lighting"
	lookIn game\GetService "ReplicatedFirst"
	lookIn game\GetService "ReplicatedStorage"
	lookIn game\GetService "ServerScriptService"
	lookIn game\GetService "ServerStorage"
	lookIn game\GetService "StarterGui"
	lookIn game\GetService "StarterPack"
	lookIn game\GetService "StarterPlayer"
	lookIn game\GetService "Workspace"

	-- When a new script is added to the game, handle it correctly. --
	game.DescendantAdded\connect (obj) ->
		pcall ->
			if obj\IsA "LuaSourceContainer"
				justAdded = obj
				sendScript obj, false

	alert "All game scripts updated on filesystem, path in output"
	debug "\\#{pmPath}\\#{gameGUID}\\"

-- Handles checking the user selection for scripts, called when the Open in Editor button is pressed. --
doSelection = ->
	-- If the initial handshake hasn't been performed, do it first. --
	return init doSelection unless polling

	selection = Selection\Get!

	-- Check if selection is empty. --
	if #selection == 0
		return alert "Select one or more scripts in the Explorer."

	-- Search the selection for scripts, and send them. --
	one = false
	for obj in *selection
		if obj\IsA "LuaSourceContainer"
			one = true
			checkLanguageHelper obj
			sendScript obj

	-- If at least one script wasn't found, show the user a help message. --
	unless one
		alert "Select one or more scripts in the Explorer."

-- Checks if a script should be automatically set to a custom language mode when a user presses the plugin button.
-- Optional parameter `forcedLanguage`, which will bypass the check and forcibly convert to custom language mode. --
checkLanguageHelper = (obj, forcedLanguage) ->
	return unless obj\IsA "LuaSourceContainer"

	if forcedLanguage and languageSupportsRobloxObject(obj, forcedLanguage.unallowedRobloxClasses)
		createOriginalSourceValue obj, forcedLanguage
		return

	for language in *languages
		return unless languageSupportsRobloxObject(obj, language.unallowedRobloxClasses)
		return if obj\FindFirstChild language.originalSourceValueName
		return if #obj.Source > 100

		for shortcut in *language.initializationShortcuts
			if shortcut.type == "source" and obj.Source\lower! == shortcut.value
				createOriginalSourceValue obj, language
				return
			elseif shortcut.type == "extension" and obj.Name\sub(#obj.Name - #shortcut.value + 1) == shortcut.value
				createOriginalSourceValue obj, language
				obj.Name = obj.Name\sub 1, #obj.Name - #shortcut.value
				return

createOriginalSourceValue = (obj, language) ->
	with Instance.new "StringValue", obj
		.Name  = language.originalSourceValueName
		.Value = language.defaultSource

-- Check HttpService for StringValue "PlaceName" to see if we should enable persistent mode. --
checkForPlaceName = (obj) ->
	-- If the object meets the requirements, enable persistent mode. --
	if obj.Name == "PlaceName" and #obj.Value > 0
		resetCache!
		gameGUID = obj.Value
		temp = false
		scan!

placeNameAdded = (obj) ->
	if obj\IsA("StringValue")
		checkForPlaceName obj
		-- Wait for any changes to `PlaceName` in HttpService
		obj.Changed\connect ->
			checkForPlaceName obj

placeNameAddedHttp = (obj) ->
	if obj\IsA("StringValue") and obj.Name == "PlaceName"
		obj.Parent = ServerScriptService

-- Create the alert box and place it in CoreGui. --
with alertBox = Instance.new "TextLabel"
	.Parent                 = Instance.new "ScreenGui", CoreGui
	.Name                   = "RbxSync Alert"
	.BackgroundColor3       = Color3.fromRGB 231, 76, 60
	.TextColor3             = Color3.fromRGB 1, 1, 1
	.BackgroundTransparency = 0
	.BorderColor3           = Color3.fromRGB 231, 76, 60
	.BorderSizePixel        = 30
	.Position               = UDim2.new 0.5, -150, 0.5, -25
	.Size                   = UDim2.new 0, 300, 0, 50
	.ZIndex                 = 10
	.Font                   = "SourceSansLight"
	.TextSize               = 24
	.Visible                = false
	.TextWrapped            = true

-- Check that the game is not in test mode before enabling the plugin.
-- After starting a test mode, checking immediately for IsRunning sometimes fails.
-- Roblox seems to be doing more work at the start of a game than previously.
-- Before checking IsRunning, wait at least until after the first heartbeat then
-- an additional half second to account for the additional work. It'd be even
-- better to locate some consistent status indicator that Roblox's initialization
-- code has completed and use that here instead of waiting an arbitrary length of
-- time.
game\GetService("RunService").Heartbeat\Wait!
wait 0.5
if (game\GetService("RunService")\IsStudio! and not game\GetService("RunService")\IsRunning!) and (game\GetService("RunService")\IsClient!)
		-- Create the plugin toolbar and button. --
		toolbar = plugin\CreateToolbar "RbxSync"
		button = toolbar\CreateButton "Open with Editor", "Open with system .lua editor (Ctrl+B)", "https://www.roblox.com/asset?id=478150446"

		button.Click\connect doSelection

		-- Hook up the keybinds Ctrl+B and any custom language hotkey bindings --
		UserInputService.InputBegan\connect (input, gpe) ->
			return if gpe

			for language in *languages
				for shortcut in *language.initializationShortcuts
					if shortcut.type == "hotkey" and input.KeyCode == Enum.KeyCode[shortcut.value] and isHoldingCtrlAndAlt!
						for obj in *Selection\Get!
							checkLanguageHelper obj, language
						doSelection!
						return

			if input.KeyCode == Enum.KeyCode.B and isHoldingCtrl!
				doSelection!

		-- Check if we should turn persistent mode on. --
		for obj in *ServerScriptService\GetChildren!
			placeNameAdded obj

		ServerScriptService.ChildAdded\connect placeNameAdded

		for obj in *HttpService\GetChildren!
			placeNameAddedHttp obj

		HttpService.ChildAdded\connect placeNameAdded

isHoldingCtrlAndAlt = ->
	isHoldingCtrl! and (UserInputService\IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService\IsKeyDown(Enum.KeyCode.RightAlt))

isHoldingCtrl = ->
	UserInputService\IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService\IsKeyDown(Enum.KeyCode.RightControl)
