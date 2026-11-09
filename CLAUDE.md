# kiro-hyprland-caelestia — Claude project instructions

## Overview
Config package for the **Kiro Hyprland (Caelestia) edition**: the Hyprland member of the KIROTUX Wayland line
paired with the Caelestia shell (sibling to [kiro-hyprland-noctalia](../kiro-hyprland-noctalia/CLAUDE.md) and
[kiro-hyprland-dms](../kiro-hyprland-dms/CLAUDE.md)). **Public, open-core**, shipped via `nemesis_repo`. The
evaluation, Gate 0 decisions and release state live in the internal
`Kiro-HQ/Kirotux/KIROTUX-HYPRLAND-CAELESTIA-RELEASE-PLAN.md` (+ `study-of-caelestia-hyprland.md`).

## Edition spec (the WM-variable matrix)
- **Compositor:** Hyprland. Config taken from kiro-hyprland-noctalia (same look and Kiro keys), shell swapped.
- **Config language:** Lua (`hl.*`, Hyprland 0.55+), one file `etc/skel/.config/kiro-hyprland-caelestia/hyprland.lua`.
  Kiro's own config, **not** upstream's dots (Gate 0 N.9, 2026-11-09).
- **Desktop shell:** `caelestia-shell` (Quickshell + compiled QML plugin): bar, launcher, dashboard, lock,
  notifications, OSD, wallpaper, Material You scheme. Driven by Hyprland global shortcuts
  `hl.dsp.global("caelestia:<name>")` and the `caelestia` CLI (`caelestia shell -s` lists the IPC calls).
- **Autostart:** `on_start(cmd)` on `hyprland.start`: env propagation, xdg-user-dirs, gsettings import, Kvantum
  default, polkit-gnome (Caelestia has no agent), cliphist watchers, `caelestia shell -d`, first-run wallpaper, the
  archiso-gated Calamares line.
- **Coexistence:** namespaced like every Hyprland edition (`~/.config/kiro-hyprland-caelestia/`, own session
  wrapper + `.desktop`, no `conflicts=`). `~/.config/caelestia/` is a fixed path owned by this package alone (only
  Caelestia edition).
- **Theming:** Caelestia's CLI owns the scheme: shell, GTK `gtk.css`/`thunar.css` + dconf colour-scheme, terminals,
  btop, fuzzel, cava. `cli.json` turns off Hyprland colours (the premium app owns them), Qt, Chromium policies and
  apps Kiro doesn't ship; `iconTheme` = Surfn. Kvantum stays the Qt style.
- **Packages:** `caelestia-shell`, `caelestia-cli`, `qt6-m3shapes-git`, `ttf-rubik-vf` are AUR packages carried in
  `~/KIRO-PKG-BUILD-3PARTY` (build in that order). `caelestia-shell` there carries a Kiro patch: `quickshell` from
  extra instead of `quickshell-git`. Never depend on `quickshell-git`.

## Patterns / gotchas
- **Never call `caelestia install` or `caelestia update`**: they update the system and install upstream's dots.
- `caelestia wallpaper` always with `-N`: without it the CLI switches light/dark from the picture.
- Caelestia's default idle = lock at 3 min, screen off at 5, suspend at 10. `shell.json` replaces the list with
  "screen off at 15 min" (Kiro rule: no idle lock by default). `shell.json` is not written atomically by the shell
  and unknown keys are dropped: keep it small, only keys that exist in the shell's `plugin/src/Caelestia/Config/*.hpp`.
- The launcher shortcut fires on key **release** (upstream binds a bare SUPER tap); our chords still work.
- No IPC opens the wallpaper picker (`>wallpaper` in the launcher); `SUPER + SHIFT + W` = random Kiro wallpaper.
- mako drop-in (`usr/lib/systemd/user/mako.service.d/`): check `busctl --user status org.freedesktop.Notifications`
  shows `qs` on every test.
- Never set `QS_CONFIG_PATH` (leaks into other Quickshell editions); Caelestia's config is `qs -c caelestia`.
- `hl.dsp.exec_cmd` (the `run()` helper) goes through `/bin/sh`; `hl.exec_cmd` in `on_start` execs argv.

## Keybindings
- Kiro SUPER scheme from kiro-hyprland-noctalia; Caelestia actions on the keys noctalia's had.
- `keybindings.txt` mirrors `hyprland.lua`: keep them in lockstep; a duplicate-chord scan must pass.

## Build / delivery
- Recipe `~/KIRO-PKG-BUILD-APPS/kiro-hyprland-caelestia/` (public, → `~/EDU/nemesis_repo/`); flow
  `flow-kiro-hyprland-caelestia`. Build the four 3PARTY packages first.
- Test in **QEMU** (plain virtio-vga + 3D) or on metal, not VirtualBox (Quickshell needs GL).
