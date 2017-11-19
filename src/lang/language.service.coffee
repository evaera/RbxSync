fs = require 'fs'
Rx = require 'rxjs/Rx'

thisFolder = '.'

isLanguageFolder = (entry) ->
  fs.lstatSync(entry).isDirectory() && fs.existsSync "#{entry}/lang.js"

listLanguageFolders = (folder) ->
  entry for entry in fs.readdirSync folder when isLanguageFolder entry

loadLanguage = (languages, languageFolder) ->
  languages.push require("#{languageFolder}/lang.js")

loadLanguagesFromFolder = (languages, folder) ->
  loadLanguage languages, languageFolder for languageFolder in listLanguageFolders folder

loadLanguagesFromFolderWithoutCaching = (languages, folder) ->
  for languageFolder in listLanguageFolders folder
    loadLanguage languages, languageFolder
    delete require.cache[require.resolve("#{languageFolder}/lang.js")]

class LanguageService
  constructor: (customLanguagesFolder) ->
    @languages = new Rx.Subject()
    this.reloadLanguages customLanguagesFolder

  reloadLanguages: (customLanguagesFolder) ->
    languages = []
    loadLanguagesFromFolder languages, thisFolder
    loadLanguagesFromFolderWithoutCaching languages, customLanguagesFolder
    @languages.next languages

module.exports = LanguageService
