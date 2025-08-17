#!/bin/bash

# Check if we're in a git repository
check_git_repository() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Warning: Not in a git repository, skipping hook execution" >&2
        exit 0
    fi
}
