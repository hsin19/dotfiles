#!/usr/bin/env bash
# Shared status line renderer for AI CLIs. Each CLI has a thin wrapper script that sources this.
#
# Output: <project>:<branch> | <model> | <effort> | C: <ctx%> | S: <short%>(reset <t>) | W: <weekly%>(reset <t>) | <HH:MM>
#
# A wrapper only maps its CLI's stdin JSON into a common shape:
#   statusline_main '<jq filter>'
# The filter runs against the CLI's JSON (with $now = current epoch seconds) and must emit
#   {model, effort, short_pct, short_reset, week_pct, week_reset}
# where *_pct is used percentage (0-100) and *_reset is seconds until reset; any may be null.
# Common fields (workspace, session id, context window) are read here.

RESET="\033[0m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
WHITE="\033[37m"
DIM="\033[2m"
RED="\033[31m"
ORANGE="\033[38;5;208m"
SEP="${DIM}|${RESET}"

# Format remaining seconds into XdYh, XhYm, or Ym
_statusline_format_reset() {
  local diff="$1"
  if [ -z "$diff" ]; then return; fi
  if [ "$diff" -le 0 ]; then
    echo "now"
    return
  fi
  local days=$(( diff / 86400 ))
  local hours=$(( (diff % 86400) / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))
  if [ "$days" -gt 0 ]; then
    printf "%dd%dh" "$days" "$hours"
  elif [ "$hours" -gt 0 ]; then
    printf "%dh%dm" "$hours" "$mins"
  else
    printf "%dm" "$mins"
  fi
}

# Color for a percentage (white < 70, orange 70-89, red >= 90)
_statusline_pct_color() {
  local int_pct
  int_pct=$(printf '%.0f' "$1")
  if [ "$int_pct" -ge 90 ]; then
    printf "%s" "$RED"
  elif [ "$int_pct" -ge 70 ]; then
    printf "%s" "$ORANGE"
  else
    printf "%s" "$WHITE"
  fi
}

# "<label>: <pct>%(reset <t>)" segment for a quota window
_statusline_quota() {
  local label="$1" pct="$2" reset_secs="$3"
  local c reset_str str
  c=$(_statusline_pct_color "$pct")
  str="${DIM}${label}:${RESET} ${c}$(printf '%.0f' "$pct")%${RESET}"
  reset_str=$(_statusline_format_reset "$reset_secs")
  if [ -n "$reset_str" ]; then
    str="${str}${DIM}(reset ${reset_str})${RESET}"
  fi
  printf "%s" "$str"
}

statusline_main() {
  local normalize="$1"
  local input project cwd session_id ctx_used model effort short_pct short_reset week_pct week_reset
  local field branch session_label status_file out ec
  input=$(cat)

  # One jq pass for common + CLI-specific fields. Missing values become "-" so the
  # tab-separated read keeps field positions (consecutive tabs would collapse).
  IFS=$'\t' read -r project cwd session_id ctx_used model effort short_pct short_reset week_pct week_reset < <(
    printf '%s' "$input" | jq -r --argjson now "$(date +%s)" "def normalize:
${normalize}
;"'
      def secs: if type == "number" then floor else . end;
      normalize as $n
      | [
          (.workspace.project_dir // .workspace.current_dir // .cwd // "."
            | sub("/+$"; "") | split("/") | last // "/"),
          (.workspace.current_dir // .cwd // "."),
          (.session_id // .conversation_id),
          .context_window.used_percentage,
          $n.model,
          $n.effort,
          $n.short_pct,
          ($n.short_reset | secs),
          $n.week_pct,
          ($n.week_reset | secs)
        ]
      | map(if . == null or . == "" then "-" else tostring end)
      | @tsv
    '
  )
  for field in project cwd session_id ctx_used model effort short_pct short_reset week_pct week_reset; do
    if [ "${!field}" = "-" ]; then printf -v "$field" '%s' ""; fi
  done

  # Git branch from current_dir / cwd
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  if [ -z "$branch" ]; then
    branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  fi

  # Session edit-context label (written by a Claude Code PostToolUse track-edit hook).
  # When present it pinpoints the subsystem/task currently being edited
  # (e.g. "adminsite:uat", "task:Foo") and replaces the generic project:branch.
  session_label=""
  if [ -n "$session_id" ]; then
    status_file="/tmp/claude_status_${session_id}"
    if [ -f "$status_file" ]; then
      session_label=$(jq -r '.label // empty' "$status_file" 2>/dev/null)
    fi
  fi

  # Edit-context label takes priority; otherwise project:branch — cyan project, green branch
  if [ -n "$session_label" ]; then
    out="${CYAN}${session_label}${RESET}"
  elif [ -n "$branch" ]; then
    out="${CYAN}${project}${RESET}:${GREEN}${branch}${RESET}"
  else
    out="${CYAN}${project}${RESET}"
  fi

  # Model — yellow, followed by effort level (colored by intensity)
  out="${out} ${SEP} ${YELLOW}${model}${RESET}"
  if [ -n "$effort" ]; then
    case "$effort" in
      max)    ec="$RED" ;;
      xhigh)  ec="$ORANGE" ;;
      high)   ec="$YELLOW" ;;
      medium) ec="$GREEN" ;;
      *)      ec="$DIM" ;;
    esac
    out="${out} ${SEP} ${ec}${effort}${RESET}"
  fi

  # Context — white/orange/red depending on usage
  if [ -n "$ctx_used" ]; then
    out="${out} ${SEP} ${DIM}C:${RESET} $(_statusline_pct_color "$ctx_used")$(printf '%.0f' "$ctx_used")%${RESET}"
  fi

  # Short / session quota, then weekly quota
  if [ -n "$short_pct" ]; then
    out="${out} ${SEP} $(_statusline_quota S "$short_pct" "$short_reset")"
  fi
  if [ -n "$week_pct" ]; then
    out="${out} ${SEP} $(_statusline_quota W "$week_pct" "$week_reset")"
  fi

  # Time — blue
  out="${out} ${SEP} ${BLUE}$(date +%H:%M)${RESET}"

  printf "%b" "$out"
}
