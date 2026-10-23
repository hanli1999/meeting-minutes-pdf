param(
  [Parameter(Mandatory = $true)][string]$Pdf,
  [Parameter(Mandatory = $true)][string]$OutDir,
  [int]$Width = 794
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# rasterize-pdf.ps1 - PDF -> one PNG per page, using Windows.Data.Pdf (WinRT)
#
# 不用 poppler / PDF.js 的原因见 references/pdf-toolchain-windows.md。
# 关键点: GetFileFromPathAsync 对中文或过长路径会失败,
#          所以先把 PDF 拷到纯 ASCII 临时目录, 渲染完再拷回目标目录。
# ---------------------------------------------------------------------------

$Pdf = (Resolve-Path $Pdf).Path
if (-not (Test-Path $OutDir)) {
  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}
$OutDir = (Resolve-Path $OutDir).Path

# 纯 ASCII 中转目录, 固定复用不堆积
$asciiDir = Join-Path $env:TEMP "pdf-raster"
if (-not (Test-Path $asciiDir)) {
  New-Item -ItemType Directory -Force -Path $asciiDir | Out-Null
}
$asciiPdf = Join-Path $asciiDir "doc.pdf"
$asciiOut = Join-Path $asciiDir "pages"
if (-not (Test-Path $asciiOut)) {
  New-Item -ItemType Directory -Force -Path $asciiOut | Out-Null
}
Copy-Item $Pdf $asciiPdf -Force

Add-Type -AssemblyName System.Runtime.WindowsRuntime

$asTaskOp = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
$asTaskAct = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.FullName -eq 'Windows.Foundation.IAsyncAction' })[0]

function Await($op, $type, $label) {
  try {
    $t = $asTaskOp.MakeGenericMethod($type).Invoke($null, @($op))
    [void]$t.Wait(120000)
    return $t.Result
  } catch {
    $e = $_.Exception
    while ($e.InnerException) { $e = $e.InnerException }
    Write-Output ("FAIL[" + $label + "] " + $e.GetType().FullName + " :: " + $e.Message)
    throw
  }
}

function AwaitAct($op, $label) {
  try {
    $t = $asTaskAct.Invoke($null, @($op))
    [void]$t.Wait(120000)
  } catch {
    $e = $_.Exception
    while ($e.InnerException) { $e = $e.InnerException }
    Write-Output ("FAIL[" + $label + "] " + $e.GetType().FullName + " :: " + $e.Message)
    throw
  }
}

[Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
[Windows.Storage.StorageFolder,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
[Windows.Data.Pdf.PdfDocument,Windows.Data.Pdf,ContentType=WindowsRuntime] | Out-Null
[Windows.Data.Pdf.PdfPageRenderOptions,Windows.Data.Pdf,ContentType=WindowsRuntime] | Out-Null

$file   = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($asciiPdf)) ([Windows.Storage.StorageFile]) 'GetFileFromPath'
$doc    = Await ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)) ([Windows.Data.Pdf.PdfDocument]) 'LoadFromFile'
Write-Output ("[raster] page count = " + $doc.PageCount)

$folder = Await ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync($asciiOut)) ([Windows.Storage.StorageFolder]) 'GetFolder'

for ($i = 0; $i -lt $doc.PageCount; $i++) {
  $page = $doc.GetPage([uint32]$i)
  $name = 'r{0:d2}.png' -f ($i + 1)
  $outFile = Await ($folder.CreateFileAsync($name, [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile]) 'CreateFile'
  $stream  = Await ($outFile.OpenAsync([Windows.Storage.FileAccessMode]::ReadWrite)) ([Windows.Storage.Streams.IRandomAccessStream]) 'OpenAsync'
  $opts = New-Object Windows.Data.Pdf.PdfPageRenderOptions
  $opts.DestinationWidth = [uint32]$Width
  AwaitAct ($page.RenderToStreamAsync($stream, $opts)) ('Render ' + $name)
  $stream.Dispose()
  $page.Dispose()
  Copy-Item (Join-Path $asciiOut $name) (Join-Path $OutDir $name) -Force
  Write-Output ("[raster] wrote " + $name)
}

Write-Output ("[raster] done = " + $OutDir)

# 写 manifest: 列出本次真实产出的页文件。
# 用途: 上一次渲染页数更多时, 目录里会残留 r05.png 这类陈旧页,
#       page-fill.ps1 按 r*.png 扫描会把它们算进填充率, 得出错误结论。
#       manifest 让下游只认本次的页文件。
$manifest = [ordered]@{ pageCount = $doc.PageCount; files = @(); generatedAt = (Get-Date).ToString('s') }
for ($i = 1; $i -le $doc.PageCount; $i++) { $manifest.files += ('r{0:d2}.png' -f $i) }
$manifestPath = Join-Path $OutDir 'pages.manifest.json'
[System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))

$stale = @(Get-ChildItem $OutDir -Filter 'r*.png' -ErrorAction SilentlyContinue | Where-Object { $manifest.files -notcontains $_.Name } | ForEach-Object { $_.Name })
if ($stale.Count -gt 0) {
  Write-Output ("[raster] WARNING stale page files left in dir (excluded by manifest, delete manually): " + ($stale -join ', '))
}
Write-Output ('[raster] manifest = ' + $manifestPath)
Write-Output 'DONE'

# WinRT 在 PowerShell 进程收尾时会抛 0xC0000005, 让退出码变成 3221225477。
# PNG 已经写好, 这里直接结束进程, 让调用方拿到干净的 0。
[System.Environment]::Exit(0)
