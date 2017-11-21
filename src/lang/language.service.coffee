fs = require 'fs'
Rx = require 'rxjs/Rx'

defaultLanguages = [
	'./Lua'
	'./MoonScript'
]

isLanguageFolder = (entry) ->
	console.log entry
	fs.lstatSync(entry).isDirectory() && fs.existsSync "#{entry}\\lang.js"

listLanguageFolders = (folder) ->
	"#{folder}\\#{entry}" for entry in fs.readdirSync folder when isLanguageFolder "#{folder}\\#{entry}"

loadLanguage = (languages, languageFolder) ->
	languages.push require("#{languageFolder}\\lang.js")

loadLanguagesFromFolderWithoutCaching = (languages, folder) ->
	for languageFolder in listLanguageFolders folder
		loadLanguage languages, languageFolder
		delete require.cache[require.resolve("#{languageFolder}\\lang.js")]

class LanguageService
	constructor: ->
		@languages = new Rx.Subject()

	reloadLanguages: (customLanguagesFolder) ->
		languages = []
		loadLanguage languages, language for language in defaultLanguages
		loadLanguagesFromFolderWithoutCaching languages, customLanguagesFolder
		@languages.next languages

module.exports = LanguageService
