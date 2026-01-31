param(
  [int]$IntervalSeconds = 60,
  [string]$OutLog = "C:\\Users\\vladi\\moltbot\\clawdbot\\my\\scripts\\agent-week-job.out.log",
  [string]$ErrLog = "C:\\Users\\vladi\\moltbot\\clawdbot\\my\\scripts\\agent-week-job.err.log",
  [string]$UrlsFile = "C:\\Users\\vladi\\code\\text_to_voice\\learn_vids\\download_urls.txt",
  [string]$TranscriptsDir = "C:\\Users\\vladi\\code\\text_to_voice\\learn_vids\\transcripts",
  [string]$MonitorLog = "C:\\Users\\vladi\\moltbot\\clawdbot\\my\\scripts\\agent-week-monitor.log"
)

function Get-AgentProcess {
  Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -like "*send-agent-command.ps1*" -and $_.CommandLine -like "*agent-week-message.txt*"
  }
}

function Get-FileSize([string]$Path) {
  if (Test-Path $Path) {
    return (Get-Item $Path).Length
  }
  return 0
}

function Get-LineCount([string]$Path) {
  if (Test-Path $Path) {
    return (Get-Content $Path | Where-Object { $_ -match "\\S" }).Count
  }
  return 0
}

function Get-TranscriptCount([string]$Path) {
  if (Test-Path $Path) {
    return (Get-ChildItem -Path $Path -Filter "*.txt" -File | Measure-Object).Count
  }
  return 0
}

while ($true) {
  $running = (Get-AgentProcess) -ne $null
  $urlsCount = Get-LineCount $UrlsFile
  $transcriptsCount = Get-TranscriptCount $TranscriptsDir
  $outBytes = Get-FileSize $OutLog
  $errBytes = Get-FileSize $ErrLog
  $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
  Add-Content -Path $MonitorLog -Value "$timestamp running=$running urls=$urlsCount transcripts=$transcriptsCount outBytes=$outBytes errBytes=$errBytes"
  if (-not $running) {
    break
  }
  Start-Sleep -Seconds $IntervalSeconds
}
