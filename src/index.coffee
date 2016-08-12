{app, BrowserWindow, Tray, Menu, shell, dialog} =
	require 'electron'

fs 				= require 'fs'
path 			= require 'path'
portastic		= require 'portastic'
mkdirp			= require 'mkdirp'

httpServer 		= require './server'

{PORT, VERSION, BUILD} = 
	require './config.json'

tray 	= null

quitApp = ->
	tray.destroy() if tray?
	app.quit()

copyPlugin = ->
	filepath = path.join(app.getPath("appData"), "..", "Local", "Roblox", "Plugins", "RSync")

	mkdirp filepath

	fs.writeFileSync path.join(filepath, "rsync.lua"), fs.readFileSync(path.join(__dirname, "plugin.min.lua"))
	fs.writeFileSync path.join(filepath, "VERSION"), BUILD

app.on 'ready', ->
	portastic.test PORT, (open) ->
		if open
			copyPlugin()
			httpServer.listen PORT
		else
			dialog.showMessageBox
				type: "warning"
				title: " "
				message: "RSync could not start the local HTTP server, please ensure no other processes are using port #{PORT}."
				buttons: []
			, ->
				quitApp()
		

	tray = new Tray path.join(__dirname, "icon.ico")

	tray.setToolTip "RSync Helper"

	menu = Menu.buildFromTemplate [
		{
			label: "RSync version #{VERSION} build #{BUILD}"
			enabled: false
		}
		{
			label: "About RSync..."
			click: (item) ->
				shell.openExternal "https://eryn.io/rsync"
		}
		{
			type: "separator"
		}
		{
			label: "Quit",
			click: (item) ->
				quitApp()
		}
	]
	tray.setContextMenu menu