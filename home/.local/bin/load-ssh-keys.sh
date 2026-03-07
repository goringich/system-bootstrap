#!/bin/bash
# SSH Agent Key Loader
# Adds all SSH keys to the agent

SSH_AGENT_ENV_FILE="$HOME/.ssh-agent-env"

# Function to start SSH agent if not running
start_ssh_agent() {
    echo "Starting SSH agent..."
    ssh-agent -s > "$SSH_AGENT_ENV_FILE"
    source "$SSH_AGENT_ENV_FILE" > /dev/null
}

# Function to check if SSH agent is running
is_ssh_agent_running() {
    if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
        ssh-add -l >/dev/null 2>&1
        return $?
    fi
    return 1
}

# Load SSH agent environment if it exists
if [ -f "$SSH_AGENT_ENV_FILE" ]; then
    source "$SSH_AGENT_ENV_FILE" > /dev/null
fi

# Start SSH agent if not running
if ! is_ssh_agent_running; then
    start_ssh_agent
fi

# Add all SSH keys
echo "Adding SSH keys to agent..."
ssh_keys_added=0

for key in ~/.ssh/id_* ~/.ssh/*-key; do
    if [ -f "$key" ] && [ "${key##*.}" != "pub" ]; then
        echo "Adding key: $(basename "$key")"
        ssh-add "$key" 2>/dev/null
        if [ $? -eq 0 ]; then
            ((ssh_keys_added++))
        fi
    fi
done

echo "Successfully added $ssh_keys_added SSH keys to agent"

# List loaded keys
echo "Currently loaded keys:"
ssh-add -l