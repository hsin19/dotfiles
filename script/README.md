# script

這個資料夾包含 dotfiles 專案的安裝與設定腳本。

## 安裝方式

所有安裝步驟都可以安全重複執行，多次執行不會造成問題。

1. 一鍵下載與執行 bootstrap：
   ```sh
   bash <(curl -fsSL https://raw.githubusercontent.com/hsin19/dotfiles/refs/heads/master/script/bootstrap)
   ```

2. 修改 `.env` 檔案
   
   我的設定：[Google 文件](https://docs.google.com/document/d/1iScKuZSXaJpC1n26h-F8VKngpWEAJ3vUBsTpVqEdTSE/edit?tab=t.0)

3. 執行安裝腳本：
   ```sh
   # chmod +x $HOME/script/setup # 如果需要，先給予執行權限

   bash $HOME/script/setup
   ```
## 常用指令

- 同步最新的配置
  直接跑 bootstrap，會自動做更新/備份
  ```sh
  # chmod +x $HOME/script/bootstrap # 如果需要，先給予執行權限

  $HOME/script/bootstrap
  ```

- 添加新的配置
  ```sh
  dotfiles add <檔案路径1> <檔案路径2> ... 多檔案時空白分隔
  dotfiles commit -m "描述變更內容"
  dotfiles push

  brew bundle dump --file=script/Brewfile --force --describe --no-vscode # sync 目前安裝的 brew packages
  ```