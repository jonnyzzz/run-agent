---
title: "run-agent.sh"
description: "Multi-Agent AI Orchestration for Software Development"
---

**Orchestrate a swarm of AI Agents from your terminal.** Built by [Eugene Petrenko](https://jonnyzzz.com).

<div class="product-cards">
<div class="product-card">
<div class="product-card-body">

### `run-agent.sh`
**The Runner**

A unified shell script that launches AI Agents (Claude, Codex, Gemini) with full isolation and traceability. Each run gets its own folder with captured prompts, stdout/stderr, PID tracking, and exit codes.

</div>
<div class="product-card-footer">

[View on GitHub](https://github.com/jonnyzzz/run-agent/blob/main/run-agent.sh)

</div>
</div>
<div class="product-card">
<div class="product-card-body">

### `MESSAGE-BUS.md`
**The Nervous System**

A file-based, append-only trace log that connects every AI Agent in the swarm. No databases, no infrastructure -- just a shared markdown file.

</div>
<div class="product-card-footer">

[Learn more](#message-bus)

</div>
</div>
<div class="product-card">
<div class="product-card-body">

### `THE_PROMPT_v5.md`
**The Brain**

A project-independent orchestration workflow that defines roles, stages, quality gates, and communication protocols for AI Agents. It turns raw LLMs into a coordinated development team.

**13 stages** from research to deployment. **7 AI Agent roles** from orchestrator to monitor.

</div>
<div class="product-card-footer">

[View on GitHub](https://github.com/jonnyzzz/run-agent/blob/main/THE_PROMPT_v5.md)

</div>
</div>
</div>

---

## Agentic Swarm

Start **dozens of AI Agents in parallel** -- research, implementation, review, testing, and debugging AI Agents all working on the same codebase simultaneously. The orchestrator coordinates the swarm, splits work by subsystem, and enforces review quorums before commits land.

Each AI Agent has a **fixed role**: Orchestrator, Research, Implementation, Review, Test, Debug, or Monitor. AI Agents don't improvise -- they follow the staged workflow, log actions to the message bus, and report blockers. The result is deterministic, reproducible multi-agent development.

### Full Traceability

Every AI Agent invocation creates an isolated run folder under `runs/`. Each folder is a self-contained record: the exact prompt, full stdout/stderr, execution metadata, and a copy of the runner script. No lost context. No "what did the AI Agent do?" mysteries.

## AI Agent Roles

`THE_PROMPT_v5.md` defines 7 specialized roles. The entry point is always the **Orchestrator**, which spawns sub-agents as needed:

**Orchestrator** coordinates the full workflow and spawns sub-agents. **Research** explores the codebase without making changes. **Implementation** writes code and tests. **Review** performs code review and quality checks. **Test** runs tests and verifies changes. **Debug** investigates failures and proposes fixes. **Monitor** watches for stalled agents and restarts them.

Each role has a dedicated prompt file (`THE_PROMPT_v5_orchestrator.md`, `THE_PROMPT_v5_research.md`, etc.) that the orchestrator copies into the run folder when spawning a sub-agent.

---

## Message Bus

The message bus (`MESSAGE-BUS.md`) is how the agentic swarm communicates. It's a simple, file-based, **append-only trace log** -- no databases, no infrastructure, no setup. Every AI Agent in the swarm reads and writes to it.

This is the nervous system of the swarm. AI Agents use it to:

- **Coordinate work** -- claim tasks, report completion, hand off to the next stage
- **Share discoveries** -- post research findings, flag blockers, surface decisions
- **Synchronize state** -- the orchestrator reads the bus to decide what to do next

Every entry is tagged with a structured type:

- **FACT** -- Concrete results (test counts, commit hashes, file paths)
- **PROGRESS** -- In-flight status updates
- **DECISION** -- Policy choices with rationale
- **REVIEW** -- Structured code review feedback
- **ERROR** -- Failures that block progress

The bus is the single source of truth. When something goes wrong, you read the bus to understand exactly what each AI Agent did and why.

---

## Quick Start

Both `run-agent.sh` and `THE_PROMPT_v5.md` are designed to work **outside your project sources**. Just point an AI Agent at the URLs and your target repository.

Give this prompt to your AI Agent (Claude, Codex, or Gemini):

```
Download and follow the orchestration workflow from:
- https://run-agent.jonnyzzz.com/run-agent.sh
- https://run-agent.jonnyzzz.com/THE_PROMPT_v5.md

Apply it to the project at: /path/to/your/repo

Set up the working directory as:
  projects/<project-name>/<task-name>/

The orchestration files, runs/, MESSAGE-BUS.md, and ISSUES.md
all live in the task directory -- separate from your project sources.
```

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

**Warning:** AI Agents run with full permissions -- they can read, write, and execute anything on the system. This is by design for autonomous multi-agent workflows, but review the prompts and understand the risks before running agents on sensitive systems.

</div>

---

## Working Directory Layout

The orchestration runs in its own directory, separate from your target codebase:

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

Each task gets its own `PROJECT_ROOT` with independent runs, message bus, and issue tracking. Your project sources stay clean -- no orchestration files mixed in.

---

## MCP Steroid Integration

Both `run-agent.sh` and `THE_PROMPT_v5.md` are designed to work with [MCP Steroid](https://mcp-steroid.jonnyzzz.com) -- an MCP server for IntelliJ-based IDEs that provides code review, search, run configurations, builds, inspections, and quality gates to AI Agents.

`THE_PROMPT_v5.md` makes MCP Steroid the **primary tool** for quality gates: no new warnings, no new errors, compilation must succeed before any commit.

---

## License

All files published at `run-agent.jonnyzzz.com` are licensed under the [Apache License 2.0](/LICENSE). Copyright 2026 Eugene Petrenko.
