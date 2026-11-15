Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:refreshSeconds = 180
$script:lastUpdated = $null
$script:countdownLabels = [System.Collections.Generic.List[object]]::new()
$script:timerLabel = $null
$script:flow = $null
$script:savingsLabel = $null
$script:sessionBaselinePath = Join-Path $env:LOCALAPPDATA 'hud-ia\rtk-session-baseline.json'

$form = New-Object System.Windows.Forms.Form
$form.Text = 'HUD·IA — Codex'
$form.ClientSize = New-Object System.Drawing.Size(430, 650)
$form.MinimumSize = New-Object System.Drawing.Size(446, 430)
$form.StartPosition = 'Manual'
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(8, 13, 23)
$form.ForeColor = [System.Drawing.Color]::FromArgb(225, 235, 250)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Top'
$header.Height = 92
$header.BackColor = [System.Drawing.Color]::FromArgb(13, 22, 38)
$form.Controls.Add($header)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'CODEX  /  PLAYER STATUS'
$title.Location = New-Object System.Drawing.Point(18, 14)
$title.Size = New-Object System.Drawing.Size(270, 28)
$title.ForeColor = [System.Drawing.Color]::FromArgb(91, 224, 255)
$title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 13)
$header.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'AI USAGE HUD     ·     AUTO-REFRESH 03:00'
$subtitle.Location = New-Object System.Drawing.Point(20, 48)
$subtitle.Size = New-Object System.Drawing.Size(300, 20)
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(133, 154, 180)
$subtitle.Font = New-Object System.Drawing.Font('Consolas', 8)
$header.Controls.Add($subtitle)

$script:timerLabel = New-Object System.Windows.Forms.Label
$script:timerLabel.Text = 'SYNC --:--'
$script:timerLabel.Location = New-Object System.Drawing.Point(318, 18)
$script:timerLabel.Size = New-Object System.Drawing.Size(94, 22)
$script:timerLabel.TextAlign = 'MiddleRight'
$script:timerLabel.ForeColor = [System.Drawing.Color]::FromArgb(110, 238, 185)
$script:timerLabel.Font = New-Object System.Drawing.Font('Consolas', 8)
$header.Controls.Add($script:timerLabel)

$script:flow = New-Object System.Windows.Forms.FlowLayoutPanel
$script:flow.Dock = 'Fill'
$script:flow.AutoScroll = $true
$script:flow.WrapContents = $false
$script:flow.FlowDirection = 'TopDown'
$script:flow.Padding = New-Object System.Windows.Forms.Padding(12, 12, 12, 8)
$script:flow.BackColor = [System.Drawing.Color]::FromArgb(8, 13, 23)
$form.Controls.Add($script:flow)

$footer = New-Object System.Windows.Forms.Label
$footer.Dock = 'Bottom'
$footer.Height = 24
$footer.Text = 'HP = quota restante     MP = janela secundária     ·     RESET TIMER'
$footer.TextAlign = 'MiddleCenter'
$footer.ForeColor = [System.Drawing.Color]::FromArgb(104, 124, 151)
$footer.Font = New-Object System.Drawing.Font('Consolas', 7)
$footer.BackColor = [System.Drawing.Color]::FromArgb(13, 22, 38)
$form.Controls.Add($footer)

function New-HudLabel($Text, $X, $Y, $Width, $Height, $Color, $Font, $Align = 'TopLeft') {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    $label.ForeColor = $Color
    $label.Font = $Font
    $label.TextAlign = $Align
    $label.AutoEllipsis = $true
    return $label
}

function Format-Remaining([double]$Percent) {
    $remaining = [Math]::Max(0, [Math]::Min(100, 100 - $Percent))
    return [int][Math]::Round($remaining)
}

function Format-Countdown($ResetAt) {
    if (-not $ResetAt) { return 'reset indisponível' }
    try {
        $delta = [DateTimeOffset]::Parse([string]$ResetAt).ToLocalTime() - [DateTimeOffset]::Now
        if ($delta.TotalSeconds -le 0) { return 'resetando…' }
        if ($delta.TotalDays -ge 1) { return '{0}d {1:00}h {2:00}m' -f [int]$delta.TotalDays, $delta.Hours, $delta.Minutes }
        if ($delta.TotalHours -ge 1) { return '{0:00}h {1:00}m {2:00}s' -f [int]$delta.TotalHours, $delta.Minutes, $delta.Seconds }
        return '{0:00}m {1:00}s' -f $delta.Minutes, $delta.Seconds
    } catch { return 'reset indisponível' }
}

