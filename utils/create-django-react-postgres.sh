#!/bin/bash
# create-django-react.sh
# Script to create Django and React projects and a PostgreSQL database

# Check if the correct number of arguments is provided
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <django_project_name> <react_project_name> <db_name> <db_user> <db_password>"
    exit 1
fi

# Get the project names and database details from the arguments
DJANGO_PROJECT_NAME="$1"
REACT_PROJECT_NAME="$2"
DB_NAME="$3"
DB_USER="$4"
DB_PASSWORD="$5"

# Function to create Django project
create_django_project() {
    echo "Creating Django project..."

    # Check if Django is installed
    if ! command -v django-admin &> /dev/null; then
        echo "Django not found. Installing Django..."
        pip install django
    fi

    # Create Django project
    django-admin startproject "$DJANGO_PROJECT_NAME"
    echo "Django project '$DJANGO_PROJECT_NAME' created."
}

# Function to create React project
create_react_project() {
    echo "Creating React project..."

    # Check if npm is installed
    if ! command -v npm &> /dev/null; then
        echo "npm not found. Installing the latest Node.js..."

        # Install Node.js using NodeSource setup script
        curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
        sudo apt-get install -y nodejs

        # Verify installation
        if ! command -v npm &> /dev/null; then
            echo "Failed to install Node.js. Please install it manually."
            exit 1
        fi

        echo "Node.js installed successfully."
    fi

    # Create React project
    npx create-react-app "$REACT_PROJECT_NAME"
    echo "React project '$REACT_PROJECT_NAME' created."
}

# Function to create PostgreSQL database
create_postgresql_database() {
    echo "Creating PostgreSQL database..."

    # Check if PostgreSQL is installed
    if ! command -v psql &> /dev/null; then
        echo "PostgreSQL not found. Installing PostgreSQL..."
        sudo apt-get update
        sudo apt-get install -y postgresql postgresql-contrib
    fi

    # Start PostgreSQL service
    sudo systemctl start postgresql

    # Create the database and user
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

    echo "PostgreSQL database '$DB_NAME' and user '$DB_USER' created."
}

# Create Django project
create_django_project

# Create React project
create_react_project

# Create PostgreSQL database
create_postgresql_database

echo "Django, React projects, and PostgreSQL database have been successfully created."
echo "Django project: $DJANGO_PROJECT_NAME"
echo "React project: $REACT_PROJECT_NAME"
echo "PostgreSQL database: $DB_NAME"
echo ""

# Print instructions to configure Django settings
echo "To configure your Django project to use the PostgreSQL database, follow these steps:"
echo "1. Open the settings.py file in your Django project ($DJANGO_PROJECT_NAME/$DJANGO_PROJECT_NAME/settings.py)."
echo "2. Update the DATABASES setting to use PostgreSQL:"
echo "   DATABASES = {"
echo "       'default': {"
echo "           'ENGINE': 'django.db.backends.postgresql',"
echo "           'NAME': '$DB_NAME',"
echo "           'USER': '$DB_USER',"
echo "           'PASSWORD': '$DB_PASSWORD',"
echo "           'HOST': 'localhost',"
echo "           'PORT': '5432',"
echo "       }"
echo "   }"
echo "3. Configure React app to communicate with Django backend using Axios or Django REST framework."
