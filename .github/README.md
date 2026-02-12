# Dotfiles

Personal development environment configuration for **macOS** and **Ubuntu**.

One command to set up a fully configured development machine.

## ✨ Features

- 🚀 **One-command setup** — Bootstrap a new machine in minutes
- 🔄 **Idempotent** — Safe to re-run without breaking existing setups
- 🍎 🐧 **Multi-platform** — Works on macOS and Ubuntu
- 📦 **Package management** — Homebrew (macOS) and apt (Ubuntu)
- 🎨 **Modern shell** — Zsh + Oh My Zsh + Powerlevel10k
- 🤖 **AI-powered commits** — Smart commit message generation
- ✅ **Clean workflow** — Files tracked in place, no symlinks needed

## 🚀 Quick Start

Run this on a fresh machine:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/hsin19/dotfiles/refs/heads/master/script/bootstrap)
```

The script will auto-detect your OS and set up everything automatically.

## 📋 What Gets Installed

### 🍎 macOS (Desktop Development)
- Homebrew + packages from Brewfile
- GUI Apps: VS Code, Notion, etc.
- Development tools: Node, Go, Python, and more

### 🐧 Ubuntu (Server Development)
- CLI essentials: build tools, git, zsh
- Modern CLI tools: eza, zoxide, fnm, btop
- Development runtimes: Node, Go, Python

### 🔧 Both Platforms
- Zsh + Oh My Zsh + Powerlevel10k theme
- Git with per-directory identities
- AI commit tools (Claude, Gemini, Copilot)

## 🛠️ Common Tasks

Update configs from repo:
```sh
dotfilesup
```

AI-assisted commits:
```sh
git ccc
```

## 💡 How It Works

This repo uses a **bare Git repository** approach. Instead of using symlinks, configuration files are tracked directly in `$HOME` while Git metadata stays in `~/.dotfiles/`.

```
Traditional approach:       This approach:
~/dotfiles/                 ~/.dotfiles/      (metadata only)
  .zshrc → ~/.zshrc         ~/.zshrc          (tracked in place)
  (symlinks everywhere)     (no symlinks!)
```

The `dotfiles` command is an alias for `git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME`, letting you manage these files like a normal Git repo.

**Benefits:**
- ✅ Files live naturally in `$HOME`
- ✅ No symlink management
- ✅ Familiar Git workflow
- ✅ Track only what you want

## ⚙️ Configuration

Optional: Create `script/.env` for personalization

```sh
GIT_USER_NAME="Your Name"
GIT_USER_EMAIL="you@example.com"
OPENAI_API_KEY="sk-..."  # For AI commits (optional)
```

See [`script/.env.sample`](../script/.env.sample) for all options.

## 🎯 Use Cases

- **Fresh machine setup** — One command to get a fully configured dev environment
- **Config sync** — Keep settings consistent across multiple machines  
- **Server provisioning** — Quickly set up remote Ubuntu servers
- **Safe experimentation** — Easy to test changes in VMs

## 📚 Documentation

- **[Script Documentation](../script/README.md)** — Technical details and architecture
- **[Environment Template](../script/.env.sample)** — Configuration options

---

**Quick Links**: [Technical Docs](../script/README.md) · [Environment Setup](../script/.env.sample) · [AI Commits](../script/ai-commit)
