---
name: lesson-distill
description: Use during /opus-harness:retro - candidate lessons in retro.md, two-strike promotion to CLAUDE.md ## Lessons with model tags, 30-cap distillation, tier routing.
---

# Lesson Distill

## 候選（第一次出現）

寫入 `.claude/harness/retro.md`，格式：

```
- [YYYY-MM-DD] [候選] <情境一句話> → <該做什麼> （因為 <原因>）
```

## 兩次門檻（晉升）

寫入候選前，先對 retro.md 既有候選做**語意查重**（同類錯誤≠逐字相同：「忘了跑 lint」與「commit 前沒驗證」算同類）。同類第二次出現 → 晉升至 CLAUDE.md `## Lessons` 區塊（無此區塊就建立），格式固定一行、含模型標籤：

```
- [YYYY-MM-DD ×2 @opus-4.8] 當 <情境> 時，<該做什麼>（因為 <一句話原因>）
```

同時把 retro.md 裡對應候選標記 `[已晉升]`。模型標籤填當前實際執行的模型 id（如 @opus-4.8、@fable-5）。

## 層級路由

- 專案特定（此 codebase 的慣例、坑）→ **專案 CLAUDE.md**
- 跨專案、關於模型行為或流程本身（「Opus 在 X 情況會 Y」）→ **全域 `~/.claude/CLAUDE.md`** 的 `## Lessons`

## 上限與蒸餾（cap 30）

任一 CLAUDE.md 的 `## Lessons` 超過 30 條 → 立即蒸餾：合併同類為一條（×N 累計）、90 天未再觸發者搬到同目錄 `retro-archive.md`。

## 退役（模型升級時）

模型標籤 ≠ 當前模型的 harness 級 lessons = 再驗證候選：bench/實際工作顯示不再需要 → 搬 archive。lessons 也要能退役，CLAUDE.md 不是只進不出。
