'use strict'

const path = require('path')
const {BrowserWindow} = require('electron')
const Util = require('./Util')

const assets = {
  ICON: path.join(__dirname, '..', 'assets', 'icon.png'),
  APP: path.join(__dirname, '..', 'app', 'place.html')
}

const _instances = {}

class Place {
  constructor () {
    this.id = Util.generateRandomString(30)
    this.response = null
    this.commands = []

    Place.instances[this.id] = this
  }

  static get instances () {
    return _instances
  }

  static getPlace (id) {
    if (Place.instances[id]) {
      return Place.instances[id]
    } else {
      throw new Error('Unknown place id!')
    }
  }

  reply () {
    if (this.commands.length === 0 || this.response === null) {
      return
    }

    console.log('command')
    this.response.json(this.commands.shift()).end()
    this.response = null
  }

  setResponse (res) {
    if (this.response !== null) {
      console.log('conflict')
      this.response.json({ status: 'conflict' }).end()
      this.response = null
    }

    this.response = res

    if (this.commands.length > 0) {
      this.reply()
    } else {
      let currentResponse = this.response
      setTimeout(() => {
        if (currentResponse === this.response) {
          console.log('timeout')
          this.response.json({ status: 'timeout' }).end()
          this.response = null
        }
      }, 55000)
    }
  }
}

module.exports = Place
