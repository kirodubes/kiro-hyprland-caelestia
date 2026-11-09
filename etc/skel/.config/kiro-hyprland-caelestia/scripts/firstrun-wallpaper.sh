#!/bin/sh
#####################################################################
# Author    : Erik Dubois
# Website   : https://kiroproject.be
#####################################################################
#   DO NOT JUST RUN THIS. EXAMINE AND JUDGE. RUN AT YOUR OWN RISK.
#
# Purpose:
#   On the FIRST login of the Kiro Hyprland (Caelestia) edition, set the
#   shipped Kiro wallpaper and switch Caelestia to its dynamic scheme, so
#   the bar, launcher, GTK apps and terminals take their colours from the
#   wallpaper. A stamp file makes it run exactly once.
# Why:
#   Caelestia starts with no wallpaper and a fixed scheme. The `caelestia`
#   CLI writes the wallpaper and scheme state files the shell watches, so
#   no IPC race with the starting shell. A wallpaper the user already has
#   (state file present) is kept. -N keeps dark mode: without it the CLI
#   picks light or dark from the picture.
#####################################################################

dir="$HOME/.config/kiro-hyprland-caelestia"
stamp="$dir/.firstrun-wallpaper-done"
wallpaper="$dir/bg/kiro.jpg"
state="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/wallpaper/path.txt"

[ -e "$stamp" ] && exit 0
command -v caelestia >/dev/null 2>&1 || exit 0

if [ ! -s "$state" ] && [ -f "$wallpaper" ]; then
    caelestia wallpaper -N -f "$wallpaper" || exit 0
fi
caelestia scheme set -n dynamic -m dark || exit 0
: > "$stamp"
