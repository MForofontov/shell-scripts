#!/bin/bash
# check-services.sh
# Script to check if a list of services are running

# Configuration
SERVICES=("nginx" "apache2" "postgresql" "django" "react" "celery-worker")  # List of services to check

# Function to check if a service is running
is_running() {
    local service_name=$1
    local pid
    pid=$(pgrep -f "$service_name")
    if [ -n "$pid" ]; then
        echo "$service_name is running with PID(s): $pid"
        return 0
    else
        echo "$service_name is not running"
        return 1
    fi
}

# Check each service
for service in "${SERVICES[@]}"; do
    is_running "$service"
done

# Check for any Celery worker
echo -n "Checking for any Celery worker... "
if pgrep -f "celery" > /dev/null; then
    echo "Celery worker is running."
else
    echo "No Celery worker is running."
fi
