{ipcRenderer} = require 'electron'

window.settings = ->
	$('#home').fadeOut()
	$('#footer').slideUp()
	$('#settings').fadeIn()

window.home = ->
	$('#footer').show()
	$('#home').fadeIn()
	$('#settings').fadeOut()

window.quit = ->
	ipcRenderer.send 'quit'

window.update = ->
	ipcRenderer.send 'update'

window.choosePluginPath = ->
	ipcRenderer.send 'setSettingPath', 'pluginPath'

window.choosePmPath = ->
	ipcRenderer.send 'setSettingPath', 'pmPath'

window.chooseLangPath = ->
	ipcRenderer.send 'setSettingPath', 'langPath'

window.reloadLangs = ->
	ipcRenderer.send 'reloadLangs'

updatePaths = ->
	updatePath 'pluginPath', '#plugin-path-text'
	updatePath 'pmPath', '#pm-path-text'
	updatePath 'langPath', '#lang-path-text'

updatePath = (name, id) ->
	path = ipcRenderer.sendSync 'getPath', name
	$(id).text(path)

ipcRenderer.on 'updateAvailable', ->
	$('#update').show()

ipcRenderer.on 'updatePaths', updatePaths

updatePaths()

Waves.attach '.waves'
Waves.init()

$('#settings .container').scrollbar();
