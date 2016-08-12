# RSync - Third party IDE support for ROBLOX Studio
RSync is an open source ROBLOX plugin that easily integrates any third-party code editor or IDE, such as Sublime Text, Notepad++, VS Code, or Atom, into ROBLOX Studio. This is accomplished via a helper application which runs in the tray and acts as a middle man between your code editor of choice and ROBLOX Studio. 

![Tray example](https://i.imgur.com/lqhr2sx.png)
![Demo Gif](https://i.imgur.com/z9oeWaF.gif)

## Download
Available in the [releases section.](https://github.com/evaera/RSync/releases/latest)

## Installation 
RSync is designed with simplicity in mind: just download the executable and run it, and it will automatically install the plugin into ROBLOX Studio. Just let the application run in the tray while you're developing. 

Files will open with your system default `.lua` editor.

RSync is designed to work on Windows only.

**Note**: If you already have Studio open when you run the application for the first time, you will need to restart Studio for the plugin to load.

## Building it yourself
The ROBLOX Studio plugin must be built before RSync will work, **even for development**. The build script will automatically copy the information from `/src/config.json` into *plugin.moon*, so that it always stays up to date with the config info.

### Prerequisites 
- `npm install -g luamin`
- `npm install -g electron-packager`
- You must have [`moonc`](http://moonscript.org/) in your PATH.

### Building the Plugin
Either run *build.bat* manually or use `cake build` if you have CoffeeScript installed. 
**Don't** run *buildc.bat* manually.

### Building the entire app
Same requirements as above, but this time just run *package.bat*. 

## Ideas / Coming Soon
- Moonscript support for game scripts
- Preprocessor mix-ins
- Helper mix-ins (like require all children modulescripts)
- Git mode, which would keep all scripts in your game on disk and up to date so you can use them in a git repo
