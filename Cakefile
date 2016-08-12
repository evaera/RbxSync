fs 		= require 'fs'
{exec} 	= require 'child_process'

config 	= require './src/config.json'

task "build:plugin", "build the plugin", ->
	invoke "config"
	exec "moonc plugin.moon", cwd: "./plugin", ->
		fs.writeFileSync "./src/plugin.lua", fs.readFileSync("./plugin/plugin.lua", encoding: "utf8")

task "build:app", "build electron app", ->
	invoke "build:plugin"

	exec "electron-packager ./src RSync --platform=win32 --arch ia32 --asar --version 1.3.3", ->
		console.log "Build complete"

task "config", "Update config in plugin.moon", ->
	code = fs.readFileSync "./plugin/plugin.moon", encoding: "utf8"
	code = code.replace /BUILD=[0-9]+/, "BUILD=#{config.BUILD}"
	code = code.replace /PORT=[0-9]+/, "PORT=#{config.PORT}"
	fs.writeFileSync "./plugin/plugin.moon", code