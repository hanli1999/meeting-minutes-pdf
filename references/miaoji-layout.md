# 飞书妙计版式规范（miaoji layout）

本文件是**可复制的版式规格**，不是介绍性文章。照着它写 HTML，渲染出来就是飞书妙记「智能纪要」的观感。
下面的数值全部来自一份已交付并逐页校验通过的 4 页纪要（`会议纪要-精华版.pdf`），
不是设计推测；改数值前先想清楚它影响哪一项校验。

## 1. 页面几何

```css
@page { size: A4 portrait; margin: 13mm 15mm; }
```

- 上下 13mm、左右 15mm。比常见的 14/12 略紧，因为妙计样例的元信息块与总结卡都比较高。
- 每一页用一个 `<section class="sheet">` 包一个 `<div class="page">`，
  `.sheet { break-after: page; }`，最后一个 `.sheet:last-child { break-after: auto; }`。
  这是靠 `break-after` 分页，**不要**用 `page-break-before`，Edge 对前者的支持更干净。
- `.page { min-height: 271mm; padding-top: 3mm; padding-bottom: 7mm; }`（271 + 13 + 13 = 297mm）。
  页脚用绝对定位压在 `.page` 底部，不占正文流。

## 2. 排版基线

| 项 | 值 |
|---|---|
| 正文字号 | `10pt` |
| 正文行高 | `1.68` |
| 字体栈 | `"Microsoft YaHei", "PingFang SC", "Hiragino Sans GB", "Source Han Sans SC", sans-serif` |
| 主文色 | `#1f2329` |
| 次级文字 | `#646a73` |
| 弱化文字 | `#8f959e` |
| 描边 | `#e5e6eb` |
| 表头底 | `#f7f8fa` |

```css
* { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
```

少了这两行，所有浅色卡底在打印时会被丢掉——这是最容易漏、且一漏就"看起来不像"的一处。

## 3. 色板

| 角色 | 前景 | 浅底 | 边框 |
|---|---|---|---|
| 蓝（已具备 / 主叙事） | `#3370ff` | `#f4f7ff` | `#d6e2ff` |
| 青（待突破 / 第二议题） | `#07856c` | `#f0fbf8` | `#cdeee7` |
| 橙（待验证 / 风险） | `#ff8800` | `#fff8ef` | `#ffe3c4` |
| 共识条 | `#b8621a`（字）/ `#ff8800`（针） | `#fff8e6` | `#ffe7b8` |

chip 底色：蓝 `#e3ecff`/字 `#2b5fd9`；青 `#d6f2ea`/字 `#07856c`；橙 `#ffeacd`/字 `#c26a12`。

状态标签（表格用）：

```css
.tag.ok   { background:#e8f6ec; color:#1f7a3d; }   /* 结论较稳 */
.tag.warn { background:#fdeee0; color:#b8621a; }   /* 路径待定 */
.tag.info { background:#eaf1ff; color:#2b5fd9; }   /* 需专业意见 */
.tag.mute { background:#f0f1f3; color:#646a73; }   /* 信息待核 */
```

## 4. 十个 block

### 4.1 标题 + 署名行

```css
.doctitle { font-size: 17.5pt; font-weight: 700; color: #1f2329; margin: 0 0 1.5mm 0; }
.byline   { font-size: 9.8pt; color: #646a73; margin: 0 0 3mm 0; }
.byline b { color: #3370ff; font-weight: 500; }
```

标题 17.5pt 是实测值：**19pt 时中文长标题会折成两行，把下面的元信息块顶出首屏**。
标题文案里带日期时更容易触发，尽量控制在 22 个汉字以内。

### 4.2 灰竖线元信息块

```css
.metablock { border-left: 2px solid #d9dbe0; padding: 0.5mm 0 0.5mm 4mm;
             font-size: 9.8pt; color: #1f2329; margin-bottom: 3mm; }
.metablock .mrow { margin: 0 0 1mm 0; }
.metablock .mk  { color: #646a73; margin-right: 2mm; }
.metablock .ai  { color: #8f959e; font-size: 9pt; margin-top: 1.2mm; }
```

