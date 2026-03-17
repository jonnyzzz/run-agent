---
title: "run-agent.sh"
description: "Multi-Agent AI Orchestration for Software Development"
---

**Split complex tasks across multiple AI Agents that research, implement, review, and test in parallel -- so each agent stays focused and your codebase gets treated like a real team project.** Built by [Eugene Petrenko](https://jonnyzzz.com).

<div class="product-cards">
<div class="product-card">
<div class="product-card-body">

### `run-agent.sh`
**The Runner**

Launch Claude, Codex, or Gemini the same way and keep the evidence. Every run captures the prompt, stdout/stderr, PID, exit code, and working directory so you can see what happened after the agent finishes.

</div>
<div class="product-card-footer">

[View on GitHub](https://github.com/jonnyzzz/run-agent/blob/main/run-agent.sh)

</div>
</div>
<div class="product-card">
<div class="product-card-body">

### `MESSAGE-BUS.md`
**The Nervous System**

Give AI Agents a shared place to coordinate handoffs, blockers, and decisions without extra infrastructure. It is just an append-only markdown file, which means you can inspect the swarm state with any editor.

</div>
<div class="product-card-footer">

[Learn more](#message-bus)

</div>
</div>
<div class="product-card">
<div class="product-card-body">

### `THE_PROMPT_v5.md`
**The Brain**

Start with a defined workflow instead of inventing agent behavior from scratch. The prompt pack assigns roles, stages the work, and adds review and quality gates before changes land.

**13 stages** from research to deployment. **7 AI Agent roles** from orchestrator to monitor.

</div>
<div class="product-card-footer">

[View on GitHub](https://github.com/jonnyzzz/run-agent/blob/main/THE_PROMPT_v5.md)

</div>
</div>
</div>

---

## Agentic Swarm

When a task spans unfamiliar code, risky edits, and verification, one AI Agent usually becomes the bottleneck. With `run-agent.sh`, one AI Agent can research the codebase while another implements, a third runs tests, and a reviewer checks the diff before you trust the result.

The orchestrator starts **up to 16 AI Agents in parallel** and assigns fixed roles -- research, implementation, review, testing, debugging. That separation reduces context overload, keeps each run focused, and makes failures easier to isolate.

Each AI Agent follows a dedicated role prompt, writes to the message bus, and reports blockers instead of improvising. The outcome is easier to reproduce because the workflow, logs, and handoffs are all explicit.

### Full Traceability

When something goes wrong, the artifact trail is already there. Every AI Agent invocation creates an isolated run folder under `runs/` with the exact prompt, full stdout/stderr, execution metadata, and a copy of the runner script.

## What is run-agent.sh?

AI Agents produce better results when they focus on one thing at a time. A single agent tasked with "research the codebase, implement the feature, write tests, review the code, and fix any issues" will lose context, skip steps, or produce shallow work.

`run-agent.sh` lets your agents delegate sub-tasks to new agent processes. The orchestrator breaks work into focused pieces -- research, implementation, review, testing -- and launches a separate agent for each. Each agent works in isolation with a clear, narrow prompt, then reports back through the [message bus](#message-bus).

The result: deeper analysis, fewer dropped threads, and a full trace of every decision.

**If a task needs parallel research, isolated experiments, or independent review, this is the runner that makes that practical.**

### Example Prompt

Paste this into Claude, Codex, or Gemini. The root AI Agent will download the orchestration files, create a task workspace, and start delegating work through `MESSAGE-BUS.md`:

```
<PUT YOUR TASK DESCRIPTION HERE>

In order to deliver on the task, you should use https://run-agent.jonnyzzz.com/run-agent.sh script
to start more tasks. You should follow the https://run-agent.jonnyzzz.com/THE_PROMPT_v5.md and
other files relative to it as the main process. Your purpose is to orchestrate and delegate
the work to other run-agent instances that you start; you must not do the work yourself.
So create /loop when necessary to monitor the process. Never stop unless the work is completed.

All your prompts should use the https://run-agent.jonnyzzz.com/MESSAGE-BUS.md as the key
communication principle.

Make sure you download the files locally and use full paths to the downloaded files.
```

---

## AI Agent Roles

If you want independent evidence from the system, do not ask the same AI Agent to research, modify, test, and review its own work. `THE_PROMPT_v5.md` assigns those jobs to separate roles so each run has a clear purpose.

The entry point is always the **Orchestrator**, which spawns sub-agents as needed. **Research** explores the codebase without making changes. **Implementation** writes code and tests. **Review** performs code review and quality checks. **Test** runs tests and verifies changes. **Debug** investigates failures and proposes fixes. **Monitor** watches for stalled agents and restarts them.

Each role has a dedicated prompt file (`THE_PROMPT_v5_orchestrator.md`, `THE_PROMPT_v5_research.md`, and so on) that the orchestrator copies into the run folder when spawning a sub-agent.

---

## Message Bus

When several AI Agents are touching the same task, `MESSAGE-BUS.md` gives them a shared operating log you can inspect with any editor. It is a simple, file-based, **append-only trace log** with no database or extra service to manage.

AI Agents use it to:

- **Coordinate work** -- claim tasks, report completion, and hand work to the next stage
- **Share discoveries** -- post findings, blockers, and decisions while work is still in progress
- **Synchronize state** -- let the orchestrator decide what to do next based on the latest facts

Every entry is tagged with a structured type:

- **FACT** -- Concrete results such as test counts, commit hashes, and file paths
- **PROGRESS** -- In-flight status updates
- **DECISION** -- Policy choices with rationale
- **REVIEW** -- Structured code review feedback
- **ERROR** -- Failures that block progress

The bus becomes the fastest way to answer three questions: what happened, who did it, and what is blocked right now.

---

## Quick Start

Three steps. No installation, no configuration files.

1. **Write your task** at the top of the [example prompt](#example-prompt) above.
2. **Paste it** into your AI Agent (Claude, Codex, or Gemini).
3. **Watch.** The agent downloads `run-agent.sh` and `THE_PROMPT_v5.md`, sets up a working directory outside your repo, and begins spawning sub-agents.

Both `run-agent.sh` and `THE_PROMPT_v5.md` are hosted at stable URLs and work **outside your project sources** -- no files to clone, no dependencies to install.

## How Agents Are Launched

`run-agent.sh` provides a consistent interface for launching Claude, Codex, or Gemini:

```bash
./run-agent.sh claude /path/to/target/repo prompt.md
./run-agent.sh codex /path/to/target/repo prompt.md
./run-agent.sh gemini /path/to/target/repo prompt.md
```

Each AI Agent CLI is invoked with **full permissions bypassed** to allow unrestricted code generation and execution:

| AI Agent | CLI | Flags |
|----------|-----|-------|
| **Claude** | `claude` | `-p --tools default --permission-mode bypassPermissions` |
| **Codex** | `codex` | `exec --dangerously-bypass-approvals-and-sandbox` |
| **Gemini** | `gemini` | `--screen-reader true --approval-mode yolo` |

<div class="warning-banner">

**Warning:** These commands intentionally give AI Agents broad read, write, and execute access so they can work without manual approval loops. Use them on repositories and machines you trust, and review prompts before starting long-running tasks.

</div>

---

## Working Directory Layout

All orchestration state lives in a dedicated directory, separate from your target codebase. That separation keeps prompts, logs, and coordination files reproducible without polluting the repository you are changing.

```
projects/
  my-app/
    fix-auth-bug/               # <-- task directory (PROJECT_ROOT)
      THE_PROMPT_v5.md          # orchestration workflow
      run-agent.sh              # agent runner
      MESSAGE-BUS.md            # swarm communication log
      ISSUES.md                 # blocker tracking
      runs/
        run_20260128-194528-12345/
          prompt.md             # exact prompt sent to the AI Agent
          agent-stdout.txt      # everything the AI Agent produced
          agent-stderr.txt      # errors and warnings
          cwd.txt               # working directory, command, exit code
          run-agent.sh          # copy of the runner for reproducibility
        run_20260128-194530-12346/
          ...
    add-dark-mode/              # <-- another task, same project
      ...
  another-project/
    ...
```

Each task gets its own `PROJECT_ROOT` with independent runs, message bus, and issue tracking. Your project sources stay clean while the orchestration remains fully auditable.

---

## MCP Steroid Integration

If you already work in JetBrains-based IDEs, [MCP Steroid](https://mcp-steroid.jonnyzzz.com) gives AI Agents a stronger verification path than blind shell commands alone: code review, search, run configurations, builds, inspections, and quality gates.

`THE_PROMPT_v5.md` makes MCP Steroid the **primary tool** for quality gates: no new warnings, no new errors, and compilation must succeed before any commit.

---

## License

All files published at `run-agent.jonnyzzz.com` are licensed under the [Apache License 2.0](/LICENSE). Copyright 2026 Eugene Petrenko.
