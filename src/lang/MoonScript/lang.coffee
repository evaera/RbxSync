{ exec } = require 'child_process'

module.exports =
  transpile: (file, fileSource, addCommand, guid) ->
    exec "moonc -p \"#{file}\"", (err, stdout, stderr) ->
      if err
        addCommand "output",
          text: stderr
      else
        addCommand "update",
          guid: guid
          source: stdout
          moon: fileSource
