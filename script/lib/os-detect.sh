#!/bin/bash

# OS Detection Library
# Provides functions to detect the operating system and make OS-specific decisions

_CACHED_OS=""

_ensure_os_detected() {
    if [[ -n "$_CACHED_OS" ]]; then
        return
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then
        _CACHED_OS="macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            # Use subshell to avoid polluting current shell with os-release vars
            _CACHED_OS=$(
                . /etc/os-release
                if [[ "${ID:-}" == "ubuntu" ]] || [[ "${ID_LIKE:-}" == *"ubuntu"* ]]; then
                    echo "ubuntu"
                else
                    echo "linux"
                fi
            )
        else
            _CACHED_OS="linux"
        fi
    else
        _CACHED_OS="unknown"
    fi
}

# Detect operating system
# Returns: "macos", "ubuntu", "linux", or "unknown"
detect_os() {
    _ensure_os_detected
    echo "$_CACHED_OS"
}

# Check if running on macOS
# Returns: 0 (true) if macOS, 1 (false) otherwise
is_macos() {
    _ensure_os_detected
    [[ "$_CACHED_OS" == "macos" ]]
}

# Check if running on Ubuntu
# Returns: 0 (true) if Ubuntu, 1 (false) otherwise
is_ubuntu() {
    _ensure_os_detected
    [[ "$_CACHED_OS" == "ubuntu" ]]
}
