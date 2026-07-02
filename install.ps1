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
  # MdMd is registered as a PWA at http://127.0.0.1:<Port>/. The port is
  # part of the PWA's identity in Edge, so it MUST stay stable across
  # reinstalls — otherwise Edge treats each fresh install as a new app
  # and you end up with duplicate entries in edge://apps. Keep this port
  # constant across all machines and across update runs.
  [int]$Port = 17645
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $root 'index.html'))) {
  Write-Host "index.html not found next to install.ps1" -ForegroundColor Red
  exit 1
}

# ── Port conflict guard ───────────────────────────────────────────────────────
# If another process is already on the chosen port, abort with a clear
# message instead of silently falling back to a random port (which would
# create a duplicate PWA install).
$inUse = $false
try {
  $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
  $probe.Start(); $probe.Stop()
} catch { $inUse = $true }
if ($inUse) {
  Write-Host "Port $Port is already in use." -ForegroundColor Red
  Write-Host "  - If MdMd's installer/updater is already running, close that window first."
  Write-Host "  - If another app uses port $Port, free it or override with: install.cmd -Port <num>"
  Write-Host "    (Use the same -Port value every time to avoid duplicate PWA registration.)"
  exit 1
}

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
Write-Host ""
Write-Host "FIRST TIME (not installed yet):"
Write-Host "  1) Edge opens in a normal tab."
Write-Host "  2) Click the install icon at the right of the address bar -> Install."
Write-Host "  3) Tick 'open .md, .markdown with this app' when prompted."
Write-Host ""
Write-Host "ALREADY INSTALLED:"
Write-Host "  - A code-only update applies in the background and the app reloads"
Write-Host "    itself; this window then closes on its own."
Write-Host "  - If the app's LOOK/FILE-HANDLING changed (manifest update), Edge"
Write-Host "    keeps the old manifest. To pick it up, uninstall first:"
Write-Host "      edge://apps  ->  MdMd  ->  Uninstall,  then run install.cmd again."
Write-Host ""
Write-Host "This window closes automatically; it also self-closes after a timeout."
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

# ── Serve files until /installed beacon arrives, or an absolute timeout ──────
# The timeout guarantees the console never hangs: an already-current install
# (no update, no fresh-install event) would otherwise never send /installed.
$installed = $false
$deadline = [DateTime]::UtcNow.AddSeconds(120)
while ($listener.IsListening -and -not $installed) {
  $task = $listener.GetContextAsync()
  while (-not $task.Wait(500)) {
    if ([DateTime]::UtcNow -gt $deadline) {
      Write-Host ""
      Write-Host "Timeout reached. Closing installer." -ForegroundColor Yellow
      $installed = $true
      break
    }
  }
  if ($installed) { break }
  try { $ctx = $task.Result } catch { break }
  try {
    $reqPath = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)

    # Install-complete beacon from index.html (window 'appinstalled' event).
    # We ACK and break out of the listener loop so the script can exit.
    if ($reqPath -eq '/installed') {
      $ctx.Response.StatusCode = 204
      $ctx.Response.Close()
      Write-Host ""
      Write-Host "Install detected. Shutting down installer." -ForegroundColor Green
      $installed = $true
      break
    }

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

try { $listener.Stop(); $listener.Close() } catch { }
exit 0
