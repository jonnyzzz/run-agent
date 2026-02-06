---
title: "run-agent"
description: "A multi-agent orchestration framework for AI-powered software development"
---

Run parallel AI agents (Claude, Codex, Gemini) with full traceability, structured workflows, and quality gates.

---

## What is this?

`run-agent` is a lightweight, shell-based framework for orchestrating multiple AI coding agents working on the same codebase. It provides:

- **Unified agent runner** (`run-agent.sh`) that creates isolated run folders with consistent artifacts
- **13-stage development workflow** from research through implementation, review, testing, and deployment
- **Role-specific prompts** for orchestrator, research, implementation, review, test, debug, and monitoring agents
- **Live monitoring** with `monitor-agents.py` for real-time agent status and log streaming
- **Full traceability** via append-only message bus and per-run artifact capture

## Quick Start

```bash
# Run a Claude agent with a prompt
./run-agent.sh claude /path/to/your/repo prompt.md

# Run a Codex agent
./run-agent.sh codex /path/to/your/repo prompt.md

# Run a Gemini agent
./run-agent.sh gemini /path/to/your/repo prompt.md

# Monitor all running agents
uv run python monitor-agents.py
```

Each agent run creates a folder under `runs/` with:
- `prompt.md` - the input prompt
- `agent-stdout.txt` / `agent-stderr.txt` - captured output
- `cwd.txt` - execution context and exit code
- `pid.txt` - PID tracking (removed on completion)

## Architecture

```
run-agent.sh                  # Unified agent runner
THE_PROMPT_v5.md              # Master orchestration guide
THE_PROMPT_v5_*.md            # Role-specific prompts (7 roles)
monitor-agents.py             # Live console monitor
monitor-agents.sh             # Background PID monitor (10min)
watch-agents.sh               # Background PID monitor (60s)
status-loop.sh                # Message bus status appender (60s)
status-loop-5m.sh             # Message bus status appender (5min)
run-agent-tests.sh            # Integration tests
test-claude-run.sh            # Claude sanity check
```

### Agent Roles

| Role | Prompt File | Purpose |
|------|------------|---------|
| **Orchestrator** | `THE_PROMPT_v5_orchestrator.md` | Coordinates full workflow, spawns sub-agents |
| **Research** | `THE_PROMPT_v5_research.md` | Codebase exploration, no code changes |
| **Implementation** | `THE_PROMPT_v5_implementation.md` | Code changes and tests |
| **Review** | `THE_PROMPT_v5_review.md` | Code review and quality checks |
| **Test** | `THE_PROMPT_v5_test.md` | Test execution and verification |
| **Debug** | `THE_PROMPT_v5_debug.md` | Investigate failures, propose fixes |
| **Monitor** | `THE_PROMPT_v5_monitor.md` | Periodic status checks and restarts |

### Development Flow

The framework enforces a 13-stage workflow:

0. **Cleanup** - Read project docs, prepare orchestration files
1. **Read local docs** - Understand project conventions
2. **Multi-agent research** - Parallel research and implementation scoping
3. **Select tasks** - Choose actionable work (low-hanging fruit first)
4. **Validate tests/build** - Confirm baseline passes
5. **Implement changes** - Code + tests
6. **Quality gate** - Verify no new warnings/errors via [MCP Steroid](https://mcp-steroid.jonnyzzz.com)
7. **Re-run tests** - Verify changes
8. **Research authorship** - Align with existing patterns
9. **Commit review** - Cross-agent review quorum
10. **Rebase/rebuild** - Clean history, verify compilation
11. **Push/preflight** - Feature branch, code review
12. **Monitor/fix** - Watch CI and apply fixes

## MCP Steroid Integration

This framework is designed to work with [MCP Steroid](https://mcp-steroid.jonnyzzz.com) - an MCP server for IntelliJ-based IDEs that provides code review, search, run configurations, builds, inspections, and quality gates to AI agents.

MCP Steroid is the preferred tool for:
- Code inspections and Find Usages
- Running tests and builds
- Quality gate verification (no new warnings/errors)
- File navigation and search

## Supported Agents

| Agent | CLI | Flags |
|-------|-----|-------|
| **Claude** | `claude` | `-p --tools default --permission-mode bypassPermissions` |
| **Codex** | `codex` | `exec --dangerously-bypass-approvals-and-sandbox` |
| **Gemini** | `gemini` | `--screen-reader true --approval-mode yolo` |

## Monitoring

### Live Console Monitor

```bash
uv run python monitor-agents.py
```

Shows a live dashboard with:
- Running / finished / unknown agent counts
- Color-coded log streaming with `[run_xxx]` prefixes
- Configurable poll and summary intervals

### Background Watchers

```bash
# 60-second polling
./watch-agents.sh &

# 10-minute polling
nohup ./monitor-agents.sh &
```

### Status Loop (Message Bus)

```bash
# Append status every 60 seconds to MESSAGE-BUS.md
./status-loop.sh &

# Append status every 5 minutes
./status-loop-5m.sh &
```

## Configuration

The framework uses environment variables for flexible deployment:

| Variable | Default | Description |
|----------|---------|-------------|
| `RUNS_DIR` | `./runs` | Directory for agent run folders |
| `MESSAGE_BUS` | `./MESSAGE-BUS.md` | Append-only trace log |

## License

[Apache License 2.0](https://github.com/jonnyzzz/run-agent/blob/main/LICENSE)

## Author

[Eugene Petrenko](https://jonnyzzz.com) ([@jonnyzzz](https://github.com/jonnyzzz))
