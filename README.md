# RbxSync - Third party IDE support for ROBLOX Studio in one click
[![Patreon](http://i.imgur.com/dujYlAK.png)](https://www.patreon.com/erynlynn)

RbxSync is an open source ROBLOX plugin that easily integrates any third-party code editor or IDE, such as Sublime Text, Notepad++, VS Code, or Atom, into ROBLOX Studio. This is accomplished via a helper application which runs in the tray and acts as a middle man between your code editor of choice and ROBLOX Studio. 

![Tray example](https://i.imgur.com/lqhr2sx.png)
![Demo Gif](https://i.imgur.com/z9oeWaF.gif)

## Download
Available in the [releases section.](https://github.com/evaera/RbxSync/releases/latest)

**Notice**: The executable will most likely cause Windows to alert you with a fullscreen SmartScreen warning because this file is not commonly downloaded. To run anyway, click *More info* then click *Run anyway*. If you're wary, you can build the plugin from the source with the instructions below.

## Installation 
RbxSync is designed with simplicity in mind: just download the executable and run it, and it will automatically install the plugin into ROBLOX Studio. Just let the application run in the tray while you're developing. (**Note**: If you have changed the ROBLOX Studio Plugin directory, you will need to configure this before using RbxSync)

Files will open with your system default `.lua` editor.

**Note**: If you already have Studio open when you run the application for the first time, you will need to restart Studio for the plugin to load.

## Features
### Persistent Mode / Git Mode
By default, RbxSync will use a temporary folder, but using a persistent directory is also supported. This will cause the plugin to write *all* scripts to disk (nested with folders that match in-game hierarchy), even ones you don't explicitly open. The plugin will keep the scripts up to date on disk, even through `Parent` or `Name` changes. If you delete the script from your game, it will also be deleted on disk. If two objects have the same name and parent, one of them will be appended with `(2)` at the end of its name. Try to avoid this.

This allows you to create a Git repository for all the scripts in your game super easily.

To enable this feature, create a `StringValue` in `ServerScriptService` named `PlaceName`, and then set the value to the name you'd like the folder to use. The scripts will then be written to `C:\Users\<Current User>\Documents\ROBLOX\RbxSync\<Place Name>` by default, but this is configurable. 

![PMode Demo](https://i.imgur.com/FsNBKK6.png)

### Mixins (DEPRECATED)
**!! Mixins are deprecated as of v1.3.4 and support for this special syntax will be dropped in version 2 (coming 2018). Code created with mixins will continue to work after support is dropped, but they will no longer be parsed into the @(...) syntax.**

Mixins allow you to use the syntax `@(mixin_name)` in your scripts, which will return any values you set in the Mixins module. To use this feature, create a *ModuleScript* in *ReplicatedStorage* named `Mixins`. 

The module should return a table with string indexes for your mixin names. The values can be any type, but if they are a function, the function will be executed, given the arguments `(mixin_name, script, function_environment)`. 

- `mixin_name`: The name of the mixin, e.g. what is `@(here)`.
- `script`: The Script object that is using the mixin
- `function_environment`: The result of `getfenv` in the function where the mixin is used

**Example `Mixins` script**: 
```lua
return {
	hello = "Hi there!";
	require_all_children = function(mixin, script, env)
		for _, child in pairs(script:GetChildren()) do
			if child:IsA("ModuleScript") then
				require(child)
			end
		end
	end;
}
```

Then, anywhere in another script:

```lua
@(require_all_children)

print(@(hello))
```

This actually compiles to:

```lua
local __RSMIXINS=require(game:GetService"ReplicatedStorage".Mixins);__RSMIXIN=function(a,b,c)if type(__RSMIXINS[a])=='function'then return __RSMIXINS[a](a,b,c)else return __RSMIXINS[a]end end

__RSMIXIN('require_all_children', script, getfenv())

print(__RSMIXIN('hello', script, getfenv()))
```

### MoonScript Support
If you have MoonScript installed on your computer (have [`moonc`](http://moonscript.org/) in your PATH), RbxSync can automatically compile your scripts into Lua every time you save them and instantly push them to your game in Studio.

Mixins can be used with the built-in `mixin` function, e.g. `mixin "hello"`. In MoonScript mode only, there are three special mixin names, which can be used to inject things into the environment:

- `autoload`: This mixin is automatically run at the start of every script.
- `client`: This mixin is automatically run at the start of every script running on the client.
- `server`: This mixin is automatically run at the start of every script running on the server.

**To put a script in MoonScript mode**, there must be a StringValue named "MoonScript" inside of it. The plugin provides several shortcuts so you don't have to do this manually:
- If you put `.moon` at the end of your script name (e.g. `KillScript.moon`, then press the *Open in Editor* button, it will remove the `.moon` from the name after it's created the value.
- If the script source contains `m`, `moon`, or `moonscript` exactly, when you press the *Open in Editor* button, it will also put the script in MoonScript mode.
- Use the hotkey `Ctrl+Alt+B` with a script selected.

## Building it yourself
Building RbxSync is made easy by using CoffeeScript's Cakefiles. The build script will automatically replace the partial strings in `plugin.coffee` with the data from the `partials/` directory.

### Prerequisites 
- `npm install -g electron-packager`
- `npm install -g electron`
- `npm install -g coffee-script`
- You must have [`moonc`](http://moonscript.org/) in your PATH.
- Go to the `./src` directory and run `npm install` to install the dependencies

### Building and running the app for developmental testing
Run `cake b && electron src` from the directory that the Cakefile is in

### Building the entire app into executable
Run `cake build:app`

## TODO
- Need to make the plugin work with multiple instances of Studio open, but this will probably require quite a bit of refactoring in `server.coffee`
