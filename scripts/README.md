# scripts

這個資料夾包含 dotfiles 專案的安裝與設定腳本。

## 安裝方式

所有安裝步驟都可以安全重複執行，多次執行不會造成問題。

1. 一鍵下載與執行 bootstrap.sh：
   ```sh
   bash <(curl -fsSL https://raw.githubusercontent.com/hsin19/dotfiles/refs/heads/master/scripts/bootstrap.sh)
   ```

2. 修改 `.env` 檔案
   
   我的設定：[Google 文件](https://docs.google.com/document/d/1iScKuZSXaJpC1n26h-F8VKngpWEAJ3vUBsTpVqEdTSE/edit?tab=t.0)

3. 執行安裝腳本：
   ```sh
   # chmod +x $HOME/scripts/install.sh # 如果需要，先給予執行權限

   bash $HOME/scripts/install.sh
   ```
