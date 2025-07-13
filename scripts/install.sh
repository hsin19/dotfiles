#!/bin/bash

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

load_env() {
    local env_file="$SCRIPT_DIR/.env"
    
    if [ -f "$env_file" ]; then
        echo "Loading configuration from .env file..."
        source "$env_file"
    else
        echo "⚠️ No .env file found, using defaults"
    fi
}

install_homebrew() {
    if ! command -v brew &>/dev/null; then
        echo "Installing Homebrew..."
        if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            echo "✅ Homebrew installed successfully"
            
            if [[ $(uname -m) == "arm64" ]]; then
                # 讓後續步驟能找到 brew
                export PATH="/opt/homebrew/bin:$PATH"
            fi
        else
            echo "❌ Failed to install Homebrew"
            exit 1
        fi
    else
        echo "✅ Homebrew already installed"
    fi
}

install_brew_packages() {
    echo "Setting up Homebrew packages..."
    
    install_homebrew

    echo "Updating Homebrew..."
    brew update

    echo "Installing packages from Brewfile..."
    # Look for Brewfile in the same directory as this script
    
    if [ -f "$SCRIPT_DIR/Brewfile" ]; then
        echo "Using Brewfile from scripts directory..."
        brew bundle --file="$SCRIPT_DIR/Brewfile"
    else
        echo "❌ Error: Brewfile not found at $SCRIPT_DIR/Brewfile"
        echo "Please create a Brewfile in the scripts directory."
        return 1
    fi

    brew cleanup
    
    echo "✅ Homebrew packages installation completed!"
}

setup_git_identities() {
    echo "Setting up Git identities..."
    
    # --- Global Git Config ---
    git config --global user.name "${GIT_USER_NAME:-Eric Yeh}"
    git config --global user.email "${GIT_USER_EMAIL:-eric91343@gmail.com}"

    # --- Per-directory Git Config ---
    mkdir -p "$HOME/repos/github"

    # onelab
    mkdir -p "$HOME/repos/onelab"
    git config --global includeIf."gitdir:~/repos/onelab/".path "~/repos/onelab/.gitconfig"
    cat <<-EOF > ~/repos/onelab/.gitconfig
[user]
    email = ${ONELAB_EMAIL:-eric.yeh@onelab.tw}
EOF
    
    # Only create NuGet.config if ONELAB_NUGET_URL is set
    if [ -n "${ONELAB_NUGET_URL:-}" ]; then
        cat <<-EOF > ~/repos/onelab/NuGet.config
<?xml version="1.0" encoding="utf-8"?>
<configuration>
    <packageSources>
        <add key="onelab" value="$ONELAB_NUGET_URL" protocolVersion="3" />
    </packageSources>
</configuration>
EOF
    else
        echo "⚠️ ONELAB_NUGET_URL not set, skipping NuGet.config creation"
    fi

    # ascentistech
    mkdir -p "$HOME/repos/ascentistech"
    git config --global includeIf."gitdir:~/repos/ascentistech/".path "~/repos/ascentistech/.gitconfig"
    cat <<-EOF > ~/repos/ascentistech/.gitconfig
[user]
    email = ${ASCENTISTECH_EMAIL:-eric.yeh@ascentistech.com}
EOF
    
    echo "✅ Git identities setup completed!"
}

setup_opencommit() {
    echo "Setting up OpenCommit..."

    if ! command -v npm &> /dev/null; then
        echo "❌ npm not found, please install Node.js first."
        return 1
    fi

    # Check if oco is already installed
    if ! command -v oco &> /dev/null; then
        npm install -g opencommit
    else
        echo "oco (opencommit) already installed, skipping npm install."
    fi
    
    # Check if OCO_API_KEY is set
    if [ -z "${OCO_API_KEY:-}" ]; then
        echo "⚠️ No OCO_API_KEY found in environment, skipping OpenCommit configuration"
        echo "To configure OpenCommit later, add OCO_API_KEY to your .env file"
        return 0
    fi
    
    # Configure opencommit
    oco config set OCO_AI_PROVIDER="${OCO_AI_PROVIDER:-gemini}"
    oco config set OCO_MODEL="${OCO_MODEL:-gemini-2.0-flash}"
    oco config set OCO_API_KEY="$OCO_API_KEY"
    oco config set OCO_GITPUSH=false
    
    echo "✅ OpenCommit setup completed!"
}

main() {
    echo "Starting development environment setup..."
    
    load_env
    install_brew_packages
    setup_git_identities
    setup_opencommit

    echo "All done! Your development environment is ready."
}

main "$@"