包含四行：会议主题 / 会议时间 / 参会人 / AI 生成提示。
最后一行"智能会议纪要由 AI 生成，可能不准确，请谨慎甄别后使用"是妙计原版的固定提示，保留。

### 4.3 导航行（在元信息块内）

```css
.metablock .nav { margin-top: 1.5mm; }
.metablock .nav a { color:#3370ff; text-decoration:none; margin-right:4.5mm; white-space:nowrap; }
.metablock .nav a i { font-style:normal; color:#8f959e; font-size:8.4pt; margin-left:1mm; }
```

```html
<div class="nav">
  <a href="#sum">总结 <i>1</i></a><a href="#disc">讨论记录 <i>2</i></a>
  <a href="#acts">行动项 <i>4</i></a><a href="#next">后续讨论与交流 <i>4</i></a>
</div>
```

**页码是必填项**：读者要靠它知道"行动项"在第 4 页。排版定稿后按最终页码回填。

### 4.4 章节标题

```css
h2.blk { font-size: 13.5pt; font-weight: 700; color: #1f2329; margin: 0 0 3mm 0; }
h3.sub { font-size: 10.8pt; font-weight: 700; color: #1f2329; margin: 3mm 0 1.6mm 0; }
p { margin: 0 0 2mm 0; }
```

续页的 h2 加 `style="margin-top:0"`，因为它紧跟在页面顶部。

### 4.5 总结卡

```css
.card { border:1px solid #e5e6eb; border-radius:8px; padding:4mm 5mm 3mm 5mm; background:#fff; }
.card .cardtitle { font-size:11.2pt; font-weight:700; margin:0 0 2.5mm 0; }
.card .minilab   { font-size:10.2pt; font-weight:700; margin:0 0 2mm 0; }
.cardfoot { text-align:right; font-size:8.2pt; color:#8f959e; margin-top:1.8mm; }
```

卡内顺序固定：**卡标题 → "研究重点" → 三列小卡 → "章节规划" → 表格 → 核心共识条 → "本纪要由 AI 整理生成"**。
卡尾那行小字是妙计原版的落款，别删。

### 4.6 三列浅色小卡

```css
.cols { display:grid; grid-template-columns:1fr 1fr 1fr; gap:3.5mm; margin-bottom:3mm; }
.col  { border:1px solid #e5e6eb; border-radius:6px; padding:2.6mm 3mm; }
.col.c1 { background:#f4f7ff; border-color:#d6e2ff; }
.col.c2 { background:#f0fbf8; border-color:#cdeee7; }
.col.c3 { background:#fff8ef; border-color:#ffe3c4; }
.col .chip { display:inline-block; font-size:8.2pt; line-height:1.45;
             padding:0.3mm 1.8mm; border-radius:3px; margin-bottom:1.6mm; }
.col .coltitle { font-size:10.2pt; font-weight:700; margin:0 0 1.6mm 0; }
.col ul { margin:0; padding-left:4mm; }
.col li { margin-bottom:1.3mm; font-size:9.2pt; line-height:1.56; }
.col li::marker { color:#8f959e; }
```

每列一个状态 chip（已具备 / 待突破 / 待验证）+ 一个列标题 + 3 条要点。
三列是并列的**判断**，不是流程步骤——列与列之间不构成先后。

### 4.7 章节规划表

```css
table.tbl { width:100%; border-collapse:collapse; font-size:9.2pt; margin-bottom:3mm; }
table.tbl th, table.tbl td { border:1px solid #e5e6eb; padding:1.6mm 2.2mm;
                              text-align:left; vertical-align:top; }
table.tbl th { background:#f7f8fa; font-weight:700; }
table.tbl td.st { white-space:nowrap; }
```

列宽用 `style="width:XXmm"` 固定：议题 30mm / 核心内容 自适应 / 依据 34mm / 进展状态 19mm。
「依据」列写证据来源（现场走访自述 / 访谈案例 / 双方讨论 / 访谈提及），
「进展状态」列放彩色 `.tag`——这两列是纪要可信度的落点，不能省。

