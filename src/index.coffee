{app, BrowserWindow, Tray, Menu, MenuItem, shell, dialog} =
	require 'electron'
 
fs 				= require 'fs'
path 			= require 'path'
portastic		= require 'portastic'
mkdirp			= require 'mkdirp'
request			= require 'request'

httpServer 		= require './server'

{PORT, VERSION, BUILD} = 
	require './config.json'

tray 	= null

quitApp = ->
	tray.destroy() if tray?
	app.quit()

copyPlugin = ->
	filepath = path.join(app.getPath("appData"), "..", "Local", "Roblox", "Plugins", "RSync")

	mkdirp filepath, ->
		fs.writeFileSync path.join(filepath, "rsync.lua"), fs.readFileSync(path.join(__dirname, "plugin.min.lua"))
		fs.writeFileSync path.join(filepath, "VERSION"), BUILD

checkForUpdate = (menu) ->
	request.get "https://raw.githubusercontent.com/evaera/RSync/master/src/config.json", (err, res, body) ->
		return if err

		try
			data = JSON.parse body
		catch
			return

		return unless data.BUILD

		return unless typeof data.BUILD is "number"

		if data.BUILD > BUILD
			menu.insert 0, new MenuItem({type: "separator"})
			menu.insert 0, new MenuItem({
				label: "Download New Update...",
				click: ->
					shell.openExternal "https://github.com/evaera/RSync/releases"
			})

			tray.displayBalloon 
				title: "A new update for RSync is available."
				content: "Right-click on the tray icon to download the new update."

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
			click: ->
				shell.openExternal "https://github.com/evaera/RSync"
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

	checkForUpdate menu