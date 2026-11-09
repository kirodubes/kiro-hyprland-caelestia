-- ════════════════════════════════════════════════════════════════════════
-- Kiro Hyprland (Caelestia) baseline config  (hyprland.lua)
-- ════════════════════════════════════════════════════════════════════════
-- Target: Hyprland 0.55+ (Lua config format; hyprlang/.conf deprecated in 0.55).
-- Lives at: ~/.config/kiro-hyprland-caelestia/hyprland.lua
--   Hyprland is pointed here by the kiro-hyprland-caelestia-session wrapper via
--   `Hyprland --config`, so this edition never touches ~/.config/hypr/ and can
--   coexist with the waybar-based kiro-hyprland edition on the same box.
--
-- Desktop shell: Caelestia (caelestia-shell on Quickshell, from nemesis_repo) — provides the
-- bar, launcher, dashboard, lock screen, notifications, OSD, wallpaper and the Material You
-- scheme taken from the wallpaper. Hyprland is only the compositor. The shell is driven
-- through Hyprland global shortcuts (hl.dsp.global("caelestia:<name>")) and the
-- `caelestia` CLI. It brings no polkit agent, so polkit-gnome is started below.
-- Upstream: https://github.com/caelestia-dots/shell (GPL-3.0).
--
-- Modeled on the mainline Hyprland Lua config, carrying Kiro's SUPER-based
-- keybind philosophy. Uses ONLY the native hl.* API (no o.* helper layer).
--
-- API reference: https://wiki.hypr.land/Configuring/Start/
-- Variables:     https://wiki.hypr.land/Configuring/Basics/Variables/
-- Window rules:  https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- ────────────────────────────────────────────────────────────────────────

local mod = "SUPER"

-- Kiro app defaults — adjust to the shipped Kiro toolset.
local term     = "alacritty"
local files    = "thunar"
local browser  = "firefox"
local editor   = "subl"                -- Sublime Text, the editor the ISO ships
local logout   = "archlinux-logout"   -- Kiro logout dialog (archlinux-logout-gtk4), as on the other editions
local keybindings = "kiro-keybindings"   -- searchable PySide6/QML cheatsheet (auto-detects Hyprland)

-- Default apps picked in Kirotux Hyprland Premium (kirotux_apps.lua in this folder), else the ones above.
-- Read here, before any key is bound, so the keys below open the chosen apps.
do
  local ok, apps = pcall(require, "kirotux_apps")
  if ok and type(apps) == "table" then
    term = apps.terminal or term
    files = apps.files or files
    browser = apps.browser or browser
    editor = apps.editor or editor
  end
end

-- Caelestia actions: global shortcuts the shell registers with Hyprland (caelestia:<name>).
local function caelestia(name) return hl.dsp.global("caelestia:" .. name) end
local launcher      = caelestia("launcher")
local controlcenter = caelestia("dashboard")
local settings      = caelestia("nexus")       -- Caelestia's own settings window
local lock          = caelestia("lock")
-- No IPC opens the wallpaper picker (type ">wallpaper " in the launcher for it); this key picks a
-- random Kiro wallpaper. -N keeps the light/dark mode: the wallpaper only recolours the scheme.
local wallpaper     = "caelestia wallpaper -N -r /usr/share/backgrounds/kiro"

