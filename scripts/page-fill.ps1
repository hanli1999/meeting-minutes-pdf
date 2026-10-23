param(
  [Parameter(Mandatory = $true)][string]$Dir,
  [int]$TopGuard = -1,
  [int]$BotGuard = -1,
  [double]$Threshold = 66.0
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# page-fill.ps1 - 扫描每页 PNG 的内容填充率
#
# 填充率 = 内容首末行之间的高度 / 可用高度 (去掉页眉页脚保护带)
# 判定"有墨迹": 行内每隔 2 像素采样, 只要有一处 RGB 之和 < 600 即认为该行有内容
# 保护带默认按图高比例推算 (A4 @1685px: 顶部 112 / 底部 108)
# ---------------------------------------------------------------------------

$Dir = (Resolve-Path $Dir).Path

# 优先读 rasterize-pdf.ps1 写的 manifest, 只统计本次真实产出的页文件。
# 没有 manifest 时退回扫描 r*.png, 并提示可能受陈旧页影响。
$manifestPath = Join-Path $Dir 'pages.manifest.json'
$manifestFiles = $null
if (Test-Path $manifestPath) {
  try {
    $mf = [System.IO.File]::ReadAllText($manifestPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($mf.files -and $mf.files.Count -gt 0) { $manifestFiles = @($mf.files) }
  } catch { Write-Output "[fill] manifest unreadable, falling back to r*.png scan" }
}
if ($manifestFiles) {
  Write-Output ("[fill] manifest: " + $manifestFiles.Count + " page(s) -> " + ($manifestFiles -join ', '))
} else {
  Write-Output "[fill] no manifest found, scanning r*.png (stale pages from an earlier run would be included)"
}

$code = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Text;

public class FillScan {
    public static string Scan(string dir, int topGuard, int botGuard, double threshold, string[] wanted) {
        string[] files;
        if (wanted != null && wanted.Length > 0) {
            files = new string[wanted.Length];
            for (int i = 0; i < wanted.Length; i++) files[i] = Path.Combine(dir, wanted[i]);
        } else {
            files = Directory.GetFiles(dir, "r*.png");
        }
        Array.Sort(files);
        StringBuilder sb = new StringBuilder();
        double sum = 0; int under = 0; string bad = "";
        foreach (string f in files) {
            using (Bitmap bmp = new Bitmap(f)) {
                int w = bmp.Width, h = bmp.Height;
                int tg = topGuard, bg = botGuard;
                if (tg < 0) tg = (int)Math.Round(h * 0.0665);
                if (bg < 0) bg = (int)Math.Round(h * 0.0641);
                if (tg + bg >= h) { tg = 0; bg = 0; }
                Rectangle rect = new Rectangle(0, 0, w, h);
                BitmapData data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
                int stride = data.Stride;
                byte[] bytes = new byte[stride * h];
                System.Runtime.InteropServices.Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
                bmp.UnlockBits(data);
                int first = -1, last = -1;
                for (int y = tg; y < h - bg; y++) {
                    bool any = false;
                    int bo = y * stride;
                    for (int x = 0; x < w; x += 2) {
                        int o = bo + x * 3;
                        if (bytes[o] + bytes[o+1] + bytes[o+2] < 600) { any = true; break; }
                    }
                    if (any) { if (first < 0) first = y; last = y; }
                }
                int usable = h - tg - bg;
                double fill = last < 0 ? 0.0 : 100.0 * (last - first + 1) / usable;
                sum += fill;
                if (fill < threshold) { under++; bad += Path.GetFileName(f) + "=" + fill.ToString("0") + "% "; }
                sb.AppendLine(Path.GetFileName(f) + "\tsize=" + w + "x" + h +
                              "\tfirst=" + first + "\tlast=" + last +
                              "\tfill=" + fill.ToString("0.0") + "%");
            }
        }
        sb.AppendLine("--- pages=" + files.Length +
                      " avg=" + (sum / Math.Max(1, files.Length)).ToString("0.0") + "%" +
                      " under" + threshold.ToString("0") + "=" + under + " : " + bad);
        return sb.ToString();
    }
}
'@

Add-Type -TypeDefinition $code -ReferencedAssemblies 'System.Drawing'
[FillScan]::Scan($Dir, $TopGuard, $BotGuard, $Threshold, $manifestFiles)
