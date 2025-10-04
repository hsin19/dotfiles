#!/bin/bash

# Extract Jira ticket from branch name
_extract_jira_ticket() {
    local branch_name
    local branch_name_no_prefix
    
    branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    branch_name_no_prefix=$(echo "$branch_name" | sed 's|^[^/]*\/||')
    echo "$branch_name_no_prefix" | grep -oE '^[A-Z]{1,5}-[0-9]+' || echo ""
}

# Add Jira ticket to commit message
_add_jira_ticket_to_commit() {
    local original_msg="$1"
    local jira_ticket
    
    if ! jira_ticket=$(_extract_jira_ticket); then
        echo "Error: Failed to extract Jira ticket" >&2
        return 1
    fi
    
    if [ -n "$jira_ticket" ]; then
        if [[ $original_msg != *"$jira_ticket"* ]]; then
            echo "[$jira_ticket] $original_msg"
            echo "✅ Added Jira ticket: $jira_ticket" >&2
        else
            echo "$original_msg"
        fi
    else
        echo "$original_msg"
    fi
}

# Build AI prompt for commit message generation
_build_commit_prompt() {
    local custom_context="$1"

    # Get first 100 lines of staged changes
    local diff_content
    diff_content=$(git -c color.ui=never diff --cached --no-ext-diff | sed -n '1,100p')

    local context_part=""
    if [ -n "$custom_context" ]; then
        context_part="

IMPORTANT - User's focus/emphasis: $custom_context
Pay special attention to this when crafting the commit message. Emphasize the aspects the user highlighted."
    fi

    cat <<EOF
Based on the following git diff, generate a concise and descriptive commit message following conventional commit format (type(scope): description).

The commit message should:
1. Start with a type (feat, fix, docs, style, refactor, test, chore, etc.)
2. Include scope if applicable (component/file affected)
3. Be written in imperative mood (e.g., 'add feature' not 'added feature')
4. The subject line should be under 72 characters
5. Focus on WHAT changed and WHY, not HOW
6. If the change is complex, include a body paragraph after a blank line explaining details${context_part}

Git diff:
$diff_content

Please respond with the commit message only. If you need to add a body, separate it from the subject with a blank line.
EOF
}

# Try Claude Code CLI
_try_claude() {
    local custom_context="$1"

    if ! command -v claude >/dev/null 2>&1; then
        return 1
    fi

    echo "ℹ️  Using Claude Code CLI for AI generation..." >&2

    local prompt
    prompt=$(_build_commit_prompt "$custom_context")

    local result
    result=$(claude -p "$prompt" 2>/dev/null)

    if [ -z "$result" ] || [ "$result" = "null" ]; then
        return 1
    fi

    echo "$result"
}

# Try Gemini CLI
_try_gemini() {
    local custom_context="$1"

    if ! command -v gemini >/dev/null 2>&1; then
        return 1
    fi

    echo "ℹ️  Using Gemini CLI for AI generation..." >&2

    local prompt
    prompt=$(_build_commit_prompt "$custom_context")

    local result
    result=$(printf "%s" "$prompt" | gemini 2>/dev/null)

    if [ -z "$result" ] || [ "$result" = "null" ]; then
        return 1
    fi

    echo "$result"
}

# Try OpenAI API
_try_openai() {
    local custom_context="$1"

    if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1 || [ -z "${OPENAI_API_KEY:-}" ]; then
        return 1
    fi

    echo "ℹ️  Using OpenAI API (GPT-5 mini) for AI generation..." >&2

    local prompt
    prompt=$(_build_commit_prompt "$custom_context")

    local result
    result=$(
        jq -n --arg prompt "$prompt" \
           '{model:"gpt-5-mini", messages:[{role:"user", content:$prompt}], max_tokens:200, temperature:0.3}' \
        | curl -s -X POST "https://api.openai.com/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${OPENAI_API_KEY}" \
            -d @- \
        | jq -r '.choices[0].message.content' 2>/dev/null
    )

    if [ -z "$result" ] || [ "$result" = "null" ]; then
        return 1
    fi

    echo "$result"
}

# Function to generate AI commit message from git diff
_generate_ai_commit_message() {
    local custom_context="$1"

    # Try LLM services in priority order
    local ai_message
    if ai_message=$(_try_claude "$custom_context"); then
        :
    elif ai_message=$(_try_gemini "$custom_context"); then
        :
    elif ai_message=$(_try_openai "$custom_context"); then
        :
    else
        echo "⚠️ No AI service available (claude CLI, gemini CLI or OpenAI API key)." >&2
        return 1
    fi

    # Clean up response (trim whitespace, remove surrounding quotes)
    ai_message=$(echo "$ai_message" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')

    if [ -z "$ai_message" ]; then
        echo "⚠️ AI generation produced empty result." >&2
        return 1
    fi

    echo "$ai_message"
}

# Fallback commit message generation based on file analysis
_generate_fallback_commit_message() {
    # Get list of changed files directly
    local files_changed
    files_changed=$(git diff --cached --name-only)
    
    if [ -z "$files_changed" ]; then
        echo "chore: update files"
        return
    fi
    
    # Count files
    local file_count
    file_count=$(echo "$files_changed" | wc -l | tr -d ' ')
    
    if [ "$file_count" -eq 1 ]; then
        # Single file - use filename
        local filename
        filename=$(basename "$files_changed")
        echo "chore: update $filename"
    elif [ "$file_count" -le 3 ]; then
        # Few files - list them
        local file_list
        file_list=$(echo "$files_changed" | xargs -I {} basename {} | tr '\n' ', ' | sed 's/, $//')
        echo "chore: update $file_list"
    else
        # Many files - just say how many
        echo "chore: update $file_count files"
    fi
}

# Function to generate/process commit message
generate_commit_message() {
    local commit_message="$1"
    local processed_message

    # Check if there are staged changes (needed for AI and fallback)
    if git diff --cached --quiet; then
        echo "Error: No staged changes found" >&2
        return 1
    fi

    # Check if message starts with # (use as AI prompt) or is empty (use AI)
    if [ -z "$commit_message" ]; then
        # No message provided, use AI to generate
        echo "ℹ️  No message provided, generating AI commit message..." >&2
        if ! commit_message=$(_generate_ai_commit_message ""); then
            echo "❌ AI generation failed, using fallback" >&2
            commit_message=$(_generate_fallback_commit_message)
        else
            echo "✅ AI generated message: $commit_message" >&2
        fi
    elif [[ "$commit_message" =~ ^#.* ]]; then
        # Message starts with #, use as AI prompt
        local ai_prompt="${commit_message#\#}"  # Remove leading #
        ai_prompt=$(echo "$ai_prompt" | sed 's/^[[:space:]]*//')  # Trim leading spaces
        echo "ℹ️  Using custom AI prompt: $ai_prompt" >&2
        if ! commit_message=$(_generate_ai_commit_message "$ai_prompt"); then
            echo "❌ AI generation failed, using fallback" >&2
            commit_message=$(_generate_fallback_commit_message)
        else
            echo "✅ AI generated message with custom prompt: $commit_message" >&2
        fi
    fi

    # Process message with Jira ticket (and future enhancements)
    if ! processed_message=$(_add_jira_ticket_to_commit "$commit_message"); then
        echo "Error: Failed to process commit message" >&2
        return 1
    fi

    # Return processed message
    echo "$processed_message"
}
