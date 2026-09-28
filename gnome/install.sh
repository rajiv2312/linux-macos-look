#!/usr/bin/env bash
# Linux, dressed as macOS: EXPERIMENTAL installer for regular Ubuntu 26.04 (GNOME)
#
# The Lubuntu version (../lubuntu/install.sh) is the one used on the author's machine.
# GNOME is built differently, so this version gets the same look with GNOME's own parts:
#   - WhiteSur GTK + GNOME Shell theme (light), WhiteSur icons, McMojave cursors, Inter font
#   - Ubuntu Dock moved to the bottom, auto-hiding, Mac-sized, with Trash
#   - traffic-light buttons on the left, Big Sur wallpaper, Mac-style clock
#   - "Launchpad" = GNOME's app grid, "Spotlight" = GNOME search (press Super)
# NOT TESTED on real hardware yet. Every setting is backed up first; undo with the restore.sh it prints.
# Not affiliated with Apple. Themes by vinceliuice (WhiteSur, McMojave), see README.

set -euo pipefail
TS="$(date +%Y%m%d-%H%M%S)"; BK="$HOME/macos-look-backup/gnome-$TS"; WORK="$(mktemp -d)"; MT="$HOME/.local/share/macos-theme"
say(){ printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn(){ printf '\033[33m!! %s\033[0m\n' "$*"; }
trap 'rm -rf "$WORK"' EXIT

[ "$(id -u)" -ne 0 ] || { echo "Run as your normal user, not root."; exit 1; }
command -v gnome-shell >/dev/null || { echo "GNOME Shell not found. On Lubuntu use ../lubuntu/install.sh"; exit 1; }
. /etc/os-release; [ "${VERSION_ID:-}" = "26.04" ] || warn "Written for Ubuntu 26.04; you have ${PRETTY_NAME:-unknown}."
cat <<EOF
EXPERIMENTAL: macOS look for Ubuntu (GNOME). Not yet tested on a real machine.
Backup + restore script go to: $BK
EOF
read -rp "Continue? [y/N] " a; [[ "$a" =~ ^[Yy]$ ]] || exit 0
sudo -v

# every key we change: schema key value
DOCK=org.gnome.shell.extensions.dash-to-dock
SETTINGS=(
  "org.gnome.desktop.interface gtk-theme 'WhiteSur-Light'"
  "org.gnome.desktop.interface icon-theme 'WhiteSur'"
  "org.gnome.desktop.interface cursor-theme 'McMojave-cursors'"
  "org.gnome.desktop.interface font-name 'Inter 11'"
  "org.gnome.desktop.interface document-font-name 'Inter 11'"
  "org.gnome.desktop.interface color-scheme 'prefer-light'"
  "org.gnome.desktop.interface clock-show-weekday true"
  "org.gnome.desktop.interface clock-show-date true"
  "org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'"
  "org.gnome.desktop.wm.preferences titlebar-font 'Inter Bold 11'"
  "org.gnome.desktop.background picture-uri 'file://$MT/whitesur-light-wallpaper.jpg'"
  "org.gnome.desktop.background picture-uri-dark 'file://$MT/whitesur-dark-wallpaper.jpg'"
  "org.gnome.desktop.background picture-options 'zoom'"
  "org.gnome.desktop.screensaver picture-uri 'file://$MT/whitesur-light-wallpaper.jpg'"
  "$DOCK dock-position 'BOTTOM'"
  "$DOCK extend-height false"
  "$DOCK dock-fixed false"
  "$DOCK autohide true"
  "$DOCK intellihide true"
  "$DOCK dash-max-icon-size 48"
  "$DOCK show-trash true"
  "$DOCK show-mounts false"
  "$DOCK show-apps-at-top true"
  "$DOCK click-action 'minimize-or-previews'"
  "$DOCK running-indicator-style 'DOTS'"
  "$DOCK transparency-mode 'FIXED'"
  "$DOCK background-opacity 0.35"
  "$DOCK custom-theme-shrink true"
)

# ---------------------------------------------------------------- backup + restore.sh
say "Backing up"
mkdir -p "$BK/files"; : > "$BK/gsettings.txt"; : > "$BK/manifest.txt"
for line in "${SETTINGS[@]}"; do read -r schema key _ <<< "$line"
  cur="$(gsettings get "$schema" "$key" 2>/dev/null)" && echo "$schema $key $cur" >> "$BK/gsettings.txt" || true; done
echo "org.gnome.shell enabled-extensions $(gsettings get org.gnome.shell enabled-extensions)" >> "$BK/gsettings.txt"
for p in .config/gtk-4.0 .config/gtk-3.0/settings.ini .local/share/macos-theme; do
  if [ -e "$HOME/$p" ]; then mkdir -p "$BK/files/$(dirname "$p")"; cp -a "$HOME/$p" "$BK/files/$p"; echo "EXISTED $p" >> "$BK/manifest.txt"; else echo "ABSENT $p" >> "$BK/manifest.txt"; fi
done
cat > "$BK/restore.sh" <<'RESTORE'
#!/usr/bin/env bash
set -uo pipefail
B="$(cd "$(dirname "$0")" && pwd)"
while read -r state p; do
  if [ "$state" = EXISTED ]; then rm -rf -- "$HOME/$p"; mkdir -p "$(dirname "$HOME/$p")"; cp -a "$B/files/$p" "$HOME/$p"
  elif [ -e "$HOME/$p" ]; then rm -rf -- "$HOME/$p"; fi
done < "$B/manifest.txt"
while read -r schema key value; do gsettings set "$schema" "$key" "$value" 2>/dev/null; done < "$B/gsettings.txt"
gsettings reset org.gnome.shell.extensions.user-theme name 2>/dev/null
echo "Restored. Log out and back in. (Downloaded themes were left installed, unused.)"
RESTORE
chmod +x "$BK/restore.sh"

# ---------------------------------------------------------------- packages + themes
say "Installing packages"
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git sassc libgio-2.0-dev-bin libxml2-utils fonts-inter gnome-shell-extensions gnome-tweaks

fetch(){ git init -q "$3"; git -C "$3" fetch -q --depth 1 "https://github.com/vinceliuice/$1.git" "$2"; git -C "$3" checkout -q FETCH_HEAD; }
say "Downloading WhiteSur and McMojave (pinned versions)"
fetch WhiteSur-gtk-theme  d5782652d412137e26fb8ff55b55a5572e4c6995 "$WORK/gtk"
fetch WhiteSur-icon-theme 73d8040da51a9ed74e47c7366e7e9ff437601a5c "$WORK/icons"
fetch McMojave-cursors    7d0bfc1f91028191cdc220b87fd335a235ee4439 "$WORK/cursors"
fetch WhiteSur-kde        cf4df59ce91004f7ea39358b1b8ff917d5c329f7 "$WORK/kde"

say "Building themes"
( cd "$WORK/gtk" && ./install.sh -c light -l >/dev/null && ./install.sh -c dark >/dev/null )   # -l: also style GTK4/libadwaita apps
( cd "$WORK/icons" && ./install.sh >/dev/null )
( cd "$WORK/cursors" && ./install.sh >/dev/null )
mkdir -p "$MT"
cp "$WORK/kde/wallpaper/WhiteSur-light/contents/images/3840x2160.jpg" "$MT/whitesur-light-wallpaper.jpg"
cp "$WORK/kde/wallpaper/WhiteSur-dark/contents/images/3840x2160.jpg"  "$MT/whitesur-dark-wallpaper.jpg"

# ---------------------------------------------------------------- apply
say "Applying settings"
for line in "${SETTINGS[@]}"; do read -r schema key value <<< "$line"
  gsettings set "$schema" "$key" "$value" 2>/dev/null || warn "skipped $schema $key (not available on this system)"; done

UT=user-theme@gnome-shell-extensions.gcampax.github.com
gnome-extensions enable "$UT" 2>/dev/null || warn "could not enable the User Themes extension (log out/in, then enable it in Extensions)"
UTS=/usr/share/gnome-shell/extensions/$UT/schemas
gsettings --schemadir "$UTS" set org.gnome.shell.extensions.user-theme name 'WhiteSur-Light' 2>/dev/null \
  || warn "set the shell theme to WhiteSur-Light in GNOME Tweaks > Appearance > Shell"

say "Done"
cat <<EOF

  Log out and back in.
  macOS equivalents:  Launchpad = "Show Apps" in the dock   Spotlight = press Super and type
  Undo:  $BK/restore.sh

EOF
