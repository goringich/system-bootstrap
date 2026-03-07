#!/bin/bash
# Auto-disable Docker bridge autoconnect in NetworkManager

echo "🔧 Disabling autoconnect for all Docker bridges"
echo "==============================================="

# Get all Docker bridge connections
docker_bridges=$(nmcli connection show | grep "bridge" | grep -E "docker|br-" | awk '{print $1}')

if [ -z "$docker_bridges" ]; then
    echo "✅ No Docker bridges found in NetworkManager"
    exit 0
fi

echo "Found Docker bridges:"
echo "$docker_bridges" | nl

# Disable autoconnect for each
echo -e "\nDisabling autoconnect..."
for bridge in $docker_bridges; do
    nmcli connection modify "$bridge" connection.autoconnect no 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "   ✅ $bridge"
    else
        echo "   ⚠️  Failed: $bridge"
    fi
done

echo -e "\n✅ Done! Docker bridges won't auto-connect on boot"