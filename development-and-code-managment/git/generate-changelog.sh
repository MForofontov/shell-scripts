#!/bin/bash

# Generate Changelog
OUTPUT_FILE=${1:-"CHANGELOG.md"}

# Get the project name from the current directory
PROJECT_NAME=$(basename "$(pwd)")

# Get the current date
CURRENT_DATE=$(date +"%Y-%m-%d %H:%M:%S")

echo "Generating changelog for $PROJECT_NAME..."

# Add a header to the changelog
{
  echo "# Changelog for $PROJECT_NAME"
  echo "Generated on $CURRENT_DATE"
  echo
} > "$OUTPUT_FILE"

# Append the git log to the changelog
if ! git log --pretty=format:"- %h %s (%an, %ar)" >> "$OUTPUT_FILE"; then
  echo "Error: Failed to generate changelog."
  exit 1
fi

echo "Changelog saved to $OUTPUT_FILE"