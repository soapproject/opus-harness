# opus-harness

讓較弱模型（Opus 4.8）維持工作品質的鷹架：模型越弱、鷹架越硬。

## 安裝

前提：**PowerShell 7（`pwsh`）**。hooks、測試、bench 子行程全部跑在 pwsh 上；Windows PowerShell 5.1 不支援。系統沒有 pwsh 時，hooks 對 Claude Code 是非阻斷錯誤＝**fail-open 全放行**（等同沒裝 harness，不會卡住工作，但也沒有閘門保護）。

### Windows

1. `winget install --id Microsoft.PowerShell`（裝完開新終端讓 PATH 生效，`pwsh -v` 應為 7.x）
2. Claude Code 內：`/plugin marketplace add soapproject/opus-harness`
3. `/plugin install opus-harness@opus-harness-local`
4. 重啟 Claude Code session

### Ubuntu

1. `sudo snap install powershell --classic`（或照 [Microsoft apt 指引](https://learn.microsoft.com/powershell/scripting/install/install-ubuntu)）
2. `pwsh -v` 確認 7.x
3. Claude Code 內：`/plugin marketplace add soapproject/opus-harness`
4. `/plugin install opus-harness@opus-harness-local`
5. 重啟 Claude Code session

從本地 clone 安裝：步驟相同，`marketplace add` 的參數改成 clone 路徑（repo 兼作自身 marketplace：`marketplace.json` 的 `source: "./"` 相對 repo 根解析）。macOS 理論相容（pwsh＋平台中立路徑），未實測。

### 更新（cutover）

已安裝的 plugin 是 SHA 釘選的快取副本，repo 變更**不會**自動生效：

1. （本地 clone 安裝者）clone 切到 `master` 並 pull 到最新
2. `/plugin marketplace update opus-harness-local`
3. `/plugin update opus-harness`（或移除後重裝）
4. 重啟 session

**嚴禁在未合併分支 checkout 狀態下 update**——那會把分支內容發佈成 live hooks，繞過 human-merge-gate。

## 指令

| 指令 | 用途 |
|---|---|
| `/opus-harness:calibrate` | 每專案一次：偵測工具鏈 → `.claude/harness/config.json` |
| `/opus-harness:cycle <任務>` | 主流程：量化 spec → 計畫(自我審查) → TDD → 三面向投票 → retro |
| `/opus-harness:retro` | 經驗蒸餾（兩次門檻 → CLAUDE.md ## Lessons） |
| `/opus-harness:bench` | harness 回歸測試（golden set） |

## 迭代協定（spec §10 摘要）

- 每條硬約束登記於 `constraints.md`（防範模式／證據／鬆綁階梯／挑戰條件）。
- hooks 觸發寫入專案 `telemetry.jsonl`；高摩擦約束優先檢討。
- 模型升級：bench 對比 → 逐一 ablation（手動關約束重跑）→ 沿鬆綁階梯放鬆 → scorecard 監測。
- lesson 級改進自動（/retro 兩次門檻）；機制級走分支 + bench A/B + **受保護分支由人類核准合併（不可配置；預設分支恆受保護）**。
- 開發/hotfix 類分支（受保護集合以外的一切）：agent 主動**分段 merge**（綠階段才合）；merge message 寫 why 不寫 what。受保護集合定義與細節見 `constraints.md` human-merge-gate 與 harness-cycle skill。
