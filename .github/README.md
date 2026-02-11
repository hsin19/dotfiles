# Dotfiles

This repository manages my development environment using a **Bare Git Repository workflow** combined with **idempotent bootstrap automation**.

It enables fast, reproducible workstation setup while keeping the `$HOME` directory clean and uncluttered.

> **Why Bare Repository?**  
> Unlike traditional dotfiles repos that use symlinks, this approach tracks configuration files directly in `$HOME` while keeping Git metadata separate (`~/.dotfiles`). No symlinks, no scripts moving files around—just pure Git tracking your configs in place.

## Capabilities

- **Reproducible Setup** — Quickly provision a new machine with a single command.
- **Idempotent Automation** — Safe to re-run without breaking existing environments.
- **Bare Repo Workflow** — Tracks configuration files without polluting `$HOME`.
- **Environment Bootstrapping** — Installs packages, configures shell, and sets up Git automatically.
- **Integrated Developer Tools** — Includes AI-assisted commits and Homebrew package management.

## Prerequisites

- macOS (tested on Big Sur and later)
- Internet connection
- `curl` (pre-installed on macOS)

## Quick Start (New Machine Setup)

Run the bootstrap script:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/hsin19/dotfiles/refs/heads/master/script/bootstrap)
```

This will automatically:

- Prepare the environment
- Install required tooling
- Sync dotfiles into $HOME
- Execute the provisioning workflow

## Environment Configuration

Some optional features require environment variables.

You may need to configure .env for:

- Git identity
- API keys (e.g., OpenAI)
- Personal preferences

Copy the [sample file](script/.env.sample) and fill in the values:

```sh
cp script/.env.sample script/.env
```

## Common Operations

This project includes several convenient Git Aliases and scripts:

### Update to latest configuration

```sh
$HOME/script/bootstrap
```

### AI-assisted commit messages

```sh
git ccc
# or
git ai-commit
# or
$HOME/script/ai-commit
```

### Setup AI Commit Hook

```sh
git sss
# or
git setup-hook

# unset
git setup-hook --unset
```

## Key Structure

```
.
├── script/
│   ├── bootstrap         # 🚀 Entry point for new machine setup
│   ├── setup             # ⚙️  Main provisioning workflow
│   ├── ai-commit         # 🤖 AI-powered commit generator
│   ├── setup-git-hook    # 🪝 Git hook installer
│   ├── Brewfile          # 📦 Homebrew packages
│   └── lib/              # 📚 Shared utilities
├── .config/              # Application configs
├── .zshrc                # Zsh configuration
└── .p10k.zsh             # Powerlevel10k theme
```
