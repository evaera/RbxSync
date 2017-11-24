fs = require 'fs'
Rx = require 'rxjs/Rx'

LanguageValidationService = require './language-validation.service.js'

defaultLanguages = [
	'./Lua'
	'./MoonScript'
]

class LanguageService
	constructor: ->
		@languages = new Rx.Subject()

	reloadLanguages: (customLanguagesFolder) ->
		languages = []
		loadLanguage languages, language for language in defaultLanguages
		loadLanguagesFromFolderWithoutCaching languages, customLanguagesFolder
		@languages.next languages

loadLanguage = (languages, languageFolder) ->
	language = require "#{languageFolder}\\lang.js"
	LanguageValidationService.setLanguageDefaults language

	if language.info.luaIncludes && language.info.luaIncludes.constructor == Array
		setIncludeSource include, "#{languageFolder}\\#{include.file}" for include in language.info.luaIncludes

	languages.push language

setIncludeSource = (include, file) ->
	try
		include.source = fs.readFileSync file, encoding: 'utf8'
	catch error
		console.log error

loadLanguagesFromFolderWithoutCaching = (languages, folder) ->
	for languageFolder in listLanguageFolders folder
		loadLanguage languages, languageFolder
		delete require.cache[require.resolve("#{languageFolder}\\lang.js")]

listLanguageFolders = (folder) ->
	"#{folder}\\#{entry}" for entry in fs.readdirSync folder when isLanguageFolder "#{folder}\\#{entry}"

isLanguageFolder = (entry) ->
	fs.lstatSync(entry).isDirectory() && fs.existsSync "#{entry}\\lang.js"

module.exports = LanguageService
