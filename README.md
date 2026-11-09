# kiro-hyprland-caelestia

The **Kiro Hyprland (Caelestia) edition**: the Hyprland member of the KIROTUX Wayland line paired with the
**Caelestia** desktop shell. Public, open-core, shipped through the Kiro package repo (`nemesis_repo`).

Sibling to [kiro-hyprland-noctalia](https://github.com/kirodubes/kiro-hyprland-noctalia) and
[kiro-hyprland-dms](https://github.com/kirodubes/kiro-hyprland-dms).

## What it is

A ready-to-run Hyprland desktop configured the Kiro way: SUPER-based keybinds, Kiro app defaults, and the whole
shell (bar, launcher, dashboard, lock screen, notifications, OSD, wallpaper and a Material You colour scheme taken
from the wallpaper) provided by [Caelestia](https://github.com/caelestia-dots/shell) (GPL-3.0, by soramane and the
caelestia-dots contributors). Hyprland is only the compositor; the shell is driven through Hyprland global
shortcuts and the `caelestia` command.

This edition uses Kiro's own Hyprland config, not the Caelestia dotfiles. It never runs `caelestia install` or
`caelestia update`: updates come as normal package updates.

The edition is namespaced: its config lives in `~/.config/kiro-hyprland-caelestia/` and it ships its own login
entry, so it installs and runs **next to** the other Kiro editions without touching `~/.config/hypr/`.

## What it ships

- `etc/skel/.config/kiro-hyprland-caelestia/hyprland.lua`: the Hyprland config (Lua, 0.55+)
- `etc/skel/.config/kiro-hyprland-caelestia/scripts/firstrun-wallpaper.sh`: Kiro wallpaper + wallpaper-based scheme on the first login
- `etc/skel/.config/kiro-hyprland-caelestia/scripts/import-gsettings.sh`: mirrors the GTK theme into gsettings
- `etc/skel/.config/kiro-hyprland-caelestia/bg/kiro.jpg`: Kiro wallpaper
- `etc/skel/.config/kiro-hyprland-caelestia/keybindings.txt`: keybinding reference
- `etc/skel/.config/caelestia/shell.json` and `cli.json`: Kiro defaults for the shell and its CLI (apps, idle, wallpaper folder, theming targets)
- `usr/bin/kiro-hyprland-caelestia-session`: session wrapper (`Hyprland --config …`)
- `usr/share/wayland-sessions/kiro-hyprland-caelestia.desktop`: "Kiro Hyprland Caelestia" login entry
- `usr/lib/systemd/user/mako.service.d/kiro-hyprland-caelestia.conf`: keeps mako from taking the notifications in this session

## How to install

On a Kiro system (the package repo is already wired into `pacman.conf`):

```bash
sudo pacman -S kiro-hyprland-caelestia
```

Then log out and pick **Kiro Hyprland Caelestia** from your display manager.

## Keybindings

`SUPER` is the mod key. `SUPER + CTRL + S` opens the searchable keybinding cheatsheet (`kiro-keybindings`); the
full list is in [`keybindings.txt`](etc/skel/.config/kiro-hyprland-caelestia/keybindings.txt).

## Credits

The desktop shell is [Caelestia](https://github.com/caelestia-dots/shell) and its
[CLI](https://github.com/caelestia-dots/cli), both GPL-3.0.

<!-- KIRO-FUNDING-FOOTER:START — managed by Kiro-HQ/cascade-readme-footer.sh -->
## Help fund Kiro

Everything I build here stays free and open — always. If Kiro or any of these
tools have ever saved you time or taught you something, a small monthly
contribution helps keep the work going. Donations target break-even, nothing
more — the core always stays free for everyone.

- GitHub Sponsors: https://github.com/sponsors/erikdubois
- Patreon: https://www.patreon.com/c/kiroproject
- YouTube memberships: https://www.youtube.com/@ErikDubois/join
- Ko-fi: https://ko-fi.com/erikdubois
- PayPal: https://www.paypal.me/erikdubois
<!-- KIRO-FUNDING-FOOTER:END -->
