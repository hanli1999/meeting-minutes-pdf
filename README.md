# 会议纪要 PDF Skill（飞书妙计版式）

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Skill Version](https://img.shields.io/badge/version-1.0.0-blue)](#)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%2B%20PowerShell%205.1-informational)](#)

> 把一份口语转写稿，变成能直接发给与会者的**分层会议纪要 PDF** —— 版式对齐飞书妙记「智能纪要」，
> 交付前**逐页校验**，不是"排得整齐"就交差。

---

## ✨ 一句话

**转写稿 → 四段式纪要 → 飞书妙计风格 A4 PDF，逐页量填充率、查结构、看图，全过才交。**

---

## 🚀 5 分钟上手

### 安装

```bash
# 方式 1：git clone
git clone https://github.com/hanli1999/meeting-minutes-pdf.git ~/.claude/skills/meeting-minutes-pdf

# 方式 2：手动复制（npm 包尚未发布，暂不支持 npx skills add）
cp -r meeting-minutes-pdf/ ~/.claude/skills/
```

### 触发

- "整理成会议纪要 PDF"
- "把录音转写整理成 PDF"
- "飞书妙计 / 妙记风格的纪要"
- "做个会议纪要，先出 4 页精华版"

### 依赖

**只依赖 Windows 10 + PowerShell 5.1 + 系统自带 Edge + WinRT。**
不需要 node / python / poppler / playwright / bash。

---

## 📦 包含什么

```
meeting-minutes-pdf/
├── SKILL.md                            ← 主说明书（触发 + 流程 + 失败处理）
├── README.md                           ← 封面/菜单（本文件）
├── LICENSE                             ← MIT
├── .gitignore                          ← 过滤
├── references/
│   ├── miaoji-layout.md                ← 飞书妙计版式规范（可直接抄的 CSS + 实测数值）
│   ├── transcript-extraction.md        ← 转写稿抽取规则（四段模型 / 角色化 / 脱敏）
│   └── pdf-toolchain-windows.md        ← Windows 渲染与校验工具链
└── scripts/
    ├── render-pdf.ps1                  ← HTML → PDF（Edge headless）
    ├── rasterize-pdf.ps1               ← PDF → 逐页 PNG（Windows.Data.Pdf）
    ├── page-fill.ps1                   ← 逐页内容填充率扫描
    └── inspect-pdf.ps1                 ← 页数 / MediaBox / 链接目标 / 内嵌字体检查
```

---

## 📐 四页结构

| 页 | 内容 |
|---|---|
| **P1** | 标题 + 署名行 + 元信息块 + 导航行 + 总结卡（研究重点三列小卡 / 章节规划表 / 核心共识条）|
| **P2** | 讨论记录 A（第一轮议题，含引语 + 小结）|
| **P3** | 讨论记录 B（第二轮议题，含引语 + 分歧点）|
| **P4** | 行动项表 + 后续讨论与交流（待明确事项 / 风险提示 / 记录与保密说明）|

P1 的总结卡本身就占掉近一整页，2 页装不下；切到 5 页以上则 P2/P3 内容不够，
每页填充率会掉到 66% 以下 —— **4 页是实测能过的切分**。
长版沿用同一套 block，讨论记录按议题拆页（每页 2–3 个 L1 议题），末尾仍是"行动项 + 后续讨论"一页。

---

## ✅ 交付前必过的三项校验

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\render-pdf.ps1    -Html "C:\p\src.html" -Pdf "C:\p\out.pdf"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\rasterize-pdf.ps1 -Pdf  "C:\p\out.pdf" -OutDir "C:\p\raster"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\page-fill.ps1    -Dir   "C:\p\raster"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\inspect-pdf.ps1  -Pdf   "C:\p\out.pdf"
```

1. **填充率** —— 每页 ≥ **66%**（PDF 交付规范的"至少填 2/3"）；目标区间 78%–92%，**超过 95% 就是贴边**，下一轮很可能多出一张空白页。
2. **结构** —— 页数符合预期、MediaBox 是 A4、导航链接数 = 导航项数且锚点都在、字体已内嵌。
3. **目视** —— 至少打开每页 PNG 看一眼。**填充率只告诉你"够满"，不告诉你"排得对"。**

外加一步**敏感词检索**：对 HTML 源做一次人名 / 单位 / 选题关键词检索，确认 0 命中。
很便宜（一次 `Select-String`），但漏掉一次就等于把不该落纸的东西落纸了。

---

## 🪟 Windows 平台要点

- 脚本是 **UTF-8 with BOM**。PowerShell 5.1 在中文系统上默认按 GBK 解码无 BOM 的 UTF-8，会把引号配对搞坏、报莫名其妙的解析错误。改脚本后若报语法错，**先查 BOM**。
- 跑 `.ps1` 用 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script> -Param value`，直接 `.\script.ps1` 可能被执行策略拦住。
- 文件读写一律显式 `-Encoding UTF8`；`Get-Content` 不带参数在中文系统上会读出乱码。
- 不要用 `Remove-Item` 清理临时产物；本机策略会拦，删除走 `rm -- "<字面量路径>"`。
- `rm --` **不展开 PowerShell 变量** —— 必须先把路径拼成完整字面量再传。
- Edge headless **不覆盖已存在文件**，且输出是**异步落盘** —— `render-pdf.ps1` 已处理（渲染到临时名再强制移动）。
- `Windows.Storage.StorageFile::GetFileFromPathAsync` 对含中文或过长的路径会失败 —— `rasterize-pdf.ps1` 已先拷到纯 ASCII 临时目录。

---

## 🩹 常见失败与处理

| 症状 | 原因 | 处理 |
|---|---|---|
| 某页填充率 < 66% | 这页内容太少 | 把相邻页内容挪过来或合并两页；**不要**靠加大字号/行高/页边距凑版面 |
| 某页填充率 > 95% | 这页已经贴边 | 压缩最高那列/那块内容的文字长度（不要删事实），而不是加页边距 |
| 页数比上一轮多 | 目录残留上一轮 `rNN.png` | `rasterize-pdf.ps1` 写 `pages.manifest.json` 只按本次统计，必要时清残留 |
| 末页被截断 | 内容溢出 | 先量 block 实际高度再剪（Edge `--dump-dom` 打 offsetTop/height），溢出大就整块挪页 |
| 导航链接少了 | 锚点只有 `name` 没有 `id`，或锚点在首屏外 | 补 `id`；Edge 只对已渲染的锚点建链接 |
| PDF 中文变方块 | 字体没内嵌 | 确认 `/BaseFont` 含 `MicrosoftYaHei`；用系统已装字体名，不用网页字体 |
| Edge 报成功但 PDF 没更新 | Edge 不覆盖同名文件 | 走脚本的临时名 + 强制移动流程，别直接写目标名 |
| WinRT 光栅化失败 | 路径含中文或过长 | 已处理：先拷到 ASCII 临时目录 |

---

## 📝 License

MIT © hanli1999
