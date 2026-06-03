# install.ps1 — one-shot PWA install helper for MdMd (Windows).
#
# Why this exists: PWAs can only be installed from an http(s) origin.
# `file://` does not qualify. This script spins up a tiny 127.0.0.1 web
# server long enough for Edge to load index.html, register the service
# worker, and pre-cache every asset. After install the server exits and
# is never needed again — the PWA runs purely from cached files.
#
# Network: binds 127.0.0.1 only (never the LAN). Zero outbound traffic.

param(
  [int]$Port = 0   # 0 = auto-pick a free port
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $root 'index.html'))) {
  Write-Host "index.html not found next to install.ps1" -ForegroundColor Red
  exit 1
}

# ── Pick a free localhost port ────────────────────────────────────────────────
function Get-FreePort {
  $l = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
  $l.Start(); $p = $l.LocalEndpoint.Port; $l.Stop(); return $p
}
if ($Port -le 0) { $Port = Get-FreePort }

# ── MIME map (small whitelist; everything else falls back to octet-stream) ────
$mime = @{
  '.html'  = 'text/html; charset=utf-8'
  '.js'    = 'application/javascript; charset=utf-8'
  '.css'   = 'text/css; charset=utf-8'
  '.json'  = 'application/manifest+json'
  '.png'   = 'image/png'
  '.svg'   = 'image/svg+xml'
  '.woff2' = 'font/woff2'
  '.md'    = 'text/markdown; charset=utf-8'
}

# ── HTTP listener ─────────────────────────────────────────────────────────────
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
try { $listener.Start() }
catch {
  Write-Host "Failed to bind http://127.0.0.1:$Port/" -ForegroundColor Red
  Write-Host "If you saw an access-denied error, this is the URL ACL issue."
  Write-Host "Workaround: rerun once as Administrator, then back to normal user."
  exit 1
}

$url = "http://127.0.0.1:$Port/index.html"
Write-Host "MdMd installer running at $url"
Write-Host "1) Edge will open shortly in a normal tab."
Write-Host "2) Look at the right end of the address bar for the"
Write-Host "   install icon (a small monitor with a downward arrow)"
Write-Host "   and click it -> 'Install'."
Write-Host "3) Tick 'open .md, .markdown, .txt with this app' when prompted."
Write-Host "4) Close this console window when finished."
Write-Host ""

# ── Launch Edge as a regular browser tab ──────────────────────────────────────
# Note: do NOT use --app= here. App-window mode hides the address bar, which
# also hides the install icon — the user would have no way to install.
$edge = @(
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if ($edge) {
  Start-Process -FilePath $edge -ArgumentList @($url)
} else {
  Start-Process $url
}

# ── Serve files until Ctrl+C or window close ──────────────────────────────────
while ($listener.IsListening) {
  try { $ctx = $listener.GetContext() } catch { break }
  try {
    $reqPath = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
    if ($reqPath -eq '/' -or $reqPath -eq '') { $reqPath = '/index.html' }
    $rel = $reqPath.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $abs = [System.IO.Path]::GetFullPath((Join-Path $root $rel))

    # Path-escape guard: never serve outside the bundle.
    if (-not $abs.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
      $ctx.Response.StatusCode = 403
      $ctx.Response.Close(); continue
    }

    if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) {
      $ctx.Response.StatusCode = 404
      $ctx.Response.Close(); continue
    }

    $ext = [System.IO.Path]::GetExtension($abs).ToLowerInvariant()
    $type = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
    $bytes = [System.IO.File]::ReadAllBytes($abs)
    $ctx.Response.ContentType = $type
    $ctx.Response.ContentLength64 = $bytes.Length
    # Required so the SW can be served from a non-root path scope without issues.
    $ctx.Response.Headers['Service-Worker-Allowed'] = '/'
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.OutputStream.Close()
  } catch {
    try { $ctx.Response.StatusCode = 500; $ctx.Response.Close() } catch { }
  }
}
