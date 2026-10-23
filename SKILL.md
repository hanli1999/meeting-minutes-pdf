---
name: meeting-minutes-pdf
description: |
  把会议转写稿 / 录音转文字整理成分层会议纪要，并渲染成飞书妙计（Feishu Miaoji）风格的 A4 PDF：
  蓝色导航行、总结卡、三列浅色小卡、章节规划表、核心共识条、正文三级圆点、行动项表、后续讨论，
  交付前逐页校验填充率、页面尺寸、导航链接与嵌入字体。Use this skill when the user asks for
  "会议纪要" / "会议记录" / "整理成纪要" / "会议纪要 PDF" / "把录音转写整理成 PDF"，或提到
  "飞书妙计、妙记风格的纪要、妙计排版"。Do not use it for 逐字稿校对、纯录音转文字、
  只要聊天复述、学术论文式纪要排版，只要 Word / PPT 而不要 PDF 的请求，
  或把飞书上已有的会议纪要汇总成周报/回顾报告（那用 lark-workflow-meeting-summary）。
descriptions:
  zh-Hans: "把会议转写稿整理成飞书妙计风格的分层会议纪要 PDF，逐页校验后交付。"
displayNames:
  zh-Hans: "会议纪要 PDF"
---

# 会议纪要 PDF（飞书妙计版式）

把一份口语化的转写稿，变成能直接发给与会者看的纪要 PDF。默认版式是飞书妙计的蓝/青/橙三色卡结构；
用户点名要别的风格时可以换视觉，但下面这套**信息结构**（总结 → 讨论 → 行动项 → 后续讨论）不要拆。

## Inputs to collect

开工前先确认这四项，缺的就问，不要用假设硬上：

1. **原稿**：转写稿 / 录音转文字 / 用户粘贴的聊天记录的实际路径。没有可读原文时停下来要文件——
   凭印象补写的纪要没有事实基础，等于编。
2. **会议元信息**：主题、日期、时长、参会人（至少到角色级）。转写稿里读得到的直接用，读不到的留空并标注。
3. **交付形态**：目标页数（默认先出 4 页精华版）、要不要长版、要不要目录页。
4. **隐私口径**：哪些真名 / 单位 / 选题不能落纸；哪些经营数据要标「自述/转述、未经第三方核验」。

## Procedure

1. **读原稿，产出结构化中间稿（Markdown）**
   先按 `references/transcript-extraction.md` 的规则把转写稿拆成四段：总结要点 / 讨论记录 /
   行动项 / 后续讨论。原因：口语稿里 80% 是过程性闲聊，直接排版会得到"每段都通但读完不知道发生了什么"；
   先抽结构再排版，后面才有素材可分页。

2. **定版面切分（默认 4 页精华版）**
   实测可过校验的切分是：

   | 页 | 内容 |
   |---|---|
   | P1 | 标题 + 署名行 + 元信息块 + 导航行 + 总结卡（研究重点三列小卡 / 章节规划表 / 核心共识条） |
   | P2 | 讨论记录 A（第一轮议题，含引语 + 小结） |
   | P3 | 讨论记录 B（第二轮议题，含引语 + 分歧点） |
   | P4 | 行动项表 + 后续讨论与交流（待明确事项 / 风险提示 / 记录与保密说明） |

   原因：P1 的总结卡本身占掉近一整页，2 页装不下；切到 5 页以上则 P2/P3 内容不够，每页填充率会掉到
   66% 以下，直接违反 PDF 交付规范。

   用户要长版时沿用同一套 block：P1 总结不变，讨论记录按议题拆成多页（每页 2–3 个 L1 议题，
   这是让填充率都在 66% 以上的节奏），末尾仍然是"行动项 + 后续讨论"一页。
   页面多了要重新标导航行页码，并再跑一轮逐页校验——长版最容易出现中间某页掉到 66% 以下。

