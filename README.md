# Lock Layer Script 1.0
TC_LockLayer is a script that brings the ability to lock layers to Moho!
Moho has support for locking layers within its scripting interface, but there exists no feature in Moho that lets the user take advantage of this.
Now, locking and unlocking layers can be done by clicking this tool's icon whilst having 1 or more layers selected.

## Installation
- Clone this repository (if you're familiar with Git), or download it as a zip file and unzip.
- Then, with Moho open, go to the top menu, Scripts > Install Script.., and point it to this folder.
- Ensure the folder you point to has the below structure, or it won't install:

```bash
Installed Folder
│   README.md
├───ScriptResources
├───tool
│       TC_LockLayer.lua
│       TC_LockLayer.png
└───utility
```

## Features

Upon clicking the lock button, the following will happen:
1. A config file (.TC_ToggleLock.config.txt) and a hook script (.TC_ToggleLock.hook.lua) will appear in your project's directory.
2. If you chose to enable Lock Hook, and a hook is not attached to a layer, you will be asked to attach it to the current layer.
4. The layer is locked (or unlocked),
5. The layer will be ignored by the layer selector (or this setting will be reverted),
6. A lock symbol '🔒' prefixes the layer's name (or it will be removed).

## About Lock Hook

Lock Hook is a layer script that binds to a given layer in your document.
- It watches for layer renaming events on locked layers that might erase the lock symbol, and prevents the lock symbol from being erased.
- It places a script symbol '📜', on the layer it is attached to, allowing the user to easily locate and remove the hook if necessary.

> Note: To attach a runnable script to a layer, Moho requires a .lua file on disk to use as a reference.
> TC_ToggleLock generates one (.TC_ToggleLock.hook.lua) in your project's folder. Do not mess with this file.

You may opt out of / re-enable this feature by modifying the config file (.TC_ToggleLock.config.txt)

To disable:
```
use_lock_hook=false
```
To re-enable:
```
use_lock_hook=true
```

### Without Lock Hook
Without Lock Hook, there is no mechanism that prevents the user from erasing the lock symbol '🔒' during renaming. As such, the layer name may not properly reflect the layer's lock status.
