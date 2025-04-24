# m1ddc

This little tool controls external displays (connected via USB-C/DisplayPort Alt Mode) using DDC/CI on Apple Silicon Macs. Useful to embed in various scripts.

For a much more advanced CLI solution check out [BetterDisplay's CLI capabilities](https://github.com/waydabber/BetterDisplay/wiki/Integration-features,-CLI).

> [!WARNING]
> Please note that this tool does not support the built-in HDMI port of M1 and entry level M2 Macs. This tool does not support Intel Macs. You can use [BetterDisplay](https://github.com/waydabber/BetterDisplay#readme) for free DDC control on all Macs and all ports.

## Prerequisites

> [!NOTE]
> You need `clang` from Apple's Command Line Tools (installs automatically if not present).

## Installation

After download, enter (in Terminal):
```shell
make
```

You can then run the app by entering:
```shell
./m1ddc [options]
```

## Usage examples

```shell
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

## Available commands

```shell
 set luminance n         - Sets luminance (brightness) to n, where n is a number between 0 and the maximum value (usually 100).
     contrast n          - Sets contrast to n, where n is a number between 0 and the maximum value (usually 100).
     (red,green,blue) n  - Sets selected color channel gain to n, where n is a number between 0 and the maximum value (usually 100).
     volume n            - Sets volume to n, where n is a number between 0 and the maximum value (usually 100).
     input n             - Sets input source to n, common values include:
                           DisplayPort 1: 15, DisplayPort 2: 16, HDMI 1: 17, HDMI 2: 18, USB-C: 27.
     input-alt n         - Sets input source to n (using alternate addressing, as used by LG), common values include:
                           DisplayPort 1: 208, DisplayPort 2: 209, HDMI 1: 144, HDMI 2: 145, USB-C / DP 3: 210.

     mute on             - Sets mute on (you can use 1 instead of 'on')
     mute off            - Sets mute off (you can use 2 instead of 'off')

     pbp n               - Switches PIP/PBP on certain Dell screens (e.g. U3421W), possible values:
                           off: 0, small window: 33, large window: 34, 50/50 split: 36, 26/74 split: 43, 74/26 split: 44.
     pbp-input n         - Sets second PIP/PBP input on certain Dell screens, possible values:
                           DisplayPort 1: 15, DisplayPort 2: 16, HDMI 1: 17, HDMI 2: 18.
     kvm n               - Sets KVM order on certain Dell screens, possible values: TBD.
     kvm-switch          - Moves KVM to the next device on some Dells.

 get luminance           - Returns current luminance (if supported by the display).
     contrast            - Returns current contrast (if supported by the display).
     (red,green,blue)    - Returns current color gain (if supported by the display).
     volume              - Returns current volume (if supported by the display).

 max luminance           - Returns maximum luminance (if supported by the display, usually 100).
     contrast            - Returns maximum contrast (if supported by the display, usually 100).
     (red,green,blue)    - Returns maximum color gain (if supported by the display, usually 100).
     volume              - Returns maximum volume (if supported by the display, usually 100).

 chg luminance n         - Changes luminance by n and returns the current value (requires current and max reading support).
     contrast n          - Changes contrast by n and returns the current value (requires current and max reading support).
     (red,green,blue) n  - Changes color gain by n and returns the current value (requires current and max reading support).
     volume n            - Changes volume by n and returns the current value (requires current and max reading support).

 display list [detailed] - Lists displays. If `detailed` is provided, prints display extended attributes.
         n               - Chooses which display to control (use number 1, 2 etc.)
         (method=)<id>   - Chooses which display to control using the number using a specific identification method. (If not set, it defaults to `uuid`).
                           Possible values for `method` are:
                           'id':    <display_id>
                           'uuid':  <system_uuid>  *Default
                           'edid':  <edid_uuid>
                           'seid':  <alphnum_serial>:<edid_uuid>
                           'basic': <vendor>:<model>:<serial>
                           'ext':   <vendor>:<model>:<serial>:<manufacturer>:<alphnum_serial>:<product_name>
                           'full':  <vendor>:<model>:<serial>:<manufacturer>:<alphnum_serial>:<product_name>:<io_location>
```

> [!TIP]
> You can also use 'l', 'v' instead of 'luminance', 'volume' etc.


## Identification methods

The following display identification methods are supported, and corresponds to the following strings

|Method|Related display attributes|
|--:|:--|
|`id`|`<display_id>`|
|`uuid`|`<system_uuid>`|
|`edid`|`<edid_uuid>`|
|`seid`|`<alphnum_serial>:<edid_uuid>`|
|`basic`|`<vendor>:<model>:<serial>`|
|`ext`|`<vendor>:<model>:<serial>:<manufacturer>:<alphnum_serial>:<product_name>`|
|`full`|`<vendor>:<model>:<serial>:<manufacturer>:<alphnum_serial>:<product_name>:<io_location>`|

> [!TIP]
> Corresponding display attributes can be obtained using the `display list detailed` command

## Example use in a script

Check out the following [hammerspoon](https://github.com/Hammerspoon/hammerspoon) script.

This script allows you to control the volume of your external Display' brightness, contrast and volume via DDC (if you use an M1 Mac) using [m1ddc](https://github.com/waydabber/m1ddc) and also control your Yamaha AV Receiver through network. The script listens to the standard Apple keyboard media keys and shos the standard macOS Brightness and Volume OSDs via uses [showosd](https://github.com/waydabber/showosd) :

https://gist.github.com/waydabber/3241fc146cef65131a42ce30e4b6eab7

## BetterDisplay

If you like m1ddc, you'll like [BetterDisplay](https://betterdisplay.pro) even better!

BetterDisplay's CLI documentation: https://github.com/waydabber/BetterDisplay/wiki/Integration-features,-CLI

If you need a complete Swift implementation for DDC control on Apple Silicon macs, you can take a look at [AppleSiliconDDC](https://github.com/waydabber/AppleSiliconDDC) which is a complete self-contained library I made for BetterDisplay (note: some features and M1 HDMI support is missing from the open source code) and MonitorControl.

## Thanks

Thanks to [@tao-j](https://github.com/tao-j) [@alin23](https://github.com/alin23), [@ybbond](https://github.com/ybbond)

Enjoy!
