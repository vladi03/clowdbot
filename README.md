# Clowdbot Orchestrator Workspace

This repo is a personal workspace for coordinating Clawdbot/Moltbot agent runs and tracking progress.

## Structure
- `docs/` — operator notes and run guides
- `scripts/` — helper scripts for agent control and monitoring
- `AGENTS.md` — operating rules injected into agent context

## Quick start
- Edit `AGENTS.md` to adjust orchestration rules.
- Use scripts under `scripts/` to run/monitor agents as needed.

## Notes
- Keep secrets out of this repo.
- Prefer short run logs per task (create a `RUNLOG.md` when needed).
