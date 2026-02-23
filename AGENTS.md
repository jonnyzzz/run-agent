# run-agent.sh -- AI Agent Configuration

**Project:** [run-agent.sh](https://run-agent.jonnyzzz.com) -- Multi-Agent AI Orchestration for Software Development

---

## Project Overview

This repository contains two products:

1. **`run-agent.sh`** -- A unified shell script that launches AI Agents (Claude, Codex, Gemini) with full isolation and traceability
2. **`THE_PROMPT_v5.md`** -- A 13-stage orchestration workflow that coordinates AI Agents into a parallel development team

Supporting files: role-specific prompts (`THE_PROMPT_v5_*.md`), monitoring scripts, and a Hugo-based website.

---

## Build & Development

| Setting | Value |
|---------|-------|
| **Site Generator** | Hugo (ananke theme v2) |
| **Site Build** | Container-based (`hugomods/hugo:exts-0.145.0`) -- never install Hugo locally |
| **Site URL** | https://run-agent.jonnyzzz.com |
| **CI/CD** | Local Docker Compose workflow (`docker-compose.yml`) |
| **Language** | Shell (bash), Python (monitoring), Markdown (prompts, site content) |
| **Package Manager** | `uv` for Python dependencies |

---

## AI Agent Roles

| Role | Prompt File | Purpose |
|------|------------|---------|
| **Orchestrator** | `THE_PROMPT_v5_orchestrator.md` | Coordinates the swarm, spawns sub-agents |
| **Research** | `THE_PROMPT_v5_research.md` | Codebase exploration, no code changes |
| **Implementation** | `THE_PROMPT_v5_implementation.md` | Code changes and tests |
| **Review** | `THE_PROMPT_v5_review.md` | Code review and quality checks |
| **Test** | `THE_PROMPT_v5_test.md` | Test execution and verification |
| **Debug** | `THE_PROMPT_v5_debug.md` | Investigate failures, propose fixes |
| **Monitor** | `THE_PROMPT_v5_monitor.md` | Periodic status checks and restarts |

---

## Supported AI Agent CLIs

| AI Agent | CLI | Flags |
|----------|-----|-------|
| **Claude** | `claude` | `-p --tools default --permission-mode bypassPermissions` |
| **Codex** | `codex` | `exec --dangerously-bypass-approvals-and-sandbox` |
| **Gemini** | `gemini` | `--screen-reader true --approval-mode yolo` |

---

## Tool Access

| Tool | Access |
|------|--------|
| [MCP Steroid](https://mcp-steroid.jonnyzzz.com) | Full -- quality gates, inspections, builds |
| Playwright MCP | Full |
| File operations | Full |
| Web search | Full |
| Bash commands | Build and test only |

---

## Conventions

### Naming

- Write **AI Agent** (singular) or **AI Agents** (plural) -- always capitalized
- Product names: `run-agent.sh` (The Runner), `THE_PROMPT_v5.md` (The Brain)
- MCP Steroid plugin: always link to https://mcp-steroid.jonnyzzz.com

### Git Commits

Format: `<type>(<scope>): <description>`

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`

### Site Development

- Hugo site lives in `content/`, `layouts/`, `static/`
- Always build Hugo in a container, never install locally
- Use `docker compose run --rm hugo-build` for the standard local production build
- Use `docker compose up hugo-serve` for local preview at `http://localhost:1313`
- Compose commands use Hugo `--forceSyncStatic` so static assets are recopied on each run
- Custom CSS in `static/css/custom.css`, use JetBrains Mono for code

---

## Communication Protocol

All AI Agents must:
1. Write significant findings to `MESSAGE-BUS.md`
2. Monitor `MESSAGE-BUS.md` for questions addressed to them
3. Log errors to `ISSUES.md`
4. Report completion via `MESSAGE-BUS.md`

---

## Author

[Eugene Petrenko](https://jonnyzzz.com) ([@jonnyzzz](https://github.com/jonnyzzz))
