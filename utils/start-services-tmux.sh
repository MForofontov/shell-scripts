#!/bin/bash
# start-services-tmux.sh
# Script to start PostgreSQL, React, and Django services in separate tmux windows, and check if they are running

# Configuration
REACT_DIR="/path/to/react-app"       # Path to your React application directory
DJANGO_DIR="/path/to/django-app"     # Path to your Django application directory

# Function to check if a service is running
is_running() {
    local process_name=$1
    local pid
    pid=$(pgrep -f "$process_name")
    if [ -n "$pid" ]; then
        echo "Running with PID(s): $pid"
        return 0
    else
        echo "Not running"
        return 1
    fi
}

# Start tmux session
SESSION="dev-session"

# Create a new tmux session
tmux new-session -d -s "$SESSION"

# Check and start PostgreSQL
echo -n "Checking PostgreSQL... "
if is_running "postgres"; then
    echo "PostgreSQL is already running."
else
    echo "Starting PostgreSQL..."
    tmux rename-window -t "$SESSION:0" 'PostgreSQL'
    tmux send-keys -t "$SESSION:0" 'sudo systemctl start postgresql' C-m
    if [ $? -ne 0 ]; then
        echo "Error: Failed to start PostgreSQL."
        exit 1
    fi
    echo "PostgreSQL started successfully."
fi

# Create a new window for React
tmux new-window -t "$SESSION:1" -n 'React'
echo -n "Checking React application... "
if is_running "react-scripts"; then
    echo "React application is already running."
else
    echo "Starting React application..."
    cd "$REACT_DIR" || { echo "Error: React directory not found."; exit 1; }
    tmux send-keys -t "$SESSION:1" 'npm start' C-m
    echo "React application started."
fi

# Create a new window for Django
tmux new-window -t "$SESSION:2" -n 'Django'
echo -n "Checking Django application... "
if is_running "manage.py runserver"; then
    echo "Django application is already running."
else
    echo "Starting Django application..."
    cd "$DJANGO_DIR" || { echo "Error: Django directory not found."; exit 1; }
    tmux send-keys -t "$SESSION:2" 'python manage.py runserver' C-m
    echo "Django application started."
fi

# Attach to tmux session
tmux attach -t "$SESSION"
