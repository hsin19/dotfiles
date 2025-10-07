#!/bin/bash

# Load environment variables from .env file
load_env() {
    local script_dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    local env_file="$script_dir/.env"

    if [ -f "$env_file" ]; then
        # shellcheck disable=SC1090
        source "$env_file"
    fi
}
