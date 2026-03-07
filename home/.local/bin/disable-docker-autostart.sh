#!/bin/bash
# Disable Docker Container Auto-Restart on System Boot

echo "🔧 Disabling Docker container auto-restart on boot"
echo "===================================================="

# Find all docker-compose files
compose_files=$(find ~/Desktop -name "docker-compose.y*ml" 2>/dev/null | grep -v node_modules)

echo -e "\nFound docker-compose files:"
echo "$compose_files" | nl

echo -e "\n📝 Updating restart policies..."

# Backup and modify each file
for file in $compose_files; do
    echo -e "\n📄 Processing: $file"
    
    # Create backup
    cp "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
    echo "   ✅ Backup created"
    
    # Check if file has 'restart: always' or 'restart: unless-stopped'
    if grep -q "restart: always\|restart: unless-stopped" "$file"; then
        # Replace restart policies
        sed -i 's/restart: always/restart: "no"/g' "$file"
        sed -i 's/restart: unless-stopped/restart: "no"/g' "$file"
        echo "   ✅ Changed restart policy to 'no'"
    else
        echo "   ℹ️  No auto-restart policies found"
    fi
done

echo -e "\n🐳 Stopping all running containers..."
docker stop $(docker ps -q) 2>/dev/null || echo "No containers running"

echo -e "\n✅ Done! Docker containers will NOT auto-start on boot"
echo -e "\n💡 To start containers manually:"
echo "   cd ~/Desktop/<project>"
echo "   docker-compose up -d"
echo -e "\n💡 To restore old configuration:"
echo "   Find backup files: find ~/Desktop -name '*.backup.*'"