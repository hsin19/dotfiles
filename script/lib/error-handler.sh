#!/bin/bash

# Error handling function
error_handler() {
    local line_number=$1
    local error_code=$2
    echo "Error: Script failed at line ${line_number}, error code: ${error_code}" >&2
    echo "Location: ${BASH_SOURCE[1]}:${line_number}" >&2
    exit "${error_code}"
}

# Setup error handling
setup_error_handling() {
    set -eE  # -E ensures ERR trap is inherited
    trap 'error_handler ${LINENO} $?' ERR
}
