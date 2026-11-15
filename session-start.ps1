$ErrorActionPreference = 'Stop'
$stateDir = Join-Path $env:LOCALAPPDATA 'hud-ia'
$baselinePath = Join-Path $stateDir 'rtk-session-baseline.json'
New-Item -ItemType Directory -Path $stateDir -Force | Out-Null

try {
    $rtk = Get-Command rtk.exe
    $stats = & $rtk.Source gain --format json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw "rtk gain: saída $LASTEXITCODE" }
    [pscustomobject]@{
        started_at = [DateTimeOffset]::Now.ToString('o')
        total_input = [long]$stats.summary.total_input
        total_saved = [long]$stats.summary.total_saved
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath $baselinePath -Encoding UTF8
} catch {
    [pscustomobject]@{
        started_at = [DateTimeOffset]::Now.ToString('o')
        total_input = 0
        total_saved = 0
        error = $_.Exception.Message
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath $baselinePath -Encoding UTF8
}

if (-not (Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like 'HUD*Codex' })) {
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Users\USERX\hud-ia\codex-hud.ps1'
}
