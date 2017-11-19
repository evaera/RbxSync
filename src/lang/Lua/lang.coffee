module.exports =
	info:
		extension: '.lua'
		syntax: 'lua'
		sendToRobloxStudio: false
	transpile: (file, fileSource, addCommand, guid) ->
		addCommand "update",
			guid: guid
			source: fileSource