function New-HudBar([int]$Value, [System.Drawing.Color]$Color) {
    $bar = New-Object System.Windows.Forms.Panel
    $bar.Height = 12
    $bar.Margin = New-Object System.Windows.Forms.Padding(0)
    $bar.BackColor = [System.Drawing.Color]::FromArgb(27, 39, 57)
    $bar.Tag = [pscustomobject]@{ Value = [Math]::Max(0, [Math]::Min(100, $Value)); Color = $Color }
    $bar.Add_Paint({
        param($sender, $eventArgs)
        $graphics = $eventArgs.Graphics
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $width = [Math]::Max(0, [int](($sender.Width - 2) * $sender.Tag.Value / 100))
        if ($width -gt 0) {
            $brush = New-Object System.Drawing.SolidBrush($sender.Tag.Color)
            $graphics.FillRectangle($brush, 1, 1, $width, $sender.Height - 2)
            $brush.Dispose()
        }
        $tickPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 8, 13, 23), 1)
        for ($i = 1; $i -lt 10; $i++) {
            $x = [int](($sender.Width - 2) * $i / 10)
            $graphics.DrawLine($tickPen, $x, 1, $x, $sender.Height - 1)
        }
        $tickPen.Dispose()
    })
    return $bar
}

function Get-ProviderColor($Id) {
    switch ($Id) {
        'openai' { return [System.Drawing.Color]::FromArgb(91, 224, 255) }
        'anthropic' { return [System.Drawing.Color]::FromArgb(188, 151, 255) }
        default { return [System.Drawing.Color]::FromArgb(110, 238, 185) }
    }
}

function Build-ProviderCard($Entry) {
    $metrics = @($Entry.metrics)
    $height = 68 + [Math]::Max(1, $metrics.Count) * 49
    $card = New-Object System.Windows.Forms.Panel
    $card.Width = [Math]::Max(340, $script:flow.ClientSize.Width - 42)
    $card.Height = $height
    $card.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)
    $card.BackColor = [System.Drawing.Color]::FromArgb(16, 25, 41)
    $card.BorderStyle = 'FixedSingle'

    $providerColor = Get-ProviderColor $Entry.id
    $name = if ($Entry.display_name) { ([string]$Entry.display_name).ToUpperInvariant() } else { ([string]$Entry.id).ToUpperInvariant() }
    $plan = if ($Entry.plan) { [string]$Entry.plan } else { 'ACCOUNT STATUS' }
    $card.Controls.Add((New-HudLabel $name 14 10 150 22 $providerColor (New-Object System.Drawing.Font('Segoe UI Semibold', 11))))
    $card.Controls.Add((New-HudLabel $plan 170 13 ($card.Width - 184) 18 ([System.Drawing.Color]::FromArgb(139, 157, 181)) (New-Object System.Drawing.Font('Consolas', 8)) 'TopRight'))

    if ($Entry.error) {
        $errorText = ([string]$Entry.error -split '[\r\n]')[0]
        $card.Controls.Add((New-HudLabel $errorText 14 39 ($card.Width - 28) 24 ([System.Drawing.Color]::FromArgb(255, 113, 126)) (New-Object System.Drawing.Font('Segoe UI', 8))))
    }

    for ($i = 0; $i -lt $metrics.Count; $i++) {
        $metric = $metrics[$i]
        $y = 38 + ($i * 49)
        $tag = switch ($i) { 0 { 'HP' } 1 { 'MP' } default { 'SP' } }
        $used = [Math]::Max(0, [Math]::Min(100, [double]$metric.percent))
        $remaining = Format-Remaining $used
        $barColor = if ($remaining -lt 20) { [System.Drawing.Color]::FromArgb(255, 91, 110) } elseif ($remaining -lt 50) { [System.Drawing.Color]::FromArgb(255, 190, 91) } else { $providerColor }
        $labelText = '{0}  {1}' -f $tag, [string]$metric.label
        $valueText = '{0}% LIVRE' -f $remaining
        $card.Controls.Add((New-HudLabel $labelText 14 $y 190 17 ([System.Drawing.Color]::FromArgb(212, 225, 243)) (New-Object System.Drawing.Font('Consolas', 8))))
        $card.Controls.Add((New-HudLabel $valueText ($card.Width - 130) $y 116 17 $barColor (New-Object System.Drawing.Font('Consolas', 8)) 'TopRight'))
        $bar = New-HudBar $remaining $barColor
        $bar.Location = New-Object System.Drawing.Point(14, ($y + 18))
        $bar.Width = $card.Width - 28
        $card.Controls.Add($bar)
        $resetLabel = New-HudLabel '' 14 ($y + 31) ($card.Width - 28) 15 ([System.Drawing.Color]::FromArgb(127, 148, 173)) (New-Object System.Drawing.Font('Consolas', 7))
        $resetLabel.Tag = [string]$metric.reset_at
        $resetLabel.Text = 'RESET EM  ' + (Format-Countdown $metric.reset_at)
        $card.Controls.Add($resetLabel)
        $script:countdownLabels.Add($resetLabel)
    }
    return $card
}

