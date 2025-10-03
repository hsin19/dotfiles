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

# Function to call LLM services with prompt
_call_llm_service() {
    local prompt="$1"
    local ai_message=""

    # Try to use different AI services (prioritize based on availability)
    if command -v claude >/dev/null 2>&1; then
        echo "ℹ️  Using Claude Code CLI for AI generation..." >&2
        # Use claude with -p flag for single prompt response
        ai_message=$(claude -p "$prompt" 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    elif command -v gemini >/dev/null 2>&1; then
        echo "ℹ️  Using Gemini CLI for AI generation..." >&2
        # Use gemini CLI in non-interactive mode with a direct prompt
        # Capture full response (not just first line) to support multi-line messages
        ai_message=$(printf "%s" "$prompt" | gemini 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    elif command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && [ -n "${OPENAI_API_KEY:-}" ]; then
        echo "ℹ️  Using OpenAI API (GPT-5 mini) for AI generation..." >&2
        ai_message=$(
            jq -n --arg prompt "$prompt" \
               '{model:"gpt-5-mini", messages:[{role:"user", content:$prompt}], max_tokens:200, temperature:0.3}' \
            | curl -s -X POST "https://api.openai.com/v1/chat/completions" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer ${OPENAI_API_KEY}" \
                -d @- \
            | jq -r '.choices[0].message.content' 2>/dev/null \
            | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
        )
    else
        echo "⚠️ No AI service available (claude CLI, gemini CLI or OpenAI API key)." >&2
        return 1
    fi

    # Validate AI response
    if [ -z "$ai_message" ] || [ "$ai_message" = "null" ]; then
        echo "⚠️ AI generation failed." >&2
        return 1
    fi

    # Clean up the response
    ai_message=$(echo "$ai_message" | sed 's/^"//; s/"$//')

    echo "$ai_message"
}

# Function to generate AI commit message from git diff
_generate_ai_commit_message() {
    local custom_context="$1"

    # Get first 100 lines of staged changes directly
    local diff_content
    diff_content=$(git -c color.ui=never diff --cached --no-ext-diff | sed -n '1,100p')

    if [ -z "$diff_content" ]; then
        echo "Error: No staged changes found for AI analysis" >&2
        return 1
    fi

    # Prepare the prompt for AI
    local context_part=""
    if [ -n "$custom_context" ]; then
        context_part="

IMPORTANT - User's focus/emphasis: $custom_context
Pay special attention to this when crafting the commit message. Emphasize the aspects the user highlighted."
    fi

    local prompt="Based on the following git diff, generate a concise and descriptive commit message following conventional commit format (type(scope): description).

The commit message should:
1. Start with a type (feat, fix, docs, style, refactor, test, chore, etc.)
2. Include scope if applicable (component/file affected)
3. Be written in imperative mood (e.g., 'add feature' not 'added feature')
4. The subject line should be under 72 characters
5. Focus on WHAT changed and WHY, not HOW
6. If the change is complex, include a body paragraph after a blank line explaining details${context_part}

Git diff:
$diff_content

Please respond with the commit message only. If you need to add a body, separate it from the subject with a blank line."

    # Call LLM service
    if ! _call_llm_service "$prompt"; then
        return 1
    fi
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
