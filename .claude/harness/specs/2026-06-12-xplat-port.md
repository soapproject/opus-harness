# 跨平台移植（Ubuntu + Windows 單一實作）量化 Spec

日期：2026-06-12 ｜ cycle：20260612-xplat-port

背景：硬閘層（hooks、runner、tests）目前綁定 Windows PowerShell 5.1。公司機器為 Ubuntu。
方案（已與使用者確認）：統一改用 PowerShell 7（pwsh，跨平台），不維護雙引擎；路徑處理全部改平台中立寫法。
已盤點的環境事實：本機（Windows）尚無 pwsh、無 WSL → Windows 端先裝 pwsh；Linux 驗證採 GitHub Actions ubuntu job（repo 已公開於 github.com/soapproject/opus-harness）。

已知的四個移植阻塞點（前期審查盤出）：
1. hooks.json 寫死 `powershell.exe`
2. 腳本內字面值反斜線路徑（如 `Join-Path $dir ".claude\harness"`）在 Linux 不解析
3. gate-ratchet 的 `/`→`\` 正規化與 `$root\docs\*` 比對方向在 Linux 相反
4. 測試 helper 的引號跳脫基於 PS 5.1 行為；pwsh 7.3+ 原生引數傳遞規則不同，需重驗

<!-- 以下五區塊為硬性要求，標題不得改字，缺一不得進入 Phase 2 -->

## 量化目標
- [ ] G1: 全套 Pester 於 **Windows pwsh 7** 執行 = 0 failed（既有 45 + 新增之跨平台測試）
- [ ] G2: 同一套測試於 **Ubuntu（GitHub Actions ubuntu-latest）** = 0 failed，workflow 常駐為 Linux 回歸防線
- [ ] G3: `git grep -nE "\bpowershell(\.exe)?\b"` 於 hooks/、bench/、tests/ = 0（含裸 `powershell` 引用；文件中描述性提及不計）[計畫審查 R1 修訂：原樣式漏抓無 .exe 引用]
- [ ] G4: `git grep -cE '\.claude\\harness'`（單一字串字面值反斜線 join）於 *.ps1 = 0
- [ ] G5: Windows 不退化：`claude plugin validate` 通過；G1 同套件數全綠
- [ ] G6: README 含 Ubuntu 與 Windows 的 pwsh 安裝步驟（各 ≤ 5 步可複製貼上）

## 邊界（Out of scope）
- 不做：bash 重寫（理由：雙實作維護成本）
- 不做：Windows PowerShell 5.1 作為 hook 引擎的持續支援（理由：統一 pwsh；Windows 裝 pwsh 為前提，入 README）
- 不做：完整 CI 矩陣（僅單一 ubuntu job 作為 G2 驗證；windows job 留待日後）
- 不做：macOS 實測（理論相容，README 註明未驗證）
- 不做：任何 gate 行為語意變更（純移植；行為變更=機制級，另開 cycle）

## 驗證工具與方法
| 目標 | 驗證指令 | 通過判準 |
|---|---|---|
| G1 | `pwsh -NoProfile -Command "$r = Invoke-Pester -Path tests -PassThru -Output None; exit $r.FailedCount"` | exit 0 |
| G2 | GitHub Actions workflow `linux-tests`（push 觸發） | run conclusion = success |
| G3 | `git grep -nE "\bpowershell(\.exe)?\b" -- hooks bench tests` | 無輸出 |
| G4 | `git grep -lE "claude\\\\harness" -- "*.ps1"` | 無輸出 |
| G5 | `claude plugin validate .` ＋ G1 | 皆通過 |
| G6 | 人工檢視 README | 兩平台步驟齊備 |

## 測試案例清單
| ID | 類型 | Given / When / Then |
|---|---|---|
| T1 | happy | Given 既有 45 測試, When 於 pwsh 7 執行, Then 全綠（含引數傳遞 helper 在 pwsh 下行為正確） |
| T2 | happy | Given 同套件, When 於 ubuntu-latest pwsh 執行, Then 全綠（fixtures 路徑為 POSIX 分隔符） |
| T3 | edge | Given Find-HarnessDir 收到含正斜線的輸入路徑(Windows 上), When 探索, Then 仍找得到 harness 目錄（新增測試） |
| T4 | edge | Given gate-ratchet 收到 POSIX 風格 file_path（Linux）, When red≥limit 且目標在 docs/ 下, Then 正確放行；目標在 src/ 下, Then 正確 block（新增測試，平台中立斷言） |
| T5 | error | Given 系統無 pwsh, When hook 觸發, Then Claude Code 視為非阻斷錯誤=天然 fail-open（文件化，不寫自動測試） |

## 風險與不確定
- pwsh 7.3+ NativeCommandArgumentPassing 改變引數跳脫 → 測試 helper 的 `-replace '"','\"'` 可能反而錯（偵測：T1 在 pwsh 上紅；對策：依 $PSVersionTable 分支或改用 stub 檔案傳遞）
- GitHub Actions 的 Pester 版本/模組安裝時間（偵測：workflow 首跑；對策：`Install-Module Pester -Force` 步驟）
- [計畫審查 R1 改寫] 已安裝 plugin 為 SHA 釘選快取副本：working tree 改動不影響 live hooks（無即時空窗）；真正的風險是 **cutover 缺失**（merge 後未 update/重啟 = 永遠跑舊版）與 **branch 狀態 update**（把未合併分支發佈到 live、繞過 human-merge-gate）。對策：cutover 步驟入 README、第一片仍先裝 pwsh（杜絕切換後裸 pwsh not-found）
- [計畫審查 R1 新增] 本機 Pester 5 裝在 Windows PowerShell user scope，pwsh 7 解析不到（只看得到內建 3.4.0）→ S1 須在 pwsh 內另裝 Pester 5
- [計畫審查 R1 新增] `-like` 不分大小寫但 Linux FS 區分：`Docs/` 會被 docs allowlist 放行——接受為已知限制（fail-open 方向），記入 constraints.md
- Actions 免費額度／公司 proxy 不在本 cycle 控制範圍（公司端首裝時驗證）
