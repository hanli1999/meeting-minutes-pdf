# Windows 渲染与校验工具链

本机（Windows 10 / PowerShell 5.1）**没有 node、python、poppler、playwright**，
只有系统自带 Edge 与 WinRT。下面这套链路在这台机器上跑通过，产出可复现。

## 0. 链路总览

```
源 HTML ──render-pdf.ps1──> PDF ──rasterize-pdf.ps1──> 每页 PNG ──page-fill.ps1──> 填充率表
                │
                └──inspect-pdf.ps1──> 页数 / MediaBox / 链接目标 / 内嵌字体
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\render-pdf.ps1    -Html "C:\p\src.html" -Pdf "C:\p\out.pdf"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\rasterize-pdf.ps1 -Pdf  "C:\p\out.pdf" -OutDir "C:\p\raster"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\page-fill.ps1    -Dir   "C:\p\raster"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\inspect-pdf.ps1  -Pdf   "C:\p\out.pdf"
```

四个脚本都在 skill 的 `scripts\` 目录下，无外部依赖，只用 PowerShell + 系统组件。

## 1. 渲染：Edge headless

### 1.1 命令形态

```powershell
$Edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
& $Edge --headless=new --disable-gpu --no-pdf-header-footer `
       --user-data-dir="$env:TEMP\edge-prof-$PID" `
       --print-to-pdf="$tmpOut" "file:///$($html -replace '\\','/')"
```

必带参数：

| 参数 | 作用 |
|---|---|
| `--headless=new` | 新版无头模式，旧 `--headless` 对 `--print-to-pdf` 支持不稳定 |
| `--no-pdf-header-footer` | 去掉 Edge 默认的页眉页脚（日期/标题/URL），否则会叠在自绘页脚上 |
| `--user-data-dir` | 独立配置目录，避免和已开着的 Edge 实例抢 profile（否则命令会挂起或静默失败） |
| `--print-to-pdf=<path>` | 输出路径，**必须是绝对路径** |

### 1.2 两个必须绕开的坑

**坑 1：输出是异步落盘。** 命令返回时 PDF 还没写完。
直接 `Test-Path` 判断会拿到"文件不存在"的假阴性，或者读到半截文件。

正确做法是轮询等文件大小稳定：

```powershell
$last = -1
for ($i = 0; $i -lt 120; $i++) {
    Start-Sleep -Milliseconds 250
    if (Test-Path $tmpOut) {
        $len = (Get-Item $tmpOut).Length
        if ($len -gt 0 -and $len -eq $last) { break }   # 连续两次大小一致 = 写完了
        $last = $len
    }
}
```

**坑 2：Edge 不覆盖已存在的文件。** 目标名已存在时，命令**返回成功但文件内容不变**——
这是最阴的一种失败：你以为重新渲染了，实际交的还是旧版。

正确做法：渲染到临时名，再强制移动。

```powershell
$tmpOut = "$Pdf.__tmp__.pdf"
& $Edge ... --print-to-pdf="$tmpOut" ...
# 等稳定后
Move-Item -Force $tmpOut $Pdf
```

### 1.3 量块高：定位溢出

页面溢出了要删内容时，别凭感觉。用 `--dump-dom` 把每个 block 的实际几何量打出来：

在 HTML 里临时插一段脚本：

```html
<script>
window.addEventListener('load', function () {
  var out = [];
  document.querySelectorAll('section.sheet, .page, .card, .cols, table.tbl, ul.l1').forEach(function (el, i) {
    var r = el.getBoundingClientRect();
    out.push(i + '\t' + el.className + '\ttop=' + Math.round(r.top + window.scrollY) +
             '\th=' + Math.round(r.height) + '\toffsetTop=' + el.offsetTop);
  });
  document.title = 'MEASURE:' + out.join('|');
});
</script>
```

然后：

```powershell
& $Edge --headless=new --disable-gpu --user-data-dir="$env:TEMP\edge-prof-$PID" --dump-dom "file:///$html"
```

从输出的 `<title>` 里解析出每块的 offsetTop / height，就能知道哪个块越过了页底边界，
该把整块挪到下一页还是拆分。

## 2. 光栅化：Windows.Data.Pdf

### 2.1 为什么是 WinRT

试过并放弃的方案：

| 方案 | 为什么不行 |
|---|---|
| poppler（pdftoppm） | 压缩包两次下载都超时残缺，解压出来的 exe 跑不动 |
| PDF.js + Edge headless 截图 | 渲染时序不可控，canvas 还没画完就被截图/导出；`file://` 下 ES module 被 CORS 拦 |
| 内置 Browser 工具 | 空白页，PDF 内嵌查看器不渲染 |

Windows 内置的 `Windows.Data.Pdf` 是系统组件，不需要安装任何东西，是这台机器上唯一可靠的路径。

### 2.2 调用要点

```powershell
Add-Type -AssemblyName System.Runtime.WindowsRuntime

# 三个类型必须先加载，否则 New-Object 失败
[Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
[Windows.Storage.StorageFolder,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
[Windows.Data.Pdf.PdfDocument,Windows.Data.Pdf,ContentType=WindowsRuntime] | Out-Null
[Windows.Data.Pdf.PdfPageRenderOptions,Windows.Data.Pdf,ContentType=WindowsRuntime] | Out-Null
```

await 桥接靠反射拿 `AsTask`：

```powershell
$asTaskOp = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
$asTaskAct = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.FullName -eq 'Windows.Foundation.IAsyncAction' })[0]
```

`GetFileFromPathAsync` 对**含中文或过长的路径会失败**。
解决：先把 PDF 拷到纯 ASCII 目录再加载。

