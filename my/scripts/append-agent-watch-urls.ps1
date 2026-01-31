param(
  [Parameter(Mandatory = $true)]
  [string]$TaskId,

  [Parameter(Mandatory = $true)]
  [string]$LogPath,

  [Parameter(Mandatory = $true)]
  [string]$OutFile,

  [int]$PollSeconds = 60,
  [string]$ProcessMatch = "agent-week-watch-urls-message-2.txt",
  [int]$TailLines = 2000,
  [string]$MonitorLog = "C:\Users\vladi\moltbot\clawdbot\my\scripts\agent-week-watch-urls-monitor.log"
)

$existing = New-Object System.Collections.Generic.HashSet[string]
if (Test-Path $OutFile) {
  Get-Content -Path $OutFile | ForEach-Object {
    if ($_.Trim().Length -gt 0) { $null = $existing.Add($_) }
  }
}

function Get-Running {
  Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -like "*send-agent-command.ps1*" -and $_.CommandLine -like "*$ProcessMatch*"
  }
}

function Get-TaskBodyFromJsonLine([string]$line, [string]$taskId) {
  try {
    $obj = $line | ConvertFrom-Json -ErrorAction Stop
  } catch {
    return $null
  }

  if ($obj.type -ne "message") { return $null }
  if (-not $obj.message -or $obj.message.role -ne "assistant") { return $null }
  if (-not $obj.message.content) { return $null }

  foreach ($item in $obj.message.content) {
    if ($item.type -ne "text") { continue }
    $text = $item.text
    if (-not $text) { continue }
    if ($text -match "TASK_ID: $taskId") {
      if ($text -match "(?s)TASK_ID: $taskId.*?URLS_START\n(?<body>.*?)\nURLS_DONE") {
        return $Matches.body
      }
    }
  }

  return $null
}

while ($true) {
  $added = 0
  if (Test-Path $LogPath) {
    $lines = Get-Content -Path $LogPath -Tail $TailLines
    foreach ($line in $lines) {
      $body = Get-TaskBodyFromJsonLine -line $line -taskId $TaskId
      if (-not $body) { continue }
      $body -split "`n" | ForEach-Object {
        $u = $_
        if ($u.Trim().Length -eq 0) { return }
        if ($existing.Add($u)) {
          Add-Content -Path $OutFile -Value $u
          $added++
        }
      }
    }
  }

  $running = (Get-Running) -ne $null
  $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
  Add-Content -Path $MonitorLog -Value "$timestamp running=$running added=$added total=$($existing.Count)"

  if (-not $running) {
    break
  }

  Start-Sleep -Seconds $PollSeconds
}
