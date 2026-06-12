---
description: harness 回歸測試：跑 golden set、rubric 評分、對比 baseline
argument-hint: [case 名…]（空 = 全部）
---

# /opus-harness:bench

opus-harness repo 位置：本指令檔所在 plugin 的根目錄（commands/ 上一層）。以下 `<plugin>` 指該路徑。

## 1. 機械執行

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <plugin>\bench\runner.ps1 -KeepWork
```

有引數時加 `-Case <名稱…>`。讀取 `<plugin>\bench\results\` 最新的 `*.json`。
任何 case `verifyExit ≠ 0` → 該 case 總分 0（rubric 必要條件）；`verifyExit = -2` → 該 case 配置錯誤（缺 verify.ps1），跳過並回報。

## 2. Rubric 評分（每個 verify 過的 case）

派 1 個 subagent（model: 繼承主模型），輸入：case 的 `rubric.md`＋`spec.md`＋該 case workdir 的 `git diff <startCommit>..HEAD`。要求回 JSON：

```json
{ "scores": { "正確性": 8, "可維護性與可讀性": 7, "效能": 8, "資安": 9 }, "total": 7.9, "notes": "..." }
```

（total 按 rubric 權重計算：0.4/0.3/0.15/0.15。）

## 3. 對比與回報

每 case 對比 `baseline/scores.json` 的 total：**≥ baseline × 0.9 = 達標**（spec §1）。
首次執行（無 `baseline/scores.json`）→ 本次得分寫入該檔成為 baseline，視為達標（rubric 規則）。
回報表格：

| case | verify | total | baseline | 達標 |

全表＋未達標 case 的 notes 摘要。提醒使用者：機制級 harness 變更要把本次結果（results JSON）隨變更一起 commit——人類核准合併（constraints.md human-merge-gate）。

## 4. 清理

評分完成後，逐 case 對其 repo 執行 `git worktree remove --force <workdir>`（runner -KeepWork 留下的）；再到各 repo 跑 `git worktree prune`。
