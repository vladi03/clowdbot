param(
  [string]$UrlsFile,
  [string]$DownloadDir,
  [string]$Mp3Dir,
  [string]$TranscriptDir,
  [string]$ProcessScript,
  [string]$ExtractScript,
  [string]$TranscribeScript,
  [int]$PollSeconds = 30,
  [string]$LogPath
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = $null
try {
  $rootDir = (Resolve-Path (Join-Path $scriptDir "..\..\..\.." )).Path
} catch {
  $rootDir = $env:USERPROFILE
}
$projectRoot = Join-Path $rootDir "code\text_to_voice"
$learnVidsDir = Join-Path $projectRoot "learn_vids"

if (-not $UrlsFile) { $UrlsFile = Join-Path $learnVidsDir "download_urls.txt" }
if (-not $DownloadDir) { $DownloadDir = $learnVidsDir }
if (-not $Mp3Dir) { $Mp3Dir = Join-Path $learnVidsDir "mp3" }
if (-not $TranscriptDir) { $TranscriptDir = Join-Path $learnVidsDir "transcripts" }
if (-not $ProcessScript) { $ProcessScript = Join-Path $learnVidsDir "scripts\process-download-urls.ps1" }
if (-not $ExtractScript) { $ExtractScript = Join-Path $projectRoot "extract_audio.ps1" }
if (-not $TranscribeScript) { $TranscribeScript = Join-Path $projectRoot "run_transcribe_all.ps1" }
if (-not $LogPath) { $LogPath = Join-Path $scriptDir "monitor-full-process.log" }


function Write-Status([string]$Message) {
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "$ts $Message"
  Write-Host $line
  Add-Content -Path $LogPath -Value $line
}

function Extract-UrlFromLine([string]$Line) {
  if (-not $Line) { return $null }
  $pattern = 'https?://download\.cdn\.hosted\.panopto\.com/[^\s"\)\]]+'
  $match = [regex]::Match($Line, $pattern)
  if ($match.Success) { return $match.Value }
  return $null
}

function Parse-UrlLine([string]$Line) {
  if (-not $Line) { return $null }
  $parts = $Line -split "`t", 2
  $title = $null
  $url = $null
  if ($parts.Count -ge 2) {
    $title = $parts[0].Trim()
    $url = $parts[1].Trim()
  } else {
    $url = Extract-UrlFromLine $Line
  }
  if (-not $url) { return $null }
  return [pscustomobject]@{ Title = $title; Url = $url }
}

function Get-ItemCount([string]$Path) {
  $rawLines = Get-Content -Path $Path
  $items = 0
  foreach ($line in $rawLines) {
    if (-not $line -or -not $line.Trim()) { continue }
    $item = Parse-UrlLine $line
    if ($item) { $items++ }
  }
  return $items
}

function Get-PrefixedCount([string]$Dir, [string]$Filter) {
  if (-not (Test-Path $Dir)) { return 0 }
  $files = Get-ChildItem -Path $Dir -Filter $Filter -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^W\d\d ' }
  $keys = New-Object System.Collections.Generic.HashSet[string]
  foreach ($file in $files) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $base = $base -replace ' \(\d+\)$', ''
    $null = $keys.Add($base)
  }
  return $keys.Count
}

function Get-ProcByMatch([string]$Match) {
  return Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*$Match*" }
}

function Stop-Procs([string[]]$Matches) {
  foreach ($match in $Matches) {
    $procs = Get-ProcByMatch $match
    if ($procs) {
      $procs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    }
  }
}

function Start-ProcessDownload {
  Write-Status "Restarting downloads..."
  Start-Process -WindowStyle Hidden -FilePath "powershell" -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $ProcessScript,
    "-UrlsFile", $UrlsFile,
    "-DownloadDir", $DownloadDir,
    "-ExtractScript", $ExtractScript,
    "-TranscribeScript", $TranscribeScript
  ) | Out-Null
}

function Start-Extract {
  Write-Status "Restarting MP3 extraction..."
  Start-Process -WindowStyle Hidden -FilePath "powershell" -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $ExtractScript
  ) | Out-Null
}

function Start-Transcribe {
  Write-Status "Restarting transcription..."
  Start-Process -WindowStyle Hidden -FilePath "powershell" -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $TranscribeScript
  ) | Out-Null
}

if (-not (Test-Path $UrlsFile)) {
  throw "Missing URLs file: $UrlsFile"
}

$total = Get-ItemCount $UrlsFile
if ($total -eq 0) {
  throw "No URLs found in $UrlsFile"
}

$prevDownload = -1
$prevMp3 = -1
$prevTxt = -1
$downloadStale = 0
$mp3Stale = 0
$txtStale = 0

Write-Status "Target files: $total"

while ($true) {
  $mp4Count = Get-PrefixedCount $DownloadDir "*.mp4"
  $mp3Count = Get-PrefixedCount $Mp3Dir "*.mp3"
  $txtCount = Get-PrefixedCount $TranscriptDir "*.txt"

  if ($mp4Count -lt $total) {
    Write-Status "Downloads: $mp4Count out of $total Complete"
    if ($mp4Count -eq $prevDownload) { $downloadStale++ } else { $downloadStale = 0 }
    $prevDownload = $mp4Count

    $downloadRunning = (Get-ProcByMatch "process-download-urls.ps1") -ne $null
    if (-not $downloadRunning) {
      Start-ProcessDownload
      $downloadStale = 0
    } elseif ($downloadStale -ge 2) {
      Stop-Procs @("process-download-urls.ps1", "curl.exe", "curl ")
      Start-ProcessDownload
      $downloadStale = 0
    }
  } elseif ($mp3Count -lt $mp4Count) {
    Write-Status "MP3s: $mp3Count out of $mp4Count Complete"
    if ($mp3Count -eq $prevMp3) { $mp3Stale++ } else { $mp3Stale = 0 }
    $prevMp3 = $mp3Count

    $extractRunning = (Get-ProcByMatch "extract_audio.ps1") -ne $null
    if (-not $extractRunning) {
      Start-Extract
      $mp3Stale = 0
    } elseif ($mp3Stale -ge 2) {
      Stop-Procs @("extract_audio.ps1", "ffmpeg.exe", "ffmpeg ")
      Start-Extract
      $mp3Stale = 0
    }
  } elseif ($txtCount -lt $mp3Count) {
    Write-Status "Transcripts: $txtCount out of $mp3Count Complete"
    if ($txtCount -eq $prevTxt) { $txtStale++ } else { $txtStale = 0 }
    $prevTxt = $txtCount

    $transcribeRunning = (Get-ProcByMatch "run_transcribe_all.ps1") -ne $null
    if (-not $transcribeRunning) {
      Start-Transcribe
      $txtStale = 0
    } elseif ($txtStale -ge 2) {
      Stop-Procs @("run_transcribe_all.ps1", "transcribe.cjs", "node.exe")
      Start-Transcribe
      $txtStale = 0
    }
  } else {
    Write-Status "All done: $txtCount out of $mp3Count Complete"
    break
  }

  Start-Sleep -Seconds $PollSeconds
}
