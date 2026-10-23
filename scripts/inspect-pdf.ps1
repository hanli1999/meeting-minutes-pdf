param(
  [Parameter(Mandatory = $true)][string]$Pdf,
  [int]$ExpectPages = -1,
  [string]$ExpectDests = ''
)

# ExpectDests 用逗号或空格分隔: -ExpectDests "sum,disc,acts,next"
# (powershell.exe -File 传参不会把数组展开, 所以这里收字符串自己切)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# inspect-pdf.ps1 - 读取 Edge 生成 PDF 的结构信息
#
# Edge 输出的 PDF 不做对象压缩 (无 ObjStm), 所以按 Latin-1 解码后正则直读。
# 如果目标 PDF 含 ObjStm / 交叉引用流, 本脚本读不准, 需换工具解析。
# ---------------------------------------------------------------------------

$Pdf = (Resolve-Path $Pdf).Path
$bytes = [System.IO.File]::ReadAllBytes($Pdf)
$text = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes)

$fail = 0
function Ok($msg)   { Write-Output ("[OK]   " + $msg) }
function Bad($msg)   { Write-Output ("[FAIL] " + $msg); $script:fail++ }
function Info($msg)  { Write-Output ("[INFO] " + $msg) }

Write-Output ("file = " + $Pdf)
Write-Output ("bytes = " + $bytes.Length)
Write-Output ''

# ---- 压缩检查 ----
$compressed = ($text -match 'ObjStm')
if ($compressed) {
  Bad "PDF contains object streams (ObjStm); byte-level parsing may be unreliable"
} else {
  Ok "PDF is not object-compressed; byte-level parsing is reliable"
}

# ---- 页数 ----
$pageCount = $null
$pagesIdx = $text.IndexOf('/Type /Pages')
if ($pagesIdx -ge 0) {
  $start = [Math]::Max(0, $pagesIdx - 300)
  $len = [Math]::Min(600, $text.Length - $start)
  $win = $text.Substring($start, $len)
  $m = [regex]::Match($win, '/Count\s+(\d+)')
  if ($m.Success) { $pageCount = [int]$m.Groups[1].Value }
}
if ($null -eq $pageCount) {
  $m2 = [regex]::Match($text, '/Count\s+(\d+)')
  if ($m2.Success) { $pageCount = [int]$m2.Groups[1].Value }
}
$pageObjs = ([regex]::Matches($text, '/Type\s*/Page(?![s])')).Count

if ($null -eq $pageCount) {
  Bad "page count not found"
} else {
  Ok ("page count = " + $pageCount + " (page objects = " + $pageObjs + ")")
  if ($pageObjs -ne $pageCount) {
    Bad ("page object count (" + $pageObjs + ") != /Count (" + $pageCount + ")")
  }
  if ($ExpectPages -gt 0 -and $pageCount -ne $ExpectPages) {
    Bad ("page count " + $pageCount + " != expected " + $ExpectPages)
  }
}

# ---- 页面尺寸 ----
$boxes = [regex]::Matches($text, '/MediaBox\s*\[([^\]]*)\]')
if ($boxes.Count -eq 0) {
  Bad "no /MediaBox found"
} else {
  $dims = @()
  foreach ($b in $boxes) {
    $nums = $b.Groups[1].Value -split '\s+' | Where-Object { $_ -ne '' } | ForEach-Object { [double]$_ }
    if ($nums.Count -ge 4) {
      $w = $nums[2] - $nums[0]
      $h = $nums[3] - $nums[1]
      $dims += ("{0}x{1}" -f [Math]::Round($w, 2), [Math]::Round($h, 2))
      if ([Math]::Abs($w - 595) -gt 3 -or [Math]::Abs($h - 842) -gt 3) {
        Bad ("non-A4 MediaBox: " + $w + " x " + $h)
      }
    }
  }
  $uniq = $dims | Sort-Object -Unique
  Ok ("MediaBox x" + $boxes.Count + " : " + ($uniq -join ', '))
  if ($uniq.Count -eq 1 -and $uniq[0] -match '595') { Ok "all pages are A4 portrait" }
}

# ---- 链接与目标 ----
$links = ([regex]::Matches($text, '/Subtype\s*/Link')).Count
$dests = [regex]::Matches($text, '/Dest\s*/(\w+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
Ok ("link annots = " + $links)
Ok ("named dests = " + (($dests -join ', ')))
if ($links -eq 0) {
  Bad "no link annotations; navigation is not clickable"
} elseif ($dests.Count -eq 0) {
  Bad "link annotations found but no named destinations"
} else {
  $want = @($ExpectDests -split '[,;\s]+' | Where-Object { $_ -ne '' })
  foreach ($d in $want) {
    if ($dests -contains $d) { Ok ("dest present: #" + $d) }
    else { Bad ("dest missing: #" + $d + " (found: " + ($dests -join ', ') + ")") }
  }
}

# ---- 字体 ----
$fonts = [regex]::Matches($text, '/BaseFont\s*/([A-Za-z0-9+#,\-]+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
if ($fonts.Count -eq 0) {
  Bad "no embedded fonts found"
} else {
  Ok ("embedded fonts = " + ($fonts -join ', '))
  $cjk = $fonts | Where-Object { $_ -match 'YaHei|SimSun|SimHei|SourceHan|NotoSansCJK|MingLiU|PingFang' }
  if ($cjk) { Ok "CJK font embedded" } else { Bad "no CJK font embedded; Chinese may render as tofu" }
}

Write-Output ''
if ($fail -eq 0) {
  Write-Output "All structural checks passed"
  Write-Output 'DONE'
} else {
  Write-Output ("Structural checks FAILED (" + $fail + ")")
  exit 1
}
