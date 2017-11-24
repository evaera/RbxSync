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

setLanguageDefaults = (language) ->
	language.info.sendToRobloxStudio = false if typeof(language.info.sendToRobloxStudio) == 'undefined'
	setDefaults(sendToRobloxStudioDefaults, language.info) if language.info.sendToRobloxStudio

setDefaults = (defaults, obj) ->
	for propName, values of defaults
		setDefaults(values.children, obj[propName]) if typeof(obj[propName]) != 'undefined' and values.children
		obj[propName] = values.default if typeof(obj[propName]) == 'undefined'

module.exports =
	setLanguageDefaults: setLanguageDefaults