-- ── Environment ──────────────────────────────────────────────────────────
-- Force Wayland across toolkits; advertise the session to portals/screenshare.
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_STYLE_OVERRIDE", "kvantum")   -- Qt style (was in /etc/environment)
-- Qt6 apps read their icon theme from the gtk3 platform theme, so app icons
-- follow the GTK/Surfn theme. Overrides the broken /etc/environment QT_QPA_PLATFORMTHEME=qt5ct
-- (qt5ct is Qt5 + not installed → Qt6 falls back to hicolor and app icons render as placeholders).
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("OZONE_PLATFORM", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- VM compatibility (VirtualBox/VMware): hardware cursors + hardware rendering are broken in
-- VMs. Without these, enabling VM "3D acceleration" black-screens Hyprland. Harmless on real
-- hardware (ALLOW_SOFTWARE only permits a fallback; it still uses the GPU when present).
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("WLR_RENDERER_ALLOW_SOFTWARE", "1")

-- ── Monitors & scaling ─────────────────────────────────────────────────────
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/  (`hyprctl monitors` to list).
-- Default: every output, preferred mode, auto position, scale 1 (good for 1080p/1440p).

-- Single Monitor
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Dual monitor
-- hl.monitor({
--     output = "desc:BNQ BenQ GW2780 K1M0156201Q",
--     mode = "1920x1080@60.0",
--     position = "2429x0",
--     scale = 1.0
-- })
-- hl.monitor({
--     output = "desc:BNQ BenQ GW2780 K1M0106301Q",
--     mode = "1920x1080@60.0",
--     position = "509x0",
--     scale = 1.0
-- })

hl.env("GDK_SCALE", "1")
-- HiDPI: bump both for crisp scaling, e.g.
--   retina 2x (13" 2.8K / 27" 5K):  scale = 2    + GDK_SCALE 2
--   27"/32" 4K (fractional):        scale = 1.6  + GDK_SCALE 1.75
-- Portrait/rotated secondary: add transform = 1 (90°) or 3 (270°) to the spec.

-- ── Look & feel ────────────────────────────────────────────────────────────
local active_border   = { colors = { "rgba(7aa2f7aa)", "rgba(c4a7e7aa)" }, angle = 45 }
local inactive_border = "rgba(414868aa)"

-- Keyboard: the layout picked in the installer (Calamares writes XKBLAYOUT / XKBVARIANT to
-- /etc/vconsole.conf), else the fallback below. Kirotux Hyprland Premium can override it in appearance.lua.
local function installer_keyboard(fallback)
  local f = io.open("/etc/vconsole.conf")
  if not f then return fallback, "" end
  local layout, variant
  for line in f:lines() do
    layout = layout or line:match('^XKBLAYOUT="?([^"]*)"?$')
    variant = variant or line:match('^XKBVARIANT="?([^"]*)"?$')
  end
  f:close()
  if not layout or layout == "" then return fallback, "" end
  return layout, variant or ""
end
local kb_layout, kb_variant = installer_keyboard("us,be")

hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 7,
    border_size = 2,
    col = {
      active_border = active_border,
      inactive_border = inactive_border,
    },
    layout = "master",            -- Kiro/ArcoLinux default; "dwindle" also available
    resize_on_border = true,
    extend_border_grab_area = 5,
    allow_tearing = false,
  },

  decoration = {
    rounding = 5,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
      color = "rgba(1a1a1aee)",
    },
    blur = {
      enabled = true,
      size = 3,
      passes = 1,
      vibrancy = 0.1696,
    },
    -- Inner glow on the focused window (0.55+) — Kiro blue accent; off when unfocused.
    glow = {
      enabled = true,
      range = 3,
      render_power = 3,
      color = "rgba(7aa2f7cc)",
      color_inactive = "rgba(00000000)",
    },
    -- Dim unfocused windows a little for focus contrast; dim more behind an open scratchpad
    -- so the popped-up window reads clearly on top.
    dim_inactive = true,
    dim_strength = 0.06,
    dim_special = 0.2,
  },

  dwindle = {
    preserve_split = true,
    -- pseudotile removed in 0.55 (was a no-op); use the `pseudo` dispatcher instead.
  },

  master = {
    new_status = "master",
    mfact = 0.5,
  },

  input = {
    kb_layout = kb_layout,                          -- installer choice, else US + Belgian
    kb_variant = kb_variant,
    kb_options = "grp:ctrls_toggle,compose:caps",  -- both Ctrl keys switch layouts (Alt+Shift stays free); Caps = Compose
    resolve_binds_by_sym = true,                    -- binds follow the active layout (Super+A = the A you see)
    repeat_rate = 40,
    repeat_delay = 600,
    follow_mouse = 1,
    numlock_by_default = true,
    sensitivity = 0,
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
      drag_lock = true,
      disable_while_typing = true,
    },
  },

  -- NOTE: the old `gestures { workspace_swipe }` keys were removed in Hyprland 0.51
  -- (replaced by the configurable `gesture` syntax). Swipe was disabled here, so the
  -- block is simply omitted. To enable touchpad workspace-swipe later, use a `gesture`.

  binds = {
    workspace_back_and_forth = true,
  },

  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    disable_watchdog_warning = true, -- we launch Hyprland --config directly (no start-hyprland wrapper)
    mouse_move_enables_dpms = true,
    key_press_enables_dpms = true,
    focus_on_activate = true,
    on_focus_under_fullscreen = 1, -- replaces 0.53-removed new_window_takes_over_fullscreen
  },

  cursor = {
    hide_on_key_press = true,
  },
})