3. **写 HTML**
   版式规范（页边距、字号、色板、10 个 block 的 CSS）见 `references/miaoji-layout.md`。几条最常踩的：
   - `@page { size: A4 portrait; margin: 13mm 15mm; }` + 全局 `print-color-adjust: exact`
     —— 不写 `print-color-adjust` 彩色底会被浏览器丢掉，卡片就没了浅色底。
   - 禁 `<br>` 和 `&nbsp;` 凑版面；换行靠块级元素的自然折行，空白靠 margin。
   - 每个导航目标都要有 `id`（`#sum` / `#disc` / `#acts` / `#next`），不能只有 `name`。
     少一个 `id`，Edge 会静默丢掉那条链接，PDF 里 `/Subtype /Link` 数量就少。
   - 导航行文字带目标页码（总结 1 / 讨论记录 2 / 行动项 4 / 后续讨论 4），读者不用翻。

4. **渲染 PDF**
   用 `scripts/render-pdf.ps1`（Edge headless `--print-to-pdf`）。
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\render-pdf.ps1 -Html "C:\path\src.html" -Pdf "C:\path\out.pdf"
   ```
   脚本已经处理了 Edge 的两个怪癖：输出是异步落盘（内部轮询等文件稳定）、不覆盖同名文件
   （先渲染到临时名再 Move-Item -Force）。直接手敲 `--print-to-pdf` 到已存在的目标名，
   结果是命令"成功"但文件还是旧的。

5. **逐页校验（交付前必做）**
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\rasterize-pdf.ps1 -Pdf "C:\path\out.pdf" -OutDir "C:\path\raster"
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\page-fill.ps1   -Dir  "C:\path\raster"
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\inspect-pdf.ps1 -Pdf  "C:\path\out.pdf"
   ```
   三项都要过：
   - **填充率**：每页 ≥ 66%（PDF 交付规范的"每页至少填 2/3"），脚本会列出每页 first/last/fill。
     同时盯住上限：目标区间 78%–92%，**超过 95% 就是贴边**，下一轮渲染很可能多出一张几乎空白的页。
   - **结构**：页数符合预期、MediaBox 是 A4、导航链接数 = 导航项数且目标锚点都在、字体已内嵌。
   - **目视**：至少打开每页 PNG 看一眼，确认没有表格被截断、孤行甩到底、图文重叠。
     填充率只告诉你"够满"，不告诉你"排得对"。
   - **敏感词检索**：对 HTML 源做一次人名 / 单位 / 选题关键词检索，确认 0 命中。
     这一步很便宜（一次 `Select-String`），但漏掉一次就等于把不该落纸的东西落纸了。

6. **交付**
   给 PDF + 源 HTML，并写一段不超过 5 行的交付说明：页数、每页填充率实测值、结构校验结果、
   以及你没验到的风险点（例如某页目视有疑问、某段数据只有当事人自述）。

## Output contract

- `会议纪要-精华版.pdf`（或用户指定文件名）+ 同名 `.html` 源文件，两者都留在工作目录。
- 一段 ≤5 行的交付说明：页数 / 每页填充率 / 结构校验结果 / 未覆盖风险。
- 纪要正文里的每个事实都能回指到原稿某处；不能回指的（推算、概括性判断）用"自述/转述"标注。

## Failure handling

- **某页填充率 < 66%** → 这一页内容太少。把相邻页的一部分内容挪过来或合并两页；
  不要靠加大字号、行高、页边距凑版面——那会让正文密度失真，而且各页之间不一致。
- **某页填充率 > 95%** → 同一类风险的另一半：这页已经贴边，多半会溢出成一张几乎空白的页。
  压缩这一页最高的那列/那块内容的文字长度（不要删事实），而不是加页边距。
- **渲染出的页数比上一轮多，填充率表里冒出多出来的页** → 目录里残留着上一轮的 `rNN.png`。
  `rasterize-pdf.ps1` 会写 `pages.manifest.json` 并只按本次页文件统计，必要时把残留文件删掉再测。
- **渲染出计划外的页数 / 末页被截断** → 内容溢出。先量块的实际高度再剪，不要凭感觉删：
  在 HTML 里插一段内联脚本，用 Edge `--dump-dom` 把每个 block 的 offsetTop/height 打出来，
  按行高边界切。溢出量大的话把整块挪到下一页而不是硬压缩。
- **导航链接少了** → 检查对应锚点的 `id` 是否真的存在（只写 `name` 不算），以及该锚点是否在首屏之外
  （Edge 只对已渲染的锚点建链接）。
