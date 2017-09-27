'use strict'

const path = require('path')
const fs = require('fs-extra')
const request = require('request-promise')
const {app, BrowserWindow, Tray, Menu, MenuItem, shell, dialog, ipcMain} = require('electron')
const config = require('./config.json')
const assets = {
  ICON: path.join(__dirname, '..', 'assets', 'icon.png'),
  ICO: path.join(__dirname, '..', 'assets', 'icon.ico'),
  APP: path.join(__dirname, '..', 'app', 'index.html'),
  PLACE: path.join(__dirname, '..', 'app', 'place.html')
}

class App {
  constructor () {
    this.window = null
    this.tray = null
    this.trayMenu = null

    this.pluginPath = path.join(app.getPath('appData'), '..', 'Local', 'Roblox', 'Plugins')

    app.on('ready', () => {
      this.initTray()
      // This.initWindow();
      this.initSettingsWindow()
      this.checkForUpdate()
    })

    this.copyPlugin().catch(e => console.log(e))
  }

  async copyPlugin () {
    await fs.remove(path.join(this.pluginPath, 'RSync'))

    await fs.ensureDir(this.pluginPath)
    await fs.copy(path.join(__dirname, '..', 'plugin', 'plugin.lua'), path.join(this.pluginPath, 'RbxSync', 'RbxSync.lua'))
  }

  initWindow () {
    this.window = new BrowserWindow({
      icon: assets.ICON,
      height: 400,
      width: 350,
      resizable: false,
      autoHideMenuBar: true,
      title: 'RbxSync',
      backgroundColor: '#e74c3c',
      frame: false,
      fullscreenable: false,
      transparent: true
    })

    this.window.on('close', e => {
      e.preventDefault()
      this.window.hide()
    })

    this.window.once('ready-to-show', () => this.window.show())

    this.window.loadURL(`file:///${assets.APP}`)
  }

  initSettingsWindow () {
    this.settingsWindow = new BrowserWindow({
      icon: assets.ICON,
      height: 500,
      width: 600,
      resizable: false,
      autoHideMenuBar: true,
      title: 'RbxSync',
      backgroundColor: '#fafafa',
      frame: false,
      fullscreenable: false,
      transparent: true
    })

    this.settingsWindow.on('close', e => {
      e.preventDefault()
      this.settingsWindow.hide()
    })

    this.settingsWindow.once('ready-to-show', () => this.settingsWindow.show())

    this.settingsWindow.loadURL(`file:///${assets.PLACE}`)
  }

  initTray () {
    this.trayMenu = Menu.buildFromTemplate([
      { label: `RbxSync version ${config.VERSION} release ${config.BUILD}`, enabled: false },
      { label: 'View GitHub repository', click: () => shell.openExternal(config.REPOSITORY) },
      { label: 'Dev Tools', click: () => this.window.webContents.openDevTools() },
      { type: 'separator' },
      { label: 'Quit', click: () => this.quit() }
    ])

    this.tray = new Tray(assets.ICO)
    this.tray.setContextMenu(this.trayMenu)
    this.tray.setToolTip('RbxSync Helper')

    this.tray.on('click', () => {
      if (this.window) this.window.show()
    })
  }

  async checkForUpdate () {
    let liveConfig = await request('https://raw.githubusercontent.com/evaera/RSync/master/src/config.json', { json: true })

    if (liveConfig.BUILD > config.BUILD) {
      this.trayMenu.insert(0, new MenuItem({ type: 'separator' }))
      this.trayMenu.insert(0, new MenuItem({
        label: 'Download new update...',
        click: () => shell.openExternal(`${config.REPOSITORY}/releases`)
      }))

      this.window.webContents.send('updateAvailable')

      this.tray.displayBalloon({
        title: 'A new update for RbxSync is available.',
        content: 'Right click on the tray icon to download the new update'
      })
    }
  }

  quit () {
    console.log('quit')
    if (this.tray) this.tray.destroy()
    if (this.window) this.window.destroy()
    if (this.settingsWindow) this.settingsWindow.destroy()
    app.quit()
  }
}

module.exports = App
