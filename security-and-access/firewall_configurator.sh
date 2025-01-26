#!/bin/bash
# Script: firewall_configurator.sh
# Description: Configure basic firewall rules using UFW.

# Function to display usage instructions
usage() {
    echo "Usage: $0 [additional_ports]"
    echo "Example: $0 8080 3306"
    exit 1
}

# Check if UFW is installed
if ! command -v ufw &> /dev/null; then
    echo "UFW is not installed. Please install it and try again."
    exit 1
fi

# Check if the correct number of arguments is provided
if [ "$#" -gt 0 ]; then
    ADDITIONAL_PORTS=("$@")
else
    ADDITIONAL_PORTS=()
fi

# Function to log messages
log_message() {
    local MESSAGE=$1
    echo "$MESSAGE"
}

# Configure firewall rules
log_message "Configuring firewall rules..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https

# Allow additional ports if specified
for port in "${ADDITIONAL_PORTS[@]}"; do
    ufw allow "$port"
    log_message "Allowed port $port"
done

ufw enable

log_message "Firewall configuration completed."
