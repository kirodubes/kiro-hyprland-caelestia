# Changelog

## 2026.11.09

### What Changed
- Initial config package for the **Kiro Hyprland (Caelestia) edition**, the shell for the coming KiroTux Hyprland
  Caelestia ISO. Kiro's own Hyprland Lua config (taken from kiro-hyprland-noctalia, same keys and look) with the
  Caelestia shell from caelestia-dots instead of noctalia.
- First login: the Kiro wallpaper, and Caelestia's dynamic scheme so the bar, launcher, GTK apps and terminals take
  their colours from the wallpaper (dark mode kept).
- Kiro defaults for the shell: alacritty, pavucontrol, VLC and Thunar as its apps; screen off after 15 minutes and
  no lock on idle (Caelestia's own default locks after 3 minutes and suspends after 10); the wallpaper picker lists
  `/usr/share/backgrounds/kiro`.
- New keys: `SUPER + N` notifications sidebar, `SUPER + ALT + V` clipboard history, `SUPER + CTRL + ALT + R`
  restart Caelestia. `SUPER + SHIFT + W` picks a random Kiro wallpaper (Caelestia has no call that opens its picker;
  type `>wallpaper` in the launcher).

### Technical Details
- Shell actions go through Hyprland global shortcuts, `hl.dsp.global("caelestia:<name>")` (launcher, dashboard,
  nexus, lock, sidebar, mediaToggle/Next/Prev, brightnessUp/Down), as upstream's own `keybinds.lua` does. Wallpaper,
  scheme, clipboard and restart use the `caelestia` CLI.
- Caelestia brings no polkit agent: `polkit-gnome` is started at login. `cliphist` watchers are started for
  `caelestia clipboard`.
- `~/.config/caelestia/cli.json`: `enableHypr` off (the Kirotux premium app owns Hyprland colours through
  `appearance.lua`), Qt off (Kiro uses Kvantum), Chromium policies off (writes to `/etc`), app themes for programs
  Kiro doesn't ship off; `iconTheme` = Surfn, or the CLI would set Papirus.
- `wallpaper -N` everywhere: without it the CLI switches light/dark from the picture.
- mako drop-in with an `ExecCondition` on this session (impasto pattern): mako's D-Bus activation would otherwise
  take `org.freedesktop.Notifications` before Caelestia is up.
- Depends on `caelestia-shell`, `caelestia-cli` (AUR, carried in KIRO-PKG-BUILD-3PARTY → nemesis_repo) and
  `quickshell` from extra (caelestia-shell 2.5.0's pinned quickshell commit is inside the 0.3.2 tag).

### Files Modified
- New repo: `etc/skel/.config/kiro-hyprland-caelestia/` (hyprland.lua, keybindings.txt, bg/, scripts/),
  `etc/skel/.config/caelestia/{shell,cli}.json`, `usr/bin/kiro-hyprland-caelestia-{session,hide-upstream-session}`,
  `usr/share/wayland-sessions/kiro-hyprland-caelestia.desktop`, `usr/share/libalpm/hooks/`,
  `usr/lib/systemd/user/mako.service.d/kiro-hyprland-caelestia.conf`, README.md, CLAUDE.md, CHANGELOG.md, up.sh,
  setup.sh, kiro.jpg, .gitignore
