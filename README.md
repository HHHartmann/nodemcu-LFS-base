# nodemcu-LFS-base

startup an esp8266

## Features
* configure WIFI (restart on connection loss)
* start ftp and telnet server
* failsafe boot (avoid boot loops and the need to reflash firmware)

## Installation
You need LFS enabled firmware.

Copy "LFS/wifiConfig.lua.sample" to "LFS/wifiConfig.lua" and adapt as needed
Generate LFS image with `*.lua` files in LFS subdir.
Transfer `*.lua` files from root directory and LFS image to MCU.
Execute
`node.flashreload(<LFS image name>)`
on the MCU to flash the image.

Reboot




## bootprotect.lua
This is to protect the system from bootloops. It replaces the 5 sec wait which is sometimes proposed.
It does not delay bootup though and can also only boot partially to like start a maintenance mode.

usage:
`dofile("bootprotect.lua").start(signalpin, timeout, startupStep, ...)`

This calls the given startupStep functions one by one.
If one failes the next reboot will only execute the steps up to the one failing.
If the system crashes before timeout seconds the next boot will execute one step less.
So when messing up the application still basic stuff as FTP can be loaded and allow maintenance.
signalPin   Pin to show boot status (maybe an LED)
timeout     Wait for any resets for some time before calling it a successful boot (only wait at the end, not after each step)
...         Functions which are called one by one
            A Callback is passed to the functions to be called after async stuff is done
            To tell the framework whether the callback will be used the function uses the return value
              nil             callback will not be used. Proceed immediately with next step
              anything else   callback will be used to start next step
            This is usefull if a startupStep has to perform async stuff, like wait for WIFI connecting to an accesspoint.


Successful bootSteps will be persisted in rtcmem if available or else in the filesystem.

