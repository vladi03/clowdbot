param(
  [Parameter(Mandatory = $true)]
  [string]$Message,

  [string]$AgentId,
  [string]$SessionId,
  [string]$Thinking,
  [switch]$Deliver,
  [int]$TimeoutSeconds
)

$pnpm = Get-Command pnpm -ErrorAction SilentlyContinue
if (-not $pnpm) {
  Write-Error "pnpm not found in PATH. Install pnpm and retry."
  exit 1
}

$resolvedAgentId = $AgentId
if (-not $resolvedAgentId -and -not $SessionId) {
  $resolvedAgentId = "main"
}

$agentArgs = @("agent", "--message", $Message)
if ($resolvedAgentId) { $agentArgs += @("--agent", $resolvedAgentId) }
if ($SessionId) { $agentArgs += @("--session-id", $SessionId) }
if ($Thinking) { $agentArgs += @("--thinking", $Thinking) }
if ($Deliver) { $agentArgs += "--deliver" }
if ($TimeoutSeconds) { $agentArgs += @("--timeout", $TimeoutSeconds) }

pnpm moltbot -- @agentArgs
exit $LASTEXITCODE
