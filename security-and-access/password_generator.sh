#!/bin/bash
# Script: password_generator.sh
# Description: Generate strong, random passwords.

# Function to display usage instructions
usage() {
    echo "Usage: $0 [length]"
    echo "Example: $0 16"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -gt 1 ]; then
    usage
fi

# Get the password length from the arguments or prompt the user
if [ "$#" -eq 1 ]; then
    LENGTH="$1"
else
    echo "Enter the desired password length (e.g., 16): "
    read LENGTH
fi

# Validate the password length
if ! [[ "$LENGTH" =~ ^[0-9]+$ ]] || [ "$LENGTH" -le 0 ]; then
    echo "Error: Password length must be a positive integer."
    usage
fi

# Function to generate a random password
generate_password() {
    local length=$1
    tr -dc 'A-Za-z0-9!@#$%^&*()_+{}[]' < /dev/urandom | head -c $length
}

# Generate the password
password=$(generate_password $LENGTH)

# Display the generated password
echo "Generated password: $password"