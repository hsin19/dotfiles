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

# Try Claude Code CLI (or CCR if configured)
_try_claude() {
    local custom_context="$1"

    # Check if CCR is enabled via env var or git config
    local use_ccr="${GIT_COMMIT_USE_CCR:-}"
    if [ -z "$use_ccr" ]; then
        use_ccr=$(git config --get dotfiles.ai.use_ccr 2>/dev/null || echo "false")
    fi

    local claude_cmd=""
    local tool_name=""

    # If CCR is enabled/requested
    if [[ "$use_ccr" == "true" || "$use_ccr" == "1" || "$use_ccr" == "yes" ]]; then
        if command -v ccr >/dev/null 2>&1; then
            claude_cmd="ccr code"
            tool_name="CCR (Claude Code Router)"
        else
            return 1
        fi
    fi

    if [ -z "$claude_cmd" ]; then
        if command -v claude >/dev/null 2>&1; then
            claude_cmd="claude"
            tool_name="Claude Code CLI"
        else
            return 1
        fi
    fi

    if ! command -v "$claude_cmd" >/dev/null 2>&1; then
        return 1
    fi

    echo "ℹ️  Using $tool_name for AI generation..." >&2

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

    # Wrap context with explicit output markers and later extract between them
    local marker_start="<<<COMMIT_MESSAGE_START>>>"
    local marker_end="<<<COMMIT_MESSAGE_END>>>"

    # Augment custom context to instruct the model to wrap its final output
    local wrapped_context
    wrapped_context=$(cat <<EOF
$custom_context

IMPORTANT: Output only the final commit message wrapped between the following markers:
- Start marker: $marker_start
- End marker: $marker_end
Do not include any other text outside the markers.
EOF
)

    local prompt
    prompt=$(_build_commit_prompt "$wrapped_context" 0)

    # Extract only the content between markers from the entire output
    copilot -p "$prompt" --allow-tool "shell(git status:*)" --allow-tool "shell(git diff:*)" --no-color 2>/dev/null \
    | awk -v start="${marker_start}" -v end="${marker_end}" '
        function trim(s) { sub(/^\s+/, "", s); sub(/\s+$/, "", s); return s }
        {
            line = $0
            # If start marker appears on this line, begin capture and drop text before it
            if (!capturing) {
                pos = index(line, start)
                if (pos) {
                    capturing = 1
                    line = substr(line, pos + length(start))
                } else {
                    next
                }
            }
            # If end marker appears on this line, append up to it and finish
            posEnd = index(line, end)
            if (capturing && posEnd) {
                piece = substr(line, 1, posEnd - 1)
                buffer = buffer (buffer ? "\n" : "") piece
                capturing = 0
                done = 1
                next
            }
            if (capturing) {
                buffer = buffer (buffer ? "\n" : "") line
            }
        }
        END {
            printf "%s", trim(buffer)
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
    local llm_priority="${GIT_COMMIT_LLM_PRIORITY:-}"
    
    if [ -z "$llm_priority" ]; then
        llm_priority=$(git config --get dotfiles.ai.llm_priority 2>/dev/null)
    fi
    
    # Default if still empty
    if [ -z "$llm_priority" ]; then
        llm_priority="claude,gemini,copilot,openai"
    fi

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
