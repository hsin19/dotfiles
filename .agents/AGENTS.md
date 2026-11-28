# 全域規則

每個專案的 session 都會讀這份。這份檔案由**公開 repo** `hsin19/dotfiles` 版控（改法見〈改 dotfiles〉），只放**可公開的個人通用偏好與工具習慣**，不放公司資訊、內部環境或專案專屬內容。

## 長期記憶放哪裡

長期有效的規則、偏好、環境知識，優先寫進有版控、看得到的地方，不寫進 auto memory：

- 某個 repo 專屬的 → 那個 repo 的 `AGENTS.md`（或 README、docs）。
- 某支 skill 用得到的 → `hsin19/skills`（私有）裡那支 skill。
- 可公開的個人通用偏好／工具習慣 → 這份檔案。

auto memory 只放找不到合適 repo 的內容（例如公司跨專案環境知識、要走 MR 才能改的公司 repo 知識）和還在進行中的事。寫進 repo 後照該 repo 的 commit 規則提交。

## Commit

除非該 repo 另有規範，commit 優先用 `git ccc`（`~/script/ai-commit`）：

- 已有 staged 變更時只提交 staged 檔案；未 stage 時會自動 `git add -A`。
- `git ccc` 自動產訊息、`git ccc "# 補充重點"` 引導重點、`git ccc "訊息"` 直接提交。

## 改 dotfiles

`$HOME` 是 bare repo `~/.dotfiles` 的 work tree。不要直接改 `$HOME` 底下被追蹤的檔案（包括這份）：

1. 改 `~/repos/github/hsin19/dotfiles`（hsin19/dotfiles 的一般 clone），`git ccc` commit 後 push `main`。
2. 確認本機乾淨：`git --git-dir=$HOME/.dotfiles --work-tree=$HOME -C $HOME status --short`，有改動 pull 會衝突。
3. 拉回本機：`git --git-dir=$HOME/.dotfiles --work-tree=$HOME -C $HOME pull --ff-only origin main`。不要用 `dotfilesup`：它是 `~/script/bootstrap -y`，會連 brew 等整套 setup 一起跑。
4. 讓設定生效（例：tmux 要 `source-file`）。
