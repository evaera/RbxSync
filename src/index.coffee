{app, BrowserWindow, Tray, Menu, MenuItem, shell, dialog, ipcMain} =
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
win 	= null

console.log "Starting application..."

# Destroys the tray icon and quits the app. #
quitApp = ->
	tray.destroy() if tray?
	win.destroy() if win?
	app.quit()

# Copies the packaged plugin.lua file into Studio's default plugin directory. #
copyPlugin = ->
	filepath = path.join httpServer.getSetting('pluginPath'), "RSync"

	mkdirp filepath, ->
		fs.writeFileSync path.join(filepath, "rsync.lua"), fs.readFileSync(path.join(__dirname, "plugin.lua"))
		fs.writeFileSync path.join(filepath, "VERSION"), BUILD

# Checks for an update in the GitHub repository. #
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
			# Add the update button to the tray context menu. #
			menu.insert 0, new MenuItem({type: "separator"})
			menu.insert 0, new MenuItem({
				label: "Download New Update...",
				click: ->
					shell.openExternal "https://github.com/evaera/RSync/releases"
			})

			win.webContents.send 'updateAvailable'

			# Display a notification that there is an update. #
			tray.displayBalloon 
				title: "A new update for RSync is available."
				content: "Right-click on the tray icon to download the new update."

# Called when the electron application is ready. #
app.on 'ready', ->
	# Test the port before we bind our http server to it. #
	portastic.test PORT, (open) ->
		if open
			# If open, copy the plugin and enable the https erver. #
			copyPlugin()
			httpServer.listen PORT
		else
			# If not open, show an error message and quit the app. #
			dialog.showMessageBox
				type: "warning"
				title: " "
				message: "It appears that another instance of RSync is already running. (port #{PORT})"
				buttons: []
			, ->
				quitApp()
		
	# Create the tray icon and context menu. #
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

	tray.on 'click', ->
		win.show() if win?

	win = new BrowserWindow
		icon: path.join __dirname, "icon.ico"
		height: 400
		width: 350
		resizable: false
		autoHideMenuBar: true
		title: "RSync"
		backgroundColor: "#e74c3c"
		frame: false
		fullscreenable: false
		transparent: true;

	win.on 'close', (event) ->
		event.preventDefault()
		win.hide()

	win.loadURL path.join(__dirname, "app/app.html")

	win.show()

	# Check for an update. 
	checkForUpdate menu

	console.log "Ready."

ipcMain.on 'quit', () ->
	quitApp()
	
ipcMain.on 'update', ->
	shell.openExternal "https://github.com/evaera/RSync/releases"
	quitApp()

ipcMain.on 'setSettingPath', (event, name) ->
	dialog.showOpenDialog win, {
		title: "Select #{name}"
		defaultPath: httpServer.getSetting(name)
		properties: ['openDirectory', 'showHiddenFiles']
	}, (files) ->
		if files?
			httpServer.setSetting name, files[0]
			win.webContents.send 'updatePaths'

ipcMain.on 'getPath', (event, name) ->
	event.returnValue = httpServer.getSetting(name)