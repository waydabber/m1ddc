# m1ddc

This little tool controls external displays using DDC/CI on Apple Silicon Macs, including displays connected through USB-C/DisplayPort Alt Mode and supported built-in HDMI ports. Useful to embed in various scripts.

For a much more advanced CLI solution check out [BetterDisplay's CLI capabilities](https://github.com/waydabber/BetterDisplay/wiki/Integration-features,-CLI).

> [!WARNING]
> Please note that this tool does not support Intel Macs. You can use [BetterDisplay](https://github.com/waydabber/BetterDisplay#readme) for free DDC control on all Macs and all ports.

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
 set luminance n         - Sets luminance (brightness) to n, between 0 and the maximum value (usually 100).
     contrast n          - Sets contrast to n, between 0 and the maximum value (usually 100).
     (red|green|blue) n  - Sets the selected color-channel gain to n, between 0 and the maximum value (usually 100).
     volume n            - Sets volume to n, between 0 and the maximum value (usually 100).
     input n             - Sets the input source. Common values:
                           DisplayPort 1: 15, DisplayPort 2: 16, HDMI 1: 17, HDMI 2: 18, USB-C: 27.
     input-alt n         - Sets the input source using the alternate VCP code used by some LG displays. Common values:
                           DisplayPort 1: 208, DisplayPort 2: 209, HDMI 1: 144, HDMI 2: 145, USB-C / DP 3: 210.

     mute on|off         - Enables or disables mute. You can use 1 for on and 2 for off.

     pbp n               - Configures PIP/PBP on certain Dell displays (such as the U3421W). Known values:
                           Off: 0, small window: 33, large window: 34, 50/50 split: 36,
                           26/74 split: 43, 74/26 split: 44, 2x2: 65.
     pbp-input n         - Sets the secondary PIP/PBP input on certain Dell displays. Known values:
                           DisplayPort 1: 15, DisplayPort 2: 16, HDMI 1: 17, HDMI 2: 18,
                           HDMI 1 + HDMI 2 + DisplayPort 1: 15953.
     kvm n               - Controls the KVM on certain Dell displays. Known values:
                           KVM order for USB 1–4: 1728, switch to the next device: 65280.
     asus-kvm n          - Selects the USB upstream on certain ASUS displays (such as the XG27UCDMG)
                           when Auto KVM is disabled. Known values:
                           USB-B: 2, USB-C: 3.

 get luminance           - Returns the current luminance, if supported by the display.
     contrast            - Returns the current contrast, if supported by the display.
     (red|green|blue)    - Returns the current color-channel gain, if supported by the display.
     volume              - Returns the current volume, if supported by the display.

 max luminance           - Returns the maximum luminance, if supported by the display (usually 100).
     contrast            - Returns the maximum contrast, if supported by the display (usually 100).
     (red|green|blue)    - Returns the maximum color-channel gain, if supported by the display (usually 100).
     volume              - Returns the maximum volume, if supported by the display (usually 100).

 chg luminance n         - Changes luminance by n (requires current- and maximum-value reading support).
     contrast n          - Changes contrast by n (requires current- and maximum-value reading support).
     (red|green|blue) n  - Changes the selected color-channel gain by n (requires current- and maximum-value reading support).
     volume n            - Changes volume by n (requires current- and maximum-value reading support).

 display list [detailed] - Lists connected displays. With detailed, also prints extended display attributes.
         n               - Selects a display by its list number (1, 2, etc.).
         [method=]<id>   - Selects a display using an identifier. The default method is uuid.
                           Available identification methods:
                           id:    <display_id>
                           uuid:  <system_uuid>  (default)
                           edid:  <edid_uuid>
                           seid:  <alphanumeric_serial>:<edid_uuid>
                           basic: <vendor>:<model>:<serial>
                           ext:   <vendor>:<model>:<serial>:<manufacturer>:<alphanumeric_serial>:<product_name>
                           full:  <vendor>:<model>:<serial>:<manufacturer>:<alphanumeric_serial>:<product_name>:<io_location>
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

## Raycast Extensions

If you use [Raycast](https://raycast.com), there are extensions available for both m1ddc and BetterDisplay:

- [Display Input Switcher](https://www.raycast.com/clins1994/display-input-switcher) — a GUI for m1ddc. It doesn't yet cover all m1ddc features — contributions are welcome via the [GitHub repository](https://github.com/clins1994/raycast-display-input-switcher) or through the [Raycast contribution guidelines](https://developers.raycast.com/basics/contribute-to-an-extension).
- [BetterDisplay](https://www.raycast.com/pascal_burkhard/betterdisplay) — a Raycast extension for interacting with BetterDisplay.

## Thanks

Thanks to [@tao-j](https://github.com/tao-j) [@alin23](https://github.com/alin23), [@ybbond](https://github.com/ybbond)

Enjoy!