- **WinRT 光栅化失败 / 拿不到页数** → `Windows.Storage.StorageFile::GetFileFromPathAsync` 对含中文或过长的
  路径会失败。`scripts/rasterize-pdf.ps1` 已把 PDF 先拷到纯 ASCII 临时目录再加载。
- **Edge 报成功但 PDF 没更新** → Edge 不覆盖已存在文件，用脚本的临时名 + 强制移动流程，别直接写目标名。
- **PDF 里的中文变方块** → 字体没内嵌。`inspect-pdf.ps1` 会列出 `/BaseFont`，确认含 `MicrosoftYaHei`；
  换字体栈时用系统已装的字体名，不要用网页字体。

## Examples

**Input**：用户给一份会议录音转写稿（46 分钟，讨论"校地协同大学生创业孵化机制"），
要求"整理成会议纪要 PDF，模仿飞书妙计那种风格，先出 4 页精华版"。

**Good path**：
1. 读转写稿 → 按 `references/transcript-extraction.md` 抽出总结要点 / 两轮讨论 / 6 条行动项 / 3 条待明确事项；
   导师姓名与拟就业单位不落纸，发言人一律角色化，经营数据标"自述"。
2. 按 4 页结构切分，按 `references/miaoji-layout.md` 写 HTML（正文 10pt/1.68，`#3370ff` 蓝、`#07856c` 青、`#ff8800` 橙）。
3. `render-pdf.ps1` 渲染 → `rasterize-pdf.ps1` 出 4 张 PNG → `page-fill.ps1` 得
   88.1% / 78.2% / 79.5% / 85.9% → `inspect-pdf.ps1` 得 4 页、MediaBox A4、4 条 `/Subtype /Link`
   指向 `#sum`/`#disc`/`#acts`/`#next`、字体 `MicrosoftYaHei` + `-Bold` 内嵌。
4. 目视 4 张 PNG → 交付 PDF + HTML + 一行填充率说明。

**Bad path**：直接按转写稿逐段铺进 HTML 排成一个 14 页长文档——页数超预期、P4 溢出 419px、
导航链接因缺 `id="acts"` 全被丢掉，最后拿一个"看起来挺像"的 PDF 交付。

## Windows (win32) platform notes

本 skill 的脚本只用 PowerShell 5.1 + 系统自带 Edge + WinRT，不依赖 node / python / poppler / bash。

- 执行 `.ps1` 用 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script> -Param value`。
  直接 `.\script.ps1` 可能被执行策略拦住。
- 脚本文件是 UTF-8 **with BOM**。PowerShell 5.1 在中文系统上默认按 GBK 解码无 BOM 的 UTF-8，
  会把引号配对搞坏、报莫名其妙的解析错误。改脚本后若报语法错，先查 BOM。
- `rm -- "<path>"` **不展开 PowerShell 变量**。写成 `rm -- "$dir\file.png"` 会原样传字符串、
  报 "No such file or directory"，必须先把路径拼成完整字面量再传。
- 文件读写一律显式 `-Encoding UTF8`；`Get-Content` 不带参数在中文系统上会读出乱码。
- 不要用 `Remove-Item` 清理临时产物；本机策略会拦，删除走 `rm -- "<字面量路径>"`。
- 脚本里的中文输出/默认路径都要求 BOM；如果临时新建脚本，先补 BOM 再运行。

## 附加资源

- `references/miaoji-layout.md` - 飞书妙计版式规范：页边距、字号、色板、10 个 block 的 CSS、实测数值
- `references/transcript-extraction.md` - 转写稿抽取规则：四段模型、发言人角色化、数据标注、信号筛选
- `references/pdf-toolchain-windows.md` - Windows 渲染与校验工具链：Edge headless、WinRT 光栅化、填充率扫描
- `scripts/render-pdf.ps1` - HTML → PDF（Edge headless，含异步落盘与不覆盖处理）
- `scripts/rasterize-pdf.ps1` - PDF → 逐页 PNG（Windows.Data.Pdf）
- `scripts/page-fill.ps1` - 逐页内容填充率扫描
- `scripts/inspect-pdf.ps1` - 页数 / MediaBox / 链接目标 / 内嵌字体结构检查
