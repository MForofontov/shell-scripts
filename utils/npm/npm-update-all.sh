#!/bin/bash
# npm-update-all.sh
# Script to update all NPM packages to the latest version

echo "Updating all NPM packages..."
npm outdated
npm update

echo "Running npm audit fix..."
npm audit fix
