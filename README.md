# run-agent.sh

**Two tools. One framework. Ship code with parallel AI agents.**

---

## `run-agent.sh` -- The Runner

A unified shell script that launches AI agents (Claude, Codex, Gemini) with full isolation and traceability. Each run gets its own folder with captured prompts, stdout/stderr, PID tracking, and exit codes.

```bash
./run-agent.sh claude /path/to/repo prompt.md
./run-agent.sh codex /path/to/repo prompt.md
./run-agent.sh gemini /path/to/repo prompt.md
```

Works best with **THE_PROMPT_v5.md** to orchestrate multi-agent workflows.

## `THE_PROMPT_v5.md` -- The Brain

A project-independent orchestration workflow that defines roles, stages, quality gates, and communication protocols for AI agents. It turns raw LLMs into a coordinated development team.

**13 stages** from research to deployment. **7 agent roles** from orchestrator to monitor. **16 parallel agents** max.

Works best with **run-agent.sh** to execute the orchestrated workflow.

---

## How They Work Together

```
THE_PROMPT_v5.md                    run-agent.sh
(defines the workflow)              (executes agents)
         │                                │
         ├── Stage 0: Cleanup             ├── ./run-agent.sh claude ...
         ├── Stage 2: Research    ──────► ├── ./run-agent.sh codex ...
         ├── Stage 5: Implement   ──────► ├── ./run-agent.sh gemini ...
         ├── Stage 6: Quality Gate        │
         ├── Stage 9: Review      ──────► ├── ./run-agent.sh claude ...
         └── Stage 12: Monitor            └── (all outputs in runs/)
```

`THE_PROMPT_v5.md` tells agents **what to do** and **in what order**. `run-agent.sh` handles **how to run them** with full artifact capture. Together, they turn your terminal into a multi-agent development shop.

## Quick Start

```bash
git clone https://github.com/jonnyzzz/run-agent.git
cd run-agent

# Run a Claude agent
./run-agent.sh claude /path/to/your/repo your-prompt.md

# Monitor all running agents
uv run python monitor-agents.py
```

Each agent run creates a folder under `runs/` with:
- `prompt.md` - the input prompt
- `agent-stdout.txt` / `agent-stderr.txt` - captured output
- `cwd.txt` - execution context and exit code
- `pid.txt` - PID tracking (removed on completion)

## Agent Roles (defined in THE_PROMPT_v5.md)

| Role | Prompt File | Purpose |
|------|------------|---------|
| **Orchestrator** | `THE_PROMPT_v5_orchestrator.md` | Coordinates full workflow, spawns sub-agents |
| **Research** | `THE_PROMPT_v5_research.md` | Codebase exploration, no code changes |
| **Implementation** | `THE_PROMPT_v5_implementation.md` | Code changes and tests |
| **Review** | `THE_PROMPT_v5_review.md` | Code review and quality checks |
| **Test** | `THE_PROMPT_v5_test.md` | Test execution and verification |
| **Debug** | `THE_PROMPT_v5_debug.md` | Investigate failures, propose fixes |
| **Monitor** | `THE_PROMPT_v5_monitor.md` | Periodic status checks and restarts |

## Supported Agents (launched by run-agent.sh)

| Agent | CLI | Flags |
|-------|-----|-------|
| **Claude** | `claude` | `-p --tools default --permission-mode bypassPermissions` |
| **Codex** | `codex` | `exec --dangerously-bypass-approvals-and-sandbox` |
| **Gemini** | `gemini` | `--screen-reader true --approval-mode yolo` |

## The 13-Stage Development Flow

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

Both `run-agent.sh` and `THE_PROMPT_v5.md` are designed to work with [MCP Steroid](https://mcp-steroid.jonnyzzz.com) - an MCP server for IntelliJ-based IDEs that provides code review, search, run configurations, builds, inspections, and quality gates to AI agents.

## Monitoring

```bash
# Live console dashboard
uv run python monitor-agents.py

# Background PID watchers
./watch-agents.sh &          # 60-second polling
nohup ./monitor-agents.sh &  # 10-minute polling

# Message bus status loop
./status-loop.sh &           # Append status every 60s
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `RUNS_DIR` | `./runs` | Directory for agent run folders |
| `MESSAGE_BUS` | `./MESSAGE-BUS.md` | Append-only trace log |

## License

[Apache License 2.0](LICENSE)

## Author

[Eugene Petrenko](https://jonnyzzz.com) ([@jonnyzzz](https://github.com/jonnyzzz))
