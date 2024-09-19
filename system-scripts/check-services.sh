#!/bin/bash
# check-services.sh
# Script to check if a list of services are running

# Configuration
SERVICES=("nginx" "apache2" "postgresql" "django" "react" "celery-worker")  # List of services to check

# Check each service
for SERVICE in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$SERVICE"; then
        echo "$SERVICE is running."
    else
        echo "$SERVICE is not running."
    fi
done
