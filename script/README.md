# script

Quick reference for maintaining this repository.

## Sync Homebrew packages
```sh
brew bundle dump --file=script/Brewfile --force --describe --no-vscode
```

## Add configuration files
```sh
dotfiles add <file_path>
dotfiles commit -m "Describe changes"
dotfiles push
```