### 4.8 核心共识条

```css
.consensus { background:#fff8e6; border:1px solid #ffe7b8; border-radius:6px;
              padding:2.6mm 3.4mm; font-size:9.5pt; line-height:1.62; }
.consensus .pin { display:inline-block; width:4mm; height:4mm; border-radius:50%;
                  background:#ff8800; color:#fff; font-size:7pt; font-weight:700;
                  text-align:center; line-height:4mm; margin-right:1.8mm; vertical-align:1px; }
```

写法：`<span class="pin">!</span><b>核心共识：</b>……`，一句话讲清"本次会议共同认可的是什么"。

### 4.9 正文三级圆点

```css
ul.l1 { list-style:none; margin:0 0 1.5mm 0; padding:0; }
ul.l1 > li { position:relative; padding-left:5.6mm; margin-bottom:2.2mm; }
ul.l1 > li::before { content:""; position:absolute; left:1.3mm; top:1.95mm;
                      width:2mm; height:2mm; border-radius:50%; background:#3370ff; }
ul.l2 { list-style:none; margin:1.2mm 0 0 0; padding:0; }
ul.l2 > li { position:relative; padding-left:4.6mm; margin-bottom:1.4mm; }
ul.l2 > li::before { content:""; position:absolute; left:1.3mm; top:2.05mm;
                      width:1.8mm; height:1.8mm; border-radius:50%;
                      border:0.9px solid #9ea4ad; background:#fff; }
ul.l3 { list-style:none; margin:1mm 0 0 0; padding:0; }
ul.l3 > li { position:relative; padding-left:4.2mm; margin-bottom:1.2mm; }
ul.l3 > li::before { content:""; position:absolute; left:1.3mm; top:2.15mm;
                      width:0; height:0; border-left:1.9mm solid #9ea4ad;
                      border-top:1.15mm solid transparent; border-bottom:1.15mm solid transparent; }
ul.l1 > li > b.lab { font-weight:700; }
```

层级语义：**L1 = 议题**（粗体标签）、**L2 = 议题下的方面**、**L3 = 具体事实**。
蓝色实心圆 / 灰色空心圆 / 灰色三角，三种 marker 不可互换。
每条 L3 应当是一句可独立成立的事实（含主语和动作），不能是"另外""还有"这种依赖上文的碎句。

### 4.10 右侧浮图 + 图注

```css
.side { float:right; width:50mm; margin:0 0 3mm 5mm; }
.side .fig { border:1px solid #e5e6eb; border-radius:6px; padding:2mm; background:#fbfcfd; }
.side .fig svg { display:block; width:100%; height:auto; }
.side .cap { font-size:8pt; color:#8f959e; text-align:center; margin-top:1mm; }
```

配图用内联 SVG（`viewBox` + `font-family="Microsoft YaHei, sans-serif"`），不要引外部图片——
Edge 渲染时外部资源可能未就绪，图会留白。配图下必须有 `本图由 AI 生成` 图注。

### 4.11 页脚与分隔线

```css
.pfoot { position:absolute; bottom:0; left:0; right:0; height:5mm;
         font-size:8.5pt; line-height:5mm; text-align:center; color:#8f959e; }
.divider { border:none; border-top:1px solid #e5e6eb; margin:3mm 0; }
```

页脚就是页码，居中，`8.5pt` 灰色。页码必须与导航行标注的页码一致。

## 5. 屏幕预览（可选但强烈建议）

```css
@media screen {
  html { background:#eceef1; }
  body { margin:0; padding:24px 0; background:#eceef1; }
  body > section.sheet {
    width:210mm; min-height:297mm; margin:0 auto 24px; padding:13mm 15mm;
    background:#fff; box-shadow:0 2px 10px rgba(0,0,0,0.14);
    box-sizing:border-box; overflow:hidden;
  }
}
```

