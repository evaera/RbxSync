module.exports =
  getInfo: ->
    extension: '.lua'
    syntax: 'lua'
    sendToRobloxStudio: false
  transpile: (file, fileSource, addCommand, guid) ->
    addCommand "update",
      guid: guid
      source: fileSource
