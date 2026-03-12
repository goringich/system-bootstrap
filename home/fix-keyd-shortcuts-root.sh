#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo /home/goringich/fix-keyd-shortcuts-root.sh" >&2
  exit 1
fi

install -d -m 755 /etc/keyd
cat > /etc/keyd/default.conf <<'EOF'
[ids]
*

[main]

[control]
# Keep common editing shortcuts working by physical key position
# even when the active layout is Russian.
a = macro(C-a)
c = macro(C-c)
f = macro(C-f)
s = macro(C-s)
v = macro(C-v)
x = macro(C-x)
y = macro(C-y)
z = macro(C-z)
EOF

chmod 644 /etc/keyd/default.conf
systemctl enable --now keyd.service
systemctl restart keyd.service

echo "Installed /etc/keyd/default.conf and restarted keyd.service"
