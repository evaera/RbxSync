module.exports =
  transpile: (file, fileSource, addCommand, guid) ->
    addCommand "update",
      guid: guid
      source: fileSource
