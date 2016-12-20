fs 		= require 'fs'
path    = require 'path'
{exec} 	= require 'child_process'
parser  = require './src/node_modules/properties-parser/index.js'

config 	= require './src/config.json'

task "build:plugin", "build the plugin", ->
	invoke "partials"
	exec "moonc plugin.moon", cwd: "./plugin/build", ->
		console.log "Plugin Compiled"
		fs.writeFileSync "./src/plugin.lua", fs.readFileSync("./plugin/build/plugin.lua", encoding: "utf8")

task "build:app", "build electron app", ->
	invoke "build:plugin"
	invoke "build:coffee"

	exec "electron-packager ./src RSync --platform=win32 --arch ia32 --asar --version 1.3.3", ->
		console.log "Build complete"

task "build:coffee", "build the coffee files into javascript", ->
	exec "coffee -c .", (err, stdio, stderr) ->
		console.log stderr
		console.log "CoffeeScript Compiled"

task "build:sass", "Compile scss into css", ->
	exec "sass ./src/app/style.scss ./src/app/style.css", ->
		console.log "Sass compiled"

task "b", "Build stuff needed before dev testing, run as cake b && electron src", ->
	console.log "Building..."

	invoke "build:coffee"
	invoke "build:sass"
	invoke "build:plugin"

task "partials", "Insert partials into plugin.moon", ->
	strings = parser.read "./plugin/partials/strings.properties"

	code = fs.readFileSync "./plugin/plugin.moon", encoding: "utf8"
	code = code.replace /\[\[\s?(config|strings|file):([a-zA-Z0-9\.]+)\s?\]\]/gi, (match, type, name) ->
		switch type
			when 'config'
				if config[name]?
					if isNaN config[name]
						"[==[#{config[name]}]==]"
					else
						config[name]
			when 'strings'
				"[==[#{strings[name]}]==]" if strings[name]?
			when 'file'
				filepath = path.join __dirname, "plugin/partials/", name

				if fs.existsSync filepath
					"[==[" + fs.readFileSync(filepath, encoding: "utf8") + "]==]"

	fs.writeFileSync "./plugin/build/plugin.moon", code
	console.log "plugin.moon partials inserted"