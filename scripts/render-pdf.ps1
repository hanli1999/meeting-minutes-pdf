param(
  [Parameter(Mandatory = $true)][string]$Html,
  [Parameter(Mandatory = $true)][string]$Pdf,
  [string]$Edge = ''
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# render-pdf.ps1 - HTML -> PDF via Edge headless
#
# 处理 Edge 的两个坑:
#   1) 输出是异步落盘 -> 轮询等文件大小连续两次一致
#   2) 不覆盖同名文件 -> 先渲染到唯一临时名, 再 Move-Item -Force 覆盖目标
#
# 本脚本不使用 Remove-Item: 本机策略会拦永久删除, 临时文件改用唯一名规避,
# profile 目录复用固定路径, 不产生堆积。
# ---------------------------------------------------------------------------

if (-not $Edge) {
  $edgeCandidates = @(
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
  )
  $Edge = $edgeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $Edge) {
    $Edge = (Get-Command msedge.exe -ErrorAction SilentlyContinue).Source
  }
}
if (-not $Edge -or -not (Test-Path $Edge)) {
  throw 'Edge not found. Install Microsoft Edge or pass -Edge <path>.'
}

$Html = (Resolve-Path $Html).Path
$pdfDir = Split-Path -Parent $Pdf
if ($pdfDir -and -not (Test-Path $pdfDir)) {
  New-Item -ItemType Directory -Force -Path $pdfDir | Out-Null
}
$Pdf = [System.IO.Path]::GetFullPath($Pdf)

# 唯一临时名, 避免与任何已存在文件冲突, 也就无需预先删除
$tmpPdf = Join-Path $pdfDir ("render-" + [Guid]::NewGuid().ToString('N') + ".pdf")

# profile 目录固定复用, 避免每次跑都堆积一份
$profileDir = Join-Path $env:TEMP "edge-prof-meeting-minutes-pdf"
if (-not (Test-Path $profileDir)) {
  New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
}

$url = 'file:///' + ($Html -replace '\\', '/')
$argList = @(
  '--headless=new'
  '--disable-gpu'
  '--no-pdf-header-footer'
  "--user-data-dir=$profileDir"
  "--print-to-pdf=$tmpPdf"
  $url
)

Write-Output "[render] edge  = $Edge"
Write-Output "[render] html  = $Html"
Write-Output "[render] pdf   = $Pdf"

Start-Process -FilePath $Edge -ArgumentList $argList -WindowStyle Hidden -Wait | Out-Null

# 轮询等输出稳定: 连续两次读取大小一致即认为写完
$stable = $false
$last = -1
for ($i = 0; $i -lt 240; $i++) {
  Start-Sleep -Milliseconds 250
  if (Test-Path $tmpPdf) {
    $len = (Get-Item $tmpPdf).Length
    if ($len -gt 0 -and $len -eq $last) { $stable = $true; break }
    $last = $len
  }
}

if (-not $stable -or $last -le 0) {
  throw "[render] Edge did not produce a PDF within 60s (last size = $last bytes)."
}

Move-Item -Force $tmpPdf $Pdf
$finalLen = (Get-Item $Pdf).Length
Write-Output "[render] done  = $Pdf ($finalLen bytes)"
Write-Output 'DONE'
