#!/usr/bin/env bash
set -euo pipefail
install -d /usr/share/wayland-sessions/_disabled
if [ -f /usr/share/wayland-sessions/hyprland-uwsm.desktop ]; then
  mv -f /usr/share/wayland-sessions/hyprland-uwsm.desktop /usr/share/wayland-sessions/_disabled/hyprland-uwsm.desktop
fi
cat > /usr/share/wayland-sessions/hyprland-jakoolit.desktop <<'EODESK'
[Desktop Entry]
Name=Hyprland (JaKooLit)
Comment=Stable main Hyprland session
Exec=/usr/bin/start-hyprland
Type=Application
DesktopNames=Hyprland
Keywords=tiling;wayland;compositor;
EODESK
cat > /usr/share/wayland-sessions/hyprland.desktop <<'EODESK'
[Desktop Entry]
Name=default-hyprland
Comment=Default Hyprland session
Exec=/usr/bin/start-hyprland
Type=Application
DesktopNames=Hyprland
Keywords=tiling;wayland;compositor;
EODESK
chmod 644 /usr/share/wayland-sessions/hyprland-jakoolit.desktop /usr/share/wayland-sessions/hyprland.desktop
