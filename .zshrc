# ------------------------------------------------------------------------------
# Powerlevel10k instant prompt
# ------------------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------------------------
# Oh My Zsh Configuration
# ------------------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
  git
  zsh-autosuggestions
  autoupdate
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# ------------------------------------------------------------------------------
# PATH Additions
# ------------------------------------------------------------------------------
# Add ~/.local/bin for tools installed via standalone scripts (e.g., zoxide)
if [[ -d "$HOME/.local/bin" ]] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

# ------------------------------------------------------------------------------
# Modern CLI Tools Initialization (fnm, uv, zoxide)
# ------------------------------------------------------------------------------
# FNM: Node Version Manager (with auto-switching)
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# UV: Python Package Manager (with auto-completion)
if command -v uv >/dev/null 2>&1; then
  eval "$(uv generate-shell-completion zsh)"
fi

# Zoxide: Smarter cd
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# ------------------------------------------------------------------------------
# Aliases
# ------------------------------------------------------------------------------

# Dotfiles Management (Bare Repository Mode)
alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias dotfilesup="$HOME/script/bootstrap -y"

# Docker to Podman
if command -v podman >/dev/null 2>&1; then
  alias docker=podman
fi

# Eza (Modern replacement for ls)
if command -v eza >/dev/null 2>&1; then
  alias ls="eza --icons"
  alias ll="eza --icons -l"
  alias la="eza --icons -la"
  alias lt="eza --icons --tree"
fi

# ------------------------------------------------------------------------------
# Powerlevel10k custom config
# ------------------------------------------------------------------------------
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
