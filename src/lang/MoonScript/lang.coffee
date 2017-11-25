{ exec } = require 'child_process'

module.exports =
	info:
		extension: '.moon'
		syntax: 'moon'
		sendToRobloxStudio: true
		originalSourceValueName: 'MoonScript'
		defaultSource: 'print "Hello", "from MoonScript", "Lua version: #{_VERSION}"'
		initializationShortcuts: [
			{ type: 'hotkey', value: 'B' }
			{ type: 'source', value: 'm' }
			{ type: 'source', value: 'moon' }
			{ type: 'source', value: 'moonscript' }
			{ type: 'extension', value: '.moon' }]
	transpile: (file, fileSource, addCommand, guid) ->
		exec "moonc -p \"#{file}\"", (err, stdout, stderr) ->
			if err
				addCommand "output",
					text: stderr
			else
				addCommand "update",
					guid: guid
					source: stdout
					originalSource: fileSource
