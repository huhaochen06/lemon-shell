# Lemon Shell

A Hyprland desktop shell built with [Quickshell](https://quickshell.outfoxxed.me). It is a fork of
[Caelestia Shell](https://github.com/caelestia-dots/shell) that carries over many features from
[MiDnight Shell](https://github.com/dim-ghub/midnight-shell), now unmaintained, and adds a dynamic
island, AirDrop and Wallpaper Engine playlists. It tracks Caelestia upstream.

## Features

On top of everything in Caelestia:

- **Dynamic island** in place of a dock. It shows live activities for media, screen recording,
  timers and stopwatches, Discord voice calls, Quick Share and AirDrop transfers, browser
  downloads, package updates, screenshots and polkit prompts, and quick banners for Bluetooth,
  network, battery, toggles and keyboard layout. Up to three activities run at once.
  Scripts can post to it too (see [Island scripting](#island-scripting)).
- **Sharing**: Quick Share with Android devices and AirDrop with iPhones (through
  [Owly](https://github.com/t4t5/owly)).
- **Wallpapers**: video, GIF and [Wallpaper Engine](https://github.com/Almamu/linux-wallpaperengine)
  wallpapers, with playlists (in order or shuffled, on a timer), Wallhaven search, recolouring
  to the colour scheme and dimming while tiled windows are open. Wallpaper Engine stops during
  game mode to free its VRAM.
- **Game mode** that disables Hyprland effects and shell transparency. It can turn on by itself
  when a window you list opens, for example `^steam_app_.*$` for Steam games.
- **Launcher**: emoji picker, clipboard history, window switcher with live previews, Hyprland
  keybind list and animation switcher.
- **Bar**: can sit on any edge, with peripheral battery status.
- **More**: workspace overview, custom polkit dialog, picture-in-picture
  window alignment, sound effects, Shimeji desktop pets, per-monitor settings and a
  settings app (Nexus) covering all of it.

## Installation

Lemon Shell installs into the same locations as Caelestia and MiDnight (`/etc/xdg/quickshell/caelestia`
and the `Caelestia` QML module), so remove `caelestia-shell` or `midnight-shell-git` first if
you have either installed.

### Dependencies

Required:

- [`quickshell-git`](https://git.outfoxxed.me/quickshell/quickshell) (the git version)
- [`midnight-cli`](https://github.com/dim-ghub/midnight-cli), MiDnight's fork of `caelestia-cli`,
  which some features need. Plain [`caelestia-cli`](https://github.com/caelestia-dots/cli) works for
  the rest.
- `qt6-base`, `qt6-declarative`, `qt6-multimedia`, `qt6-imageformats`,
  [`qt6-m3shapes-git`](https://github.com/soramanew/m3shapes)
- `ddcutil`, `brightnessctl`, `networkmanager`, `lm_sensors`, `power-profiles-daemon`
- `libcava`, `aubio`, `libpipewire`, `libqalculate`, `protobuf`, `openssl`
- `ttf-material-symbols-variable`, `ttf-rubik-vf`, `ttf-cascadia-code-nerd`
- `swappy`, `fish`, `bash`, `python`

Build: `cmake`, `ninja`, `qt6-shadertools`

Optional, for the features that use them:

| Package | Used for |
| --- | --- |
| `linux-wallpaperengine` | Wallpaper Engine wallpapers |
| `hyprpaper`, `python-pillow` | Keeping a still of the Wallpaper Engine wallpaper visible during game mode |
| `ffmpeg` | Video wallpaper thumbnails |
| `cliphist`, `wl-clipboard` | Clipboard history, emoji and calculator copying |
| `gpu-screen-recorder`, `slurp` | Screen recording |
| `owly` | AirDrop |
| `pacman-contrib`, `paru` or `yay` | Package update checks |
| `lua` | Keybind list in the launcher |
| `curl`, `unzip`, `libxml2` | Wallhaven, Shimeji packs, keyboard layouts |

### Building

```sh
git clone https://github.com/huhaochen06/lemon-shell.git
cd lemon-shell

cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/
cmake --build build
sudo cmake --install build
```

The version is taken from the latest Caelestia release tag, so the configure step needs network
access unless you pass `-DVERSION=x.y.z`.

To update, pull and run the build and install commands again.

### Running from source

To work on the shell, point Quickshell at your clone instead of the installed copy. The C++ plugin
still has to be installed, and reinstalled whenever you change anything under `plugin/`:

```sh
ln -s "$PWD" ~/.config/quickshell/caelestia
```

## Usage

Start the shell with `caelestia shell -d`, or `qs -c caelestia -n -d` without the CLI. To start it
with Hyprland:

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("caelestia shell -d")
end)
```

### Shortcuts

Everything is exposed as Hyprland global shortcuts named `caelestia:<name>`:

| Name | Action |
| --- | --- |
| `launcher` | Toggle the launcher |
| `dashboard` | Toggle the dashboard |
| `sidebar` | Toggle the sidebar |
| `utilities` | Toggle the utilities panel |
| `session` | Toggle the session menu |
| `showall` | Toggle the launcher, dashboard and OSD |
| `nexus` | Open the settings app |
| `emoji` | Open the emoji picker |
| `clipboard` | Open clipboard history |
| `windowSwitcher` | Open the window switcher |
| `wallpaper` | Open the wallpaper picker |
| `keybinds` | Open the keybind list |
| `workspaceOverview` | Toggle the workspace overview |

```lua
hl.bind("SUPER + V", hl.dsp.global("caelestia:clipboard"))
hl.bind("SUPER + Tab", hl.dsp.global("caelestia:windowSwitcher"))
```

IPC commands are available through `caelestia shell ...` or `qs -c caelestia ipc call ...`.
Run `qs -c caelestia ipc show` for the full list.

### Wallpaper Engine

Wallpaper Engine wallpapers from your Steam Workshop folder show up in the wallpaper picker.
`linux-wallpaperengine` renders on Hyprland's bottom layer. These layer rules keep the shell's
desktop overlays above it, and the Hyprpaper still below the shell's own wallpaper:

```lua
hl.layer_rule({ match = { namespace = "hyprpaper" }, order = 10 })
hl.layer_rule({ match = { namespace = "caelestia-background" }, order = -10 })
```

### Island scripting

`scripts/island` posts banners and live activities to the island:

```sh
island notify "Backup finished" "42 GB copied" -i backup
island run --title "Building" -- make -j8
rsync -a --info=progress2 src/ dst/ | island pipe backup "Backup"
```

Run `island --help` for everything else. For fish, link `scripts/fish/island.fish` into
`~/.config/fish/conf.d/` to get a banner whenever a long command finishes in a terminal you have
switched away from. Both are installed to `/etc/xdg/quickshell/caelestia/scripts/`.

## Configuration

Most settings are in Nexus, the settings app (`caelestia:nexus`). Everything is stored in
`~/.config/caelestia/shell.json`. Per-monitor overrides go in
`~/.config/caelestia/monitors/<output>/shell.json` and can also be edited from Nexus.

The desktop clock and the background visualiser follow Caelestia and are only configured in
`shell.json`:

```json
{
    "background": {
        "desktopClock": { "enabled": true },
        "visualiser": { "enabled": true, "autoHide": true }
    }
}
```

Wallpapers are read from `~/Pictures/Wallpapers` by default, which you can change with
`paths.wallpaperDir`.

## Credits

- [Caelestia Shell](https://github.com/caelestia-dots/shell) by soramane and contributors, which
  this shell is built on.
- [MiDnight Shell](https://github.com/dim-ghub/midnight-shell) by DiM and contributors, for many of
  the features listed above.
- [Quickshell](https://quickshell.outfoxxed.me) by outfoxxed.

## License

[GNU GPL version 3](LICENSE), as inherited from Caelestia. Bundled assets and fonts keep their own
license files.
