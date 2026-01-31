# Agent browser + command scripts

## Prereqs
- Run commands from the repo root.
- Install dependencies: `pnpm install`.
- Start the Gateway in another terminal (the scripts call the CLI):
  - `pnpm moltbot gateway --port 18789`
  - Dev hot-reload: `pnpm gateway:watch`

## Run the agent with a browser
Script: `my/scripts/run-agent-with-browser.ps1`

Example:
```powershell
.\my\scripts\run-agent-with-browser.ps1 -Message "Open https://example.com and take a screenshot"
```

Options:
- `-AgentId <id>`: target a specific agent id.
- `-Thinking <off|minimal|low|medium|high>`: set thinking level.
- `-Deliver`: deliver the agent reply to the configured channel.

What it does:
- Runs `moltbot browser start` to ensure the browser control server is up.
- Sends your message with `moltbot agent`.

## Send a command to the agent
Script: `my/scripts/send-agent-command.ps1`

Example:
```powershell
.\my\scripts\send-agent-command.ps1 -Message "Summarize the latest status"
```

Options:
- `-AgentId <id>`: target a specific agent id.
- `-SessionId <id>`: target an existing session.
- `-Thinking <off|minimal|low|medium|high>`: set thinking level.
- `-Deliver`: deliver the agent reply to the configured channel.
- `-TimeoutSeconds <seconds>`: override the agent timeout (default 600s).

Notes:
- If neither `-AgentId` nor `-SessionId` is provided, the script defaults to `-AgentId main`.