function Build-SessionCard {
    $card = New-Object System.Windows.Forms.Panel
    $card.Width = [Math]::Max(340, $script:flow.ClientSize.Width - 42)
    $card.Height = 104
    $card.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)
    $card.BackColor = [System.Drawing.Color]::FromArgb(17, 29, 46)
    $card.BorderStyle = 'FixedSingle'
    $card.Controls.Add((New-HudLabel 'MÓDULOS DA SESSÃO  /  ATIVOS' 14 10 280 18 ([System.Drawing.Color]::FromArgb(91, 224, 255)) (New-Object System.Drawing.Font('Segoe UI Semibold', 9))))
    $card.Controls.Add((New-HudLabel 'CAVEMAN  ·  PONYTAIL  ·  RTK' 14 32 ($card.Width - 28) 18 ([System.Drawing.Color]::FromArgb(218, 229, 245)) (New-Object System.Drawing.Font('Consolas', 9))))
    $script:savingsLabel = New-HudLabel 'ECONOMIA NESTA SESSÃO  —  lendo…' 14 61 ($card.Width - 28) 18 ([System.Drawing.Color]::FromArgb(110, 238, 185)) (New-Object System.Drawing.Font('Consolas', 9))
    $card.Controls.Add($script:savingsLabel)
    return $card
}

function Update-SessionSavings($CurrentSummary) {
    if (-not $script:savingsLabel) { return }
    if (-not $CurrentSummary) {
        $script:savingsLabel.Text = 'ECONOMIA RTK  —  métrica indisponível'
        return
    }
    try {
        $baseline = Get-Content -LiteralPath $script:sessionBaselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $saved = [Math]::Max(0, [long]$CurrentSummary.total_saved - [long]$baseline.total_saved)
        $input = [Math]::Max(0, [long]$CurrentSummary.total_input - [long]$baseline.total_input)
        $pct = if ($input -gt 0) { [Math]::Round(($saved / $input) * 100, 1) } else { 0 }
        $script:savingsLabel.Text = 'ECONOMIA NA SESSÃO  {0:N0} TOKENS  ·  {1}%  |  TOTAL {2:N0}' -f $saved, $pct, [long]$CurrentSummary.total_saved
    } catch {
        $script:savingsLabel.Text = 'ECONOMIA NA SESSÃO  —  baseline indisponível'
    }
}

function Update-Countdowns {
    foreach ($label in $script:countdownLabels) {
        $label.Text = 'RESET EM  ' + (Format-Countdown $label.Tag)
    }
    if ($script:lastUpdated) {
        $elapsed = [int]([DateTimeOffset]::Now - $script:lastUpdated).TotalSeconds
        $left = [Math]::Max(0, $script:refreshSeconds - $elapsed)
        $script:timerLabel.Text = 'SYNC {0:00}:{1:00}' -f [int]($left / 60), ($left % 60)
    }
}

function Refresh-Hud {
    try {
        $data = & "$env:LOCALAPPDATA\Programs\ai-usagebar\ai-usagebar.exe" usage --json | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) { throw "ai-usagebar: saída $LASTEXITCODE" }
        $script:flow.SuspendLayout()
        $script:flow.Controls.Clear()
        $script:countdownLabels.Clear()
        $script:flow.Controls.Add((Build-SessionCard))
        $rtkSummary = $null
        try {
            $rtkData = & (Get-Command rtk.exe -ErrorAction Stop).Source gain --format json | ConvertFrom-Json
            if ($LASTEXITCODE -eq 0) { $rtkSummary = $rtkData.summary }
        } catch { }
        Update-SessionSavings $rtkSummary
        foreach ($entry in $data.entries) {
            if ($entry.id -notin @('anthropic', 'openai', 'antigravity')) { continue }
            $script:flow.Controls.Add((Build-ProviderCard $entry))
        }
        $script:flow.ResumeLayout($true)
        $script:lastUpdated = [DateTimeOffset]::Now
        Update-Countdowns
    } catch {
        $script:flow.Controls.Clear()
        $message = New-HudLabel ("Falha ao atualizar a HUD`r`n" + $_.Exception.Message) 14 14 350 50 ([System.Drawing.Color]::FromArgb(255, 113, 126)) (New-Object System.Drawing.Font('Segoe UI', 9))
        $script:flow.Controls.Add($message)
    }
}

$refreshTimer = New-Object System.Windows.Forms.Timer
$refreshTimer.Interval = 180000
$refreshTimer.Add_Tick({ Refresh-Hud })
$clockTimer = New-Object System.Windows.Forms.Timer
$clockTimer.Interval = 1000
$clockTimer.Add_Tick({ Update-Countdowns })
$form.Add_Shown({ Refresh-Hud; $refreshTimer.Start(); $clockTimer.Start() })
$form.Add_FormClosed({ $refreshTimer.Stop(); $clockTimer.Stop(); $refreshTimer.Dispose(); $clockTimer.Dispose() })
[void]$form.ShowDialog()

