{app, shell} =
	require 'electron'

express			= require 'express'
bodyParser		= require 'body-parser'
fs 				= require 'fs'
path 			= require 'path'
mkdirp			= require 'mkdirp'
{exec}			= require 'child_process'

{BUILD, VERSION} = 
	require './config.json'

commands 	= []
lprequest 	= null
fileCache 	= {}
watchers 	= {}
guidCache	= {}
settingsLoaded = false

settings = {}
settingsPath = path.join app.getPath("userData"), "settings.json"
getSetting = (name) ->
	return settings[name] if settings[name]?

	# fallback default values
	switch name
		when "pluginPath"
			path.join(app.getPath("appData"), "..", "Local", "Roblox", "Plugins")
		when "pmPath"
			path.join(app.getPath("documents"), "ROBLOX", "RSync")
		when "tempPath"
			path.join(app.getPath("temp"), "RSync")

setSetting = (name, value) ->
	settings[name] = value
	saveSettings()

loadSettings = ->
	unless fs.existsSync settingsPath
		mkdirp app.getPath("userData"), ->
			fs.writeFileSync settingsPath, "{}"
			settings = require settingsPath
			settingsLoaded = true
	try
		settings = require settingsPath
		settingsLoaded = true
	catch
		settings = {}

saveSettings = ->
	fs.writeFileSync settingsPath, JSON.stringify(settings)

# Adds a command to the command list, and sends it if there is an available long-poll request. #
addCommand = (type, data) ->
	commands.push {type: type, data: data}
	if lprequest?
		lprequest.json(commands.shift())
		lprequest = null

# Deletes a file from our caches, stop watching it for file changes, and optionally the file system. #
deleteFile = (guid, fileToo) ->
	if fileCache[guid]?
		fs.unlinkSync fileCache[guid] if fileToo
		watchers[fileCache[guid]].close() if watchers[fileCache[guid]]?
		delete fileCache[fileCache[guid]]
		delete fileCache[guid]

loadSettings()

# Create the web server. #
server = express()
# Use automatic json body parsing, with a size limit of 50mb. #
server.use bodyParser.json(limit: '50mb')

# Endpoint is used to handeshake with the plugin and compare version information. #
server.post "/new", (req, res) ->
	loadSettings()
	data = req.body

	# Check if we've already seen this place name, and if so, clear all file watchers and caches for that place. #
	if guidCache[data.place_name]?
		for guid in guidCache[data.place_name]
			deleteFile guid, false

	guidCache[data.place_name] = []

	res.json 
		status: "OK"
		app: "RSync"
		pm: getSetting 'pmPath'
		version: VERSION
		build: BUILD

# The long-polling endpoint. It has a maximum timeout of 50 seconds, leaving 10 seconds of room as the 
# ROBLOX maximum request timeout is 60 seconds. #
server.get "/poll", (req, res) ->
	lprequest = null

	# If there is a command already queued up, send it immediately. #
	if commands.length
		res.json commands.shift()
	else
		# Otherwise, save the request in a variable and create the timeout to end 
		# the request if no commands come through. #
		lprequest = res
		setTimeout ->
			# If our request is still the long poll request, then end it. #
			if lprequest is res
				lprequest = null
				res.json({})
		, 50000

# Endpoint used to delete a script from our caches and the filesystem. #
server.post "/delete", (req, res) ->
	data = req.body

	deleteFile data.guid, true

	res.send "OK"

# The write endpoint. Called by the plugin to write new scripts and script changes to the filesystem. #
server.post "/write/:action", (req, res) ->
	# Determine if the plugin has specified if we should open the file after creating it. #
	if req.params.action? and req.params.action is "open"
		openAfter = true
	else
		openAfter = false

	data = req.body

	# Determine if we should affix a script type modifer to the file name. #
	switch data.class
		when "LocalScript"
			ext = ".local"
		when "ModuleScript"
			ext = ".module"
		else
			ext = ""

	# Determine what file extension we should use. #
	switch data.syntax
		when "lua"
			fext = ".lua"
		when "moon"
			fext = ".moon"
		else
			fext = ".rbxs"

	# Build the filename. #
	filename = "#{data.name}#{ext}#{fext}"	

	# If persistent mode is enabled, use pmPath for a save path. Otherwise, use tempPath. #
	console.log data.temp
	if data.temp
		filepath = path.join(getSetting('tempPath'), data.place_name, data.path)
	else
		filepath = path.join(getSetting('pmPath'), data.place_name, data.path)

	console.log filepath

	file = path.join(filepath, filename)

	# Check for duplicate file names. If found, a number in parenthesis is appended to the file name before the
	# file extension, incrementing for each duplicate file found. #
	unless fileCache[file] is data.guid
		while fileCache[file]
			matches = /\(([0-9]+)\)\.lua$/.exec file
			num = matches[1] if matches? and matches[1]?
			if num?
				num = parseInt num, 10
				num += 1
				file = path.join filepath, "#{data.name}#{ext} (#{num}).lua"
			else
				file = path.join filepath, "#{data.name}#{ext} (2).lua"

			if fileCache[file] is data.guid
				break

	# Add the script to our GUID cache which is used for keeping track of our scripts associated with this place. #
	guidCache[data.place_name].push data.guid

	# Create the folders that lead up to the file. #
	mkdirp filepath, ->
		# Write the script to the filesystem. #
		fs.writeFileSync file, data.source

		# If we haven't seen this file before, start watching it for changes. #
		unless fileCache[file]
			watchers[file] = fs.watch file, (type) ->
				if type is "change"
					try
						fileSource = fs.readFileSync file, encoding: 'utf8'
					catch error
						return console.log error
						
					switch data.syntax
						when "lua"
							# Send a Lua script back to the plugin. #
							addCommand "update", 
								guid: data.guid
								source: fileSource
						when "moon"
							# Compiles MoonScript and sends it back to the plugin. #
							exec "moonc -p \"#{file}\"", (err, stdout, stderr) ->
								if err
									# If there was an error while compiling, send it to Studio's output. #
									return addCommand "output",
										text: stderr

								try
									addCommand "update",
										guid: data.guid
										source: stdout
										moon: fileSource

		# Update our caches with new information about the file. #
		fileCache[file] 		= data.guid
		fileCache[data.guid]	= file

		# Open the script in the default .lua editor if specified. #
		shell.openItem file if openAfter

	res.send "OK"

module.exports = 
	areSettingsReady: -> settingsLoaded
	listen: (port) ->
		server.listen port
	addCommand: addCommand
	getSetting: getSetting
	setSetting: setSetting