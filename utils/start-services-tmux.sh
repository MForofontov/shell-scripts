#!/bin/bash
# start-services-tmux.sh
# Script to start PostgreSQL, React, and Django services in separate tmux windows, and check if they are running

# Check if the correct number of arguments is provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <react_dir> <django_dir> <tmux_session_name>"
    exit 1
fi

# Get the React directory, Django directory, and tmux session name from the arguments
REACT_DIR="$1"
DJANGO_DIR="$2"
SESSION="$3"

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
    tmux send-keys -t "$SESSION:1" "cd $REACT_DIR && npm start" C-m
    if [ $? -ne 0 ]; then
        echo "Error: Failed to start React application."
        exit 1
    fi
    echo "React application started successfully."
fi

# Create a new window for Django
tmux new-window -t "$SESSION:2" -n 'Django'
echo -n "Checking Django application... "
if is_running "manage.py runserver"; then
    echo "Django application is already running."
else
    echo "Starting Django application..."
    tmux send-keys -t "$SESSION:2" "cd $DJANGO_DIR && python manage.py runserver" C-m
    if [ $? -ne 0 ]; then
        echo "Error: Failed to start Django application."
        exit 1
    fi
    echo "Django application started successfully."
fi

# Attach to the tmux session
tmux attach-session -t "$SESSION"