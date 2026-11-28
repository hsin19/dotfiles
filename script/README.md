# Script Directory

Scripts for managing this dotfiles repository and setting up development environments.

## Architecture

This setup supports **macOS** and **Ubuntu** through a modular architecture:

```mermaid
graph TB
    subgraph "Bootstrap Phase"
        A[bootstrap] --> B{Check git}
        B -->|Found| D
        B -->|Not Found| C{Detect OS}
        C -->|macOS| E1[xcode-select --install]
        C -->|Linux| E2[apt install git]
        E1 --> D[Clone dotfiles repo]
        E2 --> D
        D --> F[Checkout to $HOME]
        F --> G[Run setup]
    end

    subgraph "Setup Phase"
        G --> H{Detect OS}
        H -->|macOS| I[setup-macos]
        H -->|Ubuntu| J[setup-ubuntu]
        I --> K[Install Homebrew + Brewfile]
        J --> L[Install apt packages + CLI tools]
        K --> M[Shared Setup]
        L --> M
        M --> N[Oh My Zsh + plugins]
        M --> O[Git config + identities]
        M --> P[pnpm + global CLIs]
    end
```

## Files

| File                                 | Purpose                                                                                   |
| ------------------------------------ | ----------------------------------------------------------------------------------------- |
| [`bootstrap`](./bootstrap)           | 🚀 Entry point - clones dotfiles and installs git (via Xcode CLT on macOS, apt on Ubuntu) |
| [`setup`](./setup)                   | ⚙️ Unified entry point - detects OS and runs platform-specific setup + shared config      |
| [`setup-macos`](./setup-macos)       | 🍎 macOS - installs Homebrew and packages from Brewfile                                   |
| [`setup-ubuntu`](./setup-ubuntu)     | 🐧 Ubuntu - installs apt packages and modern CLI tools                                    |
| [`ai-commit`](./ai-commit)           | 🤖 AI-powered commit message generator                                                    |
| [`setup-git-hook`](./setup-git-hook) | 🪝 Git hook installer for AI commits                                                      |
| [`Brewfile`](./Brewfile)             | 📦 Homebrew packages (macOS only)                                                         |
| [`lib/`](./lib)                      | 📚 Shared utilities and helper functions                                                  |

## Platform-Specific Packages

### macOS (via Homebrew)

Managed through [`Brewfile`](./Brewfile) - includes development tools, GUI apps, and CLI utilities.
`setup-macos` runs `brew upgrade` and `brew bundle` with `HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1`, so self-updating apps
(VS Code, Chrome, OrbStack…) are left to their own updaters instead of being re-downloaded (and re-quarantined) by brew.

### Ubuntu (hardcoded in setup-ubuntu)

**APT Packages:**

- Build tools: `build-essential`, `curl`, `wget`, `gnupg`, `ca-certificates`, `git`, `jq`
- Shell: `zsh`
- Search/view: `ripgrep`, `fd-find`, `bat`
- System: `btop`

**Modern CLI Tools:**

- `eza` - Modern ls replacement
- `fnm` - Fast Node Manager
- `zoxide` - Smarter cd
- `uv` - Python package manager
- `task` - Task runner (via taskfile.dev installer into `~/.local/bin`)

## Shared Configuration (Cross-platform)

These are configured by the main [`setup`](./setup) script after platform-specific installation:

- **Zsh**: Oh My Zsh + Powerlevel10k + plugins
- **Git**: Global config, aliases, per-directory identities
- **Node.js**: Installed and version-managed by `fnm` (single source of truth; no Homebrew/system node). `fnm --use-on-cd` auto-switches versions per project.
- **pnpm**: Global npm install into the fnm default Node (Node 25+ no longer bundles corepack); it runs the version each project pins in `packageManager`
- **Dev CLIs**: `task` (macOS: Homebrew `go-task`; Ubuntu: taskfile.dev installer) and GitHub Copilot CLI (macOS: Homebrew `copilot-cli` cask)
- **AI CLIs**: Claude Code (`claude`) and Antigravity (`agy`) via their official install scripts; each gets a custom status line (a thin `script/<cli>-statusline` wrapper over the shared renderer `script/lib/statusline.sh`) merged into its `settings.json`. Codex (`codex`) uses its native TUI status line, configured in `~/.codex/config.toml` with project, Git branch, model/reasoning, context, and usage-limit fields.

## Common Operations

### Sync Homebrew packages (macOS)

```sh
brew bundle dump --file=script/Brewfile --force --describe --no-vscode --no-npm
```

### Add configuration files

```sh
dotfiles add <file_path>
dotfiles commit -m "Describe changes"
dotfiles push
```

### Update dotfiles on existing machine

```sh
dotfilesup
# or
$HOME/script/bootstrap -y
```

## Environment Variables

Create `script/.env` from [`.env.sample`](./.env.sample) and see the file for configuration details.
