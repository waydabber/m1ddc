# m1ddc

This little tool controls external displays using DDC/CI on Apple Silicon Macs, including displays connected through USB-C/DisplayPort Alt Mode and supported built-in HDMI ports. Useful to embed in various scripts.

For a much more advanced CLI solution check out [BetterDisplay's CLI capabilities](https://github.com/waydabber/BetterDisplay/wiki/Integration-features,-CLI).

> [!WARNING]
> Please note that this tool does not support Intel Macs. You can use [BetterDisplay](https://github.com/waydabber/BetterDisplay#readme) for free DDC control on all Macs and all ports.

## Prerequisites

> [!NOTE]
> You need `clang` from Apple's Command Line Tools (installs automatically if not present).

## Installation

Build the CLI from the project directory and show its help.

```shell
make
./m1ddc
```

Run `make install` after `make` to install the binary in `/usr/local/bin`. The examples below use
`m1ddc` on your PATH. To run from the build directory, use `./m1ddc`.

For the static library and public header, run `make lib`. This creates `library/libm1ddc.a` and
`library/libm1ddc.h`. Use `make all` to build both the CLI and the library.

## Usage examples

```shell
# Set contrast to 5 on the default display
m1ddc set contrast 5
# Read the current brightness
m1ddc get luminance
# Set red gain to 90
m1ddc set red 90
# Decrease volume by 10
m1ddc chg volume -10
# List displays, then set volume to 50 on display 1
m1ddc display list
m1ddc display 1 set volume 50
# Switch the display with this UUID to DisplayPort 1
m1ddc display 10ACB8A0-0000-0000-1419-0104A2435078 set input 15
# Allow 80 ms for a reply when reading the current input
m1ddc --read-wait 80 get input
```

## Options

Put options before the command and any display selector. You can use them in either order.

| Option | Effect |
| --- | --- |
| `-v`, `--verbose` | Print which display is used. |
| `--read-wait ms` | Wait 1 to 1000 ms before reading a DDC reply. The default is 50 ms. Try a higher value if reads fail with `no valid reply`. |

## Available commands

```text
m1ddc [options] [display <selector>] <command> <control> [value]
m1ddc display list [all] [detailed]
m1ddc help
```

| Command | Result |
| --- | --- |
| `get <control>` | Print the current value as a number. For example, `get input` prints the selected input code. |
| `max <control>` | Print the maximum value reported by the display. |
| `set <control> <value>` | Write the supplied value directly and print `Writing N` on success. |
| `chg <control> <delta>` | Add the signed delta to the current value, clamp it between zero and the reported maximum, then write it. `Writing N` shows the value sent. Use `get` for a readback. |

`get` and `max` accept any control below when the display supports reading it. `chg` needs both
the current and maximum values and is useful for controls such as brightness or volume.
For `get`, `max` and `chg`, m1ddc makes up to four attempts to get a valid reply. If the display
replies `Unsupported VCP code`, it stops immediately. A failed read exits with status 1 and
`chg` skips the write.

### Controls

Aliases are case-sensitive. The display determines which controls and values it supports.

| Control | Alias | Values |
| --- | --- | --- |
| `luminance` | `l` | Brightness, usually 0 to 100. |
| `contrast` | `c` | Contrast, usually 0 to 100. |
| `red`, `green`, `blue` | `r`, `g`, `b` | Gain for each color channel, usually 0 to 100. |
| `volume` | `v` | Volume, usually 0 to 100. |
| `mute` | `m` | `on` or 1 mutes, `off` or 2 unmutes. |
| `standby` | `s` | Numeric power mode (VCP 0xD6). Supported modes vary by display. |
| `input` | `i` | Common input codes are DisplayPort 1 = 15, DisplayPort 2 = 16, HDMI 1 = 17, HDMI 2 = 18, USB-C = 27. |
| `input-alt` | `I` | Alternate input control on some LG displays. DisplayPort 1 = 208, DisplayPort 2 = 209, HDMI 1 = 144, HDMI 2 = 145, USB-C / DP 3 = 210. |
| `pbp` | `p` | PIP/PBP layout on some Dell displays (e.g. U3421W). Off = 0, small window = 33, large window = 34, 50/50 split = 36, 26/74 = 43, 74/26 = 44, 2x2 = 65. |
| `pbp-input` | `pi` | Secondary Dell PIP/PBP input. DisplayPort 1 = 15, DisplayPort 2 = 16, HDMI 1 = 17, HDMI 2 = 18, HDMI 1 + HDMI 2 + DisplayPort 1 = 15953. |
| `kvm` | `k` | Dell KVM. Set 1728 for USB 1–4 order or 65280 to switch to the next device on supported models. |
| `asus-kvm` | | USB upstream on supported ASUS displays (e.g. XG27UCDMG) with Auto KVM disabled. USB-B = 2, USB-C = 3. |

## Display selection

`display list` lists displays from the macOS scan, which checks up to eight online displays by default.
Use `display N` with a number from this list, starting at 1. Use `display list detailed` for
the attributes you can use to select a display by identifier. The list commands also accept
`l` for `list`, `a` for `all`, and `d` for `detailed`.

### Identification methods

Use `display <method>=<value>` to select a display. A bare UUID is equivalent to `uuid=<system_uuid>`.

| Method | Value |
| --- | --- |
| `id` | `<display_id>` |
| `uuid` | `<system_uuid>` (default) |
| `edid` | `<edid_uuid>` |
| `seid` | `<alphanumeric_serial>:<edid_uuid>` |
| `basic` | `<vendor>:<model>:<serial>` |
| `ext` | `<vendor>:<model>:<serial>:<manufacturer>:<alphanumeric_serial>:<product_name>` |
| `full` | `<vendor>:<model>:<serial>:<manufacturer>:<alphanumeric_serial>:<product_name>:<io_location>` |
| `serial` | `<alphanumeric_serial>` from the direct `display list all` scan |

### Displays showing another input

A monitor showing another computer can disappear from the macOS display list while its DDC link to the
Mac remains available. `display list all` scans up to eight external DDC services directly and reads
their EDID. Use `display list all detailed` for extra attributes. An entry marked
`no matching macOS display` means m1ddc could not match it to a display in the macOS scan.
For an example of this setup, see [issue #26](https://github.com/waydabber/m1ddc/issues/26).

**The two lists are numbered independently.** Always take the number for `display N` from
`display list`. To select an entry from `display list all`, use `display serial=<alphanumeric_serial>`
when the entry shows an EDID serial. If multiple entries report the same serial, the first match is used.

```shell
m1ddc display list all
# [1] PG32UCDM (S9LMQS102814)
# [2] PG32UCDM (SALMQS134621) - no matching macOS display
m1ddc display serial=SALMQS134621 get input
# 15
m1ddc display serial=SALMQS134621 set input 27
```

Whether a monitor accepts DDC/CI on an inactive input depends on the model. The ASUS PG32UCDM, for
example, can answer over USB-C. Try `get input` to see whether your monitor answers on that link.

## Example use in a script

Check out the following [hammerspoon](https://github.com/Hammerspoon/hammerspoon) script.

This script allows you to control the volume of your external Display' brightness, contrast and volume via DDC (if you use an M1 Mac) using [m1ddc](https://github.com/waydabber/m1ddc) and also control your Yamaha AV Receiver through network. The script listens to the standard Apple keyboard media keys and shos the standard macOS Brightness and Volume OSDs via uses [showosd](https://github.com/waydabber/showosd) :

https://gist.github.com/waydabber/3241fc146cef65131a42ce30e4b6eab7

## BetterDisplay

If you like m1ddc, you'll like [BetterDisplay](https://betterdisplay.pro) even better!

BetterDisplay's CLI documentation: https://github.com/waydabber/BetterDisplay/wiki/Integration-features,-CLI

## Raycast Extensions

If you use [Raycast](https://raycast.com), there are extensions available for both m1ddc and BetterDisplay:

- [Display Input Switcher](https://www.raycast.com/clins1994/display-input-switcher) — a GUI for m1ddc. It doesn't yet cover all m1ddc features — contributions are welcome via the [GitHub repository](https://github.com/clins1994/raycast-display-input-switcher) or through the [Raycast contribution guidelines](https://developers.raycast.com/basics/contribute-to-an-extension).
- [BetterDisplay](https://www.raycast.com/pascal_burkhard/betterdisplay) — a Raycast extension for interacting with BetterDisplay.

## Thanks

Thanks to [@tao-j](https://github.com/tao-j) [@alin23](https://github.com/alin23), [@ybbond](https://github.com/ybbond)

Enjoy!
