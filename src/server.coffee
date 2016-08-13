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

commands = []
lprequest = null
fileCache = {}

addCommand = (type, data) ->
	commands.push {type: type, data: data}
	if lprequest?
		lprequest.json(commands.shift())
		lprequest = null

server = express()
server.use bodyParser.json()

server.get "/", (req, res) ->
	res.json 
		status: "OK"
		app: "RSync"
		version: VERSION
		build: BUILD

server.get "/poll", (req, res) ->
	lprequest = null
	if commands.length
		res.json commands.shift()
	else
		lprequest = res
		setTimeout ->
			if lprequest is res
				lprequest = null
				res.json({})
		, 50000


server.post "/write/:action", (req, res) ->
	if req.params.action? and req.params.action is "open"
		openAfter = true
	else
		openAfter = false

	data = req.body

	switch data.class
		when "LocalScript"
			ext = ".local"
		when "ModuleScript"
			ext = ".module"
		else
			ext = ""

	switch data.syntax
		when "lua"
			fext = ".lua"
		when "moon"
			fext = ".moon"
		else
			fext = ".rbxs"

	filename 	= "#{data.name}#{ext}#{fext}"
	filepath 	= path.join(app.getPath("temp"), "RSync", data.place_name, data.path)
	file 		= path.join(filepath, filename)

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

	mkdirp filepath, ->
		fs.writeFileSync file, data.source

		unless fileCache[file]
			fs.watch file, (type) ->
				if type is "change"
					switch data.syntax
						when "lua"
							addCommand "update", 
								guid: data.guid
								source: fs.readFileSync file, 
									encoding: 'utf8'
						when "moon"
							exec "moonc #{file}", (err, stdout, stderr) ->
								if err
									return addCommand "output",
										text: stderr

								addCommand "output",
									text: stdout

								try
									addCommand "update",
										guid: data.guid
										source: fs.readFileSync path.join(filepath, "#{data.name}#{ext}.lua"), 
											encoding: 'utf8'
										moon: fs.readFileSync file, 
											encoding: 'utf8'

		fileCache[file] = data.guid
		shell.openItem file if openAfter

	res.send "OK"

module.exports = 
	listen: (port) ->
		server.listen port
	addCommand: addCommand