#!/bin/bash

# setup-github-repo.sh
# Script to initialize a Git repository and push to GitHub

# Make sure the script is executable
chmod +x start-mcp-servers.sh manage-mcp-servers.sh

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed. Please install git first."
    exit 1
fi

# Initialize git repository if not already initialized
if [ ! -d .git ]; then
    echo "Initializing git repository..."
    git init
else
    echo "Git repository already initialized."
fi

# Add all files except those in .gitignore
git add .

# Initial commit
echo "Creating initial commit..."
git commit -m "Initial commit: MCP Server Management Scripts"

# Ask for GitHub repository URL
echo ""
echo "To push to GitHub, you need to create a repository first."
echo "1. Go to https://github.com/new"
echo "2. Create a new repository (e.g., 'mcp-server-scripts')"
echo "3. Do NOT initialize it with README, .gitignore, or license"
echo ""
read -p "Enter your GitHub repository URL (e.g., https://github.com/username/mcp-server-scripts): " repo_url

# Extract the SSH URL from the HTTPS URL
if [[ $repo_url == https://github.com/* ]]; then
    # Convert HTTPS URL to SSH URL
    ssh_url="git@github.com:${repo_url#https://github.com/}.git"
else
    # Assume it's already in the correct format
    ssh_url=$repo_url
fi

# Add the remote
echo "Adding GitHub remote..."
git remote add origin "$ssh_url"

# Push to GitHub
echo "Pushing to GitHub..."
git push -u origin main || git push -u origin master

echo ""
echo "Repository setup complete!"
echo "Your MCP Server Management Scripts are now on GitHub at: $repo_url" 