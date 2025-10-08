#!/bin/bash

# Extract Jira ticket from branch name
_extract_jira_ticket() {
    local branch_name

    branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    # Match Jira ticket at start or after slash (e.g., ABC-123 or feature/ABC-123)
    echo "$branch_name" | grep -oE '(^|/)[A-Z]{2,5}-[0-9]+' | sed 's|^/||' || echo ""
}

# Add Jira ticket to commit message
_add_jira_ticket_to_commit() {
    local original_msg="$1"
    local jira_ticket

    jira_ticket=$(_extract_jira_ticket);

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
    local diff_lines="${2}"

    # Get staged changes diff
    local diff_section
    if [ "$diff_lines" -eq 0 ]; then
        diff_section="## Instructions

Use the following git commands to retrieve staged changes information:
- \`git status\` - to see which files are staged
- \`git diff --cached --no-ext-diff\` - to see the detailed changes

Analyze the changes and generate an appropriate commit message."
    else
        local total_lines
        total_lines=$(git -c color.ui=never diff --cached --no-ext-diff | wc -l | tr -d ' ')

        diff_section="## Git diff

\`\`\`diff
$(git -c color.ui=never diff --cached --no-ext-diff | sed -n "1,${diff_lines}p")
\`\`\`"

        # Add note if diff was truncated
        if [ "$total_lines" -gt "$diff_lines" ]; then
            diff_section="${diff_section}

**Note**: Diff truncated (showing ${diff_lines} of ${total_lines} lines)."
        fi
    fi

    local context_part=""
    # Add custom context if it contains non-whitespace characters
    if [[ -n "$custom_context" && "$custom_context" =~ [^[:space:]] ]]; then
        context_part="

### User's Focus
**IMPORTANT**: Pay special attention to the following when crafting the commit message:
- $custom_context
"
    fi

    cat <<EOF
You are a git commit message generator. Generate a commit message following the Conventional Commits specification.

$diff_section

## Output Format

<type>(<scope>): <description>

[optional body with bullet points using -]

## Rules

### Subject Line
- Start with type: feat, fix, docs, style, refactor, test, chore, perf, build, ci, revert
- If the diff changes runtime logic/behavior, pick **feat** for new capabilities or **fix** for bug corrections
- Include scope if applicable (component/file affected)
- Use imperative mood (e.g., 'add' not 'added')
- No capitalization of first letter after colon
- No period at end
- Maximum 72 characters

### Body (if needed for complex changes)
- Separate from subject with blank line
- Use bullet points with "-"
- Maximum 100 characters per line
- Explain WHAT and WHY, not HOW
- Be objective and concise
${context_part}
## Critical Requirements
1. Output ONLY the commit message
2. NO additional explanations, questions, or comments
3. NO formatting delimiters like \`\`\` or quotes
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
    prompt=$(_build_commit_prompt "$custom_context" 0)

    claude -p "$prompt" --allowedTools "Read" "Bash(git status:*)" "Bash(git diff:*)" 2>/dev/null
}

# Try Copilot CLI
_try_copilot() {
    local custom_context="$1"

    if ! command -v copilot >/dev/null 2>&1; then
        return 1
    fi

    echo "ℹ️  Using Copilot CLI for AI generation..." >&2

    local prompt
    prompt=$(_build_commit_prompt "$custom_context" 0)

    # Copilot CLI outputs blocks: ✓ for tool executions, ● for text responses
    # Extract content after the last ● marker (the final commit message)
    copilot -p "$prompt" --allow-tool "shell(git status:*)" --allow-tool "shell(git diff:*)" --no-color 2>/dev/null \
    | awk '
        function process_previous_block() {
            if (current_block ~ /^●/) {
                last_dot_block = current_block;
            }
        }
        /^[^ ]/ {
            process_previous_block();
            current_block = $0;
            next;
        }
        {
            if (current_block) {
                current_block = current_block "\n" $0;
            }
        }
        END {
            process_previous_block();
            if (last_dot_block) {
                sub(/^● /, "", last_dot_block);
                gsub(/\n  /, "\n", last_dot_block);
                printf "%s", last_dot_block;
            }
        }
    '
}

# Try Gemini CLI
_try_gemini() {
    local custom_context="$1"

    if ! command -v gemini >/dev/null 2>&1; then
        return 1
    fi

    echo "ℹ️  Using Gemini CLI for AI generation..." >&2

    local prompt
    prompt=$(_build_commit_prompt "$custom_context" 4000)

    # gemini cli 0.7.0 --allowed-tools has issues in non-interactive mode, so using diff directly
    printf "%s" "$prompt" | gemini 2>/dev/null
}

# Try OpenAI API
_try_openai() {
    local custom_context="$1"

    if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1 || [ -z "${OPENAI_API_KEY:-}" ]; then
        return 1
    fi

    echo "ℹ️  Using OpenAI API (GPT-5 mini) for AI generation..." >&2

    local prompt
    prompt=$(_build_commit_prompt "$custom_context" 500)

    jq -n --arg prompt "$prompt" \
       '{model:"gpt-5-mini", messages:[{role:"user", content:$prompt}], max_tokens:200, temperature:0.3}' \
    | curl -s -X POST "https://api.openai.com/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${OPENAI_API_KEY}" \
        -d @- \
    | jq -r '.choices[0].message.content' 2>/dev/null
}

# Function to generate AI commit message from git diff
_generate_ai_commit_message() {
    local custom_context="$1"

    # Get LLM service priority order from env var, default to claude,gemini,copilot,openai
    local llm_priority="${GIT_COMMIT_LLM_PRIORITY:-claude,gemini,copilot,openai}"

    # Try LLM services in priority order
    local ai_message
    local service
    IFS=',' read -ra services <<< "$llm_priority"

    for service in "${services[@]}"; do
        service=$(echo "$service" | xargs) # trim whitespace
        case "$service" in
            claude)
                if ai_message=$(_try_claude "$custom_context"); then
                    break
                fi
                ;;
            copilot)
                if ai_message=$(_try_copilot "$custom_context"); then
                    break
                fi
                ;;
            gemini)
                if ai_message=$(_try_gemini "$custom_context"); then
                    break
                fi
                ;;
            openai)
                if ai_message=$(_try_openai "$custom_context"); then
                    break
                fi
                ;;
            *)
                echo "⚠️ Unknown LLM service: $service" >&2
                ;;
        esac
    done

    # Check for empty or error response
    if [ -z "$ai_message" ] || [ "$ai_message" = "null" ] || [[ "$ai_message" == error* ]]; then
        echo "⚠️ AI generation failed: No service available or invalid result" >&2
        return 1
    fi

    # Clean up response: remove whitespace, quotes, backticks from start/end
    ai_message=$(echo "$ai_message" | sed -E "
        s/^\`\`\`[a-z]*//;
        s/\`\`\`$//;
        s/^[[:space:]]+//;
        s/[[:space:]]+$//;
        s/^[\"'\`]+//;
        s/[\"'\`]+$//;
    ")
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
