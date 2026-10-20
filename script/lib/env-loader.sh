#!/bin/bash

# Load environment variables from .env file
load_env() {
    local script_dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    local env_file="$script_dir/.env"

    if [ -f "$env_file" ]; then
        # .env may hold secrets (OPENAI_API_KEY, ...) and is sourced as shell
        # code. On a shared host (Ubuntu servers are a target) a group/other-
        # readable file leaks those values, so tighten it to 0600 before sourcing.
        local perms
        perms=$(stat -c '%a' "$env_file" 2>/dev/null || stat -f '%Lp' "$env_file" 2>/dev/null || echo "")
        if [ -n "$perms" ] && [ "${perms: -2}" != "00" ]; then
            if chmod 600 "$env_file" 2>/dev/null; then
                echo "ℹ️  Tightened $env_file permissions to 600 (it may hold secrets)" >&2
            else
                echo "⚠️  $env_file is group/other-readable (mode $perms); could not chmod 600" >&2
            fi
        fi
        # shellcheck disable=SC1090
        source "$env_file"
    fi
}
