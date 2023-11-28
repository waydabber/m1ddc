# m1ddc

This little tool controls external displays (connected via USB-C/DisplayPort Alt Mode) using DDC/CI on Apple Silicon Macs. Useful to embed in various scripts.

> [!WARNING]
> Please note that this tool does not support the built-in HDMI port of M1 and entry level M2 Macs. This tool does not support Intel Macs. You can use [BetterDisplay](https://github.com/waydabber/BetterDisplay#readme) for free DDC control on all Macs and all ports.

## Prerequisites

> [!NOTE]
> You need `clang` from Apple's Command Line Tools (installs automatically if not present).

## Installation

After download, enter (in Terminal):
```bash
make
```

You can then run the app by entering:
```bash
./m1ddc
```

## Usage examples:

```bash
# Sets contrast to 5 on default display
m1ddc set contrast 5
# Returns current luminance ("brightness") on default display
m1ddc get luminance
# Sets red gain to 90
m1ddc set red 90
# Decreases volume by 10 on default display
m1ddc chg volume -10
# Lists displays
m1ddc display list
# Sets volume to 50 on Display 1
m1ddc display 1 set volume 50
# Sets input to DisplayPort 1 on display with UUID '10ACB8A0-0000-0000-1419-0104A2435078'
m1ddc display 10ACB8A0-0000-0000-1419-0104A2435078 set input 15`
```

## Commands:

|Command|Options|Arguments|Description|
|---:|---|---|---|
|`set`|`luminance`|`n`|Sets luminance ("brightness") to n, where n is a number between 0 and the maximum value (usually 100).|
||`contrast`|`n`|Sets contrast to n, where n is a number between 0 and the maximum value (usually 100).|
||`(red,green,blue)`|`n`|Sets selected color channel gain to n, where n is a number between 0 and the maximum value (usually 100).|
||`volume`|`n`|Sets volume to n, where n is a number between 0 and the maximum value (usually 100).|
||`input`|`n`|Sets input source to n. Common values include:<br/> - DisplayPort 1 = `15`<br/> - DisplayPort 2 = `16`<br/> - HDMI 1 = `17`<br/> - HDMI 2 = `18`<br/> - USB-C = `27`|
||`input-alt`|`n`|Sets input source to n (using alternate addressing, as used by LG). Common values include:<br/> - DisplayPort 1 = `208`<br/> - DisplayPort 2 = `209`<br/> - HDMI 1 = `144`<br/> - HDMI 2 = `145`<br/> - USB-C / DP 3 = `210`|
||`mute`|`(on,off)`|Sets mute on/off (you can use `1` instead of `on`, `2` insead of `off`).|
||`pbp`|`n`|Switches PIP/PBP on certain Dell screens (e.g. U3421WE). Possible values:<br/> - off = `0`<br/> - toggle window size = `1`<br/> - toggle window position = `2`<br/> - small window = `33`<br/> - large window = `34`<br/> - 50/50 split = `36`<br/> - 26/74 split = `43`<br/> - 74/26 split = `44`|
||`pbp-input`|`n`|Sets second PIP/PBP input on certain Dell screens. Possible values:<br/> - DisplayPort 1 = `15`<br/> - DisplayPort 2 = `16`<br/> - HDMI 1 = `17`<br/> - HDMI 2 = `18`|
|`get`|`luminance`||Returns current luminance (if supported by the display).|
||`contrast`||Returns current contrast (if supported by the display).|
||`(red,green,blue)`||Returns current color gain (if supported by the display).|
||`volume`||Returns current volume (if supported by the display).|
|`max`|`luminance`||Returns maximum luminance (if supported by the display, usually 100).|
||`contrast`||Returns maximum contrast (if supported by the display, usually 100).|
||`(red,green,blue)`||Returns maximum color gain (if supported by the display, usually 100).|
||`volume`||Returns maximum volume (if supported by the display, usually 100).|
|`display`|`list`|`[detailed]`|Lists displays. If `detailed`, prints display extended attributes.|
|`display`|`n`|`[detailed]`|Chooses which display to control using the index (1, 2 etc.) provided by `display list`.|
|`display`|`(method)=<identifier>`|`[detailed]`|Chooses which display to control using a specific identification method. (If not set, it defaults to `uuid`). _See [identications methods](#identification-methods) for more details._|

> [!TIP]
> You can also use 'l', 'v' instead of 'luminance', 'volume' etc.


## Identification methods

The following display identifcation methods are supported, and corresponds to the following strings

|Method|Related display attributes|
|--:|:--|
|`id`|`<display_id>`|
|`uuid`|`<system_uuid>`|
|`edid`|`<edid_uuid>`|
|`seid`|`<alphnum_serial>:<edid_uuid>`.|
|`basic`|`<vendor>:<model>:<serial>`.|
|`ext`|`<vendor>:<model>:<serial>:<manufacturer>:<alphnum_serial>:<product_name>`.|
|`full`|`<vendor>:<model>:<serial>:<manufacturer>:<alphnum_serial>:<product_name>:<io_location>`.|

> [!TIP]
> Corresponding display attributes can be obtained using the `display list detailed` command

## Example use in a script

Check out the following [hammerspoon](https://github.com/Hammerspoon/hammerspoon) script.

This script allows you to control the volume of your external Display' brightness, contrast and volume via DDC (if you use an M1 Mac) using [m1ddc](https://github.com/waydabber/m1ddc) and also control your Yamaha AV Receiver through network. The script listens to the standard Apple keyboard media keys and shos the standard macOS Birghtness and Volume OSDs via uses [showosd](https://github.com/waydabber/showosd) :

https://gist.github.com/waydabber/3241fc146cef65131a42ce30e4b6eab7

## BetterDisplay

If you like m1ddc, you'll like [BetterDisplay](https://betterdisplay.pro) even better!

If you need a complete Swift implementation for DDC control on Apple Silicon macs, you can take a look at [AppleSiliconDDC](https://github.com/waydabber/AppleSiliconDDC) which is a complete self contained library I made for BetterDisplay (note: some features and M1 HDMI support is missing from the open source code) and MonitorControl.

## Thanks

Thanks to [@tao-j](https://github.com/tao-j) [@alin23](https://github.com/alin23), [@ybbond](https://github.com/ybbond)

Enjoy!
