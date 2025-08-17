#!/bin/bash

# Extract Jira ticket from branch name
extract_jira_ticket() {
    local branch_name
    local branch_name_no_prefix
    
    branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    branch_name_no_prefix=$(echo "$branch_name" | sed 's|^[^/]*\/||')
    echo "$branch_name_no_prefix" | grep -oE '^[A-Z]{1,5}-[0-9]+' || echo ""
}

# Add Jira ticket to commit message
add_jira_ticket_to_commit() {
    local original_msg="$1"
    local jira_ticket
    
    if ! jira_ticket=$(extract_jira_ticket); then
        echo "Error: Failed to extract Jira ticket" >&2
        return 1
    fi
    
    if [ -n "$jira_ticket" ]; then
        if [[ ! "$original_msg" =~ $jira_ticket ]]; then
            echo "[$jira_ticket] $original_msg"
            echo "Added Jira ticket: $jira_ticket" >&2
        else
            echo "$original_msg"
        fi
    else
        echo "$original_msg"
    fi
}

# Function to generate/process commit message
generate_commit_message() {
    local commit_message="$1"
    local processed_message
    
    # If no message provided, use a default
    if [ -z "$commit_message" ]; then
        commit_message="WIP: work in progress"
        echo "⚠️ No commit message provided, using default: $commit_message" >&2
    fi
    
    # Process message with Jira ticket (and future enhancements)
    if ! processed_message=$(add_jira_ticket_to_commit "$commit_message"); then
        echo "Error: Failed to process commit message" >&2
        return 1
    fi
    
    # TODO: Add more message processing here (AI generation, formatting, etc.)
    
    # Return processed message
    echo "$processed_message"
}