-- ── Animations (bezier curves + per-leaf, 0.53+ style) ─────────────────────
hl.config({ animations = { enabled = true } })
hl.curve("kiroEase",      { type = "bezier", points = { { 0.05, 0.9 },  { 0.1, 1.05 } } })
hl.curve("kiroSnap",      { type = "bezier", points = { { 0.16, 1 },    { 0.3, 1 } } })
hl.curve("kiroOvershoot", { type = "bezier", points = { { 0.34, 1.56 }, { 0.64, 1 } } })
hl.animation({ leaf = "windows",          enabled = true, speed = 7,  bezier = "kiroEase" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 7,  bezier = "default",       style = "popin 80%" })
hl.animation({ leaf = "border",           enabled = true, speed = 10, bezier = "kiroSnap" })
hl.animation({ leaf = "fade",             enabled = true, speed = 7,  bezier = "default" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 6,  bezier = "kiroSnap",      style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5,  bezier = "kiroOvershoot",  style = "slidevert" })

-- ── Window rules (0.53+ unified hl.window_rule) ────────────────────────────
-- ArcoLinux windowrulev2 lines migrated to the table form.
hl.window_rule({ match = { class = "^(Spotify)$" }, tile = true })
-- "update" popup terminal (e.g. a yay-update helper):
hl.window_rule({ match = { class = "^(update)$", title = "^(update)$" }, float = true })
hl.window_rule({ match = { class = "^(update)$", title = "^(update)$" }, size = { "60%", "50%" } })
hl.window_rule({ match = { class = "^(update)$", title = "^(update)$" }, center = true })
-- Firefox picture-in-picture (kept handy, commented):
-- hl.window_rule({ match = { class = "^(firefox)$", title = "^(Picture-in-Picture)$" }, float = true })
-- Smooth touchpad scrolling in terminals (from nemesis input config):
hl.window_rule({ match = { class = "(Alacritty|kitty)" }, scroll_touchpad = 1.5 })
-- Transparent terminal — compositor opacity (works in VBox/QEMU/bare-metal alike; Hyprland's
-- blur frosts it). active/inactive: 0.90/0.85. btop gets its own, more transparent rule: its
-- keybindings start it as `alacritty --class btop`, which the "Alacritty" class would not match.
hl.window_rule({ match = { class = "^(Alacritty)$" }, opacity = "0.90 0.85" })
hl.window_rule({ match = { class = "^(btop)$" }, opacity = "0.80 0.75" })
-- Lock the pointer inside an app — handy for games / remote desktop (0.55+):
-- hl.window_rule({ match = { class = "^(steam_app_.*)$" }, confine_pointer = true })

-- ── Autostart ──────────────────────────────────────────────────────────────
-- exec-once equivalent: run on the hyprland.start event.
local function on_start(cmd) hl.on("hyprland.start", function() hl.exec_cmd(cmd) end) end

