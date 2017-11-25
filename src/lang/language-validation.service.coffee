{ validate } = require 'jsonschema'

infoShortSchema = require './info-short.schema.json'
infoFullSchema  = require './info-full.schema.json'

validateOptions =
	propertyName: 'lang.info'

sendToRobloxStudioDefaults =
	unallowedRobloxClasses:
		default: []
	defaultSource:
		default: ''
	initializationShortcuts:
		default: []
	luaIncludes:
		default: []
		children:
			version:
				default: null

validateLanguage = (language) ->
	info = language.info || {}
	schema = if info.sendToRobloxStudio then infoFullSchema else infoShortSchema

	errorMessages = (error.stack for error in validate(language.info, schema, validateOptions).errors)

	unless language.transpile and typeof(language.transpile) == 'function'
		errorMessages.push 'lang.transpile function is required'

	return errorMessages

setLanguageDefaults = (language) ->
	language.info.sendToRobloxStudio = false if typeof(language.info.sendToRobloxStudio) == 'undefined'
	setDefaults(sendToRobloxStudioDefaults, language.info) if language.info.sendToRobloxStudio

setDefaults = (defaults, obj) ->
	for propName, values of defaults
		setDefaults(values.children, obj[propName]) if typeof(obj[propName]) != 'undefined' and values.children
		obj[propName] = values.default if typeof(obj[propName]) == 'undefined'

module.exports =
	validateLanguage: validateLanguage
	setLanguageDefaults: setLanguageDefaults
