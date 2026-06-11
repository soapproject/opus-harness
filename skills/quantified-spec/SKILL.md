---
name: quantified-spec
description: Use during /opus-harness:cycle Phase 1 (brainstorm) - forces the spec to end with five quantified blocks; a spec missing any block must not proceed to planning.
---

# Quantified Spec

spec 檔結尾必須包含以下五個區塊，**標題逐字固定**（供機器檢查），缺一不得進入 Phase 2。
模板正本：plugin 的 `templates/spec-template.md`（直接複製再填；填寫＝替換所有 `<…>` 佔位符，不可留空或刪節）。

## 五區塊硬規則

1. `## 量化目標`——每條含數字或可判定二元條件。不可判定（「要快」「要好維護」）→ 當場改寫（「1000 筆首屏 < 200ms」「新函式圈複雜度 ≤ 10」）。實在無法量化 → 寫成可由 reviewer 判定的明確主張並標注主觀。
2. `## 邊界（Out of scope）`——明確排除清單＋一句話理由。執行中發現需要越界 = 升級條件 #4，停下問人。（注意：標題括號為全形）
3. `## 驗證工具與方法`——表格：每個目標對應驗證指令（優先引用 `.claude/harness/config.json` 的 commands）與通過判準。缺工具（如效能目標但無 benchmark 工具）→ 在本階段補裝，不留到執行期。
4. `## 測試案例清單`——表格（ID/類型/Given-When-Then），至少 1 happy、1 edge、1 error。這張表就是 Phase 3 TDD 的工作清單。
5. `## 風險與不確定`——每條附偵測方式。

## 流程位置

- 與 superpowers:brainstorming 同時使用：對話照它的流程走，產出 spec 時套上本模板。
- 探索程式碼一律 codegraph 優先（codegraph_explore / codegraph_impact），無索引才 Grep/Glob。
- 完成後存檔 `.claude/harness/specs/YYYY-MM-DD-<topic>.md`，並自我檢查五標題齊全才回報。