```powershell
$asciiDir = Join-Path $env:TEMP "pdf-raster"
New-Item -ItemType Directory -Force -Path $asciiDir | Out-Null
$asciiPdf = Join-Path $asciiDir "doc.pdf"
Copy-Item $Pdf $asciiPdf -Force
```

### 2.3 渲染宽度与实际输出尺寸

```powershell
$opts.DestinationWidth = [uint32]794
```

传 794 时，A4 页面实际输出 **1191×1685**（浏览器按 A4 比例放大）。后续所有按像素计算的
保护带、坐标都要按 1685 这个高度算，不要按 794 折算。

### 2.4 收尾退出码

脚本跑完后可能以退出码 `3221225477`（0xC0000005）结束——这是 WinRT 在 PowerShell 进程退出时的
正常收尾崩溃，**PNG 已经生成好了，不要重试**。脚本自己会打印 `DONE` 作为成功标记。

## 3. 填充率扫描

### 3.1 算法

逐行扫描 PNG，找第一行和最后一行"有内容"的行，中间高度占可用高度的比例即填充率。

- 有内容的判定：行内每隔 2 像素采样，只要有一处 RGB 之和 < 600 就认为该行有墨迹。
- 可用高度 = 图高 - 上保护带 - 下保护带。
- 保护带：顶部 112px、底部 108px（1685 高的 A4 图上约各 6.6%），用来排除页眉页脚区域。

```powershell
$topGuard = 112
$botGuard = 108
```

换渲染分辨率时按比例缩放：`topGuard = round(h * 0.0665)`、`botGuard = round(h * 0.0641)`。

### 3.2 读数

```
r01.png   first=140   last=1613  fill=88.1%
r02.png   first=158   last=1594  fill=78.2%
r03.png   first=142   last=1610  fill=79.5%
r04.png   first=128   last=1619  fill=85.9%
--- pages=4 avg=82.9% under66=0 :
```

`under66` 必须为 0。某页 under 66 就是这一页内容太少，处置办法见 SKILL.md 的 Failure handling。

### 3.3 实现

用 `System.Drawing` 的 `LockBits` 拿像素数组，`Format24bppRgb` 下 stride = width*3，
逐行只看 BGR 三通道之和。整个文档用 `Add-Type -TypeDefinition` 内联编译 C#，
不需要任何外部程序集（`System.Drawing` 是 .NET Framework 自带）。

## 4. 结构检查：inspect-pdf.ps1

Edge 生成的 PDF **不做对象压缩**（无 `ObjStm`），所以可以用字节级正则直接读出结构。
按 Latin-1（28591）解码全文后匹配：

| 检查项 | 匹配模式 | 通过条件 |
|---|---|---|
| 页数 | `/Count\s+(\d+)` | 等于预期页数 |
| 页面尺寸 | `/MediaBox\s*\[([^\]]*)\]` | 全部等于 `[0 0 594.95996 841.91998]`（A4，PDF point） |
| 链接数 | `/Subtype\s*/Link` | 等于导航项数 |
| 链接目标 | `/Dest\s*/(\w+)` | 每个导航锚点都出现 |
| 内嵌字体 | `/BaseFont\s*/([A-Za-z0-9+#,\-]+)` | 含 `MicrosoftYaHei` |
| 是否压缩 | `ObjStm` | 不存在（存在则本脚本读不准，需换工具） |

已验证的输出（4 页精华版）：

```
pages          = 4
MediaBox       = [0 0 594.95996 841.91998]  x4
links          = 4  dests = acts, disc, next, sum
fonts          = AAAAAA+MicrosoftYaHei-Bold, BAAAAA+MicrosoftYaHei, CAAAAA+MicrosoftYaHei
compressed     = no
```

## 5. PDF 交付规范（来自 pdf skill 的硬性要求）

这几条是规范，不是建议：

- 每页填充率 ≥ 2/3（上面的 66% 阈值就是这条）。
- 多页文档必须有**可见且可点击**的目录/索引 → 妙计版的导航行就是它，
  所以导航锚点必须真的生成 `/Subtype /Link`。
- 全局 `print-color-adjust: exact` → 否则彩色卡片底色在打印时消失。
- 禁 `<br>`、`&nbsp;`、缩小页边距等凑版面手段。
- HTML / CSS / JS 里禁全角标点（`，`、`。`、`；`、`（`、`）` 等）——
  它们会让解析器报错或被当成标识符。

## 6. 故障速查

| 现象 | 原因 | 处理 |
|---|---|---|
| Edge 命令返回但 PDF 没生成 | profile 被占 / 输出路径是相对路径 | 加 `--user-data-dir`，用绝对路径 |
| PDF 是旧内容 | Edge 不覆盖同名文件 | 渲染到临时名再 `Move-Item -Force` |
| PDF 只有半截 | 输出异步落盘没等 | 轮询等文件大小稳定 |
| 光栅化报路径错误 | `GetFileFromPathAsync` 不吃中文/长路径 | 先拷到 ASCII 临时目录 |
| 光栅化 0 页 | PDF 没渲染完 | 先确认第 1 步的文件已稳定 |
| PNG 高度不是 1685 | 换了渲染宽度 | 按实际高度重算保护带 |
| 脚本退出码 3221225477 | WinRT 收尾崩溃 | 正常，看 `DONE` 标记 |
| 中文变方块 | 字体没内嵌 | 查 `/BaseFont`，用系统字体名 |
| `.ps1` 报莫名其妙语法错 | 脚本是 UTF-8 无 BOM，PS 5.1 按 GBK 解码 | 给脚本补 UTF-8 BOM |
