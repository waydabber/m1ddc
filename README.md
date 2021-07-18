# m1ddc

This little tool controls external displays (connected via USB-C/DisplayPort Alt Mode) using DDC/CI on M1 Macs. Useful to embed in various scripts.

*Please note that controlling a HDMI display thourhg the 2020 M1 Mini's HDMI port is not working. You have to use DisplayPort over USB-C!*

## Prerequisites

You need `clang` from Apple's Command Line Tools (installs automatically if not present).

## Installation

After download, enter (in Terminal):

    make

You can then run the app by entering:

    ./m1ddc

## Usage examples:

`m1ddc set contrast 5` - Sets contrast to 5 on default display

`m1ddc get brightness` - Returns current brightness on default display

`m1ddc chg volume -10` - Decreases volume by 10 on default display

`m1ddc display list` - Lists displays

`m1ddc display 1 set volume 50` - Sets volume to 50 on Display 1

## Paramteres:

`set brightness n ` - Sets brightness to n, where n is a number between 0 and the maximum value (usually 100).

`set contrast n` - Sets contrast to n, where n is a number between 0 and the maximum value (usually 100).

`set volume n` - Sets volume to n, where n is a number between 0 and the maximum value (usually 100).

`set mute on` - Sets mute on (you can use 1 instead of 'on')

`set mute off` - Sets mute off (you can use 2 instead of 'off')

`get brightness` - Returns current brightness (if supported by the display).

`get contrast` - Returns current contrast (if supported by the display).

`get volume` - Returns current volume (if supported by the display).

`max brightness` - Returns maximum brightness (if supported by the display, usually 100).

`max contrast` - Returns maximum contrast (if supported by the display, usually 100).

`max volume` - Returns maximum volume (if supported by the display, usually 100).

`chg brightness n` - Changes brightness by n and returns the current value (requires current and max reading support).

`chg contrast n` - Changes contrast by n and returns the current value (requires current and max reading support).

`chg volume n` - Changes volume by n and returns the current value (requires current and max reading support).

`display list` - Lists displays.

`display n` - Chooses which display to control (use number 1, 2 etc.)

You can also use 'b', 'c' and 'v' instead of 'brightness', 'contrast', 'volume'.

## Example use in a script

Check out the following [hammerspoon](https://github.com/Hammerspoon/hammerspoon) script. 

This script allows you to control the volume of your external Display' brightness, contrast and volume via DDC (if you use an M1 Mac) using [m1ddc](https://github.com/waydabber/m1ddc) and also control your Yamaha AV Receiver through network. The script listens to the standard Apple keyboard media keys and shos the standard macOS Birghtness and Volume OSDs via uses [showosd](https://github.com/waydabber/showosd) :

https://gist.github.com/waydabber/3241fc146cef65131a42ce30e4b6eab7

## Thanks

Thanks to [@tao-j](https://github.com/tao-j) [@alin23](https://github.com/alin23), [@ybbond](https://github.com/ybbond)

Enjoy!
