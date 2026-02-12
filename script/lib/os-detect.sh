#!/bin/bash

# OS Detection Library
# Provides functions to detect the operating system and make OS-specific decisions

# Detect operating system
# Returns: "macos", "ubuntu", "linux", or "unknown"
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            if [[ "$ID" == "ubuntu" ]] || [[ "$ID_LIKE" == *"ubuntu"* ]]; then
                echo "ubuntu"
            else
                echo "linux"
            fi
        else
            echo "linux"
        fi
    else
        echo "unknown"
    fi
}

# Check if running on macOS
# Returns: 0 (true) if macOS, 1 (false) otherwise
is_macos() {
    [[ "$(detect_os)" == "macos" ]]
}

# Check if running on Ubuntu
# Returns: 0 (true) if Ubuntu, 1 (false) otherwise
is_ubuntu() {
    [[ "$(detect_os)" == "ubuntu" ]]
}
