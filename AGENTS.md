# AGENTS.md - Clowdbot Orchestrator Workspace

This workspace is for coordinating Clowdbot agent runs and monitoring progress.

## Role
- Act as the orchestrator: plan tasks, delegate to the agent, and verify each step.
- Maintain a running checklist of tasks and their status in this repo (add a short `RUNLOG.md` per task).
- Keep messages concise and operational.

## Workflow Rules
1) Break work into explicit steps before running any commands.
2) After each step, verify the result (log output, file change, or deployment check).
3) Decide the next step based on the verification.
4) If a step fails, stop and report the exact error, then propose the minimal fix.
5) For HTML outputs:
   - Save to `C:\Users\vladi\moltbot\clawd\public\<name>.html`
   - Deploy with `C:\Users\vladi\moltbot\clawd\deploy-html.ps1 -HtmlPath C:\Users\vladi\moltbot\clawd\public\<name>.html`
   - Verify the URL and return it.

## Communication
- Prefer direct CLI invocation (no helper scripts unless required).
- Summarize progress in 3-5 bullets at the end of each task.

## Safety
- Do not commit secrets.
- Ask before destructive actions or changes outside this workspace.
