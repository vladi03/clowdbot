param(
  [Parameter(Mandatory = $true)]
  [string]$TaskId,
  [int]$PollSeconds = 60,
  [string]$AgentId = "main",
  [string]$UrlsFile = "C:\\Users\\vladi\\code\\text_to_voice\\learn_vids\\download_urls.txt",
  [string]$DownloadDir = "C:\\Users\\vladi\\code\\text_to_voice\\learn_vids",
  [string]$TextToVoiceDir = "C:\\Users\\vladi\\code\\text_to_voice",
  [string]$TranscriptsDir = "C:\\Users\\vladi\\code\\text_to_voice\\learn_vids\\transcripts",
  [string]$ExtractScript = "C:\\Users\\vladi\\code\\text_to_voice\\extract_audio.ps1",
  [string]$TranscribeScript = "C:\\Users\\vladi\\code\\text_to_voice\\run_transcribe_all.ps1"
)

function Write-Status([string]$Message) {
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Write-Host "$ts $Message"
}

function Get-LatestSessionLog([string]$Agent) {
  $dir = Join-Path $env:USERPROFILE "\.clawdbot\\agents\\$Agent\\sessions"
  if (-not (Test-Path $dir)) { return $null }
  $file = Get-ChildItem -Path $dir -Filter *.jsonl | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  return $file.FullName
}

function Extract-Urls([string]$Text) {
  $urls = @()
  $pattern = 'https?://download\\.cdn\\.hosted\\.panopto\\.com/[^\s\"\)\]]+'
  $matches = [regex]::Matches($Text, $pattern)
  foreach ($m in $matches) { $urls += $m.Value }
  return $urls
}

function Get-FileNameFromUrl([string]$Url) {
  $filename = $null
  if ($Url -match 'filename=([^&]+)') {
    $filename = [System.Uri]::UnescapeDataString($Matches[1])
    $filename = $filename.Trim('"')
  }
  if (-not $filename) {
    try {
      $uri = [System.Uri]$Url
      $filename = [System.IO.Path]::GetFileName($uri.AbsolutePath)
    } catch {
      $filename = "download.mp4"
    }
  }
  return $filename
}

$logFile = Get-LatestSessionLog $AgentId
if (-not $logFile) { throw "No session log found for agent '$AgentId'" }
Write-Status "Watching session log: $logFile"

$seen = New-Object 'System.Collections.Generic.HashSet[string]'
$done = $false
$linesToWrite = @()
$urls = @()

while (-not $done) {
  $tail = Get-Content -Path $logFile -Tail 200
  foreach ($line in $tail) {
    if (-not $line) { continue }
    $obj = $null
    try { $obj = $line | ConvertFrom-Json } catch { continue }
    if ($null -eq $obj -or $obj.type -ne 'message') { continue }
    if ($obj.id -and $seen.Contains($obj.id)) { continue }
    if ($obj.id) { $seen.Add($obj.id) | Out-Null }
    $msg = $obj.message
    if ($null -eq $msg -or $msg.role -ne 'assistant') { continue }
    if (-not $msg.content) { continue }

    $textParts = @()
    foreach ($part in $msg.content) {
      if ($part.type -eq 'text' -and $part.text) {
        $textParts += $part.text
      }
    }
    if ($textParts.Count -eq 0) { continue }
    $text = $textParts -join "`n"
    if ($text -notmatch [regex]::Escape($TaskId)) { continue }

    if ($text -match 'URLS_START' -and $text -match 'URLS_DONE') {
      $before, $rest = $text -split 'URLS_START', 2
      $body, $after = $rest -split 'URLS_DONE', 2
      $rows = $body -split "`r?`n"
      foreach ($row in $rows) {
        $lineTrim = $row.Trim()
        if (-not $lineTrim) { continue }
        $linesToWrite += $lineTrim
        $urls += Extract-Urls $lineTrim
      }
      $done = $true
      break
    }
  }

  if (-not $done) {
    Start-Sleep -Seconds $PollSeconds
  }
}

if ($linesToWrite.Count -eq 0 -and $urls.Count -eq 0) {
  throw "No URLs found in agent response for task $TaskId"
}

Write-Status "Writing URL list to $UrlsFile"
$linesToWrite | Set-Content -Path $UrlsFile -Encoding UTF8

$uniqueUrls = $urls | Sort-Object -Unique
Write-Status "Downloading $($uniqueUrls.Count) files to $DownloadDir"
New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null

foreach ($url in $uniqueUrls) {
  $fileName = Get-FileNameFromUrl $url
  $outPath = Join-Path $DownloadDir $fileName
  if (Test-Path $outPath) {
    Write-Status "Skip existing: $outPath"
    continue
  }
  Write-Status "Downloading: $fileName"
  & curl.exe -L -o $outPath $url
  if ($LASTEXITCODE -ne 0) {
    throw "Download failed: $url"
  }
}

Write-Status "Extracting MP3 audio"
& $ExtractScript
if ($LASTEXITCODE -ne 0) { throw "extract_audio.ps1 failed" }

Write-Status "Running transcription"
& $TranscribeScript
if ($LASTEXITCODE -ne 0) { throw "run_transcribe_all.ps1 failed" }

Write-Status "All done"
