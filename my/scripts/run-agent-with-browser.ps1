param(
  [Parameter(Mandatory = $true)]
  [string]$Message,

  [string]$AgentId,
  [string]$Thinking,
  [switch]$Deliver
)

$AgentId = if ($AgentId) { $AgentId } else { "main" }

$pnpm = Get-Command pnpm -ErrorAction SilentlyContinue
if (-not $pnpm) {
  Write-Error "pnpm not found in PATH. Install pnpm and retry."
  exit 1
}

Write-Host "Starting browser control service..."
pnpm moltbot -- browser start
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$agentArgs = @("agent", "--message", $Message)
if ($AgentId) { $agentArgs += @("--agent", $AgentId) }
if ($Thinking) { $agentArgs += @("--thinking", $Thinking) }
if ($Deliver) { $agentArgs += "--deliver" }

Write-Host "Running agent..."
pnpm moltbot -- @agentArgs
exit $LASTEXITCODE