-- Propagate the Wayland session into systemd + dbus so portals / screenshare work.
on_start("dbus-update-activation-environment --systemd --all")
on_start("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
-- Create the XDG user dirs (Documents, Music, Pictures, …) on first login. This config doesn't
-- process /etc/xdg/autostart, so the xdg-user-dirs autostart never fires on its own. Idempotent.
on_start("xdg-user-dirs-update")
-- Mirror GTK theme/icons/cursor/font into gsettings (no xsettings daemon on Wayland).
on_start("~/.config/kiro-hyprland-caelestia/scripts/import-gsettings.sh")
on_start("kiro-kvantum-default")   -- Qt: KvGnomeDark (matches adw-gtk3-dark) unless the user picked an installed Kvantum theme
-- Polkit agent: Caelestia has none of its own.
on_start("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
-- Clipboard history for `caelestia clipboard` (SUPER + ALT + V).
on_start("wl-paste --type text --watch cliphist store")
on_start("wl-paste --type image --watch cliphist store")
-- The whole desktop: Caelestia (bar, launcher, dashboard, lock, notifications, OSD, wallpaper).
-- Never `caelestia update` / `caelestia install`: those update the system and install upstream's dots.
on_start("caelestia shell -d")
-- First login only: the Kiro wallpaper + a scheme that follows it.
on_start("~/.config/kiro-hyprland-caelestia/scripts/firstrun-wallpaper.sh")
-- Variety changes wallpapers (Alt + N/P/T/F); its set_wallpaper_kiro hands each one to `caelestia wallpaper`.
on_start("variety")
-- Live ISO only: auto-launch the installer. archiso-gated; kiro_final strips this line on install.
-- Wrapped in `sh -c` because hl.exec_cmd execs argv directly (no shell) — the `[ ]` test and `&&`
-- need a real shell to be interpreted; a bare string would just try to exec a binary named "[".
on_start("sh -c '[ -d /run/archiso/bootmnt ] && calamares_polkit -d -style kvantum'")

-- ── Keybinds ───────────────────────────────────────────────────────────────
-- bindd-style: every bind carries a description (shown by the keybindings viewer).
local function bind(keys, desc, dispatcher, opts)
  opts = opts or {}
  if desc then opts.description = desc end
  hl.bind(keys, dispatcher, opts)
end
local function run(cmd) return hl.dsp.exec_cmd(cmd) end

-- Apps & session
bind(mod .. " + Return",         "Terminal",          run(term))
bind(mod .. " + T",              "Terminal",          run(term))
bind(mod .. " + SHIFT + Return", "File manager",      run(files))
bind(mod .. " + SHIFT + F",      "File manager",      run(files))
bind(mod .. " + E",              "Code editor",       run(editor))
bind(mod .. " + SHIFT + N",      "Code editor",       run(editor))
bind(mod .. " + SHIFT + B",      "Browser",           run(browser))
bind(mod .. " + SHIFT + M",      "Spotify",           run("spotify"))
bind(mod .. " + CTRL + SHIFT + A", "AI agent",        run(term .. " -e claude"))
bind(mod .. " + D",              "App launcher",      launcher)
bind(mod .. " + Space",          "App launcher",      launcher)
bind(mod .. " + CTRL + Return",  "App launcher",      launcher)
bind(mod .. " + S",              "Dashboard",         controlcenter)
bind(mod .. " + SHIFT + S",      "Caelestia settings", settings)
bind(mod .. " + V",              "Volume control",    run("pavucontrol"))
bind(mod .. " + CTRL + A",       "Volume control",    run("pavucontrol"))
bind(mod .. " + O",              "Colour picker",     run("hyprpicker -a"))
bind(mod .. " + Q",              "Close window",      hl.dsp.window.close())
bind(mod .. " + SHIFT + Q",      "Close window",      hl.dsp.window.close())
bind(mod .. " + X",              "Logout menu",       run(logout))
bind(mod .. " + SHIFT + X",      "Logout menu",       run(logout))
bind(mod .. " + ALT + L",        "Lock screen",       lock)
bind(mod .. " + CTRL + L",       "Lock screen",       lock)
bind(mod .. " + SHIFT + W",      "Random wallpaper",  run(wallpaper))
bind(mod .. " + Escape",         "Kill mode",         run("hyprctl kill"))
bind(mod .. " + CTRL + S",       "Show keybindings",  run(keybindings))
bind(mod .. " + K",              "Show keybindings",  run(keybindings))
bind("CTRL + ALT + K",           "Logout menu",       run(logout))
bind(mod .. " + SHIFT + R",      "Reload Hyprland",   run("hyprctl reload"))
bind(mod .. " + CTRL + ALT + R", "Restart Caelestia", run("caelestia shell -k; caelestia shell -d"))
bind(mod .. " + N",              "Notifications sidebar", caelestia("sidebar"))
bind(mod .. " + ALT + V",        "Clipboard history", run("pkill fuzzel || caelestia clipboard"))

-- CTRL+ALT app launchers (Kiro scheme)
bind("CTRL + ALT + A",       "Alacritty tweak tool", run("alacritty-tweak-tool"))
bind("CTRL + ALT + B",       "Brave",           run("brave --password-store=basic"))
bind("CTRL + ALT + C",       "Chromium",        run("chromium -no-default-browser-check"))
bind("CTRL + ALT + D",       "OBS Studio",      run("obs"))
bind("CTRL + ALT + E",       "Tweak tool",      run("archlinux-tweak-tool"))
-- Kirotux Hyprland Premium comes with the KIROTUX ISOs: open it, or tell users of this free edition where it is.
bind("CTRL + ALT + H",       "Kirotux Hyprland Premium", run("kiro-premium-hint hyprland"))
bind("CTRL + ALT + F",       "Firefox",         run("firefox"))
bind("CTRL + ALT + G",       "Chromium",        run("chromium -no-default-browser-check"))
bind("CTRL + ALT + I",       "Kiro ISO builder", run("kiro-iso-builder"))
bind("CTRL + ALT + L",       "Logout settings", run("archlinux-logout --settings"))
bind("CTRL + ALT + M",       "USB image writer", run("mintstick -m iso"))
bind("CTRL + ALT + O",       "Opera",           run("opera"))
bind("CTRL + ALT + P",       "Package manager", run("pamac-manager"))
bind("CTRL + ALT + Q",       "Alacritty tweak tool", run("alacritty-tweak-tool"))
bind("CTRL + ALT + R",       "Lock screen",     lock)
bind("CTRL + ALT + Return",  "Terminal",        run(term))
bind("CTRL + ALT + T",       "Terminal",        run(term))
bind("CTRL + ALT + S",       "Tweak tool",      run("fish-tweak-tool"))
bind("CTRL + ALT + U",       "Volume control",  run("pavucontrol"))
bind("CTRL + ALT + V",       "Vivaldi",         run("vivaldi-stable"))
bind("CTRL + ALT + W",       "Fastfetch tweak tool", run("fastfetch-tweak-tool"))
bind("CTRL + ALT + Z",       "Fastfetch tweak tool", run("fastfetch-tweak-tool"))
bind("CTRL + ALT + END",     "System monitor",  run("alacritty --class btop -e btop"))
bind("CTRL + SHIFT + Escape","System monitor",  run("alacritty --class btop -e btop"))

-- Function keys (Kiro scheme)
bind(mod .. " + F1",  "Browser",      run(browser))
bind(mod .. " + F2",  "Code editor",  run(editor))
bind(mod .. " + F3",  "Inkscape",     run("inkscape"))
bind(mod .. " + F4",  "GIMP",         run("gimp"))
bind(mod .. " + F5",  "Meld",         run("meld"))
bind(mod .. " + F6",  "VLC",          run("vlc"))
bind(mod .. " + F7",  "VirtualBox",   run("virtualbox"))
bind(mod .. " + F8",  "File manager", run("thunar"))
bind(mod .. " + F9",  "Virt-manager", run("virt-manager"))
bind(mod .. " + F10", "Spotify",      run("spotify"))
bind(mod .. " + F11", "App launcher", launcher)
bind(mod .. " + F12", "App launcher", launcher)

-- Window management
bind(mod .. " + SHIFT + Space", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))
bind(mod .. " + F",             "Fullscreen",      hl.dsp.window.fullscreen({ mode = "fullscreen" }))
bind(mod .. " + ALT + F",       "Maximize",        hl.dsp.window.fullscreen({ mode = "maximized" }))
bind(mod .. " + P",             "Pseudo-tile",     hl.dsp.window.pseudo())
bind(mod .. " + J",             "Toggle split",    hl.dsp.layout("togglesplit"))
bind(mod .. " + G",             "Toggle group",    hl.dsp.group.toggle())

-- Master layout
bind(mod .. " + I",             "Add master",       hl.dsp.layout("addmaster"))
bind(mod .. " + CTRL + Space",  "Swap with master", hl.dsp.layout("swapwithmaster"))

-- Groups — pull the focused window into the group in that direction, creating one if needed (0.55+)
bind(mod .. " + CTRL + left",  "Into group left",  hl.dsp.window.move({ into_or_create_group = "l" }))
bind(mod .. " + CTRL + right", "Into group right", hl.dsp.window.move({ into_or_create_group = "r" }))
bind(mod .. " + CTRL + up",    "Into group up",    hl.dsp.window.move({ into_or_create_group = "u" }))
bind(mod .. " + CTRL + down",  "Into group down",  hl.dsp.window.move({ into_or_create_group = "d" }))

-- Focus
bind(mod .. " + left",  "Focus left",  hl.dsp.focus({ direction = "l" }))
bind(mod .. " + right", "Focus right", hl.dsp.focus({ direction = "r" }))
bind(mod .. " + up",    "Focus up",    hl.dsp.focus({ direction = "u" }))
bind(mod .. " + down",  "Focus down",  hl.dsp.focus({ direction = "d" }))

-- Move / swap window
bind(mod .. " + SHIFT + left",  "Swap left",  hl.dsp.window.swap({ direction = "l" }))
bind(mod .. " + SHIFT + right", "Swap right", hl.dsp.window.swap({ direction = "r" }))
bind(mod .. " + SHIFT + up",    "Swap up",    hl.dsp.window.swap({ direction = "u" }))
bind(mod .. " + SHIFT + down",  "Swap down",  hl.dsp.window.swap({ direction = "d" }))

-- Resize
bind(mod .. " + SHIFT + H", "Shrink width",  hl.dsp.window.resize({ x = -50, y = 0,  relative = true }))
bind(mod .. " + SHIFT + L", "Grow width",    hl.dsp.window.resize({ x = 50,  y = 0,  relative = true }))
bind(mod .. " + SHIFT + K", "Shrink height", hl.dsp.window.resize({ x = 0,   y = -50, relative = true }))
bind(mod .. " + SHIFT + J", "Grow height",   hl.dsp.window.resize({ x = 0,   y = 50,  relative = true }))

-- Mouse drag/resize
bind(mod .. " + mouse:272", "Move window",   hl.dsp.window.drag(),   { mouse = true })
bind(mod .. " + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })

-- Workspaces 1..10 — code: keys are layout-independent (qwerty AND azerty in ONE file).
for ws = 1, 10 do
  local key = "code:" .. tostring(ws + 9)            -- code:10 = "1" … code:19 = "0"
  bind(mod .. " + " .. key,         "Workspace " .. ws,         hl.dsp.focus({ workspace = tostring(ws) }))
  bind(mod .. " + CTRL + " .. key,  "Move to workspace " .. ws, hl.dsp.window.move({ workspace = tostring(ws) }))
  bind(mod .. " + SHIFT + " .. key, "Send to workspace " .. ws, hl.dsp.window.move({ workspace = tostring(ws), follow = false }))
end

-- Workspace cycling
bind(mod .. " + period",      "Next workspace",     hl.dsp.focus({ workspace = "e+1" }))
bind(mod .. " + comma",       "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
bind(mod .. " + mouse_down",  "Next workspace",     hl.dsp.focus({ workspace = "e+1" }))
bind(mod .. " + mouse_up",    "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
bind(mod .. " + TAB",         "Next workspace",     hl.dsp.focus({ workspace = "e+1" }))
bind(mod .. " + SHIFT + TAB", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))

-- Scratchpad (special workspace)
bind(mod .. " + U",         "Toggle scratchpad",  hl.dsp.workspace.toggle_special("scratchpad"))
bind(mod .. " + SHIFT + U", "Send to scratchpad", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

-- Media & brightness keys — Caelestia's OSD follows wireplumber; brightness and media go through
-- the shell (its own brightness service drives ddcutil/brightnessctl and shows the OSD).
bind("XF86AudioRaiseVolume",  "Volume up",      run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
bind("XF86AudioLowerVolume",  "Volume down",    run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
bind("ALT + XF86AudioRaiseVolume", "Volume up 1%",   run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+"))
bind("ALT + XF86AudioLowerVolume", "Volume down 1%", run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"))
bind("XF86AudioMute",         "Mute",           run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
bind("XF86AudioMicMute",      "Mic mute",       run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
bind("XF86AudioPlay",         "Play / pause",   caelestia("mediaToggle"), { locked = true })
bind("XF86AudioPause",        "Play / pause",   caelestia("mediaToggle"), { locked = true })
bind("XF86AudioNext",         "Next track",     caelestia("mediaNext"),   { locked = true })
bind("XF86AudioPrev",         "Previous track", caelestia("mediaPrev"),   { locked = true })
bind("XF86MonBrightnessUp",   "Brightness up",  caelestia("brightnessUp"),   { locked = true })
bind("XF86MonBrightnessDown", "Brightness down",caelestia("brightnessDown"), { locked = true })

-- Screenshots
-- kiro-screenshot (kiro-wayland-dotfiles): PNG in ~/Pictures/Screenshots + clipboard + notify.
bind("PRINT",           "Screenshot region", run("kiro-screenshot region"))
bind(mod .. " + PRINT", "Screenshot screen", run("kiro-screenshot screen"))

-- Variety (its set_wallpaper_kiro hands the picture to `caelestia wallpaper`, so the scheme follows)
bind("ALT + n", "Variety --next", run("variety -n"))
bind("ALT + p", "Variety --previous", run("variety -p"))
bind("ALT + t", "Variety --trash", run("variety -t"))
bind("ALT + f", "Variety --favorite", run("variety -f"))
-- Alt+Shift: the same commands, so the keys match the editions where Alt+Shift+N recolours.
bind("ALT + SHIFT + n", "Variety --next", run("variety -n"))
bind("ALT + SHIFT + p", "Variety --previous", run("variety -p"))
bind("ALT + SHIFT + t", "Variety --trash", run("variety -t"))
bind("ALT + SHIFT + f", "Variety --favorite", run("variety -f"))

-- ── Appearance overrides (keep these lines LAST) ─────────────────────────────
-- Kirotux Hyprland Premium writes your look to appearance.lua in this folder; it only
-- holds the values you changed there. No file = this edition's own look. Put your own
-- changes ABOVE these lines. pcall: a missing or broken file never breaks the session.
local ok, err = pcall(require, "appearance")
if not ok and not tostring(err):find("module 'appearance' not found", 1, true) then print("appearance.lua: " .. tostring(err)) end
