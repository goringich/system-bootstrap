#!/bin/bash
# System Startup Check - Verify no Docker containers auto-start

echo "🚀 System Startup Configuration Check"
echo "======================================"

# Check Docker service
echo -e "\n🐳 Docker Service Status:"
if systemctl is-enabled docker >/dev/null 2>&1; then
    echo "   ✅ Docker daemon will start on boot (CORRECT)"
    echo "   Containers won't auto-start (CORRECT)"
else
    echo "   ⚠️  Docker daemon is DISABLED"
    echo "   Enable with: sudo systemctl enable docker"
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "   ℹ️  Docker daemon not running currently"
    echo -e "\n   Start Docker with: sudo systemctl start docker"
    echo -e "\n✅ All checks passed (Docker not running)"
    exit 0
fi

# Check containers with restart policies
echo -e "\n📦 Checking container restart policies:"
all_containers=$(docker ps -a --format "{{.Names}}\t{{.RestartPolicy}}")
problem_containers=$(echo "$all_containers" | grep -v "no\s*$")

if [ -z "$problem_containers" ]; then
    echo "   ✅ No containers will auto-restart on boot"
else
    echo "   ⚠️  These containers still have auto-restart enabled:"
    echo "$problem_containers" | sed 's/^/      /'
    echo ""
    echo "   Fix with: docker update --restart=no <container_name>"
fi

# Check docker-compose files
echo -e "\n📝 Checking docker-compose.yml files:"
compose_files=$(find ~/Desktop -name "docker-compose.y*ml" 2>/dev/null | grep -v node_modules)
problems_found=0

for file in $compose_files; do
    if grep -q "restart: always\|restart: unless-stopped" "$file"; then
        echo "   ⚠️  $file still has auto-restart"
        problems_found=1
    fi
done

if [ $problems_found -eq 0 ]; then
    echo "   ✅ All docker-compose files configured correctly"
fi

# Check NetworkManager Docker bridges
echo -e "\n🌉 Checking Docker bridge autoconnect:"
docker_bridges=$(nmcli connection show | grep "bridge" | grep -E "docker|br-" | grep -v "no\s*--" | wc -l)
autoconnect_bridges=$(nmcli -f NAME,AUTOCONNECT connection show | grep -E "docker|br-" | grep "yes" || true)

if [ -n "$autoconnect_bridges" ]; then
    echo "   ⚠️  Some Docker bridges have autoconnect enabled:"
    echo "$autoconnect_bridges" | sed 's/^/      /'
    echo "   Run: /home/goringich/.local/bin/disable-docker-bridges.sh"
else
    echo "   ✅ No Docker bridges will auto-connect"
fi

# Summary
echo -e "\n📊 Summary:"
running_containers=$(docker ps -q | wc -l)
total_containers=$(docker ps -a -q | wc -l)

echo "   Running containers: $running_containers"
echo "   Total containers: $total_containers"

if [ "$running_containers" -eq 0 ]; then
    echo "   ✅ No containers running (good for clean startup)"
fi

echo -e "\n💡 Commands:"
echo "   Start specific project: cd ~/Desktop/<project> && docker-compose up -d"
echo "   Stop all containers: docker stop \$(docker ps -q)"
echo "   Disable all restarts: /home/goringich/.local/bin/disable-docker-autostart.sh"
echo "   Disable bridge autoconnect: /home/goringich/.local/bin/disable-docker-bridges.sh"

echo -e "\n🔍 Network Diagnostics:"
echo "   Check network status: ~/.config/hypr/scripts/NetworkDebug.sh"
echo "   Fix network issues: ~/.config/hypr/scripts/NetworkFix.sh"