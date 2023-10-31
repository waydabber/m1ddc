# m1ddc

This little tool controls external displays (connected via USB-C/DisplayPort Alt Mode) using DDC/CI on Apple Silicon Macs. Useful to embed in various scripts.

*Please note that this tool does not support the built-in HDMI port of M1 and entry level M2 Macs. This tool does not support Intel Macs. You can use [BetterDisplay](https://github.com/waydabber/BetterDisplay#readme) for free DDC control on all Macs and all ports.*

## Prerequisites

You need `clang` from Apple's Command Line Tools (installs automatically if not present).

## Installation

After download, enter (in Terminal):

    make

You can then run the app by entering:

    ./m1ddc

## Usage examples:

`m1ddc set contrast 5` - Sets contrast to 5 on default display

`m1ddc get luminance` - Returns current luminance ("brightness") on default display

`m1ddc set red 90` - Sets red gain to 90

`m1ddc chg volume -10` - Decreases volume by 10 on default display

`m1ddc display list` - Lists displays

`m1ddc display 1 set volume 50` - Sets volume to 50 on Display 1

`m1ddc display 10ACB8A0-0000-0000-1419-0104A2435078 set input 15` - Sets input to DisplayPort 1 on display with UUID 10ACB8A0-0000-0000-1419-0104A2435078

## Commands:

`set luminance n` - Sets luminance ("brightness") to n, where n is a number between 0 and the maximum value (usually 100).

`set contrast n` - Sets contrast to n, where n is a number between 0 and the maximum value (usually 100).

`set (red,green,blue) n` - Sets selected color channel gain to n, where n is a number between 0 and the maximum value (usually 100).

`set volume n` - Sets volume to n, where n is a number between 0 and the maximum value (usually 100).

`set input n` - Sets input source to n, common values include:<br/>
DisplayPort 1: 15, DisplayPort 2: 16, HDMI 1: 17, HDMI 2: 18, USB-C: 27.

`set input-alt n` - Sets input source to n (using alternate addressing, as used by LG), common values include:<br/>
DisplayPort 1: 208, DisplayPort 2: 209, HDMI 1: 144, HDMI 2: 145, USB-C / DP 3: 210.

`set mute on` - Sets mute on (you can use 1 instead of 'on')

`set mute off` - Sets mute off (you can use 2 instead of 'off')

`set pbp n` - Switches PIP/PBP on certain Dell screens (e.g. U3421WE), possible values:<br/>
off: 0, toggle window size: 1, toggle window position: 2, small window: 33, large window: 34, 50/50 split: 36, 26/74 split: 43, 74/26 split: 44.

`set pbp-input n` - Sets second PIP/PBP input on certain Dell screens, possible values:<br/>
DisplayPort 1: 15, DisplayPort 2: 16, HDMI 1: 17, HDMI 2: 18.

`get luminance` - Returns current luminance (if supported by the display).

`get contrast` - Returns current contrast (if supported by the display).

`get (red,green,blue)` - Returns current color gain (if supported by the display).

`get volume` - Returns current volume (if supported by the display).

`max luminance` - Returns maximum luminance (if supported by the display, usually 100).

`max contrast` - Returns maximum contrast (if supported by the display, usually 100).

`max (red,green,blue)` - Returns maximum color gain (if supported by the display, usually 100).

`max volume` - Returns maximum volume (if supported by the display, usually 100).

`chg luminance n` - Changes luminance by n and returns the current value (requires current and max reading support).

`chg contrast n` - Changes contrast by n and returns the current value (requires current and max reading support).

`chg (red,green,blue) n` - Changes color gain by n and returns the current value (requires current and max reading support).

`chg volume n` - Changes volume by n and returns the current value (requires current and max reading support).

`display list` - Lists displays.

`display n` - Chooses which display to control (use number 1, 2 etc.)

You can also use 'l', 'v' instead of 'luminance', 'volume' etc.

## Example use in a script

Check out the following [hammerspoon](https://github.com/Hammerspoon/hammerspoon) script.

This script allows you to control the volume of your external Display' brightness, contrast and volume via DDC (if you use an M1 Mac) using [m1ddc](https://github.com/waydabber/m1ddc) and also control your Yamaha AV Receiver through network. The script listens to the standard Apple keyboard media keys and shos the standard macOS Birghtness and Volume OSDs via uses [showosd](https://github.com/waydabber/showosd) :

https://gist.github.com/waydabber/3241fc146cef65131a42ce30e4b6eab7

## BetterDisplay

If you like m1ddc, you'll like [BetterDisplay](https://betterdisplay.pro) even better!

If you need a complete Swift implementation for DDC control on Apple Silicon macs, you can take a look at [AppleSiliconDDC]([https://github.com/MonitorControl/MonitorControl/blob/master/MonitorControl/Support/Arm64DDC.swift](https://github.com/waydabber/AppleSiliconDDC)) which is a complete self contained library I made for BetterDisplay (note: some features and M1 HDMI support is missing from the open source code) and MonitorControl.

## Thanks

Thanks to [@tao-j](https://github.com/tao-j) [@alin23](https://github.com/alin23), [@ybbond](https://github.com/ybbond)

Enjoy!
