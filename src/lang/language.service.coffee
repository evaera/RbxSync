fs = require 'fs'
Rx = require 'rxjs/Rx'

LanguageValidationService = require './language-validation.service.js'

builtInLanguages = [
	'./Lua'
	'./MoonScript'
]

class LanguageService
	constructor: () ->
		@languages = new Rx.Subject()
		@errors = new Rx.Subject()

	reloadLanguages: (customLanguagesFolder) ->
		languages = []
		@loadLanguage languages, language for language in builtInLanguages
		@loadLanguagesFromFolderWithoutCaching languages, customLanguagesFolder
		@languages.next languages

	loadLanguage: (languages, languageFolder) ->
		language = require "#{languageFolder}\\lang.js"

		languageErrors = LanguageValidationService.validateLanguage language

		if languageErrors.length > 0
			@errors.next "Could not import the language in '#{languageFolder}' because:\n\n#{formatErrorMessages(languageErrors)}"
		else
			LanguageValidationService.setLanguageDefaults language

			if language.info.luaIncludes && language.info.luaIncludes.constructor == Array
				setIncludeSource include, "#{languageFolder}\\#{include.file}" for include in language.info.luaIncludes

			languages.push language

	loadLanguagesFromFolderWithoutCaching: (languages, folder) ->
		for languageFolder in listLanguageFolders folder
			@loadLanguage languages, languageFolder
			delete require.cache[require.resolve("#{languageFolder}\\lang.js")]

formatErrorMessages = (errorMessages) ->
	"\t- #{errorMessages.join('\n\t- ')}"

setIncludeSource = (include, file) ->
	try
		include.source = fs.readFileSync file, encoding: 'utf8'
	catch error
		console.log error

listLanguageFolders = (folder) ->
	"#{folder}\\#{entry}" for entry in fs.readdirSync folder when isLanguageFolder "#{folder}\\#{entry}"

isLanguageFolder = (entry) ->
	fs.lstatSync(entry).isDirectory() && fs.existsSync "#{entry}\\lang.js"

module.exports = LanguageService
