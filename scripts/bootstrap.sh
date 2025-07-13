#!/bin/bash

set -euo pipefail

# dotfiles 函數（替代 alias）
dotfiles() {
    /usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME" "$@"
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

install_git() {
    if ! command -v git &>/dev/null; then
        echo "Installing Git..."
        if brew install git; then
            echo "✅ Git installed successfully"
        else
            echo "❌ Failed to install Git"
            exit 1
        fi
    else
        echo "✅ Git already installed"
    fi
}

clone_dotfiles() {
    local dotfiles_dir="$HOME/.dotfiles"
    
    if [ ! -d "$dotfiles_dir" ]; then
        echo "Cloning dotfiles repository..."
        if git clone --bare https://github.com/hsin19/dotfiles.git "$dotfiles_dir"; then
            echo "✅ Dotfiles repository cloned successfully"
        else
            echo "❌ Failed to clone dotfiles repository"
            exit 1
        fi
    else
        echo "✅ Dotfiles repository already exists"
    fi

    dotfiles config --local status.showUntrackedFiles no
}

checkout_dotfiles() {
    local backup_dir="$HOME/config-backup"
    
    echo "Attempting dotfiles checkout..."
    
    if ! checkout_output=$(dotfiles checkout 2>&1); then
        local conflicts
        conflicts=$(echo "$checkout_output" | grep -E "^\s+\." | awk '{print $1}' || true)

        if [ -n "$conflicts" ]; then
            echo "⚠️ Conflicting files found. Backing up to $backup_dir"
            mkdir -p "$backup_dir"
            while IFS= read -r file; do
                if [ -n "$file" ] && [ -e "$HOME/$file" ]; then
                    local backup_path="$backup_dir/$file"
                    mkdir -p "$(dirname "$backup_path")"
                    mv "$HOME/$file" "$backup_path"
                    echo "Backed up: $file"
                fi
            done <<< "$conflicts"
            dotfiles checkout
            echo "✅ Dotfiles checked out successfully"
        else
            echo "❌ Checkout failed for unknown reason"
            exit 1
        fi
    else
        echo "✅ Dotfiles checked out successfully"
    fi
}

main() {
    echo "Starting dotfiles bootstrap..."
    
    # 執行安裝步驟
    install_homebrew
    install_git
    clone_dotfiles
    checkout_dotfiles
    
    echo "✅ Dotfiles bootstrap completed successfully!"
    echo "You may need to restart your terminal to see all changes."
}

main "$@"