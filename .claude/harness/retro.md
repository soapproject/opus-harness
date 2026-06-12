# Retro 候選 lessons（lesson-distill：第一次=候選，同類第二次=晉升 CLAUDE.md）

## cycle 20260612-xplat-port（2026-06-12～13，@fable-5 駕駛）

- [2026-06-12] [候選][已晉升→global ×3] 驗證環境保真：S2 verifier 與 S3 implementer 並行 → 套件污染假紅（16 紅 vs 靜止 45 綠）→ 會跑測試的 verifier 必須序列化或隔離 worktree（因為跑套件不是唯讀操作）
- [2026-06-12] [候選][已晉升→global，併入上條] S4 verifier 用 Windows PowerShell 5.1 host 跑 pwsh 判準的套件 → 17 假紅 → verifier 必須逐字用 spec 驗證表指令含引擎（因為換引擎＝換語意）
- [2026-06-13] [候選][已晉升→global，併入上條] Git Bash 鏈跑同一套件 → CJK 斷言假紅 5 筆，規定 pwsh 直跑 50/50 綠（因為子行程編碼鏈隨宿主 shell 改變）。裁決法已固定：安靜樹＋規定指令重跑
- [2026-06-12] [候選][已晉升→global ×2] config commands 包 `pwsh -Command "$r=..."` → gate-stop 以 -EncodedCommand 執行時外層先插值 `$r` → 5.1 引擎下假紅狂擋（telemetry 84 筆）、pwsh 引擎下假綠靜音（探針 WRAPPED=0/BARE=5）——同 bug 隨引擎雙向失效（因為雙引號字串會被外層 shell 先展開）
- [2026-06-13] [候選][已晉升→global，併入上條] 專案 CLAUDE.md pre-commit 指令同型雙引號 footgun（我自己 S8 寫進去的）→ 已改單引號＋立規
- [2026-06-12] [候選][已晉升→project ×2] PS 5.1 無 -Encoding 的 Get-Content/Set-Content 字串手術毀掉 UTF-8 中文檔（T4 期 BOM 亂碼＋S2 前計畫檔全毀兩例）→ repo 文字檔一律檔案工具
- [2026-06-13] [候選][機制級→下個 cycle] gate 自我測試 bench case：故意紅 repo 斷言 stop-gate 必擋、故意綠斷言必放行（因為本 cycle 證明 gate 可雙向失效而無偵測）
- [2026-06-13] [候選][機制級→下個 cycle] 約束無聲失效偵測：對「常設約束長期零觸發」報警；telemetry 12–24 連發 burst 顯示 escape valve（block≥2 放行）可能未生效，需 live 實例驗證
- [2026-06-13] [候選] cutover 需 version bump：`claude plugin update` 以版本號判斷，不 bump 不發佈（已立 project house rule）
- [2026-06-12] [候選] calibrate 的 gitignore 步驟缺 state.json/telemetry.jsonl（本次已補 calibrate.md 步驟 6）
- [2026-06-13] [候選][機制級→下個 cycle] 測試 CJK 斷言環境敏感：BeforeAll 統一設 console 編碼（[Console]::OutputEncoding）降低宿主依賴
- [2026-06-13] [候選] 維護面向評分 7＝壓線：deferred minors 清單（gate-ratchet cwd 正規化一致性、lib Join-Path 慣用法、fixture helper 統一 -LiteralPath、payload builder 去重、CI module cache／trigger 範圍、bench.md 類執行性文件納入 G3 掃描）＝下個 harness cycle 的現成 scope
- [2026-06-12] [候選] 評分小組的跨面向警訊要追到底：效能組的 out-of-dimension flag 直接挖出本 cycle 最大 bug（stop-gate no-op）——面向邊界外的觀察不丟棄，回主迴圈裁決