屏幕上把每页显示成一张 A4 白纸，方便肉眼核对切页是否在预期位置。
**注意**：`overflow:hidden` 会掩盖溢出——内容超了屏幕上看着正常，打印时才多出一页。
所以屏幕预览只能用来核对视觉，溢出必须靠光栅化后的页数判断。

## 6. 4 页版面的切分与实测

| 页 | 主要 block | 实测填充率 |
|---|---|---|
| P1 | 标题 / 署名 / 元信息+导航 / 总结卡 | 88.1% |
| P2 | 讨论记录（载体与信息通道、能力结构与商业闭环） | 78.2% |
| P3 | 讨论记录续（激励与组织、校内项目外包、产权安排）+ 右侧配图 | 79.5% |
| P4 | 行动项表（7 条）+ 后续讨论与交流（3 组） | 85.9% |

填充率 = 内容首末行之间的高度 ÷ 可用高度（去掉页眉页脚保护带）。
四页都在 66% 以上，说明这个切分既不空也不挤。

**这是两次独立交付的实测值**——第一版（`会议纪要-精华版.pdf`）与 skill 落地后的复现版，
两次都由同一套脚本测得，说明切分可复现：

| 页 | 主要 block | 参考值 | 复现值 |
|---|---|---|---|
| P1 | 标题 / 署名 / 元信息+导航 / 总结卡 | 88.1% | 98.0% |
| P2 | 讨论记录（载体与信息通道、能力结构与商业闭环） | 78.2% | 90.9% |
| P3 | 讨论记录续（激励与组织、校内项目外包、产权安排）+ 右侧配图 | 79.5% | 96.3% |
| P4 | 行动项表 + 后续讨论与交流 | 85.9% | 90.2% |

**填充率有上限，不能只盯着下限。** 复现版首轮渲染时 P1 到了 98.3%，
总结卡多出约 8mm 溢出到第 2 页，产出 5 页、且第 2 页只有 0.8% 内容（一张近乎空白的页）。

- 目标区间：**每页 78%–92%**。
- 超过 **95%** 视为贴边，有溢出风险；某一页掉到 **66%** 以下视为太空，需要补内容。
- 两者都是硬信号：前者表现为多出一张几乎空白的页，后者表现为版面空洞。

**切分经验**：
- 总结卡本身接近一整页高度，所以 P1 不再放别的内容。
- P2/P3 各承载 2–3 个 L1 议题，是让两页填充率都过线的关键；
  一个议题单独占一页会掉到 60% 上下。
- P4 把行动项表和后续讨论放在一页：两者都是清单型内容，凑在一起正好撑满。
- 三列小卡是 grid，**栅格行高由最高的那一列决定**。
  想给 P1 瘦身，先压缩最高列的文案（复现版就是这样把 P1 从溢出裁回一页的，
  改的只是文字长度，没有删事实，也没有加大字号或缩页边距）。

## 7. 常见排版故障与对应改法

| 症状 | 原因 | 改法 |
|---|---|---|
| 标题折成两行，元信息块被挤出首屏 | 标题 19pt | 降到 17.5pt；压缩标题字数 |
| 浅色卡底在 PDF 里是白的 | 缺 `print-color-adjust: exact` | 加上 `*` 选择器那两行 |
| PDF 里的导航链接少了 | 目标只有 `name` 没有 `id` | 补 `id="acts"` 这类 id |
| 渲染出第 5 页 | 某页内容溢出 | 量块高后把整块挪到下一页，别硬压缩 |
| 某页填充率 < 66% | 该页内容太少 | 从邻页挪内容过来，或合并两页 |
| 表格被切断 | 行高溢出页底 | 该表独占一页，或缩短单元格文字 |
| 中文显示为方块 | 字体未内嵌 | 用系统字体名，检查 `inspect-pdf.ps1` 的 `/BaseFont` |
| 屏幕预览看着正常但 PDF 多页 | `@media screen` 的 `overflow:hidden` 掩盖了溢出 | 只信光栅化后的页数 |
