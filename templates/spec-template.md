# <主題> 量化 Spec

日期：<YYYY-MM-DD> ｜ cycle：<cycle_id>

<自由敘述：背景、方案、設計——由 superpowers:brainstorming 產出>

<!-- 以下五區塊為硬性要求，標題不得改字，缺一不得進入 Phase 2 -->
<!-- 注意：「邊界（Out of scope）」的括號為全形 U+FF08/U+FF09；任何機器比對須照此字串 -->

## 量化目標
<!-- 每條必須含數字或可判定的二元條件。壞例：「要快」。好例：「列表 1000 筆首屏 < 200ms」 -->
- [ ] G1: <可判定條件>
- [ ] G2: <可判定條件>

## 邊界（Out of scope）
<!-- 明確排除清單，防 scope creep。執行中超出此界 = 升級條件 #4 -->
- 不做：<項目>（理由：<一句話>）

## 驗證工具與方法
<!-- 從 .claude/harness/config.json 的 commands 引用；缺工具在此階段補裝 -->
| 目標 | 驗證指令 | 通過判準 |
|---|---|---|
| G1 | `<config.commands.x 或專用指令>` | <exit 0 / 輸出含…> |

## 測試案例清單
<!-- 至少各 1 條 happy / edge / error；Phase 3 TDD 直接照單實作 -->
| ID | 類型 | Given / When / Then |
|---|---|---|
| T1 | happy | <…> |
| T2 | edge | <…> |
| T3 | error | <…> |

## 風險與不確定
- <風險>（偵測方式：<…>